//
//  FriendsMathTests.swift
//  fitnessAppTests
//

import Testing
import Foundation
@testable import fitnessApp

struct FriendsMathTests {

    // MARK: - Handle validation

    @Test func handle_validBasic() {
        #expect(FriendsMath.isValidHandle("ranbir"))
        #expect(FriendsMath.isValidHandle("ran_bir"))
        #expect(FriendsMath.isValidHandle("rb123"))
        #expect(FriendsMath.isValidHandle("a1b"))
    }

    @Test func handle_acceptsUppercaseAsInput() {
        // Storage is lowercased by claimHandle; validator is permissive on input case.
        #expect(FriendsMath.isValidHandle("Ranbir"))
    }

    @Test func handle_rejectsTooShort() {
        #expect(!FriendsMath.isValidHandle(""))
        #expect(!FriendsMath.isValidHandle("ab"))
    }

    @Test func handle_rejectsTooLong() {
        let twentyOne = String(repeating: "a", count: 21)
        #expect(!FriendsMath.isValidHandle(twentyOne))
    }

    @Test func handle_acceptsAtBoundary() {
        #expect(FriendsMath.isValidHandle(String(repeating: "a", count: 3)))
        #expect(FriendsMath.isValidHandle(String(repeating: "a", count: 20)))
    }

    @Test func handle_rejectsIllegalCharacters() {
        #expect(!FriendsMath.isValidHandle("ran bir"))
        #expect(!FriendsMath.isValidHandle("ran-bir"))
        #expect(!FriendsMath.isValidHandle("ran.bir"))
        #expect(!FriendsMath.isValidHandle("ran@bir"))
        #expect(!FriendsMath.isValidHandle("ran/bir"))
    }

    @Test func handle_rejectsLeadingDigit() {
        #expect(!FriendsMath.isValidHandle("1ranbir"))
        #expect(!FriendsMath.isValidHandle("_ranbir"))
    }

    @Test func handleErrorMessage_tooShort() {
        #expect(FriendsMath.handleValidationError(for: "ab") == "At least 3 characters.")
    }

    @Test func handleErrorMessage_tooLong() {
        let twentyOne = String(repeating: "a", count: 21)
        #expect(FriendsMath.handleValidationError(for: twentyOne) == "At most 20 characters.")
    }

    @Test func handleErrorMessage_badChars() {
        #expect(FriendsMath.handleValidationError(for: "ran bir") != nil)
        #expect(FriendsMath.handleValidationError(for: "ran-bir") != nil)
    }

    @Test func handleErrorMessage_valid_isNil() {
        #expect(FriendsMath.handleValidationError(for: "ranbir") == nil)
    }

    // MARK: - pairId

    @Test func pairId_isOrderIndependent() {
        #expect(Friendship.pairId("a", "b") == Friendship.pairId("b", "a"))
    }

    @Test func pairId_isDeterministic() {
        #expect(Friendship.pairId("alpha", "beta") == "alpha_beta")
        #expect(Friendship.pairId("zulu", "alpha") == "alpha_zulu")
    }

    // MARK: - friendUid helper

    @Test func friendUid_returnsTheOther() {
        let f = Friendship.newPending(requesterId: "u1", recipientId: "u2")
        #expect(f.friendUid(forMe: "u1") == "u2")
        #expect(f.friendUid(forMe: "u2") == "u1")
    }

    @Test func friendUid_returnsNilWhenNotInPair() {
        let f = Friendship.newPending(requesterId: "u1", recipientId: "u2")
        #expect(f.friendUid(forMe: "u-other") == nil)
    }

    // MARK: - PR detection

    private func session(
        completedAt: Date,
        exerciseId: String,
        sets: [(weight: Double, reps: Int)]
    ) -> WorkoutSession {
        let loggedSets = sets.map {
            LoggedSet(targetReps: $0.reps, targetWeight: $0.weight, isCompleted: true)
        }
        let exercise = LoggedExercise(exerciseId: exerciseId, exerciseName: "X", sets: loggedSets)
        return WorkoutSession(
            userId: "u",
            templateId: "t",
            templateName: "T",
            startedAt: completedAt,
            completedAt: completedAt,
            exercises: [exercise]
        )
    }

    @Test func prHighlights_firstSessionForExercise_isPR() {
        let now = Date()
        let s = session(completedAt: now, exerciseId: "bench", sets: [(135, 5)])
        let highlights = FriendsMath.prHighlights(for: s, priorSessions: [])
        #expect(highlights.contains("bench"))
    }

    @Test func prHighlights_higherE1RM_isPR() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let prior = session(completedAt: yesterday, exerciseId: "bench", sets: [(135, 5)])
        let current = session(completedAt: now, exerciseId: "bench", sets: [(155, 5)])
        let highlights = FriendsMath.prHighlights(for: current, priorSessions: [prior])
        #expect(highlights.contains("bench"))
    }

    @Test func prHighlights_lowerE1RM_isNotPR() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let prior = session(completedAt: yesterday, exerciseId: "bench", sets: [(225, 5)])
        let current = session(completedAt: now, exerciseId: "bench", sets: [(135, 5)])
        let highlights = FriendsMath.prHighlights(for: current, priorSessions: [prior])
        #expect(!highlights.contains("bench"))
    }

    @Test func prHighlights_priorMustBeStrictlyEarlier() {
        let now = Date()
        // Same session can't count as its own prior.
        let s = session(completedAt: now, exerciseId: "bench", sets: [(225, 5)])
        let highlights = FriendsMath.prHighlights(for: s, priorSessions: [s])
        // Still a PR because the prior list is filtered to strictly earlier.
        #expect(highlights.contains("bench"))
    }

    @Test func prHighlights_ignoresUncompletedSets() {
        let now = Date()
        let exercise = LoggedExercise(
            exerciseId: "bench",
            exerciseName: "Bench",
            sets: [LoggedSet(targetReps: 5, targetWeight: 225, isCompleted: false)]
        )
        let current = WorkoutSession(
            userId: "u",
            templateId: "t",
            templateName: "T",
            startedAt: now,
            completedAt: now,
            exercises: [exercise]
        )
        let highlights = FriendsMath.prHighlights(for: current, priorSessions: [])
        #expect(!highlights.contains("bench"))
    }

    @Test func prHighlights_emptyExerciseList_returnsEmpty() {
        let now = Date()
        let s = WorkoutSession(
            userId: "u",
            templateId: "t",
            templateName: "T",
            startedAt: now,
            completedAt: now,
            exercises: []
        )
        let highlights = FriendsMath.prHighlights(for: s, priorSessions: [])
        #expect(highlights.isEmpty)
    }
}
