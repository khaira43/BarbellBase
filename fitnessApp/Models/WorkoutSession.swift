//
//  WorkoutSession.swift
//  fitnessApp
//

import Foundation

struct WorkoutSession: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let templateId: String?
    let templateName: String
    let startedAt: Date
    var completedAt: Date?
    var exercises: [LoggedExercise]

    init(
        id: String = UUID().uuidString,
        userId: String,
        templateId: String?,
        templateName: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        exercises: [LoggedExercise] = []
    ) {
        self.id = id
        self.userId = userId
        self.templateId = templateId
        self.templateName = templateName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.exercises = exercises
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case templateId = "template_id"
        case templateName = "template_name"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case exercises
    }
}

extension WorkoutSession {
    static func starting(from template: WorkoutTemplate, userId: String) -> WorkoutSession {
        let exercises = template.exercises.map { planned in
            LoggedExercise(
                exerciseId: planned.exerciseId,
                exerciseName: planned.exerciseName,
                sets: (0..<planned.targetSets).map { _ in
                    LoggedSet(targetReps: planned.targetReps, targetWeight: planned.targetWeight)
                }
            )
        }
        return WorkoutSession(
            userId: userId,
            templateId: template.id,
            templateName: template.name,
            exercises: exercises
        )
    }
}
