//
//  StatsViewModel.swift
//  fitnessApp
//
//  Extracted from StatsView.swift to keep that file focused on the view.
//

import SwiftUI

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedWindow: TimeWindow = .twelveWeeks

    private var needsRefresh: Bool = true
    private var hasFetched: Bool = false
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
        let calendar = StatsMath.mondayCalendar()
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
        let calendar = StatsMath.mondayCalendar()
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
        let calendar = StatsMath.mondayCalendar()
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

    private var sessionsInWindow: [WorkoutSession] {
        let calendar = StatsMath.mondayCalendar()
        switch selectedWindow {
        case .fourWeeks:
            guard let cutoff = calendar.date(byAdding: .day, value: -28, to: Date()) else {
                return sessions
            }
            return sessions.filter { ($0.completedAt ?? .distantPast) >= cutoff }
        case .twelveWeeks:
            let today = Date()
            guard
                let thisWeekStart = calendar.date(
                    from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
                ),
                let cutoff = calendar.date(byAdding: .weekOfYear, value: -11, to: thisWeekStart)
            else {
                return sessions
            }
            return sessions.filter { ($0.completedAt ?? .distantPast) >= cutoff }
        case .allTime:
            return sessions
        }
    }

    var windowSessionCount: Int { sessionsInWindow.count }

    var windowTotalVolume: Double {
        sessionsInWindow.reduce(0) { $0 + StatsMath.volume(of: $1) }
    }

    var volumeSeries: [VolumeBin] {
        let calendar = StatsMath.mondayCalendar()
        switch selectedWindow {
        case .fourWeeks:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return sessionsInWindow
                .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
                .compactMap { session in
                    guard let date = session.completedAt else { return nil }
                    return VolumeBin(
                        label: formatter.string(from: date),
                        date: date,
                        volume: StatsMath.volume(of: session)
                    )
                }
        case .twelveWeeks:
            return weeklyBins(weeks: 12, calendar: calendar)
        case .allTime:
            return monthlyBins(calendar: calendar)
        }
    }

    private func weeklyBins(weeks: Int, calendar: Calendar) -> [VolumeBin] {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let today = Date()
        guard let thisWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        ) else { return [] }

        var bins: [(weekStart: Date, volume: Double)] = []
        for offset in (0..<weeks).reversed() {
            if let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) {
                bins.append((start, 0))
            }
        }
        for session in sessions {
            guard let completed = session.completedAt else { continue }
            let components = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: completed
            )
            guard let weekStart = calendar.date(from: components) else { continue }
            if let index = bins.firstIndex(where: { $0.weekStart == weekStart }) {
                bins[index].volume += StatsMath.volume(of: session)
            }
        }
        return bins.map {
            VolumeBin(label: formatter.string(from: $0.weekStart), date: $0.weekStart, volume: $0.volume)
        }
    }

    private func monthlyBins(calendar: Calendar) -> [VolumeBin] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        guard let earliest = sessions.compactMap(\.completedAt).min() else { return [] }
        let today = Date()
        guard
            let startMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: earliest)
            ),
            let endMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: today)
            )
        else { return [] }

        var bins: [(monthStart: Date, volume: Double)] = []
        var cursor = startMonth
        while cursor <= endMonth {
            bins.append((cursor, 0))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        for session in sessions {
            guard let completed = session.completedAt else { continue }
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: completed)
            )
            guard let monthStart else { continue }
            if let index = bins.firstIndex(where: { $0.monthStart == monthStart }) {
                bins[index].volume += StatsMath.volume(of: session)
            }
        }
        return bins.map {
            VolumeBin(label: formatter.string(from: $0.monthStart), date: $0.monthStart, volume: $0.volume)
        }
    }

    private var userId: String? {
        (try? AuthenticationManager.shared.getAuthenticatedUser())?.uid
    }

    func loadIfNeeded() async {
        guard let uid = userId else { return }
        guard !hasFetched || needsRefresh else { return }
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
            self.hasFetched = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Couldn't load stats. Pull to refresh."
        }
    }

    var prRows: [ExercisePRRow] {
        struct Aggregate {
            var exerciseName: String
            var heaviestWeight: Double = 0
            var heaviestWeightReps: Int = 0
            var bestE1RM: Double = 0
        }

        var byExercise: [String: Aggregate] = [:]
        for session in sessions {
            for exercise in session.exercises {
                for set in exercise.sets {
                    guard set.isCompleted, let weight = set.actualWeight, weight > 0 else {
                        continue
                    }
                    let e1rm = StatsMath.epleyOneRepMax(weight: weight, reps: set.actualReps)
                    var agg = byExercise[exercise.exerciseId]
                        ?? Aggregate(exerciseName: exercise.exerciseName)
                    agg.exerciseName = exercise.exerciseName // keep latest name
                    if weight > agg.heaviestWeight {
                        agg.heaviestWeight = weight
                        agg.heaviestWeightReps = set.actualReps
                    }
                    if e1rm > agg.bestE1RM {
                        agg.bestE1RM = e1rm
                    }
                    byExercise[exercise.exerciseId] = agg
                }
            }
        }

        return byExercise
            .map { id, agg in
                ExercisePRRow(
                    exerciseId: id,
                    exerciseName: agg.exerciseName,
                    heaviestWeight: agg.heaviestWeight,
                    heaviestWeightReps: agg.heaviestWeightReps,
                    bestEstimated1RM: agg.bestE1RM
                )
            }
            .sorted { $0.bestEstimated1RM > $1.bestEstimated1RM }
    }

    var categorySplit: [(category: ExerciseCategory, volume: Double)] {
        let catalog = ExerciseCatalog.shared.all
        let lookup: [String: ExerciseCategory] = Dictionary(
            uniqueKeysWithValues: catalog.map { ($0.id, $0.category) }
        )

        var totals: [ExerciseCategory: Double] = [:]
        for session in sessionsInWindow {
            for exercise in session.exercises {
                let category = lookup[exercise.exerciseId] ?? .other
                let exerciseVolume = exercise.sets.reduce(0.0) { sum, set in
                    guard set.isCompleted, let weight = set.actualWeight, weight > 0 else {
                        return sum
                    }
                    return sum + Double(set.actualReps) * weight
                }
                if exerciseVolume > 0 {
                    totals[category, default: 0] += exerciseVolume
                }
            }
        }

        return totals
            .filter { $0.value > 0 }
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }
}
