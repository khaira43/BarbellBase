//
//  NumberFormatting.swift
//  fitnessApp
//
//  Shared numeric display helpers. Previously these were duplicated as private
//  `formatWeight` / `formatVolume` / `formatNumber` methods across several views.
//

import Foundation

extension Double {
    /// Weight-style display: drops a trailing ".0", otherwise one decimal place.
    /// e.g. 135 → "135", 137.5 → "137.5".
    var formattedWeight: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }

    /// Grouped integer with thousands separators, no fraction digits.
    /// e.g. 12500 → "12,500".
    var formattedGrouped: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }
}

extension Optional where Wrapped == Double {
    /// Weight-style display with an em-dash fallback when the value is nil.
    var formattedWeight: String {
        guard let self else { return "—" }
        return self.formattedWeight
    }
}
