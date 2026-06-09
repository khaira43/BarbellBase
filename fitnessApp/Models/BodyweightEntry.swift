//
//  BodyweightEntry.swift
//  fitnessApp
//

import Foundation

struct BodyweightEntry: Codable, Identifiable, Hashable {
    var id: String
    var weightLb: Double
    var loggedAt: Date

    init(id: String = UUID().uuidString, weightLb: Double, loggedAt: Date = Date()) {
        self.id = id
        self.weightLb = weightLb
        self.loggedAt = loggedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case weightLb = "weight_lb"
        case loggedAt = "logged_at"
    }
}
