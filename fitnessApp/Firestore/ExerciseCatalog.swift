//
//  ExerciseCatalog.swift
//  fitnessApp
//

import Foundation
import FirebaseFirestore

@MainActor
final class ExerciseCatalog: ObservableObject {
    static let shared = ExerciseCatalog()

    @Published private(set) var seeded: [ExerciseCatalogItem] = []
    @Published private(set) var custom: [ExerciseCatalogItem] = []

    var all: [ExerciseCatalogItem] {
        (seeded + custom).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private init() {
        loadSeeded()
    }

    func loadSeeded() {
        guard let url = Bundle.main.url(forResource: "SeededExercises", withExtension: "json") else {
            print("SeededExercises.json missing from bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let items = try decoder.decode([SeededItem].self, from: data)
            self.seeded = items.map {
                ExerciseCatalogItem(
                    id: $0.id,
                    name: $0.name,
                    category: ExerciseCategory(rawValue: $0.category) ?? .other,
                    isCustom: false
                )
            }
        } catch {
            print("Failed to decode SeededExercises.json: \(error)")
        }
    }

    func loadCustom(userId: String) async {
        do {
            let snapshot = try await customCollection(userId: userId).getDocuments()
            self.custom = snapshot.documents.compactMap {
                try? $0.data(as: ExerciseCatalogItem.self)
            }
        } catch {
            print("Failed to load custom exercises: \(error)")
        }
    }

    func addCustom(userId: String, name: String, category: ExerciseCategory) async throws -> ExerciseCatalogItem {
        let item = ExerciseCatalogItem(
            id: UUID().uuidString,
            name: name,
            category: category,
            isCustom: true
        )
        try customCollection(userId: userId).document(item.id).setData(from: item, merge: false)
        custom.append(item)
        return item
    }

    func deleteCustom(userId: String, itemId: String) async throws {
        try await customCollection(userId: userId).document(itemId).delete()
        custom.removeAll { $0.id == itemId }
    }

    func search(_ query: String) -> [ExerciseCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private func customCollection(userId: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("customExercises")
    }

    private struct SeededItem: Codable {
        let id: String
        let name: String
        let category: String
    }
}
