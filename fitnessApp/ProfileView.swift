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
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()

            if let user = viewModel.user {
                List {
                    Section {
                        if let email = user.email {
                            infoRow("Email", value: email)
                        }
                        infoRow("User ID", value: String(user.userId.prefix(8)) + "…")
                        if let isAnonymous = user.isAnonymous {
                            infoRow("Anonymous", value: isAnonymous ? "Yes" : "No")
                        }
                    } header: {
                        Text("Account").foregroundColor(.white.opacity(0.6))
                    }
                    .listRowBackground(Color(hex: "#0c2548"))

                    Section {
                        Button {
                            viewModel.togglePremiumStatus()
                        } label: {
                            HStack {
                                Text("Premium").foregroundColor(.yellow)
                                Spacer()
                                Text((user.isPremium ?? false) ? "Active" : "Inactive")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    } header: {
                        Text("Membership").foregroundColor(.white.opacity(0.6))
                    }
                    .listRowBackground(Color(hex: "#0c2548"))
                }
                .scrollContentBackground(.hidden)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            try? await viewModel.loadCurrentUser()
        }
        .navigationTitle("Profile")
        .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView(showSignInView: $showSignInView)
                } label: {
                    Image(systemName: "gear")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.white)
            Spacer()
            Text(value).foregroundColor(.white.opacity(0.6))
        }
    }
}

#Preview {
    ProfileView(showSignInView: .constant(false))
}
