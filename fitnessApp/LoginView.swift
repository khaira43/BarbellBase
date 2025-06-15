//
//  LoginView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-15.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""

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
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    // Password Field
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    // Sign In Button
                    Button(action: signIn) {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow)
                            .foregroundColor(Color(hex: "#081f3a"))
                            .cornerRadius(10)
                    }

                    // Reset Password Link
                    NavigationLink (destination: ResetPassword()) {
                        Text("Trouble signing in?")
                            .foregroundColor(.yellow)
                            .underline(true, color: .yellow)
                    }
                    

                    Spacer()

                    // Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.yellow)
                        NavigationLink(destination: ResetPassword()) {
                            Text("Sign Up")
                                .foregroundColor(.yellow)
                                .underline(true, color: .yellow)
                        }
                    }
                }
                .padding()
            }

        }
    }

    func signIn() {
        // Insert sign-in logic here (e.g., Firebase Auth)
        print("Signing in with \(email) / \(password)")
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
