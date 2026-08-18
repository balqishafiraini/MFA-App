//
//  RootViewModel.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation
import Combine

@MainActor
final class RootViewModel: ObservableObject {
    enum Screen: Equatable {
        case blocked(SecurityBlockReason)
        case register
        case login
        case dashboard
    }

    @Published private(set) var screen: Screen

    init() {
        if let reason = SecurityBlockReason.current() {
            screen = .blocked(reason)
            return
        }
        screen = RegisterService.shared.isRegistered ? .login : .register
    }

    func didRegister() {
        screen = .login
    }

    func didAuthenticate() {
        screen = .dashboard
    }

    func didLogOut() {
        screen = .login
    }

    func didUnregister() {
        screen = .register
    }
}
