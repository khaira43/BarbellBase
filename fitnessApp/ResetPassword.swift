//
//  ResetPassword.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-15.
//

import SwiftUI

struct ResetPassword: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Binding var resetEmail: String
    @Binding var resetErrorMessage: String?
    @Binding var resetSuccessMessage: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Reset Password")
                    .font(.title2)
                    .fontWeight(.bold)

                TextField("Enter your email", text: $resetEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.black)
                    .cornerRadius(10)

                Button("Send Reset Email") {
                    Task {
                        // ✅ Clear old messages
                        resetErrorMessage = nil
                        resetSuccessMessage = nil

                        guard !resetEmail.isEmpty else {
                            resetErrorMessage = "Please enter an email address."
                            return
                        }
                        do {
                            try await AuthenticationManager.shared.resetPassword(email: resetEmail)

                            resetErrorMessage = nil
                            resetSuccessMessage =
                                "A password reset email has been sent."
                        } catch {
                            resetSuccessMessage = nil
                            resetErrorMessage =
                                "Unable to find account with that email."
                        }
                    }
                }
                .fontWeight(.semibold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.yellow)
                .foregroundColor(Color(hex: "#081f3a"))
                .cornerRadius(10)

                // Show Error or Success
                if let errorMessage = resetErrorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                if let successMessage = resetSuccessMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                Spacer()

            }
            .padding()
            .background(Color(hex: "#081f3a").ignoresSafeArea())
            .foregroundColor(.white)
        }
    }
}

#Preview {
    ResetPassword(
        resetEmail: .constant(""),
        resetErrorMessage: .constant(nil),
        resetSuccessMessage: .constant(nil)
    )
}
