//
//  CryptoService+Keychain.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import Security

extension CryptoService {
    func loadPrivateKey(in slot: KeySlot) -> SecKey? {
        var item: CFTypeRef?
        let query = Self.query(for: slot, returningReference: true)
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        guard CFGetTypeID(item) == SecKeyGetTypeID() else { return nil }
        return (item as! SecKey)
    }

    func deleteKey(in slot: KeySlot) {
        SecItemDelete(Self.query(for: slot, returningReference: false) as CFDictionary)
    }

    func deleteAllKeys() {
        deleteKey(in: .a)
        deleteKey(in: .b)
    }

    func hasStoredKey(in slot: KeySlot) -> Bool {
        loadPrivateKey(in: slot) != nil
    }

    private static func query(for slot: KeySlot, returningReference: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: slot.tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]
        if returningReference {
            query[kSecReturnRef as String] = true
        }
        return query
    }
}
