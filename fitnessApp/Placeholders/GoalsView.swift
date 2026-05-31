//
//  GoalsView.swift
//  fitnessApp
//

import SwiftUI

struct GoalsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                ComingSoonContent(
                    title: "Goals",
                    systemImage: "target",
                    subtitle: "Set targets for lifts, weight, and frequency."
                )
            }
            .navigationTitle("Goals")
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    GoalsView()
}
