//
//  ExercisePickerSheet.swift
//  fitnessApp
//

import SwiftUI

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = ExerciseCatalog.shared

    @State private var searchText: String = ""

    let userId: String
    var onPick: (_ exerciseId: String, _ exerciseName: String) -> Void

    private var filteredItems: [ExerciseCatalogItem] {
        catalog.search(searchText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField
                    list
                }
            }
            .navigationTitle("Pick Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(.red)
                }
            }
            .task {
                await catalog.loadCustom(userId: userId)
            }
        }
    }

    private var searchField: some View {
        TextField("", text: $searchText, prompt: Text("Search").foregroundColor(.white.opacity(0.6)))
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .padding()
    }

    private var list: some View {
        List(filteredItems) { item in
            Button {
                onPick(item.id, item.name)
                dismiss()
            } label: {
                Text(item.name)
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.white.opacity(0.06))
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#081f3a"))
    }
}
