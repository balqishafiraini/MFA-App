//
//  DeviceIntegrityService+Jailbreak.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import UIKit

extension DeviceIntegrityService {

    static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return hasSuspiciousFiles()
            || canWriteOutsideSandbox()
            || hasSuspiciousSymlinks()
            || canOpenCydiaURL()
        #endif
    }

    private static func hasSuspiciousFiles() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/Installer.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/db/stash",
            "/var/checkra1n.dmg",
            "/.installed_unc0ver"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private static func canWriteOutsideSandbox() -> Bool {
        let path = "/private/jailbreak_test_\(UUID().uuidString).txt"

        guard (try? "test".write(toFile: path, atomically: true, encoding: .utf8)) != nil else {
            return false
        }

        try? FileManager.default.removeItem(atPath: path)
        return true
    }

    private static func hasSuspiciousSymlinks() -> Bool {
        let paths = [
            "/Applications", "/Library/Ringtones", "/Library/Wallpaper",
            "/usr/include", "/usr/libexec", "/usr/share"
        ]

        return paths.contains { path in
            let type = try? FileManager.default.attributesOfItem(atPath: path)[.type] as? FileAttributeType
            return type == .typeSymbolicLink
        }
    }

    private static func canOpenCydiaURL() -> Bool {
        guard let url = URL(string: "cydia://package/com.example.package") else { return false }
        guard !Thread.isMainThread else { return UIApplication.shared.canOpenURL(url) }

        var result = false
        DispatchQueue.main.sync { result = UIApplication.shared.canOpenURL(url) }
        return result
    }
}
