//
//  SecurityAuditService+DeviceChecks.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import LocalAuthentication

extension SecurityAuditService {

    static func deviceChecks() -> [SecurityCheck] {
        [
            secureEnclaveCheck(),
            biometryCheck(),
            jailbreakCheck(),
            tamperingCheck(),
            pinConfiguredCheck()
        ]
    }

    private static func secureEnclaveCheck() -> SecurityCheck {
        SecurityCheck(
            id: "secureEnclave",
            title: "Secure Chip",
            status: CryptoService.shared.isSecureEnclaveAvailable
                ? .passed("This device has a Secure Enclave chip for keys")
                : .failed("Not available — the Simulator has no secure chip")
        )
    }

    private static func biometryCheck() -> SecurityCheck {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        return SecurityCheck(
            id: "biometry",
            title: "Face ID / Touch ID",
            status: canEvaluate
                ? .passed("\(biometryName(for: context.biometryType)) is set up and ready to use")
                : .failed(biometryProblem(error))
        )
    }

    private static func biometryName(for type: LABiometryType) -> String {
        switch type {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometrics"
        }
    }

    private static func biometryProblem(_ error: NSError?) -> String {
        guard let code = error.map({ LAError.Code(rawValue: $0.code) }) else {
            return "Not available on this device"
        }

        switch code {
        case .biometryNotEnrolled:
            return "Not set up yet — add Face ID or Touch ID in Settings"
        case .biometryLockout:
            return "Locked after too many failed attempts — unlock with your passcode"
        default:
            return "Not available on this device"
        }
    }

    private static func jailbreakCheck() -> SecurityCheck {
        SecurityCheck(
            id: "jailbreak",
            title: "System Not Modified",
            status: DeviceIntegrityService.isJailbroken()
                ? .failed("Signs of jailbreak found — the app can't run safely here")
                : .passed("No signs of jailbreak found")
        )
    }

    private static func tamperingCheck() -> SecurityCheck {
        SecurityCheck(id: "tampering", title: "No Debugger Attached", status: tamperingStatus())
    }

    private static func tamperingStatus() -> CheckStatus {
        #if DEBUG
        return .passed("Skipped while testing from Xcode")
        #else
        if DeviceIntegrityService.isDebuggerAttached() {
            return .failed("Something is inspecting the app")
        }
        if DeviceIntegrityService.hasSuspiciousDylibInjection() {
            return .failed("Unknown code was injected into the app")
        }
        return .passed("Nothing is inspecting the app")
        #endif
    }

    private static func pinConfiguredCheck() -> SecurityCheck {
        SecurityCheck(id: "pinConfig", title: "Server Identity Locked", status: pinConfigStatus())
    }

    private static func pinConfigStatus() -> CheckStatus {
        guard AppConfig.backendBaseURL.scheme == "https" else {
            return .failed("The server address must start with https://")
        }

        let hash = AppConfig.pinnedPublicKeyHash
        guard hash.count == 64, hash.allSatisfy(\.isHexDigit) else {
            return .failed("The saved certificate fingerprint looks invalid")
        }

        return .passed("The app only trusts one specific server certificate")
    }
}
