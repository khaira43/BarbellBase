//
//  NewWorkoutView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-17.
//

import SwiftUI

struct NewWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var workoutName: String = ""
    @State private var exercises: [String] = [] // Placeholder for real exercise data
    @State private var isAddingExercise = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    Text("New Workout")
                        .font(.largeTitle.bold())
                        .foregroundColor(.yellow)
                    Spacer()
                }
                .padding(.horizontal)
                
                Button {
                    isAddingExercise = true
                } label: {
                    Text("Add Exercise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(Color(hex: "#081f3a"))
                        .cornerRadius(10)
                }
                
                // List of Added Exercises (if any)
                if !exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exercises:")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                        ForEach(exercises, id: \.self) { ex in
                            Text("• \(ex)")
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                
                Spacer()
                
                Button("Save") {
                    // Save workout logic
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow)
                .foregroundColor(Color(hex: "#081f3a"))
                .cornerRadius(10)
                .padding(.bottom)
                
                
                
                
                
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .background(Color(hex: "#081f3a").ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingExercise) {
            AddExerciseView(exercises: $exercises)
        }
    }
}

#Preview {
    NewWorkoutView()
}
