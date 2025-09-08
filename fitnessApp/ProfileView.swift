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
        guard let user else { return }
        let currentValue = user.isPremium ?? false
        let updatedUser = DBUser(userId: user.userId, isAnonymous: user.isAnonymous, email: user.email, photoUrl: user.photoUrl, dateCreated: user.dateCreated, isPremium: !currentValue)
        Task{
            try await UserManager.shared.updateUserPremiumStatus(user: updatedUser)
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
                Text("UserId: \(user.userId)")
                if let isAnonymous = user.isAnonymous {
                    Text("Is Anonymous: \(isAnonymous.description.capitalized)")
                }
                Button {
                    viewModel.togglePremiumStatus()
                    
                } label: {
                    Text("User is premium: \((user.isPremium ?? false).description.capitalized)")
                }
            }
            
        }
        .task {
            try? await viewModel.loadCurrentUser()
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink {
//
//                }
                Image(systemName: "gear")
                    .font(.headline)
            }
        }
    }
}

#Preview {
    ProfileView(showSignInView: .constant(false))
}
