//
//  SecurityBlockReason.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

enum SecurityBlockReason: CaseIterable {
    case simulator
    case jailbroken
    case tampering

    static func current() -> SecurityBlockReason? {
        allCases.first { $0.isTriggered }
    }

    var isTriggered: Bool {
        switch self {
        case .simulator:
            return DeviceIntegrityService.isSimulator
        case .jailbroken:
            return DeviceIntegrityService.isJailbroken()
        case .tampering:
            return DeviceIntegrityService.isDebuggerAttached()
                || DeviceIntegrityService.hasSuspiciousDylibInjection()
        }
    }

    var title: String {
        switch self {
        case .simulator: return "Simulator Not Supported"
        case .jailbroken: return "Device Not Secure"
        case .tampering: return "Suspicious Activity Detected"
        }
    }

    var message: String {
        switch self {
        case .simulator:
            return "This app requires a real Secure Enclave to store the private key. Please run it on a physical iPhone, not the Simulator."
        case .jailbroken:
            return "This device appears to be jailbroken. To protect the private key and authentication data, the app cannot run on a modified device."
        case .tampering:
            return "A debugger or an injected foreign library was detected in the app's process. To protect the private key and authentication data, the app cannot continue."
        }
    }

    var systemImage: String {
        switch self {
        case .simulator: return "xmark.octagon.fill"
        case .jailbroken: return "exclamationmark.shield.fill"
        case .tampering: return "ladybug.fill"
        }
    }
}
