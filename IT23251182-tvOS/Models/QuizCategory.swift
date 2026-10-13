//
//  QuizCategory.swift
//  IT23251182-tvOS
//
//  The five subject areas in the Brain Battle question bank.
//

import Foundation

/// A subject area. The raw value is the exact string stored in `questions.json`,
/// which keeps the data file readable while the code stays type-safe.
enum QuizCategory: String, CaseIterable, Identifiable, Codable, Equatable, Hashable {
    case sriLankanCulture
    case sportsAndCricket
    case scienceAndNature
    case moviesAndEntertainment
    case generalKnowledge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sriLankanCulture:      return "Sri Lankan Culture"
        case .sportsAndCricket:      return "Sports & Cricket"
        case .scienceAndNature:      return "Science & Nature"
        case .moviesAndEntertainment: return "Movies & Entertainment"
        case .generalKnowledge:      return "General Knowledge"
        }
    }

    /// Shorter label for tight layouts such as the category tiles.
    var shortName: String {
        switch self {
        case .sriLankanCulture:      return "Sri Lanka"
        case .sportsAndCricket:      return "Sports"
        case .scienceAndNature:      return "Science"
        case .moviesAndEntertainment: return "Movies"
        case .generalKnowledge:      return "General"
        }
    }

    /// SF Symbol shown on the category tile.
    var symbolName: String {
        switch self {
        case .sriLankanCulture:      return "building.columns.fill"
        case .sportsAndCricket:      return "figure.cricket"
        case .scienceAndNature:      return "leaf.fill"
        case .moviesAndEntertainment: return "film.fill"
        case .generalKnowledge:      return "globe.americas.fill"
        }
    }

    /// One-line briefing shown on the category detail screen.
    var blurb: String {
        switch self {
        case .sriLankanCulture:
            return "Festivals, heritage, kings and the island's traditions."
        case .sportsAndCricket:
            return "Cricket records, rules and sporting milestones."
        case .scienceAndNature:
            return "The human body, the planet and the natural world."
        case .moviesAndEntertainment:
            return "Film, music and the people behind them."
        case .generalKnowledge:
            return "Geography, currencies and landmarks worldwide."
        }
    }
}
