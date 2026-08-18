//
//  AuthenticationService.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

enum AuthStep: Int, CaseIterable, FlowStep {
    case fetchingChallenge
    case signingChallenge
    case verifyingWithServer

    var title: String {
        switch self {
        case .fetchingChallenge: return "Getting a one-time code from the server"
        case .signingChallenge: return "Signing it with Face ID / Touch ID"
        case .verifyingWithServer: return "Server is verifying your signature"
        }
    }

    var systemImage: String {
        switch self {
        case .fetchingChallenge: return "arrow.down.circle"
        case .signingChallenge: return "faceid"
        case .verifyingWithServer: return "checkmark.shield"
        }
    }
}

enum AuthenticationServiceError: LocalizedError {
    case notRegistered

    var errorDescription: String? {
        switch self {
        case .notRegistered: return "No device registered yet. Please register first."
        }
    }
}

final class AuthenticationService {
    static let shared = AuthenticationService()
    private init() {}

    private let crypto = CryptoService.shared
    private let storage = SecureStorageService.shared
    private let fingerprint = FingerprintService.shared
    private let network = NetworkService.shared

    func authenticate(onStep: ((AuthStep) -> Void)? = nil) async throws -> Bool {
        guard let keyId = storage.loadKeyId() else {
            throw AuthenticationServiceError.notRegistered
        }

        let slot = crypto.activeSlot

        do {
            return try await signIn(keyId: keyId, using: slot, onStep: onStep)
        } catch {
            guard isInterruptedRotation(error, activeSlot: slot) else { throw error }
            return try await finishInterruptedRotation(keyId: keyId, staleSlot: slot, onStep: onStep)
        }
    }

    private func signIn(keyId: String, using slot: KeySlot, onStep: ((AuthStep) -> Void)?) async throws -> Bool {
        onStep?(.fetchingChallenge)
        let challenge = try await network.challenge(keyId: keyId)

        onStep?(.signingChallenge)
        let signature = try crypto.sign(message: challenge.signedMessage, in: slot)

        onStep?(.verifyingWithServer)
        let response = try await network.verify(
            VerifyRequest(
                keyId: keyId,
                signature: signature,
                fingerprint: fingerprint.hashedFingerprint()
            )
        )
        return response.verified
    }

    private func isInterruptedRotation(_ error: Error, activeSlot: KeySlot) -> Bool {
        guard (error as? NetworkError)?.isUnauthorized == true else { return false }
        return crypto.hasStoredKey(in: activeSlot.next)
    }

    private func finishInterruptedRotation(
        keyId: String,
        staleSlot: KeySlot,
        onStep: ((AuthStep) -> Void)?
    ) async throws -> Bool {
        let verified = try await signIn(keyId: keyId, using: staleSlot.next, onStep: onStep)
        guard verified else { return false }

        try crypto.activate(staleSlot.next)
        return true
    }
}
