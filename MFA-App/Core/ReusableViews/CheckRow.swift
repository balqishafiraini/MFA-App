//
//  CheckRow.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

struct CheckRow: View {
    let check: SecurityCheck

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(check.title)
                    .font(.subheadline)

                Text(check.status.detail)
                    .font(.caption)
                    .foregroundStyle(detailColor)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var icon: some View {
        switch check.status {
        case .checking:
            ProgressView()
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private var detailColor: Color {
        switch check.status {
        case .failed: return .red
        case .passed, .checking: return .secondary
        }
    }
}
