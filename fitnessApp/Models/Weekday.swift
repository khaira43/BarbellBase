//
//  Weekday.swift
//  fitnessApp
//

import Foundation

enum Weekday: String, Codable, CaseIterable, Identifiable, Hashable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    static var today: Weekday {
        let calendarComponent = Calendar.current.component(.weekday, from: Date())
        switch calendarComponent {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .sunday
        }
    }
}
