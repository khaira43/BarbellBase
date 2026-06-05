//
//  WorkoutSessionManager.swift
//  fitnessApp
//

import Foundation
import FirebaseFirestore

final class WorkoutSessionManager {
    static let shared = WorkoutSessionManager()
    static let sessionSavedNotification = Notification.Name("WorkoutSessionSaved")
    private init() {}

    private func sessionsCollection(userId: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("sessions")
    }

    private func sessionDocument(userId: String, sessionId: String) -> DocumentReference {
        sessionsCollection(userId: userId).document(sessionId)
    }

    func saveCompletedSession(_ session: WorkoutSession) async throws {
        try sessionDocument(userId: session.userId, sessionId: session.id)
            .setData(from: session, merge: false)
        NotificationCenter.default.post(name: Self.sessionSavedNotification, object: nil)
    }

    func listRecentSessions(userId: String, limit: Int = 5) async throws -> [WorkoutSession] {
        let snapshot = try await sessionsCollection(userId: userId)
            .order(by: WorkoutSession.CodingKeys.completedAt.rawValue, descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: WorkoutSession.self) }
    }

    func listAllCompletedSessions(userId: String) async throws -> [WorkoutSession] {
        let snapshot = try await sessionsCollection(userId: userId)
            .order(by: WorkoutSession.CodingKeys.completedAt.rawValue, descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: WorkoutSession.self) }
    }

    func getSession(userId: String, sessionId: String) async throws -> WorkoutSession {
        try await sessionDocument(userId: userId, sessionId: sessionId)
            .getDocument(as: WorkoutSession.self)
    }
}
