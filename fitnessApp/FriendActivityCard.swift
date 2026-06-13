//
//  FriendActivityCard.swift
//  fitnessApp
//

import SwiftUI

struct FriendActivityCard: View {
    @EnvironmentObject private var friendsVM: FriendsViewModel
    let session: WorkoutSession

    @State private var showingDetail = false

    private var displayName: String {
        friendsVM.displayName(forFriend: session.userId)
    }

    private var handleText: String? {
        friendsVM.handle(forFriend: session.userId).map { "@\($0)" }
    }

    private var canDrillDown: Bool {
        friendsVM.sharesFullDetails(forFriend: session.userId)
    }

    private var prHighlights: Set<String> {
        let priors = friendsVM.priorSessionsByFriend[session.userId] ?? []
        return FriendsMath.prHighlights(for: session, priorSessions: priors)
    }

    var body: some View {
        Button {
            if canDrillDown { showingDetail = true }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                header
                statRow
                if !prHighlights.isEmpty {
                    prRow
                }
                if !canDrillDown {
                    Text("Summary only")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#0c2548"))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingDetail) {
            SessionSummaryView(session: session, mode: .readOnly) {
                showingDetail = false
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                if let handleText {
                    Text(handleText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            if let completed = session.completedAt {
                Text(completed.relativeShort)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.15))
                .frame(width: 36, height: 36)
            Text(displayName.prefix(1).uppercased())
                .font(.subheadline.bold())
                .foregroundColor(.yellow)
        }
    }

    private var statRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.templateName)
                    .font(.headline)
                    .foregroundColor(.yellow)
                Text("\(setCount) sets · \(exerciseCount) exercises")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(volumeString)
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundColor(.white)
                Text("lb volume")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var prRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            Text("\(prHighlights.count) PR\(prHighlights.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.yellow.opacity(0.12))
        .cornerRadius(6)
    }

    private var setCount: Int {
        session.exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    private var exerciseCount: Int {
        session.exercises.count
    }

    private var volumeString: String {
        let v = session.exercises.flatMap(\.sets)
            .filter(\.isCompleted)
            .reduce(0.0) { $0 + Double($1.actualReps) * ($1.actualWeight ?? 0) }
        if v >= 10000 {
            return String(format: "%.1fk", v / 1000)
        }
        return String(format: "%.0f", v)
    }
}

private extension Date {
    var relativeShort: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
