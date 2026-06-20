//
//  NumberFormattingTests.swift
//  fitnessAppTests
//

import Testing
import Foundation
@testable import fitnessApp

struct NumberFormattingTests {

    // MARK: - formattedWeight (Double)

    @Test func weight_dropsTrailingZero() {
        #expect((135.0).formattedWeight == "135")
        #expect((0.0).formattedWeight == "0")
    }

    @Test func weight_keepsOneDecimal() {
        #expect((137.5).formattedWeight == "137.5")
        #expect((2.25).formattedWeight == "2.2") // rounds to one place
    }

    // MARK: - formattedWeight (Double?)

    @Test func optionalWeight_nilIsEmDash() {
        let value: Double? = nil
        #expect(value.formattedWeight == "—")
    }

    @Test func optionalWeight_unwrapsLikeDouble() {
        let value: Double? = 137.5
        #expect(value.formattedWeight == "137.5")
        #expect((Double?(135.0)).formattedWeight == "135")
    }

    // MARK: - formattedGrouped

    @Test func grouped_smallNumbersHaveNoSeparator() {
        // Locale-independent: values under 1000 never group.
        #expect((0.0).formattedGrouped == "0")
        #expect((500.0).formattedGrouped == "500")
    }

    @Test func grouped_dropsFractionDigits() {
        #expect((500.0).formattedGrouped == "500")
        #expect((499.4).formattedGrouped == "499")
    }

    @Test func grouped_largeNumberIsNonEmptyAndContainsDigits() {
        // Grouping separator is locale-dependent, so only assert the stable parts.
        let result = (12_500.0).formattedGrouped
        #expect(result.contains("12"))
        #expect(result.contains("500"))
    }
}
