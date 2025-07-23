//
//  SignUpView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-16.
//

import FirebaseAuth
import SwiftUI

struct SignUpView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var errorMessage: String?
    @Binding var successMessage: String?
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Create Account")
                    .font(.title2)
                    .fontWeight(.bold)

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.black)
                    .cornerRadius(10)

                // Password Field
                HStack {
                    Group {
                        if isPasswordVisible {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .autocapitalization(.none)
                    .padding()
                    .foregroundColor(.black)

                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(
                            systemName: isPasswordVisible ? "eye.slash" : "eye"
                        )
                        .foregroundColor(.gray)
                    }
                    .padding(.trailing, 8)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

                // Confirm Password Field
                HStack {
                    Group {
                        if isConfirmPasswordVisible {
                            TextField(
                                "Confirm Password",
                                text: $confirmPassword
                            )
                        } else {
                            SecureField(
                                "Confirm Password",
                                text: $confirmPassword
                            )
                        }
                    }
                    .autocapitalization(.none)
                    .padding()
                    .foregroundColor(.black)

                    Button(action: {
                        isConfirmPasswordVisible.toggle()
                    }) {
                        Image(
                            systemName: isConfirmPasswordVisible
                                ? "eye.slash" : "eye"
                        )
                        .foregroundColor(.gray)
                    }
                    .padding(.trailing, 8)
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

                Button("Sign Up") {
                    Task {
                        // ✅ Clear old messages
                        errorMessage = nil
                        successMessage = nil

                        guard email.contains("@"), email.contains(".") else {
                            errorMessage = "Please enter a valid email."
                            return
                        }

                        guard password == confirmPassword else {
                            errorMessage = "Passwords do not match."
                            return
                        }

                        guard !password.isEmpty else {
                            errorMessage = "Password cannot be empty."
                            return
                        }
                        do {
                            try await AuthenticationManager.shared.createUser(
                                email: email,
                                password: password
                            )
                            successMessage = "Account created successfully."
                        } catch {
                            if let err = error as NSError? {
                                switch err.code {
                                case AuthErrorCode.emailAlreadyInUse.rawValue:
                                    errorMessage =
                                        "That email is already in use."
                                case AuthErrorCode.invalidEmail.rawValue:
                                    errorMessage =
                                        "Please enter a valid email address."
                                case AuthErrorCode.weakPassword.rawValue:
                                    errorMessage =
                                        "Password should be at least 6 characters."
                                default:
                                    errorMessage =
                                        "Sign up failed: \(err.localizedDescription)"
                                }
                            } else {
                                errorMessage = "An unknown error occurred."
                            }
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
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                if let success = successMessage {
                    Text(success)
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
    SignUpView(
        email: .constant(""),
        password: .constant(""),
        confirmPassword: .constant(""),
        errorMessage: .constant(nil),
        successMessage: .constant(nil)
    )
}
