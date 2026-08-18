//
//  ContentView.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = RootViewModel()

    var body: some View {
        switch viewModel.screen {
        case .blocked(let reason):
            BlockedView(reason: reason)

        case .register:
            RegisterView(onRegistered: { viewModel.didRegister() })

        case .login:
            LoginView(
                onAuthenticated: { viewModel.didAuthenticate() },
                onUnregistered: { viewModel.didUnregister() }
            )

        case .dashboard:
            DashboardView(
                onLogOut: { viewModel.didLogOut() },
                onUnregistered: { viewModel.didUnregister() }
            )
        }
    }
}
