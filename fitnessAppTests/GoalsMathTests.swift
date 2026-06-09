//
//  GoalsMathTests.swift
//  fitnessAppTests
//

import Testing
import Foundation
@testable import fitnessApp

struct GoalsMathTests {

    // MARK: - Helpers

    private func liftGoal(exerciseId: String = "ex-1", targetE1RM: Double = 300) -> Goal {
        Goal(
            kind: .lift,
            lift: LiftTarget(exerciseId: exerciseId, exerciseName: "Bench Press", targetE1RM: targetE1RM)
        )
    }

    private func frequencyGoal(workoutsPerWeek: Int = 4) -> Goal {
        Goal(kind: .frequency, frequency: FrequencyTarget(workoutsPerWeek: workoutsPerWeek))
    }

    private func bodyweightGoal(start: Double, target: Double) -> Goal {
        Goal(
            kind: .bodyweight,
            bodyweight: BodyweightTarget(targetWeightLb: target, startWeightLb: start)
        )
    }

    private func session(
        completedAt: Date,
        exerciseId: String,
        sets: [(weight: Double, reps: Int)]
    ) -> WorkoutSession {
        // LoggedSet init fills actualReps/actualWeight from target when not passed.
        // We pass isCompleted: true because GoalsMath.liftProgress skips uncompleted sets.
        let loggedSets = sets.map {
            LoggedSet(targetReps: $0.reps, targetWeight: $0.weight, isCompleted: true)
        }
        let exercise = LoggedExercise(exerciseId: exerciseId, exerciseName: "Test Exercise", sets: loggedSets)
        return WorkoutSession(
            userId: "u",
            templateId: "t",
            templateName: "T",
            startedAt: completedAt,
            completedAt: completedAt,
            exercises: [exercise]
        )
    }

    private func emptySession(completedAt: Date) -> WorkoutSession {
        WorkoutSession(
            userId: "u",
            templateId: "t",
            templateName: "T",
            startedAt: completedAt,
            completedAt: completedAt,
            exercises: []
        )
    }

    // MARK: - Lift

    @Test func liftProgress_noSessions_isZero() {
        let p = GoalsMath.liftProgress(goal: liftGoal(), sessions: [])
        #expect(p.percent == 0)
        #expect(p.currentDisplay == "—")
        #expect(p.isHit == false)
    }

    @Test func liftProgress_partialProgress() {
        // 200 lb × 5 reps → Epley = 200 * (1 + 5/30) ≈ 233.33 → ~78% of 300.
        let s = session(completedAt: Date(), exerciseId: "ex-1", sets: [(200, 5)])
        let p = GoalsMath.liftProgress(goal: liftGoal(targetE1RM: 300), sessions: [s])
        #expect(p.percent > 0.7 && p.percent < 0.8)
        #expect(p.isHit == false)
    }

    @Test func liftProgress_exactHit() {
        // 250 lb × 8 reps → Epley = 250 * (1 + 8/30) ≈ 316.67 → over 300.
        let s = session(completedAt: Date(), exerciseId: "ex-1", sets: [(250, 8)])
        let p = GoalsMath.liftProgress(goal: liftGoal(targetE1RM: 300), sessions: [s])
        #expect(p.percent == 1.0)
        #expect(p.isHit == true)
    }

    @Test func liftProgress_ignoresOtherExercises() {
        let s = session(completedAt: Date(), exerciseId: "ex-OTHER", sets: [(250, 8)])
        let p = GoalsMath.liftProgress(goal: liftGoal(), sessions: [s])
        #expect(p.percent == 0)
        #expect(p.isHit == false)
    }

    @Test func liftProgress_ignoresZeroWeightOrZeroReps() {
        let s = session(
            completedAt: Date(),
            exerciseId: "ex-1",
            sets: [(0, 5), (200, 0), (250, 8)] // only the last is valid
        )
        let p = GoalsMath.liftProgress(goal: liftGoal(targetE1RM: 300), sessions: [s])
        #expect(p.isHit == true)
    }

