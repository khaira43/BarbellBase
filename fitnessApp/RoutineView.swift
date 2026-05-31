//
//  RoutineView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-17.
//

import SwiftUI

enum Weekday: String, CaseIterable, Identifiable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

struct RoutineView: View {
    @State private var workoutsByDay: [Weekday: [Workout]] = [:]

    var body: some View {
        VStack {
            HStack {
                Text("Routine")
                    .font(.largeTitle.bold())
                    .foregroundColor(.yellow)
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.top, 1)

            ScrollView(.vertical) {
                ForEach(Weekday.allCases) { day in
                    DayWorkoutSection(
                        day: day,
                        workouts: workoutsByDay[day] ?? []
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .background(Color(hex: "#081f3a").ignoresSafeArea())
    }
}

private struct DayWorkoutSection: View {
    let day: Weekday
    let workouts: [Workout]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(day.displayName) Workout(s)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.yellow)
                .padding(.leading)
                .padding(.top, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    if workouts.isEmpty {
                        NavigationLink(destination: NewWorkoutView()) {
                            workoutCard(label: "Add Workout", systemImage: "plus")
                        }
                    } else {
                        ForEach(workouts) { workout in
                            workoutCard(label: workout.name, initial: workout.name.prefix(1))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func workoutCard(label: String, systemImage: String? = nil, initial: Substring? = nil) -> some View {
        VStack {
            Circle()
                .fill(Color.yellow)
                .frame(width: 80, height: 80)
                .overlay(
                    Group {
                        if let systemImage {
                            Image(systemName: systemImage)
                                .font(.title)
                                .foregroundColor(Color(hex: "#081f3a"))
                        } else if let initial {
                            Text(initial)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#081f3a"))
                        }
                    }
                )
            Text(label)
                .foregroundColor(.white)
                .font(.footnote)
        }
    }
}

#Preview {
    NavigationStack {
        RoutineView()
    }
}
