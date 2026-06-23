//
//  WorkoutTemplateEditorView.swift
//  fitnessApp
//

import SwiftUI

@MainActor
final class WorkoutTemplateEditorViewModel: ObservableObject {
    @Published var name: String
    @Published var exercises: [PlannedExercise]
    @Published var errorMessage: String?
    @Published var isSaving: Bool = false

    let userId: String
    let existingId: String?
    private let dateCreated: Date

    init(template: WorkoutTemplate? = nil, userId: String) {
        self.userId = userId
        self.existingId = template?.id
        self.name = template?.name ?? ""
        self.exercises = template?.exercises ?? []
        self.dateCreated = template?.dateCreated ?? Date()
    }

    var isEditing: Bool { existingId != nil }

    var snapshotForSession: WorkoutTemplate? {
        guard let existingId else { return nil }
        return WorkoutTemplate(
            id: existingId,
            userId: userId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workout" : name,
            exercises: exercises,
            dateCreated: dateCreated,
            dateUpdated: Date()
        )
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
    }

    func addExercise(_ exercise: PlannedExercise) {
        exercises.append(exercise)
    }

    func remove(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }

    func move(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }

    func save() async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Give your workout a name."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let template = WorkoutTemplate(
            id: existingId ?? UUID().uuidString,
            userId: userId,
            name: trimmed,
            exercises: exercises,
            dateCreated: dateCreated,
            dateUpdated: Date()
        )

        do {
            if isEditing {
                try await WorkoutTemplateManager.shared.updateTemplate(template)
            } else {
                try await WorkoutTemplateManager.shared.createTemplate(template)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Couldn't save workout. Try again."
            return false
        }
    }

    func delete() async -> Bool {
        guard let existingId else { return true }
        isSaving = true
        defer { isSaving = false }
        do {
            try await WorkoutTemplateManager.shared.deleteTemplate(userId: userId, templateId: existingId)
            return true
        } catch {
            errorMessage = "Couldn't delete workout."
            return false
        }
    }
}

struct WorkoutTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WorkoutTemplateEditorViewModel
    @State private var showingAddExercise = false
    @State private var showingDeleteConfirm = false
    @State private var presentingSession: Bool = false

    init(template: WorkoutTemplate? = nil, userId: String) {
        _viewModel = StateObject(
            wrappedValue: WorkoutTemplateEditorViewModel(template: template, userId: userId)
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            VStack(spacing: 16) {
                nameField

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                exerciseList

                addExerciseButton

                saveButton

                if viewModel.isEditing {
                    startButton
                    deleteButton
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(viewModel.isEditing ? "Edit Workout" : "New Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView(userId: viewModel.userId) { planned in
                viewModel.addExercise(planned)
            }
        }
        .alert("Delete Workout?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This can't be undone.")
        }
        .fullScreenCover(isPresented: $presentingSession) {
            if let template = viewModel.snapshotForSession {
                ActiveSessionView(template: template, userId: viewModel.userId)
            }
        }
    }

    private var nameField: some View {
        TextField(
            "",
            text: $viewModel.name,
            prompt: Text("Workout name").foregroundColor(.white.opacity(0.5))
        )
        .padding()
        .background(Color(hex: "#06152a"))
        .foregroundColor(.white)
        .tint(.yellow)
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var exerciseList: some View {
        List {
            ForEach(viewModel.exercises) { exercise in
                exerciseRow(exercise)
                    .listRowBackground(Color(hex: "#0c2548"))
            }
            .onDelete { offsets in viewModel.remove(at: offsets) }
            .onMove { source, destination in viewModel.move(from: source, to: destination) }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .environment(\.editMode, .constant(.active))
    }

    private func exerciseRow(_ exercise: PlannedExercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                Text(targetSummary(exercise))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
    }

    private func targetSummary(_ exercise: PlannedExercise) -> String {
        var pieces = ["\(exercise.targetSets) × \(exercise.targetReps)"]
        if let weight = exercise.targetWeight {
            pieces.append("\(weight.formattedWeight) lbs")
        }
        return pieces.joined(separator: " · ")
    }

    private var addExerciseButton: some View {
        Button {
            showingAddExercise = true
        } label: {
            Label("Add Exercise", systemImage: "plus.circle.fill")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow.opacity(0.15))
                .foregroundColor(.yellow)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }

    private var saveButton: some View {
        Button {
            Task {
                if await viewModel.save() {
                    dismiss()
                }
            }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView().tint(Color(hex: "#081f3a"))
                }
                Text(viewModel.isEditing ? "Save Changes" : "Save Workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canSave ? Color.yellow : Color.yellow.opacity(0.4))
            .foregroundColor(Color(hex: "#081f3a"))
            .cornerRadius(10)
        }
        .disabled(!viewModel.canSave)
        .padding(.horizontal)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            Text("Delete Workout")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .padding(.horizontal)
    }

    private var startButton: some View {
        Button {
            presentingSession = true
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.yellow.opacity(0.2))
            .foregroundColor(.yellow)
            .cornerRadius(10)
        }
        .disabled(viewModel.exercises.isEmpty)
        .padding(.horizontal)
    }
}
