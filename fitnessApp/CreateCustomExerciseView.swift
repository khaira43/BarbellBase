//
//  CreateCustomExerciseView.swift
//  fitnessApp
//

import SwiftUI

struct CreateCustomExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var category: ExerciseCategory = .other
    @State private var errorMessage: String?
    @State private var saving = false

    let userId: String
    var onCreated: (ExerciseCatalogItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseCategory.allCases) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saving = true
        defer { saving = false }
        do {
            let item = try await ExerciseCatalog.shared.addCustom(
                userId: userId,
                name: trimmed,
                category: category
            )
            onCreated(item)
            dismiss()
        } catch {
            errorMessage = "Couldn't save exercise."
        }
    }
}
