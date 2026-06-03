//
//  LoggedExercise.swift
//  fitnessApp
//

import Foundation

struct LoggedExercise: Codable, Identifiable, Hashable {
    let id: String
    let exerciseId: String
    let exerciseName: String
    var sets: [LoggedSet]

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        exerciseName: String,
        sets: [LoggedSet] = []
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.sets = sets
    }

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case sets
    }
}
