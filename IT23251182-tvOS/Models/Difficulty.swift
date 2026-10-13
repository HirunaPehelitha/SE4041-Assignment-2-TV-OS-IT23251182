//
//  Difficulty.swift
//  IT23251182-tvOS
//
//  Question difficulty, the score each level is worth and the time allowed.
//

import Foundation

/// How hard a question is, and therefore how much it is worth.
///
/// Points and timings live on the model rather than inside the scoring code so
/// the rules sit in one obvious place and can be unit-tested directly.
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

    /// Base points awarded for a correct answer at this level.
    var basePoints: Int {
        switch self {
        case .easy:   return 100
        case .medium: return 200
        case .hard:   return 300
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
