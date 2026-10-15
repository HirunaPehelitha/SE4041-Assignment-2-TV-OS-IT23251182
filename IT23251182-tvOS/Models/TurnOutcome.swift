//
//  TurnOutcome.swift
//  IT23251182-tvOS
//
//  What happened on one question.
//
//  Lives in Models rather than beside the engine because it is also stored: a
//  saved match keeps the outcome of every turn so Review Answers can show what
//  each player actually chose.
//

import Foundation

enum TurnOutcome: Codable, Equatable, Hashable {
    case correct(selectedIndex: Int)
    case incorrect(selectedIndex: Int)
    case timedOut

    var isCorrect: Bool {
        if case .correct = self { return true }
        return false
    }

    var isTimeout: Bool { self == .timedOut }

    /// The option the player chose, or `nil` if they ran out of time.
    var selectedIndex: Int? {
        switch self {
        case .correct(let index), .incorrect(let index): return index
        case .timedOut: return nil
        }
    }

    var pointsAwarded: Int {
        switch self {
        case .correct:   return MatchScoring.correctAnswerPoints
        case .incorrect: return MatchScoring.incorrectAnswerPoints
        case .timedOut:  return MatchScoring.timeoutPoints
        }
    }

    var headline: String {
        switch self {
        case .correct:   return "Correct"
        case .incorrect: return "Not quite"
        case .timedOut:  return "Out of time"
        }
    }
}
