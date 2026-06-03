//
//  LoggedSet.swift
//  fitnessApp
//

import Foundation

struct LoggedSet: Codable, Identifiable, Hashable {
    let id: String
    let targetReps: Int
    let targetWeight: Double?
    var actualReps: Int
    var actualWeight: Double?
    var isCompleted: Bool
    var completedAt: Date?

    init(
        id: String = UUID().uuidString,
        targetReps: Int,
        targetWeight: Double?,
        actualReps: Int? = nil,
        actualWeight: Double? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.actualReps = actualReps ?? targetReps
        self.actualWeight = actualWeight ?? targetWeight
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case targetReps = "target_reps"
        case targetWeight = "target_weight"
        case actualReps = "actual_reps"
        case actualWeight = "actual_weight"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
    }
}
