//
//  StatsView.swift
//  fitnessApp
//

import SwiftUI
import Charts

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

struct VolumeBin: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let volume: Double
}

struct ExercisePRRow: Identifiable {
    var id: String { exerciseId }
    let exerciseId: String
    let exerciseName: String
    let heaviestWeight: Double
    let heaviestWeightReps: Int
    let bestEstimated1RM: Double
}

struct ExerciseDetailDestination: Hashable {
    let exerciseId: String
    let exerciseName: String
}

enum StatsMath {
    static func volume(of session: WorkoutSession) -> Double {
        session.exercises.reduce(0) { exerciseSum, exercise in
            exerciseSum + exercise.sets.reduce(0) { setSum, set in
                guard set.isCompleted, let weight = set.actualWeight, weight > 0 else {
                    return setSum
                }
                return setSum + Double(set.actualReps) * weight
            }
        }
    }

    static func epleyOneRepMax(weight: Double, reps: Int) -> Double {
        weight * (1.0 + Double(reps) / 30.0)
    }

    static func mondayCalendar() -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
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

// MARK: - Category color helper

private extension ExerciseCategory {
    var color: Color {
        switch self {
        case .chest:     return Color.red
        case .back:      return Color.blue
        case .shoulders: return Color.orange
        case .arms:      return Color.purple
        case .legs:      return Color.green
        case .core:      return Color.pink
        case .cardio:    return Color.teal
        case .other:     return Color.gray
        }
    }
}

// MARK: - StatsView

struct StatsView: View {
    @EnvironmentObject private var vm: StatsViewModel
    @State private var showAllPRs: Bool = false

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
            .navigationDestination(for: ExerciseDetailDestination.self) { destination in
                ExerciseDetailView(
                    exerciseId: destination.exerciseId,
                    exerciseName: destination.exerciseName
                )
            }
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
                    volumeCard
                        .padding(.horizontal)
                    prCard
                        .padding(.horizontal)
                    if !vm.categorySplit.isEmpty {
                        categoryCard
                            .padding(.horizontal)
                    }
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

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Volume")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Picker("Window", selection: $vm.selectedWindow) {
                    ForEach(TimeWindow.allCases) { window in
                        Text(window.label).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            if vm.volumeSeries.allSatisfy({ $0.volume == 0 }) {
                Text("No volume in this window")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(vm.volumeSeries) { bin in
                    BarMark(
                        x: .value("Date", bin.label),
                        y: .value("Volume", bin.volume)
                    )
                    .foregroundStyle(Color.yellow)
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.6))
                    }
                }
            }

            Text("Total this window: \(formatVolume(vm.windowTotalVolume)) lbs · \(vm.windowSessionCount) session\(vm.windowSessionCount == 1 ? "" : "s")")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.headline)
                .foregroundColor(.white)

            if vm.prRows.isEmpty {
                Text("Log a workout to start tracking PRs.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                let rows = showAllPRs ? vm.prRows : Array(vm.prRows.prefix(10))
                LazyVStack(spacing: 8) {
                    ForEach(rows) { row in
                        NavigationLink(value: ExerciseDetailDestination(
                            exerciseId: row.exerciseId,
                            exerciseName: row.exerciseName
                        )) {
                            prRowView(row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if vm.prRows.count > 10 {
                    Button(showAllPRs ? "Show less" : "Show all (\(vm.prRows.count))") {
                        withAnimation { showAllPRs.toggle() }
                    }
                    .font(.footnote)
                    .foregroundColor(.yellow)
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Volume by Category")
                .font(.headline)
                .foregroundColor(.white)

            let total = vm.categorySplit.reduce(0) { $0 + $1.volume }
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(vm.categorySplit, id: \.category) { entry in
                        Rectangle()
                            .fill(entry.category.color)
                            .frame(width: geo.size.width * CGFloat(entry.volume / max(total, 1)))
                    }
                }
            }
            .frame(height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(vm.categorySplit, id: \.category) { entry in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(entry.category.color)
                            .frame(width: 10, height: 10)
                        Text(entry.category.displayName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Text("\(Int((entry.volume / max(total, 1)) * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }

    private func prRowView(_ row: ExercisePRRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(row.exerciseName)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Heaviest: \(formatVolume(row.heaviestWeight)) lbs × \(row.heaviestWeightReps)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                Text("Est. 1RM: \(formatVolume(row.bestEstimated1RM)) lbs")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func formatVolume(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
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
