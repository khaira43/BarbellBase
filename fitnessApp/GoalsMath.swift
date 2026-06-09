//
//  GoalsMath.swift
//  fitnessApp
//

import Foundation

struct GoalsProgress: Equatable {
    let percent: Double
    let currentDisplay: String
    let targetDisplay: String
    let isHit: Bool
}

enum GoalsMath {
    static func liftProgress(goal: Goal, sessions: [WorkoutSession]) -> GoalsProgress {
        guard let lift = goal.lift else {
            return GoalsProgress(percent: 0, currentDisplay: "—", targetDisplay: "—", isHit: false)
        }
        var maxE1RM: Double = 0
        var sawAnySet = false
        for session in sessions {
            for exercise in session.exercises where exercise.exerciseId == lift.exerciseId {
                for set in exercise.sets {
                    guard let weight = set.actualWeight, weight > 0, set.actualReps > 0 else { continue }
                    sawAnySet = true
                    let e1rm = StatsMath.epleyOneRepMax(weight: weight, reps: set.actualReps)
                    if e1rm > maxE1RM { maxE1RM = e1rm }
                }
            }
        }
        let percent = lift.targetE1RM > 0 ? min(maxE1RM / lift.targetE1RM, 1.0) : 0
        let currentDisplay = sawAnySet ? "\(Int(maxE1RM.rounded())) lb e1RM" : "—"
        let targetDisplay = "\(Int(lift.targetE1RM.rounded())) lb"
        return GoalsProgress(
            percent: max(percent, 0),
            currentDisplay: currentDisplay,
            targetDisplay: targetDisplay,
            isHit: sawAnySet && maxE1RM >= lift.targetE1RM
        )
    }

    static func frequencyProgress(goal: Goal, sessions: [WorkoutSession], now: Date) -> GoalsProgress {
        guard let frequency = goal.frequency, frequency.workoutsPerWeek > 0 else {
            return GoalsProgress(percent: 0, currentDisplay: "0 / 0", targetDisplay: "0/wk", isHit: false)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        let weekStartComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStart = calendar.date(from: weekStartComponents),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return GoalsProgress(percent: 0, currentDisplay: "0 / \(frequency.workoutsPerWeek)", targetDisplay: "\(frequency.workoutsPerWeek)/wk", isHit: false)
        }
        let count = sessions.filter { session in
            guard let completed = session.completedAt else { return false }
            return completed >= weekStart && completed < weekEnd
        }.count
        let percent = min(Double(count) / Double(frequency.workoutsPerWeek), 1.0)
        return GoalsProgress(
            percent: max(percent, 0),
            currentDisplay: "\(count) / \(frequency.workoutsPerWeek)",
            targetDisplay: "\(frequency.workoutsPerWeek)/wk",
            isHit: count >= frequency.workoutsPerWeek
        )
    }

    static func bodyweightProgress(goal: Goal, entries: [BodyweightEntry]) -> GoalsProgress {
        guard let bodyweight = goal.bodyweight else {
            return GoalsProgress(percent: 0, currentDisplay: "—", targetDisplay: "—", isHit: false)
        }
        let targetDisplay = "\(Int(bodyweight.targetWeightLb.rounded())) lb"
        guard let current = entries.first?.weightLb else {
            return GoalsProgress(percent: 0, currentDisplay: "—", targetDisplay: targetDisplay, isHit: false)
        }
        let currentDisplay = "\(Int(current.rounded())) lb"
        let start = bodyweight.startWeightLb
        let target = bodyweight.targetWeightLb
        let isBulk = target > start
        let isCut = target < start
        let percent: Double
        let isHit: Bool
        if isBulk {
            let denom = target - start
            percent = denom > 0 ? (current - start) / denom : 0
            isHit = current >= target
        } else if isCut {
            let denom = start - target
            percent = denom > 0 ? (start - current) / denom : 0
            isHit = current <= target
        } else {
            // start == target — guarded at create time, but defensive
            percent = 1.0
            isHit = true
        }
        return GoalsProgress(
            percent: min(max(percent, 0), 1.0),
            currentDisplay: currentDisplay,
            targetDisplay: targetDisplay,
            isHit: isHit
        )
    }
}
