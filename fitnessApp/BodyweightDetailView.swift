//
//  BodyweightDetailView.swift
//  fitnessApp
//

import SwiftUI
import Charts
import FirebaseAuth

struct BodyweightDetailView: View {
    @EnvironmentObject private var goalsVM: GoalsViewModel

    let goal: Goal

    @State private var showingLogSheet = false
    @State private var showingEditSheet = false

    private var entriesAsc: [BodyweightEntry] {
        goalsVM.bodyweightEntries.sorted { $0.loggedAt < $1.loggedAt }
    }

    var body: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Text("Log weight").bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }

                    if entriesAsc.count >= 2 {
                        Chart(entriesAsc) { e in
                            LineMark(x: .value("Date", e.loggedAt), y: .value("Weight", e.weightLb))
                                .foregroundStyle(Color.yellow)
                            PointMark(x: .value("Date", e.loggedAt), y: .value("Weight", e.weightLb))
                                .foregroundStyle(Color.yellow)
                        }
                        .frame(height: 220)
                        .padding(.horizontal)
                    } else {
                        Text("Log at least 2 entries to see a chart.")
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text("History").font(.headline).foregroundColor(.white)
                    ForEach(goalsVM.bodyweightEntries) { entry in
                        HStack {
                            Text(entry.loggedAt.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(entry.weightLb.rounded())) lb")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(10)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await deleteEntry(entry) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Bodyweight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit Goal") { showingEditSheet = true }
                    .foregroundColor(.yellow)
            }
        }
        .sheet(isPresented: $showingLogSheet) {
            LogBodyweightSheet()
                .environmentObject(goalsVM)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingEditSheet) {
            EditGoalSheet(goal: goal)
                .environmentObject(goalsVM)
                .presentationDetents([.large])
        }
    }

    private func deleteEntry(_ entry: BodyweightEntry) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        do {
            try await GoalsManager.shared.deleteBodyweightEntry(userId: userId, entryId: entry.id)
            await goalsVM.load()
        } catch {
            goalsVM.errorMessage = "Couldn't delete entry."
        }
    }
}

// Temporary stub — replaced in Task 12.
struct EditGoalSheet: View {
    let goal: Goal
    var body: some View { Text("Edit Goal placeholder").padding() }
}
