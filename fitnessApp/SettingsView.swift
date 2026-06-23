//
//  SettingsView.swift
//  fitnessApp
//

import SwiftUI
import FirebaseAuth

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
    @EnvironmentObject private var friendsVM: FriendsViewModel
    @Binding var showSignInView: Bool
    @State private var resetSent = false
    @State private var errorMessage: String?
    @State private var showingHandleSheet = false
    @State private var sharesFullDetails: Bool = true
    #if DEBUG
    @State private var seedStatus: String?
    @State private var isSeeding = false
    #endif

    var body: some View {
        List {
            Section("Profile") {
                Button {
                    showingHandleSheet = true
                } label: {
                    HStack {
                        Text("Handle")
                        Spacer()
                        if let handle = friendsVM.currentUser?.handle {
                            Text("@\(handle)").foregroundColor(.secondary)
                        } else {
                            Text("Set").foregroundColor(.yellow)
                        }
                    }
                }

                Toggle("Share full workout details with friends", isOn: $sharesFullDetails)
                    .onChange(of: sharesFullDetails) { _, newValue in
                        Task { await updateSharesFullDetails(newValue) }
                    }
            }

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

            #if DEBUG
            Section("Demo Data") {
                Button {
                    runSeed { try await DebugSeeder.seed(userId: $0) }
                } label: {
                    Label("Seed demo workouts", systemImage: "wand.and.stars")
                }
                .disabled(isSeeding)

                Button(role: .destructive) {
                    runSeed { try await DebugSeeder.clear(userId: $0) }
                } label: {
                    Label("Clear all sessions", systemImage: "trash")
                }
                .disabled(isSeeding)

                if let seedStatus {
                    Text(seedStatus)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            #endif
        }
        .navigationTitle("Settings")
        .task {
            sharesFullDetails = friendsVM.currentUser?.sharesFullDetails ?? true
        }
        .sheet(isPresented: $showingHandleSheet) {
            ClaimHandleSheet(isInitialSetup: false)
                .environmentObject(friendsVM)
        }
    }

    #if DEBUG
    private func runSeed(_ action: @escaping (String) async throws -> Int) {
        guard let uid = Auth.auth().currentUser?.uid else {
            seedStatus = "Not signed in."
            return
        }
        isSeeding = true
        seedStatus = "Working…"
        Task {
            do {
                let count = try await action(uid)
                seedStatus = "Done — \(count) session(s)."
            } catch {
                seedStatus = "Failed: \(error.localizedDescription)"
            }
            isSeeding = false
        }
    }
    #endif

    private func updateSharesFullDetails(_ value: Bool) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await UserManager.shared.updateSharesFullDetails(userId: uid, sharesFullDetails: value)
            await friendsVM.reloadCurrentUser()
        } catch {
            errorMessage = "Couldn't update sharing setting."
            sharesFullDetails = !value
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(showSignInView: .constant(false))
            .environmentObject(FriendsViewModel())
    }
}
