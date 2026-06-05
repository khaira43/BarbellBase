//
//  RootTabView.swift
//  fitnessApp
//

import SwiftUI

struct RootTabView: View {
    @Binding var showSignInView: Bool
    @StateObject private var statsViewModel = StatsViewModel()

    init(showSignInView: Binding<Bool> = .constant(false)) {
        self._showSignInView = showSignInView
    }

    var body: some View {
        TabView {
            StatsView()
                .environmentObject(statsViewModel)
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2") }

            WorkoutView()
                .tabItem { Label("Workout", systemImage: "bolt.circle") }

            NavigationStack {
                ProfileView(showSignInView: $showSignInView)
            }
            .tabItem { Label("Profile", systemImage: "person") }

            GoalsView()
                .tabItem { Label("Goals", systemImage: "target") }
        }
        .tint(.yellow)
        .toolbarBackground(Color(hex: "#06152a"), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

#Preview {
    RootTabView()
}
