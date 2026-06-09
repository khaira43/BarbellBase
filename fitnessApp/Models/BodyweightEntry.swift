//
//  BodyweightEntry.swift
//  fitnessApp
//

import Foundation

struct BodyweightEntry: Codable, Identifiable, Hashable {
    let id: String
    let weightLb: Double
    let loggedAt: Date

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
