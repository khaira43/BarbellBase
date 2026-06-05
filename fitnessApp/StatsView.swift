//
//  StatsView.swift
//  fitnessApp
//

import SwiftUI

// MARK: - Helper types

enum TimeWindow: String, CaseIterable, Identifiable {
    case fourWeeks
    case twelveWeeks
    case allTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fourWeeks:   return "4w"
        case .twelveWeeks: return "12w"
        case .allTime:     return "All"
        }
    }
}

// MARK: - StatsViewModel

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedWindow: TimeWindow = .twelveWeeks

    private var needsRefresh: Bool = true
    private var sessionSavedObserver: NSObjectProtocol?

    init() {
        sessionSavedObserver = NotificationCenter.default.addObserver(
            forName: WorkoutSessionManager.sessionSavedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // `queue: .main` guarantees the calling thread, but MainActor
            // isolation isn't inferred — hop explicitly.
            Task { @MainActor [weak self] in
                self?.needsRefresh = true
            }
        }
    }

    deinit {
        if let observer = sessionSavedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var totalWorkouts: Int { sessions.count }

    private var weekStartsWithSession: Set<Date> {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        var starts: Set<Date> = []
        for session in sessions {
            guard let completed = session.completedAt else { continue }
            let components = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: completed
            )
            if let weekStart = calendar.date(from: components) {
                starts.insert(weekStart)
            }
        }
        return starts
    }

    var currentStreakWeeks: Int {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let starts = weekStartsWithSession
        guard !starts.isEmpty else { return 0 }
        let today = Date()
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: today
        )
        guard var cursor = calendar.date(from: components) else { return 0 }
        var streak = 0
        while starts.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        return streak
    }

    var longestStreakWeeks: Int {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let sorted = weekStartsWithSession.sorted()
        guard !sorted.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<sorted.count {
            let diff = calendar.dateComponents(
                [.weekOfYear],
                from: sorted[index - 1],
                to: sorted[index]
            ).weekOfYear ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private var userId: String? {
        (try? AuthenticationManager.shared.getAuthenticatedUser())?.uid
    }

    func loadIfNeeded() async {
        guard let uid = userId else { return }
        guard sessions.isEmpty || needsRefresh else { return }
        await fetch(userId: uid)
    }

    func refresh() async {
        guard let uid = userId else { return }
        await fetch(userId: uid)
    }

    private func fetch(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await WorkoutSessionManager.shared
                .listAllCompletedSessions(userId: userId)
                .filter { $0.completedAt != nil }
            self.sessions = loaded
            self.needsRefresh = false
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Couldn't load stats. Pull to refresh."
        }
    }
}

// MARK: - StatsView

struct StatsView: View {
    @EnvironmentObject private var vm: StatsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                content
            }
            .navigationTitle("Stats")
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await vm.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.sessions.isEmpty && vm.isLoading {
            ProgressView().tint(.yellow)
        } else if vm.sessions.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage = vm.errorMessage {
                        errorBanner(errorMessage)
                    }
                    headerTiles
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .refreshable { await vm.refresh() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow.opacity(0.8))
            Text("No stats yet")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Finish your first workout to see your progress here.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundColor(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.4))
            .cornerRadius(8)
            .padding(.horizontal)
    }

    private var headerTiles: some View {
        HStack(spacing: 12) {
            statTile(
                title: "Total Workouts",
                value: "\(vm.totalWorkouts)",
                subtitle: nil
            )
            statTile(
                title: "Current Streak",
                value: "\(vm.currentStreakWeeks)",
                subtitle: "weeks · longest \(vm.longestStreakWeeks)"
            )
        }
    }

    private func statTile(title: String, value: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(.yellow)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }
}

#Preview {
    StatsView()
        .environmentObject(StatsViewModel())
}
