//
//  RegisterView.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

struct RegisterView: View {
    var onRegistered: () -> Void

    @StateObject private var viewModel = RegisterViewModel()

    @StateObject private var checklist = SecurityChecklistViewModel(includesKeyChecks: false)

    var body: some View {
        content
            .onChange(of: viewModel.state) { _, newValue in
                handle(newValue)
            }
    }

    private func handle(_ state: ViewState) {
        switch state {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task {
                try? await Task.sleep(for: .seconds(0.8))
                onRegistered()
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
            welcomeContent
        case .loading, .success:
            centered { registeringContent }
        case .failed(let message):
            centered { failedContent(message) }
        }
    }

    private func centered<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        VStack {
            Spacer()
            inner()
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomeContent: some View {
        NavigationStack {
            List {
                Section {
                    introHeader
                }

                Section {
                    ForEach(checklist.deviceChecks) { check in
                        CheckRow(check: check)
                    }
                    CheckRow(check: checklist.backendCheck)
                } header: {
                    Text("Checking Your Device")
                } footer: {
                    Text("These run automatically. Pull down to check again.")
                }
            }
            .navigationTitle("Set Up")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                checklist.run()
            }
            .task {
                checklist.run()
            }
            .safeAreaInset(edge: .bottom) {
                registerBar
            }
        }
    }

    private var introHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("Welcome")
                .font(.title.bold())

            Text("Log in without a password. This app keeps a key inside your iPhone's secure chip and uses Face ID to prove it's you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var registerBar: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.register()
            } label: {
                Text("Register This Device")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!checklist.allPassed)

            Text(checklist.allPassed
                 ? "Face ID will be asked once to create your key."
                 : "Waiting for the checks above to pass.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var registeringContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)

            Text("Setting up your device...")
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            FlowStepList(currentStep: viewModel.currentStep, isFinished: viewModel.state == .success)
        }
    }

    private func failedContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Setup didn't finish")
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                viewModel.retry()
                checklist.run()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
