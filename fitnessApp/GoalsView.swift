//
//  GoalsView.swift
//  fitnessApp
//

import SwiftUI
import Combine
import Charts
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

    func evaluateAndPersistCompletions(sessions: [WorkoutSession]) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        var didChange = false
        for goal in activeGoals {
            let isHit: Bool
            switch goal.kind {
            case .lift:
                isHit = GoalsMath.liftProgress(goal: goal, sessions: sessions).isHit
            case .bodyweight:
                isHit = GoalsMath.bodyweightProgress(goal: goal, entries: bodyweightEntries).isHit
            case .frequency:
                continue
            }
            if isHit {
                do {
                    try await GoalsManager.shared.markCompleted(userId: userId, goalId: goal.id, at: Date(), silent: true)
                    didChange = true
                } catch {
                    // Non-fatal; eval will retry on next reload.
                }
            }
        }
        if didChange {
            do {
                goals = try await GoalsManager.shared.listGoals(userId: userId)
            } catch {
                errorMessage = "Couldn't refresh after completion."
            }
        }
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
    @State private var showingLogWeight = false
    @State private var editingGoal: Goal?

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
                await goalsVM.evaluateAndPersistCompletions(sessions: statsVM.sessions)
            }
            .refreshable {
                await goalsVM.load()
                await statsVM.refresh()
                await goalsVM.evaluateAndPersistCompletions(sessions: statsVM.sessions)
            }
            .sheet(isPresented: $showingAddSheet) {
                AddGoalSheet()
                    .environmentObject(goalsVM)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingLogWeight) {
                LogBodyweightSheet()
                    .environmentObject(goalsVM)
                    .presentationDetents([.medium])
            }
            .sheet(item: $editingGoal) { goal in
                EditGoalSheet(goal: goal)
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
                        onTap: { editingGoal = goal },
                        onDelete: {
                            Task { await deleteGoal(goal) }
                        }
                    )
                }
                if let freq = goalsVM.activeFrequencyGoal {
                    FrequencyGoalCard(
                        goal: freq,
                        sessions: statsVM.sessions,
                        onTap: { editingGoal = freq },
                        onDelete: { Task { await deleteGoal(freq) } }
                    )
                }
                if let bw = goalsVM.activeBodyweightGoal {
                    NavigationLink {
                        BodyweightDetailView(goal: bw)
                            .environmentObject(goalsVM)
                    } label: {
                        BodyweightGoalCard(
                            goal: bw,
                            entries: goalsVM.bodyweightEntries,
                            onTapCard: { /* unused — NavigationLink handles the tap */ },
                            onTapLog: { showingLogWeight = true },
                            onDelete: { Task { await deleteGoal(bw) } }
                        )
                    }
                    .buttonStyle(.plain)
                }
                if !goalsVM.completedGoals.isEmpty {
                    DisclosureGroup("Completed (\(goalsVM.completedGoals.count))") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(goalsVM.completedGoals) { goal in
                                CompletedGoalRow(goal: goal, onDelete: { Task { await deleteGoal(goal) } })
                            }
                        }
                        .padding(.top, 8)
                    }
                    .accentColor(.white)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
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

struct BodyweightGoalCard: View {
    let goal: Goal
    let entries: [BodyweightEntry]
    let onTapCard: () -> Void
    let onTapLog: () -> Void
    let onDelete: () -> Void

    private var progress: GoalsProgress {
        GoalsMath.bodyweightProgress(goal: goal, entries: entries)
    }

    private var trendEntries: [BodyweightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        return entries.filter { $0.loggedAt >= cutoff }.sorted { $0.loggedAt < $1.loggedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTapCard) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "figure.arms.open")
                            .foregroundColor(.yellow)
                        Text("Bodyweight")
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
                    Text("Start \(Int((goal.bodyweight?.startWeightLb ?? 0).rounded())) → Target \(progress.targetDisplay)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    if trendEntries.count >= 2 {
                        Chart(trendEntries) { e in
                            LineMark(x: .value("Date", e.loggedAt), y: .value("Weight", e.weightLb))
                                .foregroundStyle(Color.yellow)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: 60)
                    }
                }
            }
            .buttonStyle(.plain)
            Button(action: onTapLog) {
                Text("Log weight")
                    .font(.subheadline).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
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
                Text("Overdue").font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.red.opacity(0.7))
                    .foregroundColor(.white).cornerRadius(8)
            } else {
                Text("Due in \(days)d").font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white).cornerRadius(8)
            }
        }
    }
}

struct CompletedGoalRow: View {
    let goal: Goal
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundColor(.white).font(.subheadline).bold()
                if let date = goal.completedAt {
                    Text("Hit on " + date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var iconName: String {
        switch goal.kind {
        case .lift: return "dumbbell"
        case .frequency: return "calendar"
        case .bodyweight: return "figure.arms.open"
        }
    }

    private var title: String {
        switch goal.kind {
        case .lift:
            let name = goal.lift?.exerciseName ?? "Lift"
            let t = Int((goal.lift?.targetE1RM ?? 0).rounded())
            return "\(name) — \(t) lb e1RM"
        case .frequency:
            let n = goal.frequency?.workoutsPerWeek ?? 0
            return "Workouts: \(n)/wk"
        case .bodyweight:
            let t = Int((goal.bodyweight?.targetWeightLb ?? 0).rounded())
            return "Bodyweight \(t) lb"
        }
    }
}
