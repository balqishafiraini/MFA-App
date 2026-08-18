//
//  AppConfig.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

// MARK: Edit before build. Check README.md for more info

enum AppConfig {
    static let backendBaseURL = URL(string: "https://172.20.10.2:8443")!

    static let pinnedPublicKeyHash = "eb5f55167d0a37c3a3938a099a228ddf6fd48f22e5b22c46ee4cd42098110348"
}
