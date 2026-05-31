//
//  Schedule.swift
//  fitnessApp
//

import Foundation

struct Schedule: Codable, Hashable {
    let userId: String
    var assignments: [Weekday: String]

    init(userId: String, assignments: [Weekday: String] = [:]) {
        self.userId = userId
        self.assignments = assignments
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case assignments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        let rawAssignments = try container.decodeIfPresent([String: String].self, forKey: .assignments) ?? [:]
        var mapped: [Weekday: String] = [:]
        for (key, value) in rawAssignments {
            if let day = Weekday(rawValue: key) {
                mapped[day] = value
            }
        }
        self.assignments = mapped
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        let raw = Dictionary(uniqueKeysWithValues: assignments.map { ($0.key.rawValue, $0.value) })
        try container.encode(raw, forKey: .assignments)
    }
}
