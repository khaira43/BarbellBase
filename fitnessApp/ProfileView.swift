//
//  ProfileView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-07-20.
//

import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var user: AuthDataResultModel? = nil
    
    func loadCurrentUser() throws {
        self.user = try AuthenticationManager.shared.getAuthenticatedUser()
    }
}
struct ProfileView: View {
    
    @StateObject private var viewModel = ProfileViewModel()
    @Binding var showSignInView: Bool
    
    var body: some View {
        List {
            if let user = viewModel.user {
                Text("UserId: \(user.uid)")
            }
            
        }
        .onAppear {
            try? viewModel.loadCurrentUser()
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
