//
//  MatchResultsViewModel.swift
//  IT23251182-tvOS
//
//  State and rules for the end-of-match results screen.
//
//  Two responsibilities worth separating from the view:
//
//  1. Saving exactly once. The results screen can appear repeatedly for the
//     same match — returning from Review Answers, a SwiftUI re-render, the
//     screen being rebuilt. `recordResultIfNeeded()` is therefore safe to call
//     as often as the view likes: it is guarded here *and* by the store, which
//     refuses a result id it already holds.
//
//  2. Building the rematch. "Play Again" must produce a genuinely new session —
//     new id, freshly shuffled questions, every score back to zero — rather
//     than reusing the finished one.
//

import Foundation
import Observation

@Observable
final class MatchResultsViewModel {

    let result: MatchResult

    /// True once this match is in the saved history. Drives the small
    /// "saved" confirmation and stops a second write.
    private(set) var isSaved = false

    private let historyStore: MatchHistoryStore
    private let repository: QuestionRepository

    init(result: MatchResult,
         repository: QuestionRepository,
         historyStore: MatchHistoryStore = MatchHistoryStore()) {
        self.result = result
        self.repository = repository
        self.historyStore = historyStore
    }

    // MARK: Saving

    /// Saves the match the first time it is called and does nothing afterwards.
    /// - Returns: `true` only on the call that actually wrote it.
    @discardableResult
    func recordResultIfNeeded() -> Bool {
        guard !isSaved else { return false }

        let didSave = historyStore.save(result)
        // Either we just saved it, or the store already had it — both mean the
        // match is recorded and must not be written again.
        isSaved = true
        return didSave
    }

    // MARK: Ranking and statistics

    /// Final standings, highest first. Computed from the stored scores, which
    /// the engine produced from actual play.
    var ranking: [PlayerScore] { result.ranking }

    var winners: [PlayerScore] { result.winners }
    var isDraw: Bool { result.isDraw }

    var winnerIDs: Set<UUID> { Set(winners.map(\.id)) }

    func isWinner(_ entry: PlayerScore) -> Bool { winnerIDs.contains(entry.id) }

    /// Headline above the scoreboard.
    var headline: String {
        guard !ranking.isEmpty else { return "No players" }
        if isDraw {
            let names = winners.map(\.player.name)
            return names.count == ranking.count
                ? "Everybody Ties"
                : "\(formatted(names)) Tie"
        }
        return "\(ranking[0].player.name) Wins"
    }

    var subtitle: String {
        let asked = questionsCompleted
        let label = asked == 1 ? "question" : "questions"
        return "\(result.settings.categoryDisplayName) · \(asked) \(label) completed"
    }

    var questionsCompleted: Int { result.totalQuestionsAsked }

    var totalCorrectAnswers: Int { result.totalCorrectAnswers }

    /// Share of all answers that were correct, as a whole percentage.
    var overallAccuracyPercent: Int { Int((result.overallAccuracy * 100).rounded()) }

    var topScore: Int { ranking.first?.score ?? 0 }

    func positionLabel(_ index: Int) -> String {
        // Tied players share the top position rather than being listed 1st and 2nd.
        if index < winners.count && isDraw { return "Tied 1st" }
        switch index {
        case 0:  return "1st place"
        case 1:  return "2nd place"
        case 2:  return "3rd place"
        default: return "4th place"
        }
    }

    func accuracyLabel(for entry: PlayerScore) -> String {
        "\(entry.correctCount) of \(entry.answeredCount) correct"
    }

    func accuracyPercent(for entry: PlayerScore) -> Int {
        Int((entry.accuracy * 100).rounded())
    }

    private func formatted(_ names: [String]) -> String {
        switch names.count {
        case 0:  return ""
        case 1:  return names[0]
        case 2:  return "\(names[0]) and \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "")
        }
    }

    // MARK: Review

    /// Only offered when the match actually stored its turns.
    var canReviewAnswers: Bool { result.canReviewAnswers }

    var turns: [TurnRecord] { result.turns }

    // MARK: Play again

    /// A brand new session with the same players and settings.
    ///
    /// Returns `nil` if the bank can no longer supply questions, so "Play Again"
    /// can be hidden rather than starting an empty match.
    func makeRematchSession() -> GameSession? {
        let questions = repository.makeAdaptivePool(for: result.settings)
        guard !questions.isEmpty else { return nil }

        let players = ranking.isEmpty
            ? []
            : result.scores.map(\.player)   // original seat order, not the ranking
        guard !players.isEmpty else { return nil }

        return GameSession(players: players,
                           settings: result.settings,
                           questions: questions,
                           plannedQuestionCount: min(result.settings.questionCount, questions.count))
    }

    var canPlayAgain: Bool {
        !result.scores.isEmpty && !repository.questions(matching: result.settings).isEmpty
    }
}
