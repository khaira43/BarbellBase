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

            Text("Total this window: \(vm.windowTotalVolume.formattedGrouped) lbs · \(vm.windowSessionCount) session\(vm.windowSessionCount == 1 ? "" : "s")")
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
                Text("Heaviest: \(row.heaviestWeight.formattedGrouped) lbs × \(row.heaviestWeightReps)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                Text("Est. 1RM: \(row.bestEstimated1RM.formattedGrouped) lbs")
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
