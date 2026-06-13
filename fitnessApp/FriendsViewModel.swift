//
//  FriendsViewModel.swift
//  fitnessApp
//

import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published var friendships: [Friendship] = []
    @Published var userCache: [String: DBUser] = [:]
    @Published var feed: [WorkoutSession] = []
    @Published var priorSessionsByFriend: [String: [WorkoutSession]] = [:]
    @Published var currentUser: DBUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var observersRegistered = false

    var pendingIncomingRequests: [Friendship] {
        guard let uid = currentUser?.userId else { return [] }
        return friendships.filter { $0.status == .pending && $0.requesterId != uid }
    }

    var pendingOutgoingRequests: [Friendship] {
        guard let uid = currentUser?.userId else { return [] }
        return friendships.filter { $0.status == .pending && $0.requesterId == uid }
    }

    var acceptedFriendships: [Friendship] {
        friendships.filter { $0.status == .accepted }
    }

    var acceptedFriendUids: [String] {
        guard let uid = currentUser?.userId else { return [] }
        return acceptedFriendships.compactMap { $0.friendUid(forMe: uid) }
    }

    init() {
        registerObservers()
    }

    private func registerObservers() {
        guard !observersRegistered else { return }
        observersRegistered = true
        NotificationCenter.default.addObserver(
            forName: FriendsManager.friendshipsChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.load() }
        }
        NotificationCenter.default.addObserver(
            forName: UserManager.userUpdatedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.reloadCurrentUser() }
        }
        NotificationCenter.default.addObserver(
            forName: WorkoutSessionManager.sessionSavedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.loadFeed() }
        }
    }

    func load() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            reset()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            async let userTask = UserManager.shared.getUser(userId: uid)
            async let friendshipsTask = FriendsManager.shared.listFriendships(userId: uid)
            let user = try await userTask
            let allFriendships = try await friendshipsTask
            self.currentUser = user
            self.friendships = allFriendships
            try await hydrateUserCache(for: allFriendships, myUid: uid)
            await loadFeed()
        } catch {
            errorMessage = "Couldn't load friends."
        }
    }

    func reloadCurrentUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if let user = try? await UserManager.shared.getUser(userId: uid) {
            self.currentUser = user
        }
    }

    func loadFeed() async {
        let friendUids = acceptedFriendUids
        guard !friendUids.isEmpty else {
            self.feed = []
            self.priorSessionsByFriend = [:]
            return
        }
        do {
            let sessions = try await FriendsManager.shared.listFeedSessions(friendUids: friendUids, limit: 20)
            self.feed = sessions
            await hydratePriorSessions(forFriendUidsIn: sessions)
        } catch {
            errorMessage = "Couldn't load activity."
        }
    }

    private func hydrateUserCache(for friendships: [Friendship], myUid: String) async throws {
        let otherUids = friendships.compactMap { $0.friendUid(forMe: myUid) }
        let needed = otherUids.filter { userCache[$0] == nil }
        guard !needed.isEmpty else { return }
        let users = try await UserManager.shared.getUsers(userIds: needed)
        for user in users { userCache[user.userId] = user }
    }

    /// For each friend in the feed, fetch their full session history once and cache it.
    /// Used by PR detection in `FriendActivityCard`.
    private func hydratePriorSessions(forFriendUidsIn feed: [WorkoutSession]) async {
        let uids = Set(feed.map(\.userId))
        for uid in uids where priorSessionsByFriend[uid] == nil {
            if let sessions = try? await FriendsManager.shared.listAllCompletedSessions(userId: uid) {
                priorSessionsByFriend[uid] = sessions
            }
        }
    }

    func reset() {
        friendships = []
        userCache = [:]
        feed = []
        priorSessionsByFriend = [:]
        currentUser = nil
    }

    func displayName(forFriend uid: String) -> String {
        if let user = userCache[uid] {
            if let display = user.displayName, !display.isEmpty { return display }
            if let handle = user.handle, !handle.isEmpty { return "@\(handle)" }
        }
        return "Friend"
    }

    func handle(forFriend uid: String) -> String? {
        userCache[uid]?.handle
    }

    func sharesFullDetails(forFriend uid: String) -> Bool {
        userCache[uid]?.sharesFullDetails ?? true
    }
}
