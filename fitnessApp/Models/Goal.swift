//
//  Goal.swift
//  fitnessApp
//

import Foundation

struct Goal: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case lift, frequency, bodyweight }
    enum Status: String, Codable { case active, completed }

    var id: String
    var kind: Kind
    var createdAt: Date
    var status: Status
    var completedAt: Date?
    var targetDate: Date?

    var lift: LiftTarget?
    var frequency: FrequencyTarget?
    var bodyweight: BodyweightTarget?

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        createdAt: Date = Date(),
        status: Status = .active,
        completedAt: Date? = nil,
        targetDate: Date? = nil,
        lift: LiftTarget? = nil,
        frequency: FrequencyTarget? = nil,
        bodyweight: BodyweightTarget? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.status = status
        self.completedAt = completedAt
        self.targetDate = targetDate
        self.lift = lift
        self.frequency = frequency
        self.bodyweight = bodyweight
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case createdAt = "created_at"
        case status
        case completedAt = "completed_at"
        case targetDate = "target_date"
        case lift
        case frequency
        case bodyweight
    }
}

struct LiftTarget: Codable, Hashable {
    var exerciseId: String
    var exerciseName: String
    var targetE1RM: Double

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case targetE1RM = "target_e1rm"
    }
}

struct FrequencyTarget: Codable, Hashable {
    var workoutsPerWeek: Int

    enum CodingKeys: String, CodingKey {
        case workoutsPerWeek = "workouts_per_week"
    }
}

struct BodyweightTarget: Codable, Hashable {
    var targetWeightLb: Double
    var startWeightLb: Double

    enum CodingKeys: String, CodingKey {
        case targetWeightLb = "target_weight_lb"
        case startWeightLb = "start_weight_lb"
    }
}
