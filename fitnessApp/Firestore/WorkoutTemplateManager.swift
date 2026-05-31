//
//  WorkoutTemplateManager.swift
//  fitnessApp
//

import Foundation
import FirebaseFirestore

final class WorkoutTemplateManager {
    static let shared = WorkoutTemplateManager()
    private init() {}

    private func templatesCollection(userId: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("workoutTemplates")
    }

    private func templateDocument(userId: String, templateId: String) -> DocumentReference {
        templatesCollection(userId: userId).document(templateId)
    }

    func createTemplate(_ template: WorkoutTemplate) async throws {
        try templateDocument(userId: template.userId, templateId: template.id)
            .setData(from: template, merge: false)
    }

    func updateTemplate(_ template: WorkoutTemplate) async throws {
        var updated = template
        updated.dateUpdated = Date()
        try templateDocument(userId: updated.userId, templateId: updated.id)
            .setData(from: updated, merge: false)
    }

    func deleteTemplate(userId: String, templateId: String) async throws {
        try await templateDocument(userId: userId, templateId: templateId).delete()
    }

    func getTemplate(userId: String, templateId: String) async throws -> WorkoutTemplate {
        try await templateDocument(userId: userId, templateId: templateId)
            .getDocument(as: WorkoutTemplate.self)
    }

    func listTemplates(userId: String) async throws -> [WorkoutTemplate] {
        let snapshot = try await templatesCollection(userId: userId)
            .order(by: WorkoutTemplate.CodingKeys.dateUpdated.rawValue, descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: WorkoutTemplate.self) }
    }
}
