//
//  LoginView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-15.
//

import SwiftUI

@MainActor
final class SignInEmailViewModel: ObservableObject {

    @Published var email = ""
    @Published var password = ""

    func signUp() async throws {
        guard !email.isEmpty, !password.isEmpty else {
            print("No email or password is found.")
            return
        }

        let authDataResult = try await AuthenticationManager.shared.createUser(
            email: email,
            password: password
        )
        try await UserManager.shared.createNewUser(auth: authDataResult)
    }

    func signIn() async throws {
        guard !email.isEmpty, !password.isEmpty else {
            print("No email or password is found.")
            return
        }

        let authDataResult = try await AuthenticationManager.shared.signInUser(
            email: email,
            password: password
        )
        try await UserManager.shared.createNewUser(auth: authDataResult)
    }

}

struct LoginView: View {
    @StateObject private var viewModel = SignInEmailViewModel()
    @State private var isSignedIn = false
    @State private var signInErrorMessage: String?
    @State private var showingResetSheet = false
    @State private var resetEmail = ""
    @State private var resetErrorMessage: String?
    @State private var resetSuccessMessage: String?
    @State private var showingSignUpSheet = false
    @State private var signUpEmail = ""
    @State private var signUpPassword = ""
    @State private var signUpConfirmPassword = ""
    @State private var signUpErrorMessage: String?
    @State private var signUpSuccessMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a")
                    .ignoresSafeArea()

                VStack(spacing: 24) {

                    Spacer()

                    // LOGO Placeholder – Replace with your actual logo
                    Image("Barbellbase")  // Add your logo image to the Assets folder and name it "AppLogo"
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .padding(.bottom, 30)

                    // Email Field
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    // Password Field
                    SecureField("Password", text: $viewModel.password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    // Sign In Button
                    Button {
                        Task {
                            do {
//                                let authDataResult = try await AuthenticationManager.shared.signInUser(email: viewModel.email, password: viewModel.password)
//                                signInErrorMessage = nil
//                                isSignedIn = true
//                                
//                                Task{
//                                    do{
//                                        try await UserManager.shared.createNewUser(auth: authDataResult)
//                                    } catch {
//                                        print("Failed: \(error.localizedDescription)")
//                                    }
//                                }
                                try await viewModel.signIn()
                                signInErrorMessage = nil
                                isSignedIn = true
                                return
                            } catch {
                                signInErrorMessage = "Invalid email or password. Please try again. "
//                                signInErrorMessage = error.localizedDescription
//                                print("SignIn error: \(error)")
                            }
                        }
                    } label: {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow)
                            .foregroundColor(Color(hex: "#081f3a"))
                            .cornerRadius(10)
                    }

                    if let errorMessage = signInErrorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.top, -10)
                    }

                    // Reset Password Link
                    Button {
                        showingResetSheet = true
                    } label: {
                        Text("Trouble signing in?")
                            .foregroundColor(.yellow)
                            .underline(true, color: .yellow)
                    }
                    .sheet(isPresented: $showingResetSheet) {
                        ResetPassword(
                            resetEmail: $resetEmail,
                            resetErrorMessage: $resetErrorMessage,
                            resetSuccessMessage: $resetSuccessMessage
                        )
                        .presentationDetents([.fraction(0.35)])  // 👈 moved here
                        .presentationDragIndicator(.visible)
                        .onDisappear {
                            resetEmail = ""
                            resetErrorMessage = nil
                            resetSuccessMessage = nil
                        }
                    }

                    Spacer()

                    // Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.yellow)
                        Button {
                            showingSignUpSheet = true
                        } label: {
                            Text("Sign Up")
                                .foregroundColor(.yellow)
                                .underline(true, color: .yellow)
                        }
                        .sheet(isPresented: $showingSignUpSheet) {
                            SignUpView(
                                email: $signUpEmail,
                                password: $signUpPassword,
                                confirmPassword: $signUpConfirmPassword,
                                errorMessage: $signUpErrorMessage,
                                successMessage: $signUpSuccessMessage
                            )
                            .presentationDetents([.fraction(0.5)])  // 👈 moved here
                            .presentationDragIndicator(.visible)
                            .onDisappear {
                                signUpEmail = ""
                                signUpPassword = ""
                                signUpConfirmPassword = ""
                                signUpErrorMessage = nil
                                signUpSuccessMessage = nil
                            }
                        }

                    }

                    NavigationLink(
                        destination: WorkoutView(),
                        isActive: $isSignedIn
                    ) {
                        EmptyView()
                    }
                }
                .padding()
            }

        }
    }

}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (
                255, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff
            )
        case 8:
            (a, r, g, b) = (
                (int >> 24) & 0xff, (int >> 16) & 0xff, (int >> 8) & 0xff,
                int & 0xff
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LoginView()
}
