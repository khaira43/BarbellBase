//
//  ClaimHandleSheet.swift
//  fitnessApp
//

import SwiftUI
import FirebaseAuth

/// Used both as a required full-screen cover for first-time handle setup and as an
/// edit sheet from Settings. When `isInitialSetup` is true, there is no Cancel.
struct ClaimHandleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var friendsVM: FriendsViewModel

    let isInitialSetup: Bool

    @State private var handle: String = ""
    @State private var displayName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(isInitialSetup: Bool = false) {
        self.isInitialSetup = isInitialSetup
    }

    private var validationError: String? {
        guard !handle.isEmpty else { return nil }
        return FriendsMath.handleValidationError(for: handle)
    }

    private var canSave: Bool {
        validationError == nil && !handle.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text(isInitialSetup ? "Pick a handle" : "Edit handle")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    if isInitialSetup {
                        Text("Friends will find you by your handle. You can change it later.")
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Handle").font(.caption).foregroundColor(.white.opacity(0.8))
                        HStack(spacing: 2) {
                            Text("@").foregroundColor(.white.opacity(0.5))
                            TextField("", text: $handle)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .foregroundColor(.white)
                                .onChange(of: handle) { _, newValue in
                                    handle = newValue.lowercased()
                                }
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(10)

                        if let validationError {
                            Text(validationError)
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("3–20 chars, letters/numbers/underscore, starts with a letter.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display name (optional)").font(.caption).foregroundColor(.white.opacity(0.8))
                        TextField("", text: $displayName)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }

                    Button { Task { await save() } } label: {
                        HStack {
                            if isSaving { ProgressView() }
                            Text("Save").bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.yellow : Color.white.opacity(0.2))
                        .foregroundColor(canSave ? .black : .white.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .disabled(!canSave || isSaving)
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !isInitialSetup {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") { dismiss() }.foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                if let user = friendsVM.currentUser {
                    if handle.isEmpty, let h = user.handle { handle = h }
                    if displayName.isEmpty, let d = user.displayName { displayName = d }
                }
            }
        }
        .interactiveDismissDisabled(isInitialSetup)
    }

    private func save() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        do {
            try await UserManager.shared.claimHandle(
                userId: userId,
                handle: handle,
                displayName: displayName
            )
            await friendsVM.reloadCurrentUser()
            dismiss()
        } catch {
            if let nsErr = error as NSError?, nsErr.localizedDescription == "handleTaken" {
                errorMessage = "That handle is taken."
            } else if case UserManagerError.invalidHandle = error {
                errorMessage = "Invalid handle."
            } else {
                errorMessage = "Couldn't save handle."
            }
        }
    }
}
