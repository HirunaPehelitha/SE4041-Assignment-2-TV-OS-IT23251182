//
//  MatchResult.swift
//  IT23251182-tvOS
//
//  The saved outcome of a completed match.
//
//  Nothing in this file is ever populated from the question bank. A
//  `MatchResult` is only ever produced by actually finishing a game, which is
//  why the leaderboard shows an empty state until one has been played.
//

import Foundation

/// One player's performance in a finished match.
struct PlayerScore: Identifiable, Codable, Equatable, Hashable {
    let player: Player
    var score: Int
    var correctCount: Int
    var answeredCount: Int

    var id: UUID { player.id }

    init(player: Player, score: Int = 0, correctCount: Int = 0, answeredCount: Int = 0) {
        self.player = player
        self.score = score
        self.correctCount = correctCount
        self.answeredCount = answeredCount
    }

    /// Share of answered questions that were correct, 0...1.
    /// Returns 0 rather than dividing by zero when nothing was answered.
    var accuracy: Double {
        guard answeredCount > 0 else { return 0 }
        return Double(correctCount) / Double(answeredCount)
    }
}

/// A completed match, ready to be written to local storage.
struct MatchResult: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let playedAt: Date
    let settings: QuizSettings
    let scores: [PlayerScore]

    init(id: UUID = UUID(),
         playedAt: Date = Date(),
         settings: QuizSettings,
         scores: [PlayerScore]) {
        self.id = id
        self.playedAt = playedAt
        self.settings = settings
        self.scores = scores
    }

    /// Players ordered for the scoreboard: highest score first, then the most
    /// correct answers, then name — so the order is stable and never arbitrary.
    var ranking: [PlayerScore] {
        scores.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.correctCount != rhs.correctCount { return lhs.correctCount > rhs.correctCount }
            return lhs.player.trimmedName.localizedCaseInsensitiveCompare(rhs.player.trimmedName) == .orderedAscending
        }
    }

    /// Every player tied on the top score. Returns more than one on a draw, so
    /// the results screen can say "it's a tie" instead of inventing a winner.
    var winners: [PlayerScore] {
        guard let best = ranking.first else { return [] }
        return scores.filter { $0.score == best.score }
    }

    var isDraw: Bool { winners.count > 1 }

    var totalQuestionsAsked: Int {
        scores.map(\.answeredCount).max() ?? 0
    }
}
