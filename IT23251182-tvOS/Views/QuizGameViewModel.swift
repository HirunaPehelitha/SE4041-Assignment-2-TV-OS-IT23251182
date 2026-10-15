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

    /// Every resolved turn, in play order. Carried into the result so the
    /// results screen can show what each player actually answered.
    private(set) var turns: [TurnRecord] = []

    /// Indices into `session.questions` not yet asked. Adaptive selection picks
    /// from here, so a question can never be served twice and the match length
    /// stays exactly what player setup promised.
    private var remainingQuestionIndices: [Int] = []

    /// Which question in the session is on screen right now.
    private var currentQuestionPoolIndex: Int?

    /// Recent correctness per player, oldest first. A timeout counts as a wrong
    /// answer, because the policy is about how the player is coping.
    private var recentAnswersByPlayerID: [UUID: [Bool]] = [:]

    private var timerTask: Task<Void, Never>?

    /// Tests pass `false` and drive `tick()` by hand, so timeout behaviour is
    /// verified instantly and deterministically instead of waiting on a clock.
    private let runsCountdown: Bool

    /// The player's chosen pace, applied to every question's base time limit.
    private let questionDuration: QuestionDuration

    /// Answer feedback. Optional so tests run silently, and the player itself
    /// checks the sound preference at play time.
    private let sounds: SoundPlaying?

    /// When off, questions are served in the order the session already shuffled
    /// them. Defaults to off so the engine is deterministic unless adaptation is
    /// explicitly asked for; the app switches it on from Settings.
    private let adaptiveDifficultyEnabled: Bool

    /// Injectable so adaptive selection is reproducible in tests.
    private var generator: RandomNumberGenerator

    init(session: GameSession,
         questionDuration: QuestionDuration = .standard,
         sounds: SoundPlaying? = nil,
         adaptiveDifficultyEnabled: Bool = false,
         generator: RandomNumberGenerator = SystemRandomNumberGenerator(),
         runsCountdown: Bool = true) {
        self.session = session
        self.questionDuration = questionDuration
        self.sounds = sounds
        self.adaptiveDifficultyEnabled = adaptiveDifficultyEnabled
        self.generator = generator
        self.runsCountdown = runsCountdown
        self.scoresByPlayerID = Dictionary(
            uniqueKeysWithValues: session.players.map { ($0.id, PlayerScore(player: $0)) }
        )
    }

    // MARK: Derived values for the view

    var currentQuestionIndex: Int? { phase.questionIndex }

    var currentQuestion: PreparedQuestion? {
        guard phase.questionIndex != nil,
              let poolIndex = currentQuestionPoolIndex,
              session.questions.indices.contains(poolIndex) else { return nil }
        return session.questions[poolIndex]
    }

    /// The band the current player is in, for the on-screen explanation.
    /// `nil` when adaptive selection is switched off.
    var currentPerformanceBand: PerformanceBand? {
        guard adaptiveDifficultyEnabled, let player = currentPlayer else { return nil }
        return AdaptiveDifficultyPolicy.band(for: recentAnswersByPlayerID[player.id] ?? [])
    }

    /// Recent answers for a player, used by the band display and by tests.
    func recentAnswers(for player: Player) -> [Bool] {
        recentAnswersByPlayerID[player.id] ?? []
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

    /// A fresh session with the same players and settings, for "Play Again".
    /// New id and newly shuffled questions, so nothing from this match carries
    /// over — the engine for the next match starts from zero.
    func rematchSession(using repository: QuestionRepository) -> GameSession {
        GameSession(players: session.players,
                    settings: session.settings,
                    questions: repository.makeQuestionSet(for: session.settings))
    }

    var isLastQuestion: Bool {
        guard let turn = phase.questionIndex else { return false }
        return turn >= session.questionCount - 1 || remainingQuestionIndices.isEmpty
    }

    /// Label for the button shown after an answer is revealed.
    var continueButtonTitle: String {
        guard !isLastQuestion else { return "See Results" }
        guard let index = phase.questionIndex,
              let next = session.player(forQuestionIndex: index + 1) else { return "Next" }
        return "Next: \(next.name)"
    }

    var timeLimitForCurrentQuestion: Int {
        guard let question = currentQuestion else { return 0 }
        return questionDuration.seconds(for: question.difficulty)
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
        remainingQuestionIndices = Array(session.questions.indices)
        beginQuestion(atTurn: 0)
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
        guard case .revealing(let turn, _) = phase else { return }

        let nextTurn = turn + 1
        // The match ends at the planned length, or sooner if the pool somehow
        // runs dry — whichever comes first.
        if nextTurn < session.questionCount && !remainingQuestionIndices.isEmpty {
            beginQuestion(atTurn: nextTurn)
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

    /// Opens the next question.
    ///
    /// `turn` is the position in the match (0-based), which is what drives whose
    /// turn it is and the progress bar. *Which* question fills that turn is
    /// decided here — in session order normally, or by the adaptive policy when
    /// it is switched on.
    private func beginQuestion(atTurn turn: Int) {
        guard let poolIndex = takeNextQuestionIndex() else {
            finish()
            return
        }

        currentQuestionPoolIndex = poolIndex
        phase = .asking(index: turn)
        remainingSeconds = questionDuration.seconds(for: session.questions[poolIndex].difficulty)
        startCountdown()
    }

    /// Removes and returns the next question's index in `session.questions`.
    ///
    /// Adaptive selection can only ever choose from questions already in this
    /// session, so the result is always valid and always in the chosen category.
    private func takeNextQuestionIndex() -> Int? {
        guard !remainingQuestionIndices.isEmpty else { return nil }

        guard adaptiveDifficultyEnabled,
              let player = session.player(forQuestionIndex: turns.count)
        else {
            return remainingQuestionIndices.removeFirst()
        }

        let band = AdaptiveDifficultyPolicy.band(for: recentAnswersByPlayerID[player.id] ?? [])
        let candidates = remainingQuestionIndices.map { session.questions[$0] }

        guard let choice = AdaptiveDifficultyPolicy.selectIndex(from: candidates,
                                                               band: band,
                                                               using: &generator) else {
            // Cannot happen with a non-empty pool, but falling back keeps the
            // match running rather than ending it early.
            return remainingQuestionIndices.removeFirst()
        }
        return remainingQuestionIndices.remove(at: choice)
    }

    /// The single place a turn is scored, recorded and frozen.
    private func resolve(questionIndex index: Int, outcome: TurnOutcome) {
        cancelCountdown()

        if let player = session.player(forQuestionIndex: index),
           let poolIndex = currentQuestionPoolIndex,
           session.questions.indices.contains(poolIndex) {
            let question = session.questions[poolIndex]
            // `award` is guarded against scoring twice; the turn log is appended
            // in the same guarded step so the two can never disagree.
            if award(outcome, for: question.id, to: player) {
                turns.append(TurnRecord(questionNumber: index + 1,
                                        question: question,
                                        player: player,
                                        outcome: outcome))
                // Feeds the policy for this player's next turn. Recorded inside
                // the same guard as scoring, so a repeated press cannot skew it.
                recentAnswersByPlayerID[player.id, default: []].append(outcome.isCorrect)
            }
        }

        phase = .revealing(index: index, outcome: outcome)

        switch outcome {
        case .correct:   sounds?.play(.correct)
        case .incorrect: sounds?.play(.incorrect)
        case .timedOut:  sounds?.play(.timeout)
        }
    }

    /// - Returns: `true` if this turn was scored, `false` if it had already been.
    @discardableResult
    private func award(_ outcome: TurnOutcome, for questionID: String, to player: Player) -> Bool {
        // Second lock on double scoring: a question can only ever pay out once.
        guard !scoredQuestionIDs.contains(questionID) else { return false }
        scoredQuestionIDs.insert(questionID)

        guard var score = scoresByPlayerID[player.id] else { return false }
        score.score += outcome.pointsAwarded
        score.answeredCount += 1
        if outcome.isCorrect { score.correctCount += 1 }
        scoresByPlayerID[player.id] = score
        return true
    }

    private func finish() {
        cancelCountdown()
        remainingSeconds = 0
        phase = .finished(MatchResult(settings: session.settings,
                                      scores: standings,
                                      turns: turns))
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
