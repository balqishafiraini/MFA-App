//
//  CertificatePinningDelegate.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import CryptoKit

final class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedPublicKeyHash: String

    init(pinnedPublicKeyHash: String) {
        self.pinnedPublicKeyHash = pinnedPublicKeyHash
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let publicKeyHash = Self.publicKeyHash(of: serverTrust),
              publicKeyHash == pinnedPublicKeyHash
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    private static func publicKeyHash(of serverTrust: SecTrust) -> String? {
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leaf = chain.first,
              let publicKey = SecCertificateCopyKey(leaf),
              let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
        else { return nil }

        return SHA256.hash(data: keyData).map { String(format: "%02x", $0) }.joined()
    }
}
