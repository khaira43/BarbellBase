//
//  ExerciseCategory.swift
//  fitnessApp
//

import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case chest
    case back
    case shoulders
    case arms
    case legs
    case core
    case cardio
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .legs: return "Legs"
        case .core: return "Core"
        case .cardio: return "Cardio"
        case .other: return "Other"
        }
    }
}
