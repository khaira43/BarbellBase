//
//  EditGoalSheet.swift
//  fitnessApp
//

import SwiftUI
import FirebaseAuth

struct EditGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var goalsVM: GoalsViewModel

    let goal: Goal

    @State private var liftTargetText: String = ""
    @State private var workoutsPerWeek: Int = 4
    @State private var bodyweightTargetText: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if goal.status == .completed {
                            Text("This goal is completed. Editing locked — you can delete it from the Completed section.")
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            kindForm
                            if goal.kind != .frequency {
                                deadlineSection
                            }
                            if let errorMessage {
                                Text(errorMessage).foregroundColor(.red).font(.caption)
                            }
                            saveButton
                        }
                        deleteButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(.red)
                }
            }
            .onAppear { hydrate() }
        }
    }

    @ViewBuilder
    private var kindForm: some View {
        switch goal.kind {
        case .lift:
            VStack(alignment: .leading, spacing: 12) {
                Text(goal.lift?.exerciseName ?? "")
                    .font(.headline).foregroundColor(.white)
                labeledField(label: "Target e1RM (lb)", text: $liftTargetText, keyboard: .decimalPad)
            }
        case .frequency:
            Stepper(value: $workoutsPerWeek, in: 1...7) {
                HStack {
                    Text("Workouts per week").foregroundColor(.white)
                    Spacer()
                    Text("\(workoutsPerWeek)").foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
        case .bodyweight:
            VStack(alignment: .leading, spacing: 12) {
                labeledField(label: "Target weight (lb)", text: $bodyweightTargetText, keyboard: .decimalPad)
                Text("Start weight: \(Int((goal.bodyweight?.startWeightLb ?? 0).rounded())) lb (locked)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $hasDeadline) {
                Text("Set deadline").foregroundColor(.white)
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            if hasDeadline {
                DatePicker("Target date", selection: $deadline, in: Date()..., displayedComponents: .date)
                    .colorScheme(.dark)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
            }
        }
    }

    private var saveButton: some View {
        Button { Task { await save() } } label: {
            HStack {
                if isSaving { ProgressView() }
                Text("Save").bold()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSave ? Color.yellow : Color.white.opacity(0.2))
            .foregroundColor(canSave ? .black : .white.opacity(0.5))
            .cornerRadius(12)
        }
        .disabled(!canSave || isSaving)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            Task { await deleteGoal() }
        } label: {
            Text("Delete Goal").bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }

    private func labeledField(label: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.white.opacity(0.8))
            TextField("", text: text)
                .keyboardType(keyboard)
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
        }
    }

    private var canSave: Bool {
        switch goal.kind {
        case .lift:
            guard let v = Double(liftTargetText), v > 0 else { return false }
            return true
        case .frequency:
            return workoutsPerWeek >= 1 && workoutsPerWeek <= 7
        case .bodyweight:
            guard let target = Double(bodyweightTargetText), target > 0 else { return false }
            return target != (goal.bodyweight?.startWeightLb ?? 0)
        }
    }

    private func hydrate() {
        switch goal.kind {
        case .lift:
            if let t = goal.lift?.targetE1RM { liftTargetText = String(Int(t.rounded())) }
        case .frequency:
            if let f = goal.frequency?.workoutsPerWeek { workoutsPerWeek = f }
        case .bodyweight:
            if let t = goal.bodyweight?.targetWeightLb { bodyweightTargetText = String(Int(t.rounded())) }
        }
        if let target = goal.targetDate {
            hasDeadline = true
            deadline = target
        }
    }

    private func save() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        defer { isSaving = false }
        var updated = goal
        switch goal.kind {
        case .lift:
            if var lift = updated.lift, let v = Double(liftTargetText) {
                lift.targetE1RM = v
                updated.lift = lift
            }
            updated.targetDate = hasDeadline ? deadline : nil
        case .frequency:
            updated.frequency = FrequencyTarget(workoutsPerWeek: workoutsPerWeek)
        case .bodyweight:
            if var bw = updated.bodyweight, let v = Double(bodyweightTargetText) {
                bw.targetWeightLb = v
                updated.bodyweight = bw
            }
            updated.targetDate = hasDeadline ? deadline : nil
        }
        do {
            try await GoalsManager.shared.updateGoal(userId: userId, goal: updated)
            await goalsVM.load()
            dismiss()
        } catch {
            errorMessage = "Couldn't save."
        }
    }

    private func deleteGoal() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await GoalsManager.shared.deleteGoal(userId: userId, goalId: goal.id)
            await goalsVM.load()
            dismiss()
        } catch {
            errorMessage = "Couldn't delete."
        }
    }
}
