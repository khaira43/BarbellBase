//
//  DebugSeeder.swift
//  fitnessApp
//
//  DEBUG-only helper that populates Firestore with realistic backdated
//  workout history so Stats / PRs / Goals / the Friends feed have data to
//  show during a demo. Not compiled into release builds.
//

#if DEBUG
import Foundation
import FirebaseFirestore

enum DebugSeeder {

    private struct SeedExercise {
        let id: String
        let name: String
        let sets: Int
        let reps: Int
        let baseWeight: Double
        let weeklyIncrement: Double
    }

    private struct SeedDay {
        let templateName: String
        let dayOffset: Int          // days back from the start of each week
        let exercises: [SeedExercise]
    }

    // A simple weekly split. Weights climb every week so the most recent
    // week is always a personal record.
    private static let days: [SeedDay] = [
        SeedDay(templateName: "Push Day", dayOffset: 0, exercises: [
            SeedExercise(id: "bench_press", name: "Bench Press", sets: 3, reps: 5, baseWeight: 135, weeklyIncrement: 5),
            SeedExercise(id: "overhead_press", name: "Overhead Press", sets: 3, reps: 5, baseWeight: 75, weeklyIncrement: 2.5),
        ]),
        SeedDay(templateName: "Pull Day", dayOffset: 2, exercises: [
            SeedExercise(id: "deadlift", name: "Conventional Deadlift", sets: 3, reps: 5, baseWeight: 225, weeklyIncrement: 10),
            SeedExercise(id: "barbell_row", name: "Barbell Row", sets: 3, reps: 8, baseWeight: 115, weeklyIncrement: 5),
        ]),
        SeedDay(templateName: "Leg Day", dayOffset: 4, exercises: [
            SeedExercise(id: "barbell_back_squat", name: "Barbell Back Squat", sets: 4, reps: 5, baseWeight: 185, weeklyIncrement: 10),
        ]),
        SeedDay(templateName: "Arm Day", dayOffset: 5, exercises: [
            SeedExercise(id: "barbell_curl", name: "Barbell Curl", sets: 3, reps: 10, baseWeight: 65, weeklyIncrement: 2.5),
        ]),
    ]

    /// Inserts `weeks` worth of completed sessions ending in the current week.
    /// Returns the number of sessions written.
    @discardableResult
    static func seed(userId: String, weeks: Int = 6) async throws -> Int {
        let calendar = Calendar.current
        let now = Date()
        var written = 0

        for week in 0..<weeks {
            let weeksAgo = weeks - 1 - week          // oldest first, newest = this week

            for day in days {
                let daysBack = weeksAgo * 7 + day.dayOffset
                guard let dayDate = calendar.date(byAdding: .day, value: -daysBack, to: now) else { continue }
                let completedAt = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayDate) ?? dayDate
                let startedAt = completedAt.addingTimeInterval(-45 * 60)

                let exercises = day.exercises.map { ex -> LoggedExercise in
                    let weight = ex.baseWeight + Double(week) * ex.weeklyIncrement
                    let sets = (0..<ex.sets).map { _ in
                        LoggedSet(
                            targetReps: ex.reps,
                            targetWeight: weight,
                            actualReps: ex.reps,
                            actualWeight: weight,
                            isCompleted: true,
                            completedAt: completedAt
                        )
                    }
                    return LoggedExercise(exerciseId: ex.id, exerciseName: ex.name, sets: sets)
                }

                let session = WorkoutSession(
                    userId: userId,
                    templateId: nil,
                    templateName: day.templateName,
                    startedAt: startedAt,
                    completedAt: completedAt,
                    exercises: exercises
                )
                try await WorkoutSessionManager.shared.saveCompletedSession(session)
                written += 1
            }
        }

        return written
    }

    /// Deletes every session document for the user. Returns the count removed.
    @discardableResult
    static func clear(userId: String) async throws -> Int {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("sessions")
            .getDocuments()

        for document in snapshot.documents {
            try await document.reference.delete()
        }
        NotificationCenter.default.post(name: WorkoutSessionManager.sessionSavedNotification, object: nil)
        return snapshot.documents.count
    }
}
#endif
