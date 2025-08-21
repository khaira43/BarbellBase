//
//  AddExerciseView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-24.
//

import SwiftUI

struct AddExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var exercises: [String]
    @State private var exerciseName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Exercise Name", text: $exerciseName)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .foregroundColor(.black)

                Button("Add") {
                    if !exerciseName.isEmpty {
                        exercises.append(exerciseName)
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow)
                .foregroundColor(Color(hex: "#081f3a"))
                .cornerRadius(10)

                Spacer()
            }
            .padding()
            .navigationTitle("Add Exercise")
            .background(Color(hex: "#081f3a").ignoresSafeArea())
        }
    }
}

#Preview {
    AddExerciseView(exercises: .constant(["Bench Press", "Squat"]))
}
