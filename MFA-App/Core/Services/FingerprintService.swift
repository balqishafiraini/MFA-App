//
//  FingerprintService.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import UIKit
import Security
import CryptoKit

struct DeviceFingerprint {
    let model: String
    let osVersion: String
    let appVersion: String
    let bundleId: String
    let vendorId: String
    let teamId: String
    let hardwareSecurityAvailable: Bool

    var canonicalString: String {
        [
            "model=\(model)",
            "os=\(osVersion)",
            "appVersion=\(appVersion)",
            "bundleId=\(bundleId)",
            "vendorId=\(vendorId)",
            "teamId=\(teamId)",
            "hwSecurity=\(hardwareSecurityAvailable)"
        ].joined(separator: "|")
    }

    var sha256Hex: String {
        let digest = SHA256.hash(data: Data(canonicalString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

final class FingerprintService {
    static let shared = FingerprintService()
    private init() {}

    func current() -> DeviceFingerprint {
        DeviceFingerprint(
            model: Self.modelIdentifier(),
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            bundleId: Bundle.main.bundleIdentifier ?? "unknown",
            vendorId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            teamId: Self.teamIdentifier(),
            hardwareSecurityAvailable: CryptoService.shared.isSecureEnclaveAvailable
        )
    }

    func hashedFingerprint() -> String {
        current().sha256Hex
    }

    private static func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private static func teamIdentifier() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "id.mfaapp.teamIdentifierProbe",
            kSecReturnAttributes as String: true
        ]

        var item: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = Data("probe".utf8)
            SecItemAdd(addQuery as CFDictionary, nil)
            status = SecItemCopyMatching(query as CFDictionary, &item)
        }

        guard status == errSecSuccess,
              let attributes = item as? [String: Any],
              let accessGroup = attributes[kSecAttrAccessGroup as String] as? String
        else {
            return "unknown"
        }

        return accessGroup.components(separatedBy: ".").first ?? "unknown"
    }
}
