//
//  LoginView.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

struct LoginView: View {
    var onAuthenticated: () -> Void
    var onUnregistered: () -> Void

    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        VStack {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.bottom, 8)

            content

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.state) { _, newValue in
            handle(newValue)
        }
    }

    private func handle(_ state: ViewState) {
        switch state {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                onAuthenticated()
            }
        case .failed:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .idle, .loading:
            break
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            promptContent
        case .loading, .success:
            loadingContent
        case .failed(let message):
            failedContent(message)
        }
    }

    private var promptContent: some View {
        VStack(spacing: 16) {
            Text("You're all set")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Log in with Face ID to see your security details")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Log In with Face ID") {
                viewModel.authenticate()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 12)
        }
    }

    private var loadingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)

            Text("Checking that it's really you...")
                .font(.subheadline.bold())

            FlowStepList(currentStep: viewModel.currentStep, isFinished: viewModel.state == .success)
        }
    }

    private func failedContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                viewModel.authenticate()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
