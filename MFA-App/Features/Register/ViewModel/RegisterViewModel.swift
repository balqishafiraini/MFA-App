//
//  RegisterViewModel.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import Combine

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published private(set) var state: ViewState = .idle
    @Published private(set) var currentStep: RegisterStep?

    private let registerService = RegisterService.shared

    func register() {
        state = .loading
        currentStep = nil

        Task {
            do {
                try await registerService.register(onStep: { [weak self] step in
                    self?.currentStep = step
                })
                state = .success
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func retry() {
        state = .idle
        currentStep = nil
    }
}