    @Test func liftProgress_ignoresUncompletedSets() {
        // Manually build a session where the heavy set isn't marked completed.
        let uncompletedSet = LoggedSet(targetReps: 8, targetWeight: 250, isCompleted: false)
        let exercise = LoggedExercise(exerciseId: "ex-1", exerciseName: "Bench Press", sets: [uncompletedSet])
        let s = WorkoutSession(
            userId: "u",
            templateId: "t",
            templateName: "T",
            startedAt: Date(),
            completedAt: Date(),
            exercises: [exercise]
        )
        let p = GoalsMath.liftProgress(goal: liftGoal(targetE1RM: 300), sessions: [s])
        #expect(p.percent == 0)
        #expect(p.currentDisplay == "—")
        #expect(p.isHit == false)
    }

    // MARK: - Frequency

    @Test func frequencyProgress_emptyWeek_isZero() {
        let now = Date()
        let p = GoalsMath.frequencyProgress(goal: frequencyGoal(workoutsPerWeek: 4), sessions: [], now: now)
        #expect(p.percent == 0)
        #expect(p.currentDisplay == "0 / 4")
        #expect(p.isHit == false)
    }

    @Test func frequencyProgress_hitsTarget() {
        let now = Date()
        let sessions = (0..<4).map { _ in emptySession(completedAt: now) }
        let p = GoalsMath.frequencyProgress(goal: frequencyGoal(workoutsPerWeek: 4), sessions: sessions, now: now)
        #expect(p.percent == 1.0)
        #expect(p.isHit == true)
    }

    @Test func frequencyProgress_excludesLastWeek() {
        let calendar = StatsMath.mondayCalendar()
        let now = Date()
        guard let lastWeek = calendar.date(byAdding: .day, value: -8, to: now) else {
            Issue.record("date math failed")
            return
        }
        let sessions = [emptySession(completedAt: lastWeek), emptySession(completedAt: now)]
        let p = GoalsMath.frequencyProgress(goal: frequencyGoal(workoutsPerWeek: 4), sessions: sessions, now: now)
        #expect(p.currentDisplay == "1 / 4")
    }

    // MARK: - Bodyweight

    @Test func bodyweightProgress_noEntries_isZero() {
        let p = GoalsMath.bodyweightProgress(
            goal: bodyweightGoal(start: 180, target: 175),
            entries: []
        )
        #expect(p.percent == 0)
        #expect(p.currentDisplay == "—")
    }

    @Test func bodyweightProgress_cutPartial() {
        // start 180 → target 175 (5 lb cut). Current 178 = 2 lb down = 40%.
        let entries = [BodyweightEntry(weightLb: 178, loggedAt: Date())]
        let p = GoalsMath.bodyweightProgress(
            goal: bodyweightGoal(start: 180, target: 175),
            entries: entries
        )
        #expect(p.percent == 0.4)
        #expect(p.isHit == false)
    }

    @Test func bodyweightProgress_cutHit() {
        let entries = [BodyweightEntry(weightLb: 174, loggedAt: Date())]
        let p = GoalsMath.bodyweightProgress(
            goal: bodyweightGoal(start: 180, target: 175),
            entries: entries
        )
        #expect(p.percent == 1.0)
        #expect(p.isHit == true)
    }

    @Test func bodyweightProgress_bulkPartial() {
        // start 175 → target 185 (10 lb bulk). Current 180 = 5 lb up = 50%.
        let entries = [BodyweightEntry(weightLb: 180, loggedAt: Date())]
        let p = GoalsMath.bodyweightProgress(
            goal: bodyweightGoal(start: 175, target: 185),
            entries: entries
        )
        #expect(p.percent == 0.5)
        #expect(p.isHit == false)
    }

    @Test func bodyweightProgress_bulkHit() {
        let entries = [BodyweightEntry(weightLb: 186, loggedAt: Date())]
        let p = GoalsMath.bodyweightProgress(
            goal: bodyweightGoal(start: 175, target: 185),
            entries: entries
        )
        #expect(p.percent == 1.0)
        #expect(p.isHit == true)
    }

    @Test func bodyweightProgress_wrongDirection_clampsToZero() {
        // bulk goal but user lost weight
        let entries = [BodyweightEntry(weightLb: 170, loggedAt: Date())]
        let p = GoalsMath.bodyweightProgress(
            goal: bodyweightGoal(start: 175, target: 185),
            entries: entries
        )
        #expect(p.percent == 0)
        #expect(p.isHit == false)
    }
}
