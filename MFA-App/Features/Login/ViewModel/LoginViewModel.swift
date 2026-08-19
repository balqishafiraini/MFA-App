//
//  LoginViewModel.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var state: ViewState = .idle
    @Published private(set) var currentStep: AuthStep?

    private let authService = AuthenticationService.shared

    #if DEBUG
    @Published var showUnregisterConfirm = false

    private let registerService = RegisterService.shared

    func unregister() {
        registerService.resetRegistration()
    }
    #endif

    func authenticate() {
        state = .loading
        currentStep = nil

        Task {
            do {
                let verified = try await authService.authenticate(onStep: { [weak self] step in
                    self?.currentStep = step
                })
                state = verified ? .success : .failed("Verification failed.")
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
