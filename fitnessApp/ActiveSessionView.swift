//
//  ActiveSessionView.swift
//  fitnessApp

import SwiftUI

@MainActor
final class ActiveSessionViewModel: ObservableObject {
    @Published var session: WorkoutSession
    @Published var elapsedSeconds: Int = 0
    @Published var errorMessage: String?
    @Published var isSaving: Bool = false
    @Published var didFinish: Bool = false

    private var elapsedTimer: Timer?

    init(session: WorkoutSession) {
        self.session = session
        startElapsedTimer()
    }

    deinit {
        elapsedTimer?.invalidate()
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(self.session.startedAt))
            }
        }
    }

    var completedSetCount: Int {
        session.exercises.reduce(0) { sum, ex in sum + ex.sets.filter(\.isCompleted).count }
    }

    var totalSetCount: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    var canFinish: Bool {
        completedSetCount > 0 && !isSaving
    }

    func toggleSetComplete(exerciseId: String, setId: String) {
        guard let eIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              let sIdx = session.exercises[eIdx].sets.firstIndex(where: { $0.id == setId })
        else { return }
        var set = session.exercises[eIdx].sets[sIdx]
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? Date() : nil
        session.exercises[eIdx].sets[sIdx] = set
    }

    func updateReps(exerciseId: String, setId: String, reps: Int) {
        guard let eIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              let sIdx = session.exercises[eIdx].sets.firstIndex(where: { $0.id == setId })
        else { return }
        session.exercises[eIdx].sets[sIdx].actualReps = reps
    }

    func updateWeight(exerciseId: String, setId: String, weight: Double?) {
        guard let eIdx = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              let sIdx = session.exercises[eIdx].sets.firstIndex(where: { $0.id == setId })
        else { return }
        session.exercises[eIdx].sets[sIdx].actualWeight = weight
    }

    func finish() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        var done = session
        done.completedAt = Date()
        do {
            try await WorkoutSessionManager.shared.saveCompletedSession(done)
            session = done
            didFinish = true
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't save workout. Try again."
        }
    }
}

struct ActiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ActiveSessionViewModel
    @State private var showingDiscardConfirm = false

    init(template: WorkoutTemplate, userId: String) {
        let session = WorkoutSession.starting(from: template, userId: userId)
        _viewModel = StateObject(wrappedValue: ActiveSessionViewModel(session: session))
    }

    var body: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.session.exercises) { exercise in
                            exerciseCard(exercise)
                        }
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 16)
                }
                finishBar
            }
        }
        .alert("Discard workout?", isPresented: $showingDiscardConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your logged sets won't be saved.")
        }
        .onChange(of: viewModel.didFinish) { _, finished in
            if finished { dismiss() }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.session.templateName)
                    .font(.headline)
                    .foregroundColor(.yellow)
                Text(formatElapsed(viewModel.elapsedSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button {
                showingDiscardConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(hex: "#06152a"))
    }

    private func exerciseCard(_ exercise: LoggedExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.exerciseName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(exercise.sets.filter(\.isCompleted).count) / \(exercise.sets.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
            }
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                setRow(exerciseId: exercise.id, set: set, index: index)
            }
        }
        .padding()
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func setRow(exerciseId: String, set: LoggedSet, index: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.toggleSetComplete(exerciseId: exerciseId, setId: set.id)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(set.isCompleted ? .yellow : .white.opacity(0.5))
                    .font(.title3)
            }
            Text("Set \(index + 1)")
                .foregroundColor(.white.opacity(set.isCompleted ? 0.5 : 1.0))
                .frame(width: 56, alignment: .leading)
            repsField(exerciseId: exerciseId, set: set)
            weightField(exerciseId: exerciseId, set: set)
        }
    }

    private func repsField(exerciseId: String, set: LoggedSet) -> some View {
        let binding = Binding<String>(
            get: { String(set.actualReps) },
            set: { viewModel.updateReps(exerciseId: exerciseId, setId: set.id, reps: Int($0) ?? 0) }
        )
        return HStack(spacing: 4) {
            TextField("0", text: binding)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 44)
                .padding(.vertical, 4)
                .background(Color(hex: "#06152a"))
                .foregroundColor(.white)
                .cornerRadius(6)
            Text("reps")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func weightField(exerciseId: String, set: LoggedSet) -> some View {
        let binding = Binding<String>(
            get: { set.actualWeight.map { formatWeight($0) } ?? "" },
            set: { viewModel.updateWeight(exerciseId: exerciseId, setId: set.id, weight: Double($0)) }
        )
        return HStack(spacing: 4) {
            TextField("—", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 56)
                .padding(.vertical, 4)
                .background(Color(hex: "#06152a"))
                .foregroundColor(.white)
                .cornerRadius(6)
            Text("lbs")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var finishBar: some View {
        Button {
            Task { await viewModel.finish() }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView().tint(Color(hex: "#081f3a"))
                }
                Text("Finish Workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canFinish ? Color.yellow : Color.yellow.opacity(0.4))
            .foregroundColor(Color(hex: "#081f3a"))
            .cornerRadius(10)
        }
        .disabled(!viewModel.canFinish)
        .padding()
        .background(Color(hex: "#06152a"))
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
