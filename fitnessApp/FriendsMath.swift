//
//  FriendsMath.swift
//  fitnessApp
//

import Foundation

enum FriendsMath {
    static let minHandleLength = 3
    static let maxHandleLength = 20

    /// Allowed handle: lowercase a-z (input may be uppercase; we lowercase at storage),
    /// must start with a letter, then [a-z0-9_]{minLength-1..maxLength-1}.
    static func isValidHandle(_ handle: String) -> Bool {
        let lower = handle.lowercased()
        guard lower.count >= minHandleLength, lower.count <= maxHandleLength else { return false }
        guard let first = lower.first, first.isLetter else { return false }
        return lower.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    /// Returns a user-facing error string for an invalid handle, or `nil` if valid.
    static func handleValidationError(for handle: String) -> String? {
        let lower = handle.lowercased()
        if lower.count < minHandleLength { return "At least \(minHandleLength) characters." }
        if lower.count > maxHandleLength { return "At most \(maxHandleLength) characters." }
        if let first = lower.first, !first.isLetter { return "Must start with a letter." }
        if !lower.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return "Letters, numbers, and underscore only."
        }
        return nil
    }

    /// Returns the set of exerciseIds in `session` for which the session's best e1RM
    /// is strictly greater than the best e1RM from `priorSessions` (sessions logged before).
    /// "Prior" is filtered by `completedAt` strictly less than the session's `completedAt`.
    static func prHighlights(for session: WorkoutSession, priorSessions: [WorkoutSession]) -> Set<String> {
        guard let sessionCompletedAt = session.completedAt else { return [] }
        let earlier = priorSessions.filter { other in
            guard let c = other.completedAt else { return false }
            return c < sessionCompletedAt
        }

        var prs: Set<String> = []
        for exercise in session.exercises {
            let currentBest = bestE1RM(in: exercise)
            guard currentBest > 0 else { continue }
            let priorBest = earlier.reduce(0.0) { acc, s in
                let e = s.exercises.first { $0.exerciseId == exercise.exerciseId }.map(bestE1RM(in:)) ?? 0
                return max(acc, e)
            }
            if currentBest > priorBest {
                prs.insert(exercise.exerciseId)
            }
        }
        return prs
    }

    private static func bestE1RM(in exercise: LoggedExercise) -> Double {
        var best: Double = 0
        for set in exercise.sets {
            guard set.isCompleted, let weight = set.actualWeight, weight > 0, set.actualReps > 0 else { continue }
            let e = StatsMath.epleyOneRepMax(weight: weight, reps: set.actualReps)
            if e > best { best = e }
        }
        return best
    }
}
