//
//  Friendship.swift
//  fitnessApp
//

import Foundation

struct Friendship: Codable, Identifiable, Hashable {
    enum Status: String, Codable {
        case pending
        case accepted
    }

    let id: String
    let users: [String]
    let requesterId: String
    var status: Status
    let createdAt: Date
    var acceptedAt: Date?

    init(
        id: String,
        users: [String],
        requesterId: String,
        status: Status = .pending,
        createdAt: Date = Date(),
        acceptedAt: Date? = nil
    ) {
        self.id = id
        self.users = users
        self.requesterId = requesterId
        self.status = status
        self.createdAt = createdAt
        self.acceptedAt = acceptedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case users
        case requesterId = "requester_id"
        case status
        case createdAt = "created_at"
        case acceptedAt = "accepted_at"
    }

    func friendUid(forMe myUid: String) -> String? {
        guard users.contains(myUid) else { return nil }
        return users.first { $0 != myUid }
    }
}

extension Friendship {
    /// Deterministic doc id for the pair: sorted uids joined with `_`.
    static func pairId(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "_")
    }

    static func newPending(requesterId: String, recipientId: String, now: Date = Date()) -> Friendship {
        let users = [requesterId, recipientId].sorted()
        return Friendship(
            id: pairId(requesterId, recipientId),
            users: users,
            requesterId: requesterId,
            status: .pending,
            createdAt: now,
            acceptedAt: nil
        )
    }
}
