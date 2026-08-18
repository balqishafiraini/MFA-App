//
//  SecureStorageService+Audit.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

extension SecureStorageService {
    func findSensitiveKeysInUserDefaults() -> [String] {
        let forbidden = ["keyid", "privatekey", "challenge", "nonce", "signature", "secret"]

        return UserDefaults.standard.dictionaryRepresentation().keys.filter { key in
            let lowered = key.lowercased()
            return forbidden.contains { lowered.contains($0) }
        }
    }
}
