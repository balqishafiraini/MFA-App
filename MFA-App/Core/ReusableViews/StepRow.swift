//
//  StepRow.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

enum StepStatus {
    case pending
    case active
    case done

    var backgroundColor: Color {
        switch self {
        case .pending: return Color.gray.opacity(0.25)
        case .active: return .accentColor
        case .done: return .green
        }
    }
}

struct StepRow: View {
    let title: String
    let systemImage: String
    let status: StepStatus

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.backgroundColor)
                    .frame(width: 30, height: 30)

                if status == .active {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: status == .done ? "checkmark" : systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: status.backgroundColor)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(status == .pending ? .secondary : .primary)

            Spacer()
        }
    }
}
