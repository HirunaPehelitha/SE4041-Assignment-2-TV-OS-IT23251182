//
//  MatchScoring.swift
//  IT23251182-tvOS
//
//  The scoring rules for a match, in one place.
//
//  Every point awarded anywhere in the app comes from this type. Earlier stages
//  weighted points by difficulty (100/200/300); the agreed rule is now a flat
//  award for any correct answer, and keeping it here means the whole app —
//  gameplay, the category screen's "points available" and the How to Play text —
//  changes together rather than drifting apart.
//
//  Difficulty still matters: it sets how long a player has to answer.
//

import Foundation

enum MatchScoring {

    /// Awarded for a correct answer, regardless of difficulty.
    static let correctAnswerPoints = 100

    /// A wrong answer costs nothing; there is no penalty.
    static let incorrectAnswerPoints = 0

    /// Running out of time scores nothing.
    static let timeoutPoints = 0

    /// The most a single player could score if they answered every question in
    /// a round of `questionCount` questions correctly.
    static func maximumPoints(forQuestionCount questionCount: Int) -> Int {
        max(0, questionCount) * correctAnswerPoints
    }
}
