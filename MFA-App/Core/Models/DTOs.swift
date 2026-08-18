//
//  DTOs.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

struct RegisterRequest: Encodable {
    let deviceId: String
    let publicKey: String
    let fingerprint: String
}

struct RegisterResponse: Decodable {
    let keyId: String
}

struct ChallengeResponse: Decodable {
    let challenge: String
    let nonce: String

    var signedMessage: Data {
        Data((challenge + nonce).utf8)
    }
}

struct VerifyRequest: Encodable {
    let keyId: String
    let signature: String
    let fingerprint: String
}

struct VerifyResponse: Decodable {
    let verified: Bool
}

struct RotateRequest: Encodable {
    let keyId: String
    let newPublicKey: String
    let signature: String
}

struct RotateResponse: Decodable {
    let rotated: Bool
}
