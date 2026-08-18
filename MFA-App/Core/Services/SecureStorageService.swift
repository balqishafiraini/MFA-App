//
//  SecureStorageService.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import Security

final class SecureStorageService {
    static let shared = SecureStorageService()

    private let service = "id.mfaapp.credentials"
    private let keyIdAccount = "keyId"
    private let activeSlotAccount = "activeKeySlot"

    func saveKeyId(_ keyId: String) throws {
        try save(value: keyId, account: keyIdAccount)
    }

    func loadKeyId() -> String? {
        load(account: keyIdAccount)
    }

    func saveActiveKeySlot(_ slot: KeySlot) throws {
        try save(value: slot.rawValue, account: activeSlotAccount)
    }

    func loadActiveKeySlot() -> KeySlot? {
        load(account: activeSlotAccount).flatMap(KeySlot.init(rawValue:))
    }

    func clear() {
        delete(account: keyIdAccount)
        delete(account: activeSlotAccount)
    }

    private func save(value: String, account: String) throws {
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "SecureStorageService", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Failed to save to Keychain (status \(status))"
            ])
        }
    }

    private func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
