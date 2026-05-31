//
//  ComingSoonContent.swift
//  fitnessApp
//

import SwiftUI

struct ComingSoonContent: View {
    let title: String
    let systemImage: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            Text(title)
                .font(.largeTitle.bold())
                .foregroundColor(.yellow)
            Text("Coming Soon")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "#081f3a").ignoresSafeArea()
        ComingSoonContent(
            title: "Stats",
            systemImage: "chart.bar.fill",
            subtitle: "Track your volume, PRs, and streaks over time."
        )
    }
}
