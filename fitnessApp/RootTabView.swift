//
//  RootTabView.swift
//  fitnessApp
//

import SwiftUI

struct RootTabView: View {
    @Binding var showSignInView: Bool
    @StateObject private var statsViewModel = StatsViewModel()
    @StateObject private var goalsViewModel = GoalsViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()

    @State private var showingHandleClaim = false

    init(showSignInView: Binding<Bool> = .constant(false)) {
        self._showSignInView = showSignInView
    }

    var body: some View {
        TabView {
            StatsView()
                .environmentObject(statsViewModel)
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            FriendsView()
                .environmentObject(friendsViewModel)
                .tabItem { Label("Friends", systemImage: "person.2") }
                .badge(friendsViewModel.pendingIncomingRequests.count)

            WorkoutView()
                .tabItem { Label("Workout", systemImage: "bolt.circle") }

            NavigationStack {
                ProfileView(showSignInView: $showSignInView)
            }
            .environmentObject(friendsViewModel)
            .tabItem { Label("Profile", systemImage: "person") }

            GoalsView()
                .environmentObject(goalsViewModel)
                .environmentObject(statsViewModel)
                .tabItem { Label("Goals", systemImage: "target") }
        }
        .tint(.yellow)
        .toolbarBackground(Color(hex: "#06152a"), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .task {
            await friendsViewModel.load()
            if let user = friendsViewModel.currentUser, user.handle == nil {
                showingHandleClaim = true
            }
        }
        .onChange(of: friendsViewModel.currentUser?.handle) { _, newValue in
            if newValue != nil { showingHandleClaim = false }
        }
        .fullScreenCover(isPresented: $showingHandleClaim) {
            ClaimHandleSheet(isInitialSetup: true)
                .environmentObject(friendsViewModel)
        }
    }
}

#Preview {
    RootTabView()
}
