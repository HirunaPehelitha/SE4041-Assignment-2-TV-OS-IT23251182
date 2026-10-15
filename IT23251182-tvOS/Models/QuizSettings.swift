//
//  QuizSettings.swift
//  IT23251182-tvOS
//
//  The configuration chosen for a single match.
//

import Foundation

/// How a match is set up: what to ask, how much of it, and how hard.
///
/// `Codable` so a completed match can store the exact settings it was played
/// under — a score of 1,200 means something very different over five easy
/// questions than over ten hard ones.
struct QuizSettings: Codable, Equatable, Hashable {

    /// The subject to draw from. `nil` means a mixed round across every category.
    var category: QuizCategory?

    /// Difficulties allowed in this match. Empty is treated as "no filter"
    /// rather than "no questions", so a settings bug cannot produce an
    /// unplayable match.
    var difficulties: Set<Difficulty>

    /// How many questions the match should contain.
    var questionCount: Int

    static let defaultQuestionCount = 10
    static let allowedQuestionCounts = [5, 10, 15, 20]
    static let minimumQuestionCount = 1

    init(category: QuizCategory? = nil,
         difficulties: Set<Difficulty> = Set(Difficulty.allCases),
         questionCount: Int = QuizSettings.defaultQuestionCount) {
        self.category = category
        self.difficulties = difficulties
        self.questionCount = max(Self.minimumQuestionCount, questionCount)
    }

    /// A standard mixed-category round.
    static let standard = QuizSettings()

    /// The difficulties actually used when filtering. An empty set is widened
    /// to every difficulty — see the note on `difficulties` above.
    var effectiveDifficulties: Set<Difficulty> {
        difficulties.isEmpty ? Set(Difficulty.allCases) : difficulties
    }

    var categoryDisplayName: String {
        category?.displayName ?? "Mixed Categories"
    }

    /// True when every difficulty is permitted.
    var includesAllDifficulties: Bool {
        effectiveDifficulties == Set(Difficulty.allCases)
    }

    /// Whether a given question is eligible under these settings.
    func matches(_ question: Question) -> Bool {
        if let category, question.category != category { return false }
        return effectiveDifficulties.contains(question.difficulty)
    }
}
