//
//  ExerciseDetailView.swift
//  fitnessApp
//

import SwiftUI
import Charts

struct ExerciseDetailView: View {
    let exerciseId: String
    let exerciseName: String

    @EnvironmentObject private var statsVM: StatsViewModel
    @State private var window: TimeWindow = .twelveWeeks
    @State private var selectedHistorySession: WorkoutSession?

    var body: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    tilesRow
                        .padding(.horizontal)
                    chartCard
                        .padding(.horizontal)
                    historyCard
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $selectedHistorySession) { session in
            SessionSummaryView(
                session: session,
                mode: .readOnly,
                onDismiss: { selectedHistorySession = nil }
            )
        }
    }

    // MARK: - Derived data

    private var sessionsContainingExercise: [WorkoutSession] {
        statsVM.sessions.filter { session in
            session.exercises.contains { $0.exerciseId == exerciseId }
        }
    }

    private var pointsInWindow: [(date: Date, e1rm: Double)] {
        let cutoff = windowCutoff()
        return sessionsContainingExercise.compactMap { session in
            guard let completed = session.completedAt, completed >= cutoff else { return nil }
            let best = bestE1RM(in: session)
            guard best > 0 else { return nil }
            return (completed, best)
        }
        .sorted { $0.date < $1.date }
    }

    private func windowCutoff() -> Date {
        let calendar = Calendar.current
        switch window {
        case .fourWeeks:
            return calendar.date(byAdding: .day, value: -28, to: Date()) ?? .distantPast
        case .twelveWeeks:
            return calendar.date(byAdding: .weekOfYear, value: -12, to: Date()) ?? .distantPast
        case .allTime:
            return .distantPast
        }
    }

    private func bestE1RM(in session: WorkoutSession) -> Double {
        session.exercises
            .filter { $0.exerciseId == exerciseId }
            .flatMap(\.sets)
            .compactMap { set -> Double? in
                guard set.isCompleted, let weight = set.actualWeight, weight > 0 else {
                    return nil
                }
                return StatsMath.epleyOneRepMax(weight: weight, reps: set.actualReps)
            }
            .max() ?? 0
    }

    private var heaviestWeight: Double {
        statsVM.prRows.first(where: { $0.exerciseId == exerciseId })?.heaviestWeight ?? 0
    }

    private var heaviestReps: Int {
        statsVM.prRows.first(where: { $0.exerciseId == exerciseId })?.heaviestWeightReps ?? 0
    }

    private var bestE1RMOverall: Double {
        statsVM.prRows.first(where: { $0.exerciseId == exerciseId })?.bestEstimated1RM ?? 0
    }

    // MARK: - View pieces

    private var tilesRow: some View {
        HStack(spacing: 12) {
            tile(title: "Heaviest", value: "\(heaviestWeight.formattedGrouped)", subtitle: "lbs × \(heaviestReps)")
            tile(title: "Est. 1RM", value: "\(bestE1RMOverall.formattedGrouped)", subtitle: "lbs")
            tile(title: "Sessions", value: "\(sessionsContainingExercise.count)", subtitle: nil)
        }
    }

    private func tile(title: String, value: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundColor(.yellow)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(10)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Estimated 1RM")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Picker("Window", selection: $window) {
                    ForEach(TimeWindow.allCases) { w in
                        Text(w.label).tag(w)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .colorScheme(.dark)
            }
            let points = pointsInWindow
            if points.isEmpty {
                Text("No sessions in this window")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(Array(points.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("e1RM", point.e1rm)
                    )
                    .foregroundStyle(Color.yellow)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("e1RM", point.e1rm)
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
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)
                .foregroundColor(.white)

            let sessions = sessionsContainingExercise.sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }

            ForEach(sessions) { session in
                Button {
                    selectedHistorySession = session
                } label: {
                    sessionCard(session)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
    }

    private func sessionCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(relativeDateLabel(session.completedAt ?? session.startedAt))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text(session.templateName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            ForEach(setLines(in: session), id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(10)
        .background(Color(hex: "#081f3a"))
        .cornerRadius(8)
    }

    private func setLines(in session: WorkoutSession) -> [String] {
        let exercises = session.exercises.filter { $0.exerciseId == exerciseId }
        let sets = exercises.flatMap(\.sets).filter(\.isCompleted)
        return sets.enumerated().map { index, set in
            let weight = set.actualWeight ?? 0
            let e1rm = weight > 0
                ? StatsMath.epleyOneRepMax(weight: weight, reps: set.actualReps)
                : 0
            if weight > 0 {
                return "Set \(index + 1) — \(set.actualReps) × \(weight.formattedGrouped) lbs (e1RM \(e1rm.formattedGrouped))"
            } else {
                return "Set \(index + 1) — \(set.actualReps) reps"
            }
        }
    }

    private func relativeDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

}
