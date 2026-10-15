//
//  QuizGameViewModel.swift
//  IT23251182-tvOS
//
//  The Brain Battle match engine.
//
//  All gameplay rules live here: turn rotation, scoring, the countdown, and
//  when a match ends. The quiz screen renders `phase` and calls three methods —
//  `start()`, `submitAnswer(_:)` and `continueAfterReveal()`. It makes no
//  decisions of its own, which is what lets every rule below be tested without
//  SwiftUI and without waiting on a real clock.
//
//  Key state decisions, in order of how much trouble they prevent:
//
//  1. `phase` is a single enum, not a scatter of booleans. A question is either
//     being asked or being revealed — never both, and never neither. Answering
//     is only legal in `.asking`, so "is input frozen?" is not a separate flag
//     that could disagree with the rest of the state.
//  2. `scoredQuestionIDs` is a second, independent guard on double scoring. The
//     phase check already prevents it, but a scoring bug is invisible until the
//     final scoreboard is wrong, so it is worth two locks.
//  3. The countdown is a cancellable `Task` that is torn down on every phase
//     change, and `tick()` itself refuses to act outside `.asking`. The timer
//     therefore cannot touch a question that is already answered, or a match
//     that has already finished.
//  4. Advancing between questions is an explicit press, not an automatic
//     timeout. In a pass-the-remote game the players need an unhurried moment
//     to hand the remote over, and it removes a second timer that could race
//     with the first.
//

import Foundation
import Observation

// MARK: - Turn outcome

/// What happened on one question.
enum TurnOutcome: Equatable, Hashable {
    case correct(selectedIndex: Int)
    case incorrect(selectedIndex: Int)
    case timedOut

    var isCorrect: Bool {
        if case .correct = self { return true }
        return false
    }

    /// The index the player chose, or `nil` if they ran out of time.
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

// MARK: - Phase

/// The match lifecycle. Exactly one of these is true at any moment.
enum MatchPhase: Equatable {
    /// Built but not begun. The screen shows who is up first.
    case ready
    /// Question `index` is on screen, the clock is running, input is accepted.
    case asking(index: Int)
    /// Question `index` is resolved. Input is frozen and the answer is shown.
    case revealing(index: Int, outcome: TurnOutcome)
    /// Every question is done and the result is final.
    case finished(MatchResult)

    var isAsking: Bool {
        if case .asking = self { return true }
        return false
    }

    var isRevealing: Bool {
        if case .revealing = self { return true }
        return false
    }

    var isFinished: Bool {
        if case .finished = self { return true }
        return false
    }

    /// The question currently on screen, whether being asked or revealed.
    var questionIndex: Int? {
        switch self {
        case .asking(let index):           return index
        case .revealing(let index, _):     return index
        case .ready, .finished:            return nil
        }
    }

    var outcome: TurnOutcome? {
        if case .revealing(_, let outcome) = self { return outcome }
        return nil
    }
}

// MARK: - Engine

@MainActor
@Observable
final class QuizGameViewModel {

    // MARK: Fixed match data

    let session: GameSession

    // MARK: Observable state

    private(set) var phase: MatchPhase = .ready
    /// Seconds left on the current question. Zero outside `.asking`.
    private(set) var remainingSeconds: Int = 0

    /// Scores keyed by player id. Every player is present from the start, on
    /// zero, so the standings are complete before anyone has answered.
    private(set) var scoresByPlayerID: [UUID: PlayerScore]

    // MARK: Internals

    /// Questions already scored. The independent guard described above.
    private var scoredQuestionIDs: Set<String> = []

    private var timerTask: Task<Void, Never>?

    /// Tests pass `false` and drive `tick()` by hand, so timeout behaviour is
    /// verified instantly and deterministically instead of waiting on a clock.
    private let runsCountdown: Bool

    init(session: GameSession, runsCountdown: Bool = true) {
        self.session = session
        self.runsCountdown = runsCountdown
        self.scoresByPlayerID = Dictionary(
            uniqueKeysWithValues: session.players.map { ($0.id, PlayerScore(player: $0)) }
        )
    }

    // MARK: Derived values for the view

    var currentQuestionIndex: Int? { phase.questionIndex }

    var currentQuestion: PreparedQuestion? {
        guard let index = phase.questionIndex,
              session.questions.indices.contains(index) else { return nil }
        return session.questions[index]
    }

    var currentPlayer: Player? {
        guard let index = phase.questionIndex else { return nil }
        return session.player(forQuestionIndex: index)
    }

    /// The player who will take the very first turn, shown before the match starts.
    var openingPlayer: Player? { session.players.first }

    /// One-based, for display.
    var questionNumber: Int { (phase.questionIndex ?? 0) + 1 }

    var totalQuestions: Int { session.questionCount }

