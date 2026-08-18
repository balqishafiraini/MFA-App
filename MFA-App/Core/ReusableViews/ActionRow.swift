//
//  ActionRow.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

struct ActionRow: View {
    let title: String
    let systemImage: String
    let status: ActionStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let detail = status.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(detailColor)
                    }
                }

                Spacer()

                trailing
            }
        }
        .disabled(status == .running)
    }

    @ViewBuilder
    private var trailing: some View {
        switch status {
        case .idle:
            Image(systemName: "play.circle")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private var detailColor: Color {
        switch status {
        case .failed: return .red
        case .success: return .green
        case .idle, .running: return .secondary
        }
    }
}
