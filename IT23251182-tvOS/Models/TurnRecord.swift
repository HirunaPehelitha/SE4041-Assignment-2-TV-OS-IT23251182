//
//  TurnRecord.swift
//  IT23251182-tvOS
//
//  A permanent record of one answered question.
//
//  The engine appends one of these as each turn resolves. They are what makes
//  "Review Answers" show real history rather than a reconstruction: the question
//  as it was actually displayed, who it was asked of, and exactly which option
//  that player chose.
//

import Foundation

struct TurnRecord: Identifiable, Codable, Equatable, Hashable {

    let id: UUID
    /// One-based position in the match, for display.
    let questionNumber: Int
    /// The question exactly as shown, with the answer order the player saw.
    let question: PreparedQuestion
    let player: Player
    let outcome: TurnOutcome

    init(id: UUID = UUID(),
         questionNumber: Int,
         question: PreparedQuestion,
         player: Player,
         outcome: TurnOutcome) {
        self.id = id
        self.questionNumber = questionNumber
        self.question = question
        self.player = player
        self.outcome = outcome
    }

    var pointsAwarded: Int { outcome.pointsAwarded }
    var isCorrect: Bool { outcome.isCorrect }
    var correctAnswer: String { question.correctAnswer }

    /// The text of the option the player chose, or `nil` on a timeout.
    var selectedAnswer: String? {
        guard let index = outcome.selectedIndex,
              question.options.indices.contains(index) else { return nil }
        return question.options[index]
    }
}
