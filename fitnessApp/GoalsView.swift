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

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                ComingSoonContent(
                    title: "Goals",
                    systemImage: "target",
                    subtitle: "Set targets for lifts, weight, and frequency."
                )
            }
            .navigationTitle("Goals")
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await goalsVM.loadIfNeeded()
                await statsVM.loadIfNeeded()
            }
        }
    }
}
