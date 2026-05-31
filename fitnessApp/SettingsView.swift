//
//  SettingsView.swift
//  fitnessApp
//

import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    func signOut() throws {
        try AuthenticationManager.shared.signOut()
    }

    func resetPassword() async throws {
        let authUser = try AuthenticationManager.shared.getAuthenticatedUser()
        guard let email = authUser.email else {
            throw URLError(.badServerResponse)
        }
        try await AuthenticationManager.shared.resetPassword(email: email)
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Binding var showSignInView: Bool
    @State private var resetSent = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Account") {
                Button {
                    Task {
                        do {
                            try await viewModel.resetPassword()
                            resetSent = true
                            errorMessage = nil
                        } catch {
                            errorMessage = "Couldn't send reset email."
                        }
                    }
                } label: {
                    Text("Reset Password")
                }

                if resetSent {
                    Text("Reset email sent.")
                        .font(.footnote)
                        .foregroundColor(.green)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    do {
                        try viewModel.signOut()
                        showSignInView = true
                    } catch {
                        errorMessage = "Couldn't sign out."
                    }
                } label: {
                    Text("Sign Out")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView(showSignInView: .constant(false))
    }
}
