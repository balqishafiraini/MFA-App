//
//  BlockedView.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

struct BlockedView: View {
    let reason: SecurityBlockReason

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 88, height: 88)
                Image(systemName: reason.systemImage)
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
            }

            Text(reason.title)
                .font(.title2.bold())

            Text(reason.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}

#Preview {
    BlockedView(reason: .jailbroken)
}
