//
//  SessionSummaryView.swift
//  fitnessApp
//

import SwiftUI

struct SessionSummaryView: View {
    enum Mode {
        case finish   // Done button, shows "Workout Complete" header
        case readOnly // Close button, shows template name as header
    }

    let session: WorkoutSession
    let mode: Mode
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    statRow
                    exerciseBreakdown
                }
                .padding()
            }
            VStack {
                Spacer()
                doneButton
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mode == .finish ? "Workout Complete" : session.templateName)
                .font(.largeTitle.bold())
                .foregroundColor(.yellow)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var subtitle: String {
        let date = session.completedAt ?? session.startedAt
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if mode == .finish {
            return "\(session.templateName) · \(formatter.string(from: date))"
        }
        return formatter.string(from: date)
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            statTile(label: "Duration", value: durationString)
            statTile(label: "Sets", value: "\(completedSets)/\(totalSets)")
            statTile(label: "Volume", value: "\(volumeString) lbs")
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundColor(.yellow)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(10)
    }

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 8)
            ForEach(session.exercises) { exercise in
                exerciseSummary(exercise)
            }
            Color.clear.frame(height: 80)
        }
    }

    private func exerciseSummary(_ exercise: LoggedExercise) -> some View {
        let completed = exercise.sets.filter(\.isCompleted)
        return VStack(alignment: .leading, spacing: 6) {
            Text(exercise.exerciseName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            if completed.isEmpty {
                Text("No sets completed")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            } else {
                ForEach(Array(completed.enumerated()), id: \.element.id) { index, set in
                    Text("Set \(index + 1) — \(set.actualReps) × \(formatWeight(set.actualWeight))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#0c2548"))
        .cornerRadius(10)
    }

    private var doneButton: some View {
        Button {
            onDismiss()
        } label: {
            Text(mode == .finish ? "Done" : "Close")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow)
                .foregroundColor(Color(hex: "#081f3a"))
                .cornerRadius(10)
        }
        .padding()
        .background(Color(hex: "#06152a"))
    }

    private var durationString: String {
        let end = session.completedAt ?? Date()
        let total = Int(end.timeIntervalSince(session.startedAt))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var completedSets: Int {
        session.exercises.reduce(0) { sum, ex in sum + ex.sets.filter(\.isCompleted).count }
    }

    private var totalSets: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var volumeString: String {
        let total = session.exercises.flatMap(\.sets)
            .filter(\.isCompleted)
            .reduce(0.0) { $0 + Double($1.actualReps) * ($1.actualWeight ?? 0) }
        return formatWeight(total)
    }

    private func formatWeight(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
