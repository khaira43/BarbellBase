//
//  WorkoutTemplate.swift
//  fitnessApp
//

import Foundation

struct WorkoutTemplate: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    var name: String
    var exercises: [PlannedExercise]
    let dateCreated: Date
    var dateUpdated: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        exercises: [PlannedExercise] = [],
        dateCreated: Date = Date(),
        dateUpdated: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.exercises = exercises
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case exercises
        case dateCreated = "date_created"
        case dateUpdated = "date_updated"
    }
}
