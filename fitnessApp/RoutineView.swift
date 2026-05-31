//
//  RoutineView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-17.
//

import SwiftUI

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published private(set) var templatesById: [String: WorkoutTemplate] = [:]
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var schedule: Schedule?
    @Published var errorMessage: String?

    var userId: String? {
        (try? AuthenticationManager.shared.getAuthenticatedUser())?.uid
    }

    func load() async {
        guard let uid = userId else { return }
        do {
            async let templatesTask = WorkoutTemplateManager.shared.listTemplates(userId: uid)
            async let scheduleTask = ScheduleManager.shared.getSchedule(userId: uid)
            let loadedTemplates = try await templatesTask
            let loadedSchedule = try await scheduleTask
            self.templates = loadedTemplates
            self.templatesById = Dictionary(uniqueKeysWithValues: loadedTemplates.map { ($0.id, $0) })
            self.schedule = loadedSchedule
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Couldn't load schedule."
        }
    }

    func template(for day: Weekday) -> WorkoutTemplate? {
        guard let id = schedule?.assignments[day] else { return nil }
        return templatesById[id]
    }

    func assign(_ templateId: String?, to day: Weekday) async {
        guard let uid = userId else { return }
        do {
            try await ScheduleManager.shared.assignWorkout(userId: uid, day: day, templateId: templateId)
            if var sched = schedule {
                if let templateId {
                    sched.assignments[day] = templateId
                } else {
                    sched.assignments.removeValue(forKey: day)
                }
                schedule = sched
            }
        } catch {
            errorMessage = "Couldn't update schedule."
        }
    }
}

struct RoutineView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var assigningDay: Weekday?

    var body: some View {
        ZStack {
            Color(hex: "#081f3a").ignoresSafeArea()
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Weekly Plan")
                            .font(.largeTitle.bold())
                            .foregroundColor(.yellow)
                            .padding(.horizontal)
                        Spacer()
                    }
                    .padding(.top, 1)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.horizontal)
                    }

                    ForEach(Weekday.allCases) { day in
                        dayRow(day)
                    }
                }
                .padding(.bottom, 24)
            }
            .refreshable {
                await viewModel.load()
            }
        }
        .navigationTitle("Weekly Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.load()
        }
        .sheet(item: $assigningDay) { day in
            AssignWorkoutSheet(
                day: day,
                templates: viewModel.templates,
                currentTemplateId: viewModel.schedule?.assignments[day]
            ) { templateId in
                Task { await viewModel.assign(templateId, to: day) }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func dayRow(_ day: Weekday) -> some View {
        let assigned = viewModel.template(for: day)
        Button {
            assigningDay = day
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.displayName)
                        .font(.headline)
                        .foregroundColor(.yellow)
                    if let assigned {
                        Text(assigned.name)
                            .foregroundColor(.white)
                    } else {
                        Text("Rest Day · Tap to Assign")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.subheadline)
                    }
                }
                Spacer()
                Image(systemName: assigned == nil ? "plus.circle" : "chevron.right")
                    .foregroundColor(.yellow)
            }
            .padding()
            .background(Color(hex: "#0c2548"))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct AssignWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let day: Weekday
    let templates: [WorkoutTemplate]
    let currentTemplateId: String?
    let onSelect: (String?) -> Void

    var body: some View {
        NavigationStack {
            List {
                if !templates.isEmpty {
                    Section("Assign a Workout") {
                        ForEach(templates) { template in
                            Button {
                                onSelect(template.id)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(template.name)
                                    Spacer()
                                    if template.id == currentTemplateId {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        Text("No workouts yet. Create one from the Workout tab first.")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        Text(currentTemplateId == nil ? "Leave Unassigned" : "Clear Assignment")
                    }
                }
            }
            .navigationTitle(day.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RoutineView()
    }
}
