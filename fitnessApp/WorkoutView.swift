//
//  WorkoutView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-15.
//

import SwiftUI

struct WorkoutView: View {
    @State private var routines: [Routine] = []
    @State private var recentWorkouts: [Workout] = []

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Text("Workout")
                        .font(.largeTitle.bold())
                        .foregroundColor(.yellow)
                        .padding(.horizontal)
                    Spacer()
                }
                .padding(.top, 1)

                Button(action: {
                    // TODO: open active workout session for today's routine
                }) {
                    Text("Start Today's Workout")
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow)
                        .foregroundColor(Color(hex: "#081f3a"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .padding(.top)

                ScrollView(.vertical) {
                    sectionHeader("Routines")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if routines.isEmpty {
                                NavigationLink(destination: RoutineView()) {
                                    circleCard(label: "Add Routine", systemImage: "plus")
                                }
                            } else {
                                ForEach(routines) { routine in
                                    circleCard(label: routine.name, initial: routine.name.prefix(1))
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    sectionHeader("Recent Workouts")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if recentWorkouts.isEmpty {
                                NavigationLink(destination: NewWorkoutView()) {
                                    circleCard(label: "Create Workout", systemImage: "plus")
                                }
                            } else {
                                ForEach(recentWorkouts) { workout in
                                    circleCard(label: workout.name, initial: workout.name.prefix(1))
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .background(Color(hex: "#081f3a").ignoresSafeArea())
        }
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.yellow)
                .padding(.leading)
                .padding(.top, 24)
            Spacer()
        }
    }

    @ViewBuilder
    private func circleCard(label: String, systemImage: String? = nil, initial: Substring? = nil) -> some View {
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

struct Routine: Identifiable {
    var id = UUID()
    var name: String
}

struct Workout: Identifiable {
    var id = UUID()
    var name: String
}

#Preview {
    WorkoutView()
}
