//
//  CryptoService.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import Security

enum CryptoServiceError: LocalizedError {
    case secureEnclaveUnavailable
    case keyGenerationFailed(String)
    case publicKeyExportFailed
    case keyNotFound
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .secureEnclaveUnavailable:
            return "This device doesn't have a Secure Enclave (Simulator not supported). Please run on a physical iPhone."
        case .keyGenerationFailed(let reason):
            return "Failed to generate key pair: \(reason)"
        case .publicKeyExportFailed:
            return "Failed to export public key."
        case .keyNotFound:
            return "Private key not found in Secure Enclave. Please register again."
        case .signingFailed(let reason):
            return "Failed to sign challenge: \(reason)"
        }
    }
}

final class CryptoService {
    static let shared = CryptoService()

    private let storage: SecureStorageService

    init(storage: SecureStorageService = .shared) {
        self.storage = storage
    }

    var activeSlot: KeySlot {
        storage.loadActiveKeySlot() ?? .a
    }

    func activate(_ slot: KeySlot) throws {
        try storage.saveActiveKeySlot(slot)
        deleteKey(in: slot.next)
    }

    var isSecureEnclaveAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    @discardableResult
    func generateKeyPair(in slot: KeySlot) throws -> SecKey {
        guard isSecureEnclaveAvailable else {
            throw CryptoServiceError.secureEnclaveUnavailable
        }

        deleteKey(in: slot)

        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        ) else {
            throw CryptoServiceError.keyGenerationFailed("SecAccessControlCreateWithFlags returned nil")
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: slot.tag,
                kSecAttrAccessControl as String: access
            ]
        ]

        var cfError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &cfError) else {
            throw CryptoServiceError.keyGenerationFailed(Self.message(from: cfError))
        }
        return privateKey
    }

    func exportPublicKeyBase64(privateKey: SecKey) throws -> String {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CryptoServiceError.publicKeyExportFailed
        }

        var cfError: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &cfError) as Data? else {
            _ = cfError?.takeRetainedValue()
            throw CryptoServiceError.publicKeyExportFailed
        }
        return data.base64EncodedString()
    }

    func sign(message: Data, in slot: KeySlot) throws -> String {
        guard let privateKey = loadPrivateKey(in: slot) else {
            throw CryptoServiceError.keyNotFound
        }

        var cfError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            message as CFData,
            &cfError
        ) as Data? else {
            throw CryptoServiceError.signingFailed(Self.message(from: cfError))
        }
        return signature.base64EncodedString()
    }

    private static func message(from cfError: Unmanaged<CFError>?) -> String {
        guard let error = cfError?.takeRetainedValue() else { return "unknown" }
        return (error as Error).localizedDescription
    }
}
