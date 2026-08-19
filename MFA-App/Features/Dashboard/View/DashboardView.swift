//
//  DashboardView.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

struct DashboardView: View {
    var onLogOut: () -> Void
    var onUnregistered: () -> Void

    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var checklist = SecurityChecklistViewModel(includesKeyChecks: true)

    var body: some View {
        NavigationStack {
            List {
                keySection
                deviceSection
                actionsSection
                unregisterSection
            }
            .navigationTitle("Security")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log Out") { onLogOut() }
                }
            }
            .refreshable {
                checklist.run()
            }
            .task {
                checklist.run()
            }
            .onChange(of: viewModel.rotateStatus) { _, newValue in
                guard case .success = newValue else { return }
                checklist.run()
            }
            .unregisterConfirmation(isPresented: $viewModel.showUnregisterConfirm) {
                viewModel.unregister()
                onUnregistered()
            }
        }
    }

    private var keySection: some View {
        Section {
            ForEach(checklist.keyChecks) { check in
                CheckRow(check: check)
            }
        } header: {
            Text("Your Login Key")
        } footer: {
            Text("Each line here is tested on the spot, not just claimed.")
        }
    }

    private var deviceSection: some View {
        Section("This Device") {
            ForEach(checklist.deviceChecks) { check in
                CheckRow(check: check)
            }
            CheckRow(check: checklist.backendCheck)
        }
    }

    private var actionsSection: some View {
        Section {
            ActionRow(
                title: "Replace My Key",
                systemImage: "arrow.triangle.2.circlepath",
                status: viewModel.rotateStatus
            ) {
                viewModel.rotateKey()
            }

        } header: {
            Text("Things You Can Try")
        } footer: {
            Text("Tap a row to run it. Replacing your key asks for Face ID and you stay logged in.")
        }
    }

    private var unregisterSection: some View {
        Section {
            Button("Remove This Device", role: .destructive) {
                viewModel.showUnregisterConfirm = true
            }
        } footer: {
            Text("Deletes your key from this iPhone. You'd need to set it up again from scratch.")
        }
    }
}
