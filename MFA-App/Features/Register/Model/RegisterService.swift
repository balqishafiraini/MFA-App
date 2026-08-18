//
//  RegisterService.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

enum RegisterStep: Int, CaseIterable, FlowStep {
    case generatingKey
    case exportingPublicKey
    case computingFingerprint
    case registeringWithServer

    var title: String {
        switch self {
        case .generatingKey: return "Creating your key in the secure chip"
        case .exportingPublicKey: return "Preparing the public half of the key"
        case .computingFingerprint: return "Building this device's fingerprint"
        case .registeringWithServer: return "Registering with the server"
        }
    }

    var systemImage: String {
        switch self {
        case .generatingKey: return "key.fill"
        case .exportingPublicKey: return "square.and.arrow.up"
        case .computingFingerprint: return "number"
        case .registeringWithServer: return "server.rack"
        }
    }
}

enum KeyRotationError: LocalizedError {
    case notRegistered

    var errorDescription: String? {
        switch self {
        case .notRegistered: return "No device registered yet. Please register first."
        }
    }
}

final class RegisterService {
    static let shared = RegisterService()
    private init() {}

    private let crypto = CryptoService.shared
    private let storage = SecureStorageService.shared
    private let fingerprint = FingerprintService.shared
    private let network = NetworkService.shared

    var isRegistered: Bool {
        storage.loadKeyId() != nil
    }

    @discardableResult
    func register(onStep: ((RegisterStep) -> Void)? = nil) async throws -> String {
        let slot = KeySlot.a

        onStep?(.generatingKey)
        let privateKey = try crypto.generateKeyPair(in: slot)

        onStep?(.exportingPublicKey)
        let publicKeyBase64 = try crypto.exportPublicKeyBase64(privateKey: privateKey)

        onStep?(.computingFingerprint)
        let device = fingerprint.current()

        onStep?(.registeringWithServer)
        let response = try await network.register(
            RegisterRequest(
                deviceId: device.vendorId,
                publicKey: publicKeyBase64,
                fingerprint: device.sha256Hex
            )
        )

        try crypto.activate(slot)
        try storage.saveKeyId(response.keyId)
        return response.keyId
    }

    func rotateKey() async throws {
        guard let keyId = storage.loadKeyId() else {
            throw KeyRotationError.notRegistered
        }

        let currentSlot = crypto.activeSlot
        let nextSlot = currentSlot.next

        // 1. Prove the request comes from the device the server already trusts.
        let challenge = try await network.challenge(keyId: keyId)
        let proof = try crypto.sign(message: challenge.signedMessage, in: currentSlot)

        // 2. Build the replacement alongside the old key — nothing destroyed yet.
        let newPrivateKey = try crypto.generateKeyPair(in: nextSlot)
        let newPublicKey = try crypto.exportPublicKeyBase64(privateKey: newPrivateKey)

        // 3. Server verifies with the OLD public key, then stores the new one.
        _ = try await network.rotate(
            RotateRequest(keyId: keyId, newPublicKey: newPublicKey, signature: proof)
        )

        // 4. Only now switch over and drop the old key.
        try crypto.activate(nextSlot)
    }

    func resetRegistration() {
        crypto.deleteAllKeys()
        storage.clear()
    }
}
