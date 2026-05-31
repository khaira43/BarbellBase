//
//  StatsView.swift
//  fitnessApp
//

import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                ComingSoonContent(
                    title: "Stats",
                    systemImage: "chart.bar.fill",
                    subtitle: "Track your volume, PRs, and streaks over time."
                )
            }
            .navigationTitle("Stats")
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    StatsView()
}
