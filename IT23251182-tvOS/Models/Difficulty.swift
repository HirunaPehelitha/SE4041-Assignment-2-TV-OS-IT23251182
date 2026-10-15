//
//  Difficulty.swift
//  IT23251182-tvOS
//
//  Question difficulty, the score each level is worth and the time allowed.
//

import Foundation

/// How hard a question is, and therefore how long a player gets to answer it.
///
/// Difficulty no longer affects the score — every correct answer is worth the
/// same (see `MatchScoring`). What it still controls is thinking time, which is
/// why the timing lives here and the points do not.
enum Difficulty: String, CaseIterable, Identifiable, Codable, Equatable, Hashable, Comparable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    /// Seconds allowed to answer. Harder questions get more thinking time.
    var timeLimit: Int {
        switch self {
        case .easy:   return 15
        case .medium: return 20
        case .hard:   return 25
        }
    }

    /// Rank used for sorting, easiest first.
    private var order: Int {
        switch self {
        case .easy:   return 0
        case .medium: return 1
        case .hard:   return 2
        }
    }

    static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.order < rhs.order
    }
}
