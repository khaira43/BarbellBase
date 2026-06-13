//
//  UserSearchSheet.swift
//  fitnessApp
//

import SwiftUI
import FirebaseAuth

struct UserSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var friendsVM: FriendsViewModel

    @State private var query: String = ""
    @State private var results: [DBUser] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var actionedUids: Set<String> = []
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                VStack(spacing: 12) {
                    searchField
                    if isSearching {
                        ProgressView().tint(.white)
                    } else if results.isEmpty, !query.isEmpty {
                        Text("No users found.")
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 32)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(filteredResults) { user in
                                    row(for: user)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.yellow)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 2) {
            Text("@").foregroundColor(.white.opacity(0.5))
            TextField("handle", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundColor(.white)
                .onChange(of: query) { _, newValue in
                    let lower = newValue.lowercased()
                    if lower != newValue { query = lower }
                    scheduleSearch(prefix: lower)
                }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var filteredResults: [DBUser] {
        let myUid = Auth.auth().currentUser?.uid
        return results.filter { user in
            user.userId != myUid
        }
    }

    private func row(for user: DBUser) -> some View {
        let pairId = Friendship.pairId(Auth.auth().currentUser?.uid ?? "", user.userId)
        let existing = friendsVM.friendships.first { $0.id == pairId }
        let stateText: String = {
            if let existing {
                switch existing.status {
                case .accepted: return "Friends"
                case .pending:
                    if existing.requesterId == Auth.auth().currentUser?.uid {
                        return "Pending"
                    } else {
                        return "Wants to be friends"
                    }
                }
            }
            if actionedUids.contains(user.userId) { return "Sent" }
            return ""
        }()

        return HStack(spacing: 12) {
            Circle()
                .fill(Color.yellow.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Text((user.displayName ?? user.handle ?? "?").prefix(1).uppercased())
                        .font(.subheadline.bold())
                        .foregroundColor(.yellow)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? user.handle ?? "User")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                if let h = user.handle {
                    Text("@\(h)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            if stateText.isEmpty {
                Button {
                    Task { await sendRequest(to: user) }
                } label: {
                    Text("Add")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
            } else {
                Text(stateText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(10)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(10)
    }

    private func scheduleSearch(prefix: String) {
        debounceTask?.cancel()
        guard !prefix.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await runSearch(prefix: prefix)
        }
    }

    private func runSearch(prefix: String) async {
        do {
            let users = try await UserManager.shared.searchUsersByHandlePrefix(prefix, limit: 10)
            self.results = users
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Search failed."
        }
        self.isSearching = false
    }

    private func sendRequest(to user: DBUser) async {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        do {
            try await FriendsManager.shared.sendRequest(myUid: myUid, otherUid: user.userId)
            actionedUids.insert(user.userId)
            await friendsVM.load()
        } catch let err as FriendsError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = "Couldn't send request."
        }
    }
}
