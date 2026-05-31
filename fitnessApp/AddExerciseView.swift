//
//  AddExerciseView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-24.
//

import SwiftUI

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = ExerciseCatalog.shared

    @State private var searchText: String = ""
    @State private var selectedItem: ExerciseCatalogItem?
    @State private var targetSets: Int = 3
    @State private var targetReps: Int = 8
    @State private var targetWeightText: String = ""
    @State private var showingCreateCustom = false

    let userId: String
    var onAdd: (PlannedExercise) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField
                    if let selectedItem {
                        targetsSection(for: selectedItem)
                    }
                    catalogList
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showingCreateCustom) {
                CreateCustomExerciseView(userId: userId) { newItem in
                    selectedItem = newItem
                }
                .presentationDetents([.medium])
            }
            .task {
                await catalog.loadCustom(userId: userId)
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            TextField("Search exercises", text: $searchText)
                .foregroundColor(.white)
                .autocapitalization(.none)
        }
        .padding()
        .background(Color(hex: "#06152a"))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func targetsSection(for item: ExerciseCatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.yellow)
                Spacer()
                Text(item.category.displayName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 12) {
                stepperField(label: "Sets", value: $targetSets, range: 1...20)
                stepperField(label: "Reps", value: $targetReps, range: 1...50)
            }

            HStack {
                Text("Target weight (lbs)")
                    .foregroundColor(.white)
                Spacer()
                TextField("optional", text: $targetWeightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .padding(8)
                    .background(Color(hex: "#06152a"))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }

            Button {
                let planned = PlannedExercise(
                    exerciseId: item.id,
                    exerciseName: item.name,
                    targetSets: targetSets,
                    targetReps: targetReps,
                    targetWeight: Double(targetWeightText)
                )
                onAdd(planned)
                dismiss()
            } label: {
                Text("Add to Workout")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(Color(hex: "#081f3a"))
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(hex: "#0c2548"))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func stepperField(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .foregroundColor(.yellow)
                    .monospacedDigit()
            }
            .labelsHidden()
            Text("\(value.wrappedValue)")
                .foregroundColor(.yellow)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
        .padding(8)
        .background(Color(hex: "#06152a"))
        .cornerRadius(8)
    }

    private var filteredItems: [ExerciseCatalogItem] {
        catalog.search(searchText)
    }

    private var catalogList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Button {
                    showingCreateCustom = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.yellow)
                        Text("Add custom exercise")
                            .foregroundColor(.yellow)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                Divider().background(Color.white.opacity(0.2))

                ForEach(filteredItems) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .foregroundColor(.white)
                                Text(item.category.displayName + (item.isCustom ? " · Custom" : ""))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            if selectedItem?.id == item.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                    }
                    Divider().background(Color.white.opacity(0.1))
                }
            }
            .padding(.top, 8)
        }
    }
}
