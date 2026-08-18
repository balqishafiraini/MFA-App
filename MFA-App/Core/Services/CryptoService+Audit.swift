//
//  CryptoService+Audit.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import Security

extension CryptoService {
    func canExportPrivateKey(in slot: KeySlot) -> Bool {
        guard let privateKey = loadPrivateKey(in: slot) else { return false }

        var cfError: Unmanaged<CFError>?
        let exported = SecKeyCopyExternalRepresentation(privateKey, &cfError) as Data?
        _ = cfError?.takeRetainedValue()
        return exported != nil
    }

    func supportsECDSAP256Signing(in slot: KeySlot) -> Bool {
        guard let privateKey = loadPrivateKey(in: slot) else { return false }
        return SecKeyIsAlgorithmSupported(privateKey, .sign, .ecdsaSignatureMessageX962SHA256)
    }
}
