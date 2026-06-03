//
//  WorkoutView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-15.
//

import SwiftUI

@MainActor
final class WorkoutListViewModel: ObservableObject {
    @Published private(set) var templates: [WorkoutTemplate] = []
    @Published private(set) var todaysTemplateId: String?
    @Published var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    var userId: String? {
        (try? AuthenticationManager.shared.getAuthenticatedUser())?.uid
    }

    var todaysTemplate: WorkoutTemplate? {
        guard let id = todaysTemplateId else { return nil }
        return templates.first { $0.id == id }
    }

    func load() async {
        guard let uid = userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let templatesTask = WorkoutTemplateManager.shared.listTemplates(userId: uid)
            async let scheduleTask = ScheduleManager.shared.getSchedule(userId: uid)
            let loadedTemplates = try await templatesTask
            let schedule = try await scheduleTask
            self.templates = loadedTemplates
            self.todaysTemplateId = schedule.assignments[.today]
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Couldn't load workouts."
        }
    }
}

struct WorkoutView: View {
    @StateObject private var viewModel = WorkoutListViewModel()
    @State private var presentingSessionFor: WorkoutTemplate?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        header

                        startTodayButton

                        sectionHeader("Routines")
                        routinesRow

                        weeklyPlanLink

                        sectionHeader("Recent Workouts")
                        recentWorkoutsRow

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await viewModel.load()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.load()
            }
            .fullScreenCover(item: $presentingSessionFor) { template in
                if let uid = viewModel.userId {
                    ActiveSessionView(template: template, userId: uid)
                        .onDisappear {
                            Task { await viewModel.load() }
                        }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Workout")
                .font(.largeTitle.bold())
                .foregroundColor(.yellow)
                .padding(.horizontal)
            Spacer()
        }
        .padding(.top, 1)
    }

    @ViewBuilder
    private var startTodayButton: some View {
        if let template = viewModel.todaysTemplate, viewModel.userId != nil {
            Button {
                presentingSessionFor = template
            } label: {
                VStack(spacing: 4) {
                    Text("Start Today's Workout")
                        .fontWeight(.semibold)
                    Text(template.name)
                        .font(.caption)
                        .opacity(0.8)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.yellow)
                .foregroundColor(Color(hex: "#081f3a"))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
        } else {
            VStack(spacing: 4) {
                Text("No Workout Scheduled for \(Weekday.today.displayName)")
                    .fontWeight(.semibold)
                Text("Assign one in your weekly plan.")
                    .font(.caption)
                    .opacity(0.8)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.yellow.opacity(0.2))
            .foregroundColor(.yellow)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.yellow)
                .padding(.leading)
                .padding(.top, 24)
            Spacer()
        }
    }

    @ViewBuilder
    private var routinesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                if let uid = viewModel.userId {
                    NavigationLink {
                        WorkoutTemplateEditorView(userId: uid)
                    } label: {
                        circleCard(label: "Add Routine", systemImage: "plus")
                    }
                }
                ForEach(viewModel.templates) { template in
                    if let uid = viewModel.userId {
                        NavigationLink {
                            WorkoutTemplateEditorView(template: template, userId: uid)
                        } label: {
                            circleCard(label: template.name, initial: template.name.prefix(1))
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var weeklyPlanLink: some View {
        NavigationLink {
            RoutineView()
        } label: {
            HStack {
                Image(systemName: "calendar")
                Text("Manage Weekly Plan")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color(hex: "#06152a"))
            .foregroundColor(.yellow)
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var recentWorkoutsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                VStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.25))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "clock")
                                .font(.title)
                                .foregroundColor(.yellow)
                        )
                    Text("Coming Soon")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.footnote)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func circleCard(label: String, systemImage: String? = nil, initial: Substring? = nil) -> some View {
        VStack {
            Circle()
                .fill(Color.yellow)
                .frame(width: 80, height: 80)
                .overlay(
                    Group {
                        if let systemImage {
                            Image(systemName: systemImage)
                                .font(.title)
                                .foregroundColor(Color(hex: "#081f3a"))
                        } else if let initial {
                            Text(initial)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#081f3a"))
                        }
                    }
                )
            Text(label)
                .foregroundColor(.white)
                .font(.footnote)
                .lineLimit(1)
        }
    }
}

#Preview {
    WorkoutView()
}
