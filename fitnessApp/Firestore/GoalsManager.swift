//
//  GoalsManager.swift
//  fitnessApp
//

import Foundation
import FirebaseFirestore

enum GoalsError: Error {
    case singletonKindExists(Goal.Kind)
    case invalidTarget
}

final class GoalsManager {
    static let shared = GoalsManager()
    static let goalSavedNotification = Notification.Name("GoalsManager.goalSaved")
    static let bodyweightEntrySavedNotification = Notification.Name("GoalsManager.bodyweightEntrySaved")
    private init() {}

    // MARK: - Refs

    private func goalsCollection(userId: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("goals")
    }

    private func goalDocument(userId: String, goalId: String) -> DocumentReference {
        goalsCollection(userId: userId).document(goalId)
    }

    private func entriesCollection(userId: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("bodyweightEntries")
    }

    private func entryDocument(userId: String, entryId: String) -> DocumentReference {
        entriesCollection(userId: userId).document(entryId)
    }

    // MARK: - Goals

    func listGoals(userId: String) async throws -> [Goal] {
        let snapshot = try await goalsCollection(userId: userId)
            .order(by: Goal.CodingKeys.createdAt.rawValue, descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Goal.self) }
    }

    func createGoal(userId: String, goal: Goal) async throws {
        if goal.kind == .frequency || goal.kind == .bodyweight {
            let existing = try await goalsCollection(userId: userId)
                .whereField(Goal.CodingKeys.kind.rawValue, isEqualTo: goal.kind.rawValue)
                .whereField(Goal.CodingKeys.status.rawValue, isEqualTo: Goal.Status.active.rawValue)
                .limit(to: 1)
                .getDocuments()
            if !existing.documents.isEmpty {
                throw GoalsError.singletonKindExists(goal.kind)
            }
        }
        try goalDocument(userId: userId, goalId: goal.id)
            .setData(from: goal, merge: false)
        NotificationCenter.default.post(name: Self.goalSavedNotification, object: nil)
    }

    func updateGoal(userId: String, goal: Goal) async throws {
        try goalDocument(userId: userId, goalId: goal.id)
            .setData(from: goal, merge: false)
        NotificationCenter.default.post(name: Self.goalSavedNotification, object: nil)
    }

    func deleteGoal(userId: String, goalId: String) async throws {
        try await goalDocument(userId: userId, goalId: goalId).delete()
        NotificationCenter.default.post(name: Self.goalSavedNotification, object: nil)
    }

    func markCompleted(userId: String, goalId: String, at completionDate: Date, silent: Bool) async throws {
        let ref = goalDocument(userId: userId, goalId: goalId)
        let snapshot = try await ref.getDocument()
        guard var goal = try? snapshot.data(as: Goal.self) else { return }
        if goal.status == .completed { return }
        goal.status = .completed
        goal.completedAt = completionDate
        try ref.setData(from: goal, merge: false)
        if !silent {
            NotificationCenter.default.post(name: Self.goalSavedNotification, object: nil)
        }
    }

    // MARK: - Bodyweight entries

    func listBodyweightEntries(userId: String) async throws -> [BodyweightEntry] {
        let snapshot = try await entriesCollection(userId: userId)
            .order(by: BodyweightEntry.CodingKeys.loggedAt.rawValue, descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: BodyweightEntry.self) }
    }

    func latestBodyweight(userId: String) async throws -> BodyweightEntry? {
        let snapshot = try await entriesCollection(userId: userId)
            .order(by: BodyweightEntry.CodingKeys.loggedAt.rawValue, descending: true)
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: BodyweightEntry.self) }.first
    }

    func logBodyweight(userId: String, weightLb: Double, at loggedAt: Date) async throws {
        let entry = BodyweightEntry(weightLb: weightLb, loggedAt: loggedAt)
        try entryDocument(userId: userId, entryId: entry.id)
            .setData(from: entry, merge: false)
        NotificationCenter.default.post(name: Self.bodyweightEntrySavedNotification, object: nil)
    }

    func deleteBodyweightEntry(userId: String, entryId: String) async throws {
        try await entryDocument(userId: userId, entryId: entryId).delete()
        NotificationCenter.default.post(name: Self.bodyweightEntrySavedNotification, object: nil)
    }
}
