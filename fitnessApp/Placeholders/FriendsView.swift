//
//  FriendsView.swift
//  fitnessApp
//

import SwiftUI

struct FriendsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                ComingSoonContent(
                    title: "Friends",
                    systemImage: "person.2.fill",
                    subtitle: "Follow lifters and compare workouts."
                )
            }
            .navigationTitle("Friends")
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    FriendsView()
}
