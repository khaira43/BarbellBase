//
//  WorkoutView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-15.
//

import SwiftUI

struct WorkoutView: View {
    @State private var routines: [Routine] = []
    @State private var recentWorkouts: [Workout] = []  // Example data structure
    @State private var selectedTab: Tab = .workout

    enum Tab {
        case stats, friends, workout, profile, goals
    }

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

                // Start Today's Workout Button
                Button(action: {
                    // Action to start workout
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
                    Text("Routines")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if routines.isEmpty {
                                NavigationLink(destination: RoutineView()) {
                                    VStack {
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "plus")
                                                    .font(.title)
                                                    .foregroundColor(
                                                        Color(hex: "#081f3a")
                                                    )
                                            )
                                        Text("Add Routine")
                                            .foregroundColor(.yellow)
                                            .font(.footnote)
                                    }
                                }
                            } else {
                                ForEach(routines) { routine in
                                    VStack {
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Text(routine.name.prefix(1))
                                                    .font(.title)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(
                                                        Color(hex: "#081f3a")
                                                    )
                                            )
                                        Text(routine.name)
                                            .foregroundColor(.white)
                                            .font(.footnote)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    Text("Recent Workouts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if recentWorkouts.isEmpty {
                                Button(action: {
                                    // Action to add new routine
                                }) {
                                    VStack {
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "plus")
                                                    .font(.title)
                                                    .foregroundColor(
                                                        Color(hex: "#081f3a")
                                                    )
                                            )
                                        Text("Create Workout")
                                            .foregroundColor(.yellow)
                                            .font(.footnote)
                                    }
                                }
                            } else {
                                ForEach(recentWorkouts) { workout in
                                    VStack {
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Text(workout.name.prefix(1))
                                                    .font(.title)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(
                                                        Color(hex: "#081f3a")
                                                    )
                                            )
                                        Text(workout.name)
                                            .foregroundColor(.white)
                                            .font(.footnote)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }

                    Text("Example Routines")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    Text("Example Workouts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                }
                // Routines Section

                Spacer()

                // Tab Bar
                HStack {
                    tabBarButton(
                        icon: "chart.bar",
                        label: "Stats",
                        tab: .stats,
                        destination: ProfileView(showSignInView: .constant(false))
                    )
                    tabBarButton(
                        icon: "person.2",
                        label: "Friends",
                        tab: .friends,
                        destination: ProfileView(showSignInView: .constant(false))
                    )
                    tabBarButton(
                        icon: "bolt.circle",
                        label: "Workout",
                        tab: .workout,
                        destination: ProfileView(showSignInView: .constant(false))
                    )
                    tabBarButton(
                        icon: "person",
                        label: "Profile",
                        tab: .profile,
                        destination: ProfileView(showSignInView: .constant(false))
                        
                    )
                    tabBarButton(
                        icon: "target",
                        label: "Goals",
                        tab: .goals,
                        destination: ProfileView(showSignInView: .constant(false))
                    )
                }
                .padding()
                .background(Color(hex: "#06152a"))
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .padding(.horizontal)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            //            .toolbar {
            //                ToolbarItem(placement: .navigationBarLeading) {
            //                    Text("Workout")
            //                        .font(.largeTitle.bold())
            //                        .foregroundColor(.yellow)
            //                }
            //            }
            .navigationBarBackButtonHidden(true)
            .background(Color(hex: "#081f3a").ignoresSafeArea())
        }
    }

    @ViewBuilder
    private func tabBarButton(icon: String, label: String, tab: Tab, destination: some View) -> some View {
        NavigationLink (
            destination: destination,
            label: {
                VStack {
                    Image(systemName: icon)
                        .font(.headline)
                    Text(label)
                        .font(.caption2)
                }
                .foregroundColor(selectedTab == tab ? .yellow : .white)
                .frame(maxWidth: .infinity)
            }
        )
        .simultaneousGesture(TapGesture().onEnded {
            selectedTab = tab
        })
    }
//        Button(action: {
//            selectedTab = tab
//            // Navigation logic here
//        }) {
//            VStack {
//                Image(systemName: icon)
//                    .font(.headline)
//                Text(label)
//                    .font(.caption2)
//            }
//            .foregroundColor(selectedTab == tab ? .yellow : .white)
//            .frame(maxWidth: .infinity)
//        }
                
    
}

// Dummy model (replace with your actual model)
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
