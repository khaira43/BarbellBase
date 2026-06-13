//
//  FriendsManager.swift
//  fitnessApp
//

import Foundation
import FirebaseFirestore

enum FriendsError: Error, LocalizedError {
    case alreadyFriends
    case requestPending
    case incomingRequestExists
    case cannotFriendSelf
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .alreadyFriends: return "You're already friends."
        case .requestPending: return "Request already sent."
        case .incomingRequestExists: return "They sent you a request — check your inbox."
        case .cannotFriendSelf: return "You can't add yourself."
        case .notSignedIn: return "You need to be signed in."
        }
    }
}

final class FriendsManager {
    static let shared = FriendsManager()
    static let friendshipsChangedNotification = Notification.Name("FriendsManager.friendshipsChanged")
    private init() {}

    private let friendshipsCollection = Firestore.firestore().collection("friendships")

    private func friendshipDocument(_ pairId: String) -> DocumentReference {
        friendshipsCollection.document(pairId)
    }

    // MARK: - Read

    /// All friendships involving `userId` — both `pending` and `accepted`.
    func listFriendships(userId: String) async throws -> [Friendship] {
        let snapshot = try await friendshipsCollection
            .whereField(Friendship.CodingKeys.users.rawValue, arrayContains: userId)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Friendship.self) }
    }

    func getFriendship(myUid: String, otherUid: String) async throws -> Friendship? {
        let pairId = Friendship.pairId(myUid, otherUid)
        let snap = try await friendshipDocument(pairId).getDocument()
        guard snap.exists else { return nil }
        return try? snap.data(as: Friendship.self)
    }

    // MARK: - Write

    func sendRequest(myUid: String, otherUid: String) async throws {
        guard myUid != otherUid else { throw FriendsError.cannotFriendSelf }
        if let existing = try await getFriendship(myUid: myUid, otherUid: otherUid) {
            switch existing.status {
            case .accepted: throw FriendsError.alreadyFriends
            case .pending:
                if existing.requesterId == myUid {
                    throw FriendsError.requestPending
                } else {
                    throw FriendsError.incomingRequestExists
                }
            }
        }
        let friendship = Friendship.newPending(requesterId: myUid, recipientId: otherUid)
        try friendshipDocument(friendship.id).setData(from: friendship, merge: false)
        NotificationCenter.default.post(name: Self.friendshipsChangedNotification, object: nil)
    }

    func accept(myUid: String, otherUid: String) async throws {
        let pairId = Friendship.pairId(myUid, otherUid)
        let ref = friendshipDocument(pairId)
        try await ref.updateData([
            Friendship.CodingKeys.status.rawValue: Friendship.Status.accepted.rawValue,
            Friendship.CodingKeys.acceptedAt.rawValue: FieldValue.serverTimestamp()
        ])
        NotificationCenter.default.post(name: Self.friendshipsChangedNotification, object: nil)
    }

    func decline(myUid: String, otherUid: String) async throws {
        let pairId = Friendship.pairId(myUid, otherUid)
        try await friendshipDocument(pairId).delete()
        NotificationCenter.default.post(name: Self.friendshipsChangedNotification, object: nil)
    }

    func unfriend(myUid: String, otherUid: String) async throws {
        try await decline(myUid: myUid, otherUid: otherUid)
    }

    // MARK: - Feed

    /// Most-recent completed sessions across the given friend uids. Uses a collection-group
    /// query on the existing `users/{uid}/sessions/{id}` path — no migration.
    /// `friendUids` is capped at 30 (Firestore `in` clause limit) by the caller.
    func listFeedSessions(friendUids: [String], limit: Int = 20) async throws -> [WorkoutSession] {
        guard !friendUids.isEmpty else { return [] }
        let capped = Array(friendUids.prefix(30))
        let snapshot = try await Firestore.firestore()
            .collectionGroup("sessions")
            .whereField(WorkoutSession.CodingKeys.userId.rawValue, in: capped)
            .order(by: WorkoutSession.CodingKeys.completedAt.rawValue, descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: WorkoutSession.self) }
            .filter { $0.completedAt != nil }
    }

    /// All completed sessions for a single friend — used for PR-detection priors.
    func listAllCompletedSessions(userId: String) async throws -> [WorkoutSession] {
        try await WorkoutSessionManager.shared.listAllCompletedSessions(userId: userId)
    }
}
