//
//  SecurityAuditService.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

enum SecurityAuditService {}

extension SecurityAuditService {

    static func backendCheck() async -> SecurityCheck {
        do {
            try await NetworkService.shared.healthCheck()
            return SecurityCheck(
                id: "backend",
                title: "Server Connection",
                status: .passed("Connected securely to \(AppConfig.backendBaseURL.absoluteString)")
            )
        } catch {
            return SecurityCheck(id: "backend", title: "Server Connection", status: .failed(hint(for: error)))
        }
    }

    private static func hint(for error: Error) -> String {
        let url = AppConfig.backendBaseURL.absoluteString
        let nsError = error as NSError

        guard nsError.domain == NSURLErrorDomain else {
            return "\(error.localizedDescription) (server: \(url))"
        }

        switch nsError.code {
        case NSURLErrorCancelled:
            return "The server's certificate doesn't match the one saved in the app. Run certs/generate.sh and update AppConfig."
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
            return "Secure connection failed. Is the backend running with HTTPS turned on?"
        case NSURLErrorTimedOut:
            return "Couldn't reach \(url) in time. Check the IP address, and make sure your Mac and iPhone are on the same Wi-Fi."
        case NSURLErrorCannotConnectToHost:
            return "No server found at \(url). Is the backend running on that port?"
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return "No network access. Allow Local Network for this app in Settings."
        default:
            return "\(nsError.localizedDescription) (server: \(url))"
        }
    }
}
