//
//  GoalsView.swift
//  fitnessApp
//

import SwiftUI
import Combine
import FirebaseAuth

@MainActor
final class GoalsViewModel: ObservableObject {
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var bodyweightEntries: [BodyweightEntry] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private var needsRefresh: Bool = true
    private var hasFetched: Bool = false

    private var goalSavedObserver: NSObjectProtocol?
    private var entrySavedObserver: NSObjectProtocol?
    private var sessionSavedObserver: NSObjectProtocol?

    init() {
        let nc = NotificationCenter.default
        goalSavedObserver = nc.addObserver(forName: GoalsManager.goalSavedNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.needsRefresh = true }
        }
        entrySavedObserver = nc.addObserver(forName: GoalsManager.bodyweightEntrySavedNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.needsRefresh = true }
        }
        sessionSavedObserver = nc.addObserver(forName: WorkoutSessionManager.sessionSavedNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.needsRefresh = true }
        }
    }

    deinit {
        for observer in [goalSavedObserver, entrySavedObserver, sessionSavedObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var activeGoals: [Goal] { goals.filter { $0.status == .active } }
    var completedGoals: [Goal] { goals.filter { $0.status == .completed } }

    var activeLiftGoals: [Goal] { activeGoals.filter { $0.kind == .lift } }
    var activeFrequencyGoal: Goal? { activeGoals.first { $0.kind == .frequency } }
    var activeBodyweightGoal: Goal? { activeGoals.first { $0.kind == .bodyweight } }

    func loadIfNeeded() async {
        if hasFetched && !needsRefresh { return }
        await load()
    }

    func load() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not signed in."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            async let goalsTask = GoalsManager.shared.listGoals(userId: userId)
            async let entriesTask = GoalsManager.shared.listBodyweightEntries(userId: userId)
            let (loadedGoals, loadedEntries) = try await (goalsTask, entriesTask)
            goals = loadedGoals
            bodyweightEntries = loadedEntries
            errorMessage = nil
            hasFetched = true
            needsRefresh = false
        } catch {
            errorMessage = "Couldn't load goals. Pull to refresh."
        }
    }
}

struct GoalsView: View {
    @EnvironmentObject private var goalsVM: GoalsViewModel
    @EnvironmentObject private var statsVM: StatsViewModel
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                contentBody
            }
            .navigationTitle("Goals")
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(.yellow)
                }
            }
            .task {
                await goalsVM.loadIfNeeded()
                await statsVM.loadIfNeeded()
            }
            .refreshable {
                await goalsVM.load()
                await statsVM.refresh()
            }
            .sheet(isPresented: $showingAddSheet) {
                AddGoalSheet()
                    .environmentObject(goalsVM)
                    .presentationDetents([.large])
            }
        }
    }

    private func deleteGoal(_ goal: Goal) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            try await GoalsManager.shared.deleteGoal(userId: userId, goalId: goal.id)
            await goalsVM.load()
        } catch {
            goalsVM.errorMessage = "Couldn't delete goal."
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if let errorMessage = goalsVM.errorMessage {
            errorBanner(errorMessage)
        } else if goalsVM.activeGoals.isEmpty && goalsVM.completedGoals.isEmpty {
            emptyState
        } else {
            goalsList
        }
    }

    private var emptyState: some View {
        ComingSoonContent(
            title: "No goals yet",
            systemImage: "target",
            subtitle: "Tap + to add a goal for a lift, your weekly workouts, or your bodyweight."
        )
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Text(message)
                .foregroundColor(.white)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
            Spacer()
        }
        .padding()
    }

    private var goalsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(goalsVM.activeLiftGoals) { goal in
                    LiftGoalCard(
                        goal: goal,
                        sessions: statsVM.sessions,
                        onTap: { /* opens EditGoalSheet in Task 12 — leave noop for now */ },
                        onDelete: {
                            Task { await deleteGoal(goal) }
                        }
                    )
                }
                if let freq = goalsVM.activeFrequencyGoal {
                    FrequencyGoalCard(
                        goal: freq,
                        sessions: statsVM.sessions,
                        onTap: { /* EditGoalSheet wired in Task 12 */ },
                        onDelete: { Task { await deleteGoal(freq) } }
                    )
                }
                if let bw = goalsVM.activeBodyweightGoal {
                    Text("Bodyweight goal placeholder: target \(Int(bw.bodyweight?.targetWeightLb ?? 0)) lb")
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding()
        }
    }
}

struct LiftGoalCard: View {
    let goal: Goal
    let sessions: [WorkoutSession]
    let onTap: () -> Void
    let onDelete: () -> Void

    private var progress: GoalsProgress {
        GoalsMath.liftProgress(goal: goal, sessions: sessions)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "dumbbell")
                        .foregroundColor(.yellow)
                    Text(goal.lift?.exerciseName ?? "Lift")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    deadlinePill
                }
                Text(progress.currentDisplay)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                ProgressView(value: progress.percent)
                    .tint(.yellow)
                Text("of \(progress.targetDisplay) e1RM")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var deadlinePill: some View {
        if let target = goal.targetDate {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0
            if days < 0 {
                Text("Overdue")
                    .font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.red.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            } else {
                Text("Due in \(days)d")
                    .font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}

struct FrequencyGoalCard: View {
    let goal: Goal
    let sessions: [WorkoutSession]
    let onTap: () -> Void
    let onDelete: () -> Void

    private var progress: GoalsProgress {
        GoalsMath.frequencyProgress(goal: goal, sessions: sessions, now: Date())
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.yellow)
                    Text("Workouts this week")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                Text(progress.currentDisplay)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                ProgressView(value: progress.percent)
                    .tint(.yellow)
                Text("Resets Monday")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
