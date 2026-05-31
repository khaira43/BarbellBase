//
//  PlannedExercise.swift
//  fitnessApp
//

import Foundation

struct PlannedExercise: Codable, Identifiable, Hashable {
    let id: String
    let exerciseId: String
    let exerciseName: String
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double?

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        exerciseName: String,
        targetSets: Int = 3,
        targetReps: Int = 8,
        targetWeight: Double? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
    }

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case targetSets = "target_sets"
        case targetReps = "target_reps"
        case targetWeight = "target_weight"
    }
}
