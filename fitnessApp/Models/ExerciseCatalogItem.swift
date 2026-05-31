//
//  ExerciseCatalogItem.swift
//  fitnessApp
//

import Foundation

struct ExerciseCatalogItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let isCustom: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case isCustom = "is_custom"
    }
}
