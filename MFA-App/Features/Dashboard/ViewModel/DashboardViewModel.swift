//
//  DashboardViewModel.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import Combine

/// Drives the actions on the Security screen. The checklist itself belongs to
/// `SecurityChecklistViewModel`.
@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var rotateStatus: ActionStatus = .idle
    @Published var showUnregisterConfirm = false

    private let registerService = RegisterService.shared

    func rotateKey() {
        rotateStatus = .running

        Task {
            do {
                try await registerService.rotateKey()
                rotateStatus = .success("New key is active, old one no longer works")
            } catch {
                rotateStatus = .failed(error.localizedDescription)
            }
        }
    }

    func unregister() {
        registerService.resetRegistration()
    }
}
