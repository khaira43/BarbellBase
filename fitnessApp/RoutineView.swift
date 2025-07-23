//
//  RoutineView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-17.
//

import SwiftUI

struct RoutineView: View {
    @State private var Workouts1: [Workout] = []  // Example data structure
    @State private var Workouts2: [Workout] = []
    @State private var Workouts3: [Workout] = []
    @State private var Workouts4: [Workout] = []
    @State private var Workouts5: [Workout] = []
    @State private var Workouts6: [Workout] = []
    @State private var Workouts7: [Workout] = []
    @State private var selectedTab: Tab = .workout

    enum Tab {
        case stats, friends, workout, profile, goals
    }

    var body: some View {
        NavigationStack {
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
                    Text("Sunday Workout(s)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if Workouts1.isEmpty {
                                NavigationLink(destination: NewWorkoutView()) {
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
                                        Text("Add Workout")
                                            .foregroundColor(.yellow)
                                            .font(.footnote)
                                    }
                                }
                            } else {
                                ForEach(Workouts1) { workout in
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
                    
                    Text("Monday Workout(s)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if Workouts2.isEmpty {
                                NavigationLink(destination: NewWorkoutView()) {
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
                                        Text("Add Workout")
                                            .foregroundColor(.yellow)
                                            .font(.footnote)
                                    }
                                }
                            } else {
                                ForEach(Workouts2) { workout in
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
                    
                    Text("Tuesday Workout(s)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if Workouts3.isEmpty {
                                NavigationLink(destination: NewWorkoutView()) {
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
                                        Text("Add Workout")
                                            .foregroundColor(.yellow)
                                            .font(.footnote)
                                    }
                                }
                            } else {
                                ForEach(Workouts3) { workout in
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
                    
                    Text("Wednesday Workout(s)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if Workouts4.isEmpty {
                                NavigationLink(destination: NewWorkoutView()) {
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
                                        Text("Add Workout")
                                            .foregroundColor(.yellow)
                                            .font(.footnote)
                                    }
                                }
                            } else {
                                ForEach(Workouts4) { workout in
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
                    
                    Text("Thursday Workout(s)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if Workouts5.isEmpty {
                                NavigationLink(destination: NewWorkoutView()) {
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
                                        Text("Add Workout")
                                            .foregroundColor(.yellow)
                                            .font(.footnote)
                                    }
                                }
                            } else {
                                ForEach(Workouts5) { workout in
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
                    
                    Text("Friday Workout(s)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if Workouts6.isEmpty {
                                NavigationLink(destination: NewWorkoutView()) {
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
                                        Text("Add Workout")
                                            .foregroundColor(.yellow)
                                            .font(.footnote)
                                    }
                                }
                            } else {
                                ForEach(Workouts6) { workout in
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
                    
                    Text("Saturday Workout(s)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .padding(.leading)
                        .padding(.top, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            if Workouts7.isEmpty {
                                NavigationLink(destination: NewWorkoutView()) {
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
                                        Text("Add Workout")
                                            .foregroundColor(.yellow)
                                            .font(.footnote)
                                    }
                                }
                            } else {
                                ForEach(Workouts7) { workout in
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

                    

                }
                // Routines Section

                Spacer()

                // Tab Bar
                HStack {
                    tabBarButton(icon: "chart.bar", label: "Stats", tab: .stats)
                    tabBarButton(
                        icon: "person.2",
                        label: "Friends",
                        tab: .friends
                    )
                    tabBarButton(
                        icon: "bolt.circle",
                        label: "Workout",
                        tab: .workout
                    )
                    tabBarButton(
                        icon: "person",
                        label: "Profile",
                        tab: .profile
                    )
                    tabBarButton(icon: "target", label: "Goals", tab: .goals)
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
            
            .background(Color(hex: "#081f3a").ignoresSafeArea())
        }
    }

    @ViewBuilder
    private func tabBarButton(icon: String, label: String, tab: Tab)
        -> some View
    {
        Button(action: {
            selectedTab = tab
            // Navigation logic here
        }) {
            VStack {
                Image(systemName: icon)
                    .font(.headline)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(selectedTab == tab ? .yellow : .white)
            .frame(maxWidth: .infinity)
        }
    }
}


//struct Workout: Identifiable {
//    var id = UUID()
//    var name: String
//}


#Preview {
    RoutineView()
}
