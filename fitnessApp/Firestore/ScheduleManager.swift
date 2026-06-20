//
//  ScheduleManager.swift
//  fitnessApp
//

import Foundation
import FirebaseFirestore

final class ScheduleManager {
    static let shared = ScheduleManager()
    private init() {}

    private func scheduleDocument(userId: String) -> DocumentReference {
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("schedule")
            .document("main")
    }

    func getSchedule(userId: String) async throws -> Schedule {
        let snapshot = try await scheduleDocument(userId: userId).getDocument()
        if snapshot.exists, let schedule = try? snapshot.data(as: Schedule.self) {
            return schedule
        }
        return Schedule(userId: userId, assignments: [:])
    }

    func setSchedule(_ schedule: Schedule) async throws {
        try scheduleDocument(userId: schedule.userId).setData(from: schedule, merge: false)
    }

    func assignWorkout(userId: String, day: Weekday, templateId: String?) async throws {
        var schedule = try await getSchedule(userId: userId)
        if let templateId {
            schedule.assignments[day] = templateId
        } else {
            schedule.assignments.removeValue(forKey: day)
        }
        try await setSchedule(schedule)
    }

    /// Clears any weekday assignments pointing at the given template. Called when a
    /// template is deleted so the schedule doesn't keep dangling references.
    /// No-ops (and avoids a write) when nothing references the template.
    func removeAssignments(userId: String, templateId: String) async throws {
        var schedule = try await getSchedule(userId: userId)
        let staleDays = schedule.assignments.filter { $0.value == templateId }.map(\.key)
        guard !staleDays.isEmpty else { return }
        for day in staleDays {
            schedule.assignments.removeValue(forKey: day)
        }
        try await setSchedule(schedule)
    }
}
