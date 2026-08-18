//
//  UnregisterConfirmation.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import SwiftUI

extension View {
    func unregisterConfirmation(isPresented: Binding<Bool>, onConfirm: @escaping () -> Void) -> some View {
        alert("Remove this device?", isPresented: isPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive, action: onConfirm)
        } message: {
            Text("Your key will be deleted from this iPhone. You'll have to set the device up again to log in.")
        }
    }
}
