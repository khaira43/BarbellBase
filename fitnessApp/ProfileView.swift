//
//  ProfileView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-07-20.
//

import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var user: DBUser? = nil
    
    func loadCurrentUser() async throws {
        let authDataResult = try AuthenticationManager.shared.getAuthenticatedUser()
        self.user = try await UserManager.shared.getUser(userId: authDataResult.uid)
    }
    
    func togglePremiumStatus() {
        guard var user else { return }
        let currentValue = user.isPremium ?? false
        Task{
            try await UserManager.shared.updateUserPremiumStatus(userId: user.userId,isPremium: !currentValue)
            self.user = try await UserManager.shared.getUser(userId: user.userId)
        }
    }
}
struct ProfileView: View {

    @StateObject private var viewModel = ProfileViewModel()
    @Binding var showSignInView: Bool

    var body: some View {
        List {
            if let user = viewModel.user {
                Section("Account") {
                    if let email = user.email {
                        LabeledContent("Email", value: email)
                    }
                    LabeledContent("User ID", value: String(user.userId.prefix(8)) + "…")
                    if let isAnonymous = user.isAnonymous {
                        LabeledContent("Anonymous", value: isAnonymous ? "Yes" : "No")
                    }
                }

                Section("Membership") {
                    Button {
                        viewModel.togglePremiumStatus()
                    } label: {
                        HStack {
                            Text("Premium")
                            Spacer()
                            Text((user.isPremium ?? false) ? "Active" : "Inactive")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            try? await viewModel.loadCurrentUser()
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView(showSignInView: $showSignInView)
                } label: {
                    Image(systemName: "gear")
                        .font(.headline)
                }
            }
        }
    }
}

#Preview {
    ProfileView(showSignInView: .constant(false))
}