    var progress: Double {
        guard totalQuestions > 0 else { return 0 }
        if case .finished = phase { return 1 }
        guard let index = phase.questionIndex else { return 0 }
        // A question counts as complete once it has been revealed.
        let completed = phase.isRevealing ? index + 1 : index
        return Double(completed) / Double(totalQuestions)
    }

    /// Standings in seat order, so the row does not jump around mid-match.
    var standings: [PlayerScore] {
        session.players.compactMap { scoresByPlayerID[$0.id] }
    }

    /// Standings ranked for the results screen.
    var ranking: [PlayerScore] {
        MatchResult(settings: session.settings, scores: standings).ranking
    }

    var isLastQuestion: Bool {
        guard let index = phase.questionIndex else { return false }
        return index == totalQuestions - 1
    }

    /// Label for the button shown after an answer is revealed.
    var continueButtonTitle: String {
        guard !isLastQuestion else { return "See Results" }
        guard let index = phase.questionIndex,
              let next = session.player(forQuestionIndex: index + 1) else { return "Next" }
        return "Next: \(next.name)"
    }

    var timeLimitForCurrentQuestion: Int {
        currentQuestion?.difficulty.timeLimit ?? 0
    }

    /// 1 → full clock, 0 → expired. Used by the countdown ring.
    var timeFraction: Double {
        let limit = timeLimitForCurrentQuestion
        guard limit > 0 else { return 0 }
        return max(0, min(1, Double(remainingSeconds) / Double(limit)))
    }

    // MARK: Lifecycle

    /// Begins the match. Ignored if it has already begun, so an accidental
    /// second call cannot restart a round in progress.
    func start() {
        guard case .ready = phase else { return }
        guard session.isPlayable else {
            finish()
            return
        }
        beginQuestion(at: 0)
    }

    /// Records an answer for the current question.
    ///
    /// Only legal while that exact question is being asked. Every later call —
    /// a double press, a second button mashed, the timer firing late — lands in
    /// a phase that is no longer `.asking` and returns immediately.
    func submitAnswer(_ optionIndex: Int) {
        guard case .asking(let index) = phase,
              let question = currentQuestion,
              question.options.indices.contains(optionIndex)
        else { return }

        let outcome: TurnOutcome = question.isCorrect(optionIndex)
            ? .correct(selectedIndex: optionIndex)
            : .incorrect(selectedIndex: optionIndex)

        resolve(questionIndex: index, outcome: outcome)
    }

    /// Called once per second by the countdown while a question is open.
    func tick() {
        guard case .asking(let index) = phase else { return }

        remainingSeconds -= 1
        guard remainingSeconds <= 0 else { return }

        remainingSeconds = 0
        resolve(questionIndex: index, outcome: .timedOut)
    }

    /// Moves on from a revealed answer: the next question, or the results.
    func continueAfterReveal() {
        guard case .revealing(let index, _) = phase else { return }

        let next = index + 1
        if session.questions.indices.contains(next) {
            beginQuestion(at: next)
        } else {
            finish()
        }
    }

    /// Stops the countdown. Called when the screen goes away so a backgrounded
    /// or dismissed match leaves nothing running.
    func tearDown() {
        cancelCountdown()
    }

    // MARK: Transitions

    private func beginQuestion(at index: Int) {
        guard session.questions.indices.contains(index) else {
            finish()
            return
        }

        phase = .asking(index: index)
        remainingSeconds = session.questions[index].difficulty.timeLimit
        startCountdown()
    }

    /// The single place a turn is scored and frozen.
    private func resolve(questionIndex index: Int, outcome: TurnOutcome) {
        cancelCountdown()

        if let player = session.player(forQuestionIndex: index),
           session.questions.indices.contains(index) {
            award(outcome, for: session.questions[index].id, to: player)
        }

        phase = .revealing(index: index, outcome: outcome)
    }

    private func award(_ outcome: TurnOutcome, for questionID: String, to player: Player) {
        // Second lock on double scoring: a question can only ever pay out once.
        guard !scoredQuestionIDs.contains(questionID) else { return }
        scoredQuestionIDs.insert(questionID)

        guard var score = scoresByPlayerID[player.id] else { return }
        score.score += outcome.pointsAwarded
        score.answeredCount += 1
        if outcome.isCorrect { score.correctCount += 1 }
        scoresByPlayerID[player.id] = score
    }

    private func finish() {
        cancelCountdown()
        remainingSeconds = 0
        phase = .finished(MatchResult(settings: session.settings, scores: standings))
    }

    /// The finished result, for the caller that performs the navigation.
    var finalResult: MatchResult? {
        if case .finished(let result) = phase { return result }
        return nil
    }

    // MARK: Countdown

    private func startCountdown() {
        cancelCountdown()
        guard runsCountdown else { return }

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard let self else { return }
                // `tick()` is itself guarded, so even a tick that arrives after
                // the phase changed cannot alter a resolved question.
                self.tick()
            }
        }
    }

    private func cancelCountdown() {
        timerTask?.cancel()
        timerTask = nil
    }
}
