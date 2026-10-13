//
//  CategoryAvailability.swift
//  IT23251182-tvOS
//
//  A summary of what one category can offer a match.
//
//  This type is the *only* thing the category screen sees. The views never hold
//  `[Question]`, never filter the bank and never count anything themselves —
//  they render a pre-computed summary. That keeps question data in exactly one
//  place (the repository) and makes the playability rule unit-testable without
//  a single SwiftUI view.
//

import Foundation

struct CategoryAvailability: Identifiable, Equatable, Hashable {

    let category: QuizCategory
    let totalQuestions: Int
    let maximumPoints: Int
    /// Question count per difficulty. Missing keys mean zero.
    let countsByDifficulty: [Difficulty: Int]

    var id: String { category.id }

    /// A match shorter than this is not worth starting: with fewer questions the
    /// round ends before every player in a four-player game has had two turns.
    static let minimumPlayableQuestions = 5

    /// Whether a match can actually be started from this category.
    var isPlayable: Bool { totalQuestions >= Self.minimumPlayableQuestions }

    /// How many more questions this category needs before it becomes playable.
    var shortfall: Int { max(0, Self.minimumPlayableQuestions - totalQuestions) }

    /// True when the category exists in the enum but has no questions at all.
    var isEmpty: Bool { totalQuestions == 0 }

    func count(for difficulty: Difficulty) -> Int {
        countsByDifficulty[difficulty] ?? 0
    }

    /// The longest round this category can supply without repeating a question.
    var longestPossibleRound: Int { totalQuestions }

    /// Explains the locked state to the player. `nil` when the category is playable.
    var unavailableReason: String? {
        guard !isPlayable else { return nil }
        if isEmpty {
            return "No questions available yet."
        }
        let plural = shortfall == 1 ? "question" : "questions"
        return "Only \(totalQuestions) of \(Self.minimumPlayableQuestions) needed — \(shortfall) more \(plural) required."
    }
}
