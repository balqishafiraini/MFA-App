//
//  SecurityAuditService+KeyChecks.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

extension SecurityAuditService {

    static func keyChecks() -> [SecurityCheck] {
        let slot = CryptoService.shared.activeSlot

        return [
            keyPresenceCheck(slot),
            nonExportableCheck(slot),
            ecdsaCheck(slot),
            fingerprintHashCheck(),
            localStorageCheck()
        ]
    }

    private static func keyPresenceCheck(_ slot: KeySlot) -> SecurityCheck {
        SecurityCheck(
            id: "keyPresence",
            title: "Key Saved in Secure Chip",
            status: CryptoService.shared.hasStoredKey(in: slot)
                ? .passed("Your login key lives inside the Secure Enclave")
                : .failed("No key found — register this device first")
        )
    }

    private static func nonExportableCheck(_ slot: KeySlot) -> SecurityCheck {
        SecurityCheck(
            id: "nonExportable",
            title: "Key Cannot Be Copied Out",
            status: status(forKeyIn: slot) {
                CryptoService.shared.canExportPrivateKey(in: slot)
                    ? .failed("The key could be copied out — it isn't really in the chip!")
                    : .passed("We tried to copy the key out and the chip refused")
            }
        )
    }

    private static func ecdsaCheck(_ slot: KeySlot) -> SecurityCheck {
        SecurityCheck(
            id: "ecdsa",
            title: "Signing Method (ECDSA P-256)",
            status: status(forKeyIn: slot) {
                CryptoService.shared.supportsECDSAP256Signing(in: slot)
                    ? .passed("The key can sign logins using ECDSA P-256")
                    : .failed("The key can't sign with ECDSA P-256")
            }
        )
    }

    private static func fingerprintHashCheck() -> SecurityCheck {
        let hash = FingerprintService.shared.hashedFingerprint()
        let looksLikeSHA256 = hash.count == 64 && hash.allSatisfy(\.isHexDigit)

        return SecurityCheck(
            id: "fingerprintHash",
            title: "Device Details Are Scrambled",
            status: looksLikeSHA256
                ? .passed("Sent as a SHA-256 hash, never as readable device info")
                : .failed("Device info isn't being hashed properly")
        )
    }

    private static func localStorageCheck() -> SecurityCheck {
        let leaked = SecureStorageService.shared.findSensitiveKeysInUserDefaults()

        return SecurityCheck(
            id: "localStorage",
            title: "Nothing Secret Left on Disk",
            status: leaked.isEmpty
                ? .passed("Checked app storage — nothing sensitive saved there")
                : .failed("Found sensitive values saved: \(leaked.joined(separator: ", "))")
        )
    }
 
    private static func status(forKeyIn slot: KeySlot, test: () -> CheckStatus) -> CheckStatus {
        guard CryptoService.shared.hasStoredKey(in: slot) else {
            return .failed("No key to test yet")
        }
        return test()
    }
}
