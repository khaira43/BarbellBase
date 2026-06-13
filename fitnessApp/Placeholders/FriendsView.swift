//
//  FriendsView.swift
//  fitnessApp
//

import SwiftUI
import FirebaseAuth

struct FriendsView: View {
    @EnvironmentObject private var friendsVM: FriendsViewModel
    @State private var showingSearch = false

    private var myUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                content
            }
            .navigationTitle("Friends")
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingSearch = true } label: {
                        Image(systemName: "person.badge.plus").foregroundColor(.yellow)
                    }
                }
            }
            .task { await friendsVM.load() }
            .refreshable { await friendsVM.load() }
            .sheet(isPresented: $showingSearch) {
                UserSearchSheet().environmentObject(friendsVM)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !friendsVM.pendingIncomingRequests.isEmpty {
                    requestsSection
                }
                friendsSection
                feedSection
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    // MARK: - Requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Requests")
            VStack(spacing: 8) {
                ForEach(friendsVM.pendingIncomingRequests) { friendship in
                    requestRow(friendship)
                }
            }
        }
    }

    private func requestRow(_ friendship: Friendship) -> some View {
        let uid = myUid ?? ""
        let otherUid = friendship.friendUid(forMe: uid) ?? friendship.requesterId
        let name = friendsVM.displayName(forFriend: otherUid)
        let handle = friendsVM.handle(forFriend: otherUid)
        return HStack(spacing: 12) {
            avatar(name: name)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                if let handle {
                    Text("@\(handle)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            Button {
                Task { await accept(friendship) }
            } label: {
                Text("Accept")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(8)
            }
            Button {
                Task { await decline(friendship) }
            } label: {
                Text("Decline")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(10)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(10)
    }

    // MARK: - Friends list

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Friends")
            if friendsVM.acceptedFriendships.isEmpty {
                emptyState("No friends yet.\nTap the icon above to add one.")
            } else {
                VStack(spacing: 8) {
                    ForEach(friendsVM.acceptedFriendships) { friendship in
                        friendRow(friendship)
                    }
                }
            }
        }
    }

    private func friendRow(_ friendship: Friendship) -> some View {
        let uid = myUid ?? ""
        let otherUid = friendship.friendUid(forMe: uid) ?? ""
        let name = friendsVM.displayName(forFriend: otherUid)
        let handle = friendsVM.handle(forFriend: otherUid)
        return HStack(spacing: 12) {
            avatar(name: name)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                if let handle {
                    Text("@\(handle)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    Task { await unfriend(friendship) }
                } label: {
                    Label("Unfriend", systemImage: "person.fill.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.white.opacity(0.6))
                    .padding(8)
            }
        }
        .padding(10)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(10)
    }

    // MARK: - Feed

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Recent Activity")
            if friendsVM.feed.isEmpty {
                emptyState(
                    friendsVM.acceptedFriendships.isEmpty
                        ? "Add a friend to see their workouts."
                        : "No workouts logged yet."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(friendsVM.feed) { session in
                        FriendActivityCard(session: session).environmentObject(friendsVM)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(hex: "#0c2548"))
            .cornerRadius(10)
    }

    private func avatar(name: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.15))
                .frame(width: 36, height: 36)
            Text(name.prefix(1).uppercased())
                .font(.subheadline.bold())
                .foregroundColor(.yellow)
        }
    }

    // MARK: - Actions

    private func accept(_ friendship: Friendship) async {
        guard let uid = myUid, let otherUid = friendship.friendUid(forMe: uid) else { return }
        try? await FriendsManager.shared.accept(myUid: uid, otherUid: otherUid)
        await friendsVM.load()
    }

    private func decline(_ friendship: Friendship) async {
        guard let uid = myUid, let otherUid = friendship.friendUid(forMe: uid) else { return }
        try? await FriendsManager.shared.decline(myUid: uid, otherUid: otherUid)
        await friendsVM.load()
    }

    private func unfriend(_ friendship: Friendship) async {
        guard let uid = myUid, let otherUid = friendship.friendUid(forMe: uid) else { return }
        try? await FriendsManager.shared.unfriend(myUid: uid, otherUid: otherUid)
        await friendsVM.load()
    }
}

#Preview {
    FriendsView().environmentObject(FriendsViewModel())
}
