//
//  AddGoalSheet.swift
//  fitnessApp
//

import SwiftUI
import FirebaseAuth

struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var goalsVM: GoalsViewModel

    @State private var selectedKind: Goal.Kind = .lift

    // Lift
    @State private var liftExerciseId: String = ""
    @State private var liftExerciseName: String = ""
    @State private var liftTargetText: String = ""
    @State private var showingPicker = false

    // Frequency
    @State private var workoutsPerWeek: Int = 4

    // Bodyweight
    @State private var bodyweightTargetText: String = ""
    @State private var startWeightText: String = ""
    @State private var needsStartWeightEntry: Bool = false

    // Deadline (lift + bodyweight)
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    @State private var errorBanner: String?
    @State private var isSaving = false

    private var userId: String? { Auth.auth().currentUser?.uid }

    private var availableKinds: [Goal.Kind] {
        var kinds: [Goal.Kind] = [.lift]
        if goalsVM.activeFrequencyGoal == nil { kinds.append(.frequency) }
        if goalsVM.activeBodyweightGoal == nil { kinds.append(.bodyweight) }
        return kinds
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        kindPicker
                        if let errorBanner {
                            Text(errorBanner)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        switch selectedKind {
                        case .lift: liftForm
                        case .frequency: frequencyForm
                        case .bodyweight: bodyweightForm
                        }
                        if selectedKind != .frequency {
                            deadlineSection
                        }
                        createButton
                    }
                    .padding()
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showingPicker) {
                if let userId {
                    ExercisePickerSheet(userId: userId) { id, name in
                        liftExerciseId = id
                        liftExerciseName = name
                    }
                }
            }
            .task {
                needsStartWeightEntry = goalsVM.bodyweightEntries.isEmpty
                if !availableKinds.contains(selectedKind) {
                    selectedKind = availableKinds.first ?? .lift
                }
            }
        }
    }

    // MARK: - Sections

    private var kindPicker: some View {
        Picker("Kind", selection: $selectedKind) {
            ForEach(availableKinds, id: \.self) { kind in
                Text(kindLabel(kind)).tag(kind)
            }
        }
        .pickerStyle(.segmented)
    }

    private func kindLabel(_ kind: Goal.Kind) -> String {
        switch kind {
        case .lift: return "Lift"
        case .frequency: return "Frequency"
        case .bodyweight: return "Bodyweight"
        }
    }

    private var liftForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingPicker = true
            } label: {
                HStack {
                    Text(liftExerciseName.isEmpty ? "Pick exercise" : liftExerciseName)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
            }

            labeledField(label: "Target e1RM (lb)", text: $liftTargetText, keyboard: .decimalPad)
        }
    }

    private var frequencyForm: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        }
    }

    private var bodyweightForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledField(label: "Target weight (lb)", text: $bodyweightTargetText, keyboard: .decimalPad)
            if needsStartWeightEntry {
                labeledField(label: "Current weight (lb)", text: $startWeightText, keyboard: .decimalPad)
                Text("You haven't logged your bodyweight yet — this becomes the start point for tracking progress.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            } else if let latest = goalsVM.bodyweightEntries.first {
                Text("Start weight: \(Int(latest.weightLb.rounded())) lb (from last entry)")
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

    private var createButton: some View {
        Button {
            Task { await createGoal() }
        } label: {
            HStack {
                if isSaving { ProgressView() }
                Text("Create Goal").bold()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCreate ? Color.yellow : Color.white.opacity(0.2))
            .foregroundColor(canCreate ? .black : .white.opacity(0.5))
            .cornerRadius(12)
        }
        .disabled(!canCreate || isSaving)
    }

    // MARK: - Validation + save

    private var canCreate: Bool {
        switch selectedKind {
        case .lift:
            guard !liftExerciseId.isEmpty, let v = Double(liftTargetText), v > 0 else { return false }
            return true
        case .frequency:
            return workoutsPerWeek >= 1 && workoutsPerWeek <= 7
        case .bodyweight:
            guard let target = Double(bodyweightTargetText), target > 0 else { return false }
            let start: Double?
            if needsStartWeightEntry {
                start = Double(startWeightText)
                guard let s = start, s > 0 else { return false }
                if s == target { return false }
            } else {
                start = goalsVM.bodyweightEntries.first?.weightLb
                guard let s = start, s != target else { return false }
            }
            return true
        }
    }

    private func createGoal() async {
        guard let userId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            switch selectedKind {
            case .lift:
                let target = Double(liftTargetText) ?? 0
                let goal = Goal(
                    kind: .lift,
                    targetDate: hasDeadline ? deadline : nil,
                    lift: LiftTarget(exerciseId: liftExerciseId, exerciseName: liftExerciseName, targetE1RM: target)
                )
                try await GoalsManager.shared.createGoal(userId: userId, goal: goal)
            case .frequency:
                let goal = Goal(
                    kind: .frequency,
                    frequency: FrequencyTarget(workoutsPerWeek: workoutsPerWeek)
                )
                try await GoalsManager.shared.createGoal(userId: userId, goal: goal)
            case .bodyweight:
                let target = Double(bodyweightTargetText) ?? 0
                let start: Double
                if needsStartWeightEntry {
                    let s = Double(startWeightText) ?? 0
                    try await GoalsManager.shared.logBodyweight(userId: userId, weightLb: s, at: Date())
                    start = s
                } else {
                    start = goalsVM.bodyweightEntries.first?.weightLb ?? 0
                }
                let goal = Goal(
                    kind: .bodyweight,
                    targetDate: hasDeadline ? deadline : nil,
                    bodyweight: BodyweightTarget(targetWeightLb: target, startWeightLb: start)
                )
                try await GoalsManager.shared.createGoal(userId: userId, goal: goal)
            }
            await goalsVM.load()
            dismiss()
        } catch GoalsError.singletonKindExists(let k) {
            errorBanner = "You already have an active \(kindLabel(k).lowercased()) goal."
        } catch {
            errorBanner = "Couldn't create goal: \(error.localizedDescription)"
        }
    }
}
