//
//  UserManager.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-07-23.
//

import Foundation
import FirebaseFirestore

struct DBUser: Codable, Identifiable {
    let userId: String
    let isAnonymous: Bool?
    let email: String?
    let photoUrl: String?
    let dateCreated: Date?
    let isPremium: Bool?
    let handle: String?
    let displayName: String?
    let sharesFullDetails: Bool?

    var id: String { userId }

    init(auth: AuthDataResultModel) {
        self.userId = auth.uid
        self.isAnonymous = auth.isAnonymous
        self.email = auth.email
        self.photoUrl = auth.photoUrl
        self.dateCreated = Date()
        self.isPremium = false
        self.handle = nil
        self.displayName = nil
        self.sharesFullDetails = true
    }

    init(
        userId: String,
        isAnonymous: Bool? = nil,
        email: String? = nil,
        photoUrl: String? = nil,
        dateCreated: Date? = nil,
        isPremium: Bool? = nil,
        handle: String? = nil,
        displayName: String? = nil,
        sharesFullDetails: Bool? = nil
    ) {
        self.userId = userId
        self.isAnonymous = isAnonymous
        self.email = email
        self.photoUrl = photoUrl
        self.dateCreated = dateCreated
        self.isPremium = isPremium
        self.handle = handle
        self.displayName = displayName
        self.sharesFullDetails = sharesFullDetails
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isAnonymous = "is_anonymous"
        case email = "email"
        case photoUrl = "photo_url"
        case dateCreated = "date_created"
        case isPremium = "user_isPremium"
        case handle = "handle"
        case displayName = "display_name"
        case sharesFullDetails = "shares_full_details"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        self.dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated)
        self.isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium)
        self.handle = try container.decodeIfPresent(String.self, forKey: .handle)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.sharesFullDetails = try container.decodeIfPresent(Bool.self, forKey: .sharesFullDetails)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.userId, forKey: .userId)
        try container.encodeIfPresent(self.isAnonymous, forKey: .isAnonymous)
        try container.encodeIfPresent(self.email, forKey: .email)
        try container.encodeIfPresent(self.photoUrl, forKey: .photoUrl)
        try container.encodeIfPresent(self.dateCreated, forKey: .dateCreated)
        try container.encodeIfPresent(self.isPremium, forKey: .isPremium)
        try container.encodeIfPresent(self.handle, forKey: .handle)
        try container.encodeIfPresent(self.displayName, forKey: .displayName)
        try container.encodeIfPresent(self.sharesFullDetails, forKey: .sharesFullDetails)
    }
}

enum UserManagerError: Error {
    case handleTaken
    case invalidHandle
    case notSignedIn
}

final class UserManager {

    static let shared = UserManager()
    static let userUpdatedNotification = Notification.Name("UserManager.userUpdated")
    private init(){}

    private let userCollection = Firestore.firestore().collection("users")
    private let usernamesCollection = Firestore.firestore().collection("usernames")

    private func userDocument(userId: String) -> DocumentReference {
        userCollection.document(userId)
    }

    private func usernameDocument(handle: String) -> DocumentReference {
        usernamesCollection.document(handle.lowercased())
    }

    func createNewUser(user: DBUser) async throws {
        try userDocument(userId: user.userId).setData(from: user, merge: false)
    }

    func ensureUserExists(user: DBUser) async throws {
        let snapshot = try await userDocument(userId: user.userId).getDocument()
        guard !snapshot.exists else { return }
        try userDocument(userId: user.userId).setData(from: user, merge: false)
    }

    func getUser(userId: String) async throws -> DBUser {
        try await userDocument(userId: userId).getDocument(as: DBUser.self)
    }

    func updateUserPremiumStatus(userId: String, isPremium: Bool) async throws {
        let data: [String: Any] = [
            DBUser.CodingKeys.isPremium.rawValue: isPremium
        ]
        try await userDocument(userId: userId).updateData(data)
    }

    // MARK: - Friends-related

    /// Atomically claim a handle: writes `usernames/{lowercased}` and updates the user doc.
    /// Throws `UserManagerError.handleTaken` if already owned by a different user.
    func claimHandle(userId: String, handle: String, displayName: String) async throws {
        guard FriendsMath.isValidHandle(handle) else { throw UserManagerError.invalidHandle }
        let lower = handle.lowercased()
        let trimmedDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDisplay = trimmedDisplay.isEmpty ? handle : trimmedDisplay

        let db = Firestore.firestore()
        let usernameRef = usernameDocument(handle: lower)
        let userRef = userDocument(userId: userId)

        // Look up the user's current handle (so we can release it if they're renaming).
        let userSnap = try await userRef.getDocument()
        let previousHandle = userSnap.data()?[DBUser.CodingKeys.handle.rawValue] as? String

        _ = try await db.runTransaction { transaction, errorPointer in
            let existing: DocumentSnapshot
            do {
                existing = try transaction.getDocument(usernameRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            if existing.exists, (existing.data()?["user_id"] as? String) != userId {
                errorPointer?.pointee = NSError(
                    domain: "UserManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "handleTaken"]
                )
                return nil
            }
            transaction.setData(["user_id": userId], forDocument: usernameRef)
            transaction.updateData([
                DBUser.CodingKeys.handle.rawValue: lower,
                DBUser.CodingKeys.displayName.rawValue: finalDisplay
            ], forDocument: userRef)
            if let previousHandle, previousHandle != lower {
                let oldRef = self.usernameDocument(handle: previousHandle)
                transaction.deleteDocument(oldRef)
            }
            return nil
        }
        NotificationCenter.default.post(name: Self.userUpdatedNotification, object: nil)
    }

    func updateSharesFullDetails(userId: String, sharesFullDetails: Bool) async throws {
        try await userDocument(userId: userId).updateData([
            DBUser.CodingKeys.sharesFullDetails.rawValue: sharesFullDetails
        ])
        NotificationCenter.default.post(name: Self.userUpdatedNotification, object: nil)
    }

    /// Prefix search on `handle`. `prefix` is lowercased before querying.
    func searchUsersByHandlePrefix(_ prefix: String, limit: Int = 10) async throws -> [DBUser] {
        let lower = prefix.lowercased()
        guard !lower.isEmpty else { return [] }
        let upper = lower + "\u{f8ff}"
        let snapshot = try await userCollection
            .whereField(DBUser.CodingKeys.handle.rawValue, isGreaterThanOrEqualTo: lower)
            .whereField(DBUser.CodingKeys.handle.rawValue, isLessThan: upper)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: DBUser.self) }
    }

    /// Batch-fetch users by id. Chunks to Firestore's 30-doc `in` limit.
    func getUsers(userIds: [String]) async throws -> [DBUser] {
        let unique = Array(Set(userIds))
        guard !unique.isEmpty else { return [] }
        var results: [DBUser] = []
        for chunk in unique.chunked(into: 30) {
            let snapshot = try await userCollection
                .whereField(DBUser.CodingKeys.userId.rawValue, in: chunk)
                .getDocuments()
            results.append(contentsOf: snapshot.documents.compactMap { try? $0.data(as: DBUser.self) })
        }
        return results
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
