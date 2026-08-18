//
//  SecurityChecklistViewModel.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import Combine

@MainActor
final class SecurityChecklistViewModel: ObservableObject {
    @Published private(set) var keyChecks: [SecurityCheck] = []
    @Published private(set) var deviceChecks: [SecurityCheck] = []
    @Published private(set) var backendCheck: SecurityCheck = .pendingBackend
    @Published private(set) var isRunning = false

    private let includesKeyChecks: Bool

    init(includesKeyChecks: Bool) {
        self.includesKeyChecks = includesKeyChecks
    }

    var allPassed: Bool {
        guard !isRunning, !deviceChecks.isEmpty else { return false }
        return (deviceChecks + keyChecks + [backendCheck]).allSatisfy(\.status.isPassed)
    }

    func run() {
        guard !isRunning else { return }
        isRunning = true

        let keyResults = includesKeyChecks ? SecurityAuditService.keyChecks() : []
        let deviceResults = SecurityAuditService.deviceChecks()

        keyChecks = keyResults.map(\.pending)
        deviceChecks = deviceResults.map(\.pending)
        backendCheck = .pendingBackend

        Task {
            async let backendResult = SecurityAuditService.backendCheck()

            await reveal(keyResults) { self.keyChecks[$0] = $1 }
            await reveal(deviceResults) { self.deviceChecks[$0] = $1 }

            backendCheck = await backendResult
            isRunning = false
        }
    }

    private func reveal(_ results: [SecurityCheck], assign: (Int, SecurityCheck) -> Void) async {
        for (index, result) in results.enumerated() {
            try? await Task.sleep(for: .milliseconds(200))
            assign(index, result)
        }
    }
}
