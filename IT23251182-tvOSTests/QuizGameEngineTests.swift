//
//  QuizGameEngineTests.swift
//  IT23251182-tvOSTests
//
//  Tests for the match engine: scoring, turn rotation, the countdown, input
//  freezing and match completion.
//
//  Every test drives the countdown by calling `tick()` directly, so timeout
//  behaviour is verified exactly and instantly rather than by waiting on a real
//  clock. That is the whole reason the engine takes `runsCountdown`.
//

import XCTest
@testable import IT23251182_tvOS

@MainActor
final class QuizGameEngineTests: XCTestCase {

    // MARK: Fixtures

    /// A question whose correct answer is always at index 0 before shuffling,
    /// built unshuffled so tests can target a known-correct option.
    private func question(_ id: String, difficulty: Difficulty = .easy) -> PreparedQuestion {
        PreparedQuestion(source: Question(
            id: id,
            category: .generalKnowledge,
            difficulty: difficulty,
            prompt: "Prompt \(id)?",
            options: ["RIGHT", "wrong1", "wrong2", "wrong3"],
            correctIndex: 0,
            explanation: "Because."
        ))
    }

    private func session(players: Int = 2,
                         questions: Int = 4,
                         difficulty: Difficulty = .easy) -> GameSession {
        GameSession(
            players: (1...players).map {
                Player(name: "P\($0)", colorIndex: $0 - 1, avatar: PlayerAvatar.default(forSeat: $0))
            },
            settings: QuizSettings(category: .generalKnowledge, questionCount: questions),
            questions: (1...questions).map { question("q\($0)", difficulty: difficulty) }
        )
    }

    private func engine(players: Int = 2,
                        questions: Int = 4,
                        difficulty: Difficulty = .easy) -> QuizGameViewModel {
        QuizGameViewModel(session: session(players: players,
                                           questions: questions,
                                           difficulty: difficulty),
                          runsCountdown: false)
    }

    private let correctOption = 0
    private let wrongOption = 1

    private func score(_ vm: QuizGameViewModel, _ name: String) -> Int {
        vm.standings.first { $0.player.name == name }?.score ?? -1
    }

    // MARK: Lifecycle

    func testStartsInReadyPhase() {
        let vm = engine()
        XCTAssertEqual(vm.phase, .ready)
        XCTAssertNil(vm.currentQuestion)
    }

    func testStartBeginsFirstQuestion() {
        let vm = engine()
        vm.start()

        XCTAssertEqual(vm.phase, .asking(index: 0))
        XCTAssertEqual(vm.questionNumber, 1)
        XCTAssertEqual(vm.currentQuestion?.id, "q1")
        XCTAssertEqual(vm.currentPlayer?.name, "P1")
    }

    func testStartIsIgnoredOnceUnderway() {
        let vm = engine()
        vm.start()
        vm.submitAnswer(correctOption)
        vm.continueAfterReveal()
        XCTAssertEqual(vm.phase, .asking(index: 1))

        vm.start()   // stray second call

        XCTAssertEqual(vm.phase, .asking(index: 1), "A match in progress must not restart")
    }

    func testCountdownStartsAtTheQuestionsTimeLimit() {
        let vm = engine(difficulty: .hard)
        vm.start()
        XCTAssertEqual(vm.remainingSeconds, Difficulty.hard.baseTimeLimit)
    }

    // MARK: Correct answers

    func testCorrectAnswerAwardsPoints() {
        let vm = engine()
        vm.start()

        vm.submitAnswer(correctOption)

        XCTAssertEqual(score(vm, "P1"), MatchScoring.correctAnswerPoints)
        XCTAssertEqual(vm.phase, .revealing(index: 0, outcome: .correct(selectedIndex: correctOption)))
    }

    func testCorrectAnswerUpdatesCounts() {
        let vm = engine()
        vm.start()
        vm.submitAnswer(correctOption)

        let entry = vm.standings.first { $0.player.name == "P1" }
        XCTAssertEqual(entry?.correctCount, 1)
        XCTAssertEqual(entry?.answeredCount, 1)
    }

    // MARK: Incorrect answers

    func testIncorrectAnswerScoresNothing() {
        let vm = engine()
        vm.start()

        vm.submitAnswer(wrongOption)

        XCTAssertEqual(score(vm, "P1"), 0)
        XCTAssertEqual(vm.phase.outcome, .incorrect(selectedIndex: wrongOption))
    }

    func testIncorrectAnswerStillCountsAsAnswered() {
        let vm = engine()
        vm.start()
        vm.submitAnswer(wrongOption)

        let entry = vm.standings.first { $0.player.name == "P1" }
        XCTAssertEqual(entry?.answeredCount, 1)
        XCTAssertEqual(entry?.correctCount, 0)
    }

    func testOutOfRangeOptionIsIgnored() {
        let vm = engine()
        vm.start()

        vm.submitAnswer(99)
        vm.submitAnswer(-1)

        XCTAssertEqual(vm.phase, .asking(index: 0), "An impossible option must not resolve the turn")
        XCTAssertEqual(score(vm, "P1"), 0)
    }

    // MARK: Timeout

    func testTimeoutScoresNothingAndFreezesTheQuestion() {
        let vm = engine(difficulty: .easy)
        vm.start()

        for _ in 0..<Difficulty.easy.baseTimeLimit { vm.tick() }

        XCTAssertEqual(vm.phase.outcome, .timedOut)
        XCTAssertEqual(score(vm, "P1"), 0)
        XCTAssertEqual(vm.remainingSeconds, 0)
    }

    func testTimeoutCountsAsAnAnsweredQuestion() {
        let vm = engine()
        vm.start()
        for _ in 0..<Difficulty.easy.baseTimeLimit { vm.tick() }

        XCTAssertEqual(vm.standings.first { $0.player.name == "P1" }?.answeredCount, 1)
    }

    func testTicksBeforeExpiryDoNotResolveTheTurn() {
        let vm = engine()
        vm.start()

        vm.tick()
        vm.tick()

        XCTAssertEqual(vm.phase, .asking(index: 0))
        XCTAssertEqual(vm.remainingSeconds, Difficulty.easy.baseTimeLimit - 2)
    }

    func testTickAfterAnsweringCannotChangeAnything() {
        // The timer must never alter a question that is already resolved.
        let vm = engine()
        vm.start()
        vm.submitAnswer(correctOption)
        let phaseAfterAnswer = vm.phase

        for _ in 0..<50 { vm.tick() }

        XCTAssertEqual(vm.phase, phaseAfterAnswer)
        XCTAssertEqual(score(vm, "P1"), MatchScoring.correctAnswerPoints)
    }

    func testTickAfterMatchEndsCannotChangeAnything() {
        let vm = engine(players: 2, questions: 2)
        vm.start()
        vm.submitAnswer(correctOption); vm.continueAfterReveal()
        vm.submitAnswer(correctOption); vm.continueAfterReveal()
        XCTAssertTrue(vm.phase.isFinished)
        let finalScores = vm.standings.map(\.score)

        for _ in 0..<50 { vm.tick() }

        XCTAssertTrue(vm.phase.isFinished)
        XCTAssertEqual(vm.standings.map(\.score), finalScores)
    }

    // MARK: Rapid repeated input

    func testRepeatedPressesScoreOnlyOnce() {
        let vm = engine()
        vm.start()

        for _ in 0..<10 { vm.submitAnswer(correctOption) }

        XCTAssertEqual(score(vm, "P1"), MatchScoring.correctAnswerPoints,
                       "A mashed remote must not multiply the score")
        XCTAssertEqual(vm.standings.first { $0.player.name == "P1" }?.answeredCount, 1)
    }

    func testPressingADifferentOptionAfterAnsweringIsIgnored() {
        let vm = engine()
        vm.start()

        vm.submitAnswer(correctOption)
        vm.submitAnswer(wrongOption)      // too late

        XCTAssertEqual(vm.phase.outcome, .correct(selectedIndex: correctOption))
        XCTAssertEqual(score(vm, "P1"), MatchScoring.correctAnswerPoints)
    }

    func testAnsweringAfterTimeoutIsIgnored() {
        let vm = engine()
        vm.start()
        for _ in 0..<Difficulty.easy.baseTimeLimit { vm.tick() }

        vm.submitAnswer(correctOption)

        XCTAssertEqual(vm.phase.outcome, .timedOut)
        XCTAssertEqual(score(vm, "P1"), 0)
    }

    func testRepeatedContinuePressesAdvanceOnlyOneQuestion() {
        let vm = engine(players: 2, questions: 4)
        vm.start()
        vm.submitAnswer(correctOption)

        for _ in 0..<10 { vm.continueAfterReveal() }

        XCTAssertEqual(vm.phase, .asking(index: 1), "Continue must advance exactly one question")
    }

    func testContinueDoesNothingWhileAQuestionIsOpen() {
        let vm = engine()
        vm.start()

        vm.continueAfterReveal()

        XCTAssertEqual(vm.phase, .asking(index: 0))
    }

    // MARK: Turn rotation

    func testTurnsRotateBetweenTwoPlayers() {
        let vm = engine(players: 2, questions: 4)
        vm.start()
        XCTAssertEqual(vm.currentPlayer?.name, "P1")

        vm.submitAnswer(correctOption); vm.continueAfterReveal()
        XCTAssertEqual(vm.currentPlayer?.name, "P2")

        vm.submitAnswer(correctOption); vm.continueAfterReveal()
        XCTAssertEqual(vm.currentPlayer?.name, "P1")
    }

    func testTurnsRotateBetweenFourPlayers() {
        let vm = engine(players: 4, questions: 8)
        vm.start()

        var seen: [String] = []
        for _ in 0..<5 {
            seen.append(vm.currentPlayer?.name ?? "?")
            vm.submitAnswer(wrongOption)
            vm.continueAfterReveal()
        }

        XCTAssertEqual(seen, ["P1", "P2", "P3", "P4", "P1"])
    }

    func testEachPlayerKeepsTheirOwnScore() {
        let vm = engine(players: 2, questions: 4)
        vm.start()

        vm.submitAnswer(correctOption); vm.continueAfterReveal()   // P1 right
        vm.submitAnswer(wrongOption);   vm.continueAfterReveal()   // P2 wrong
        vm.submitAnswer(correctOption); vm.continueAfterReveal()   // P1 right

        XCTAssertEqual(score(vm, "P1"), 2 * MatchScoring.correctAnswerPoints)
        XCTAssertEqual(score(vm, "P2"), 0)
    }

    func testStandingsStayInSeatOrder() {
        let vm = engine(players: 3, questions: 6)
        vm.start()
        vm.submitAnswer(wrongOption); vm.continueAfterReveal()
        vm.submitAnswer(correctOption); vm.continueAfterReveal()

        XCTAssertEqual(vm.standings.map(\.player.name), ["P1", "P2", "P3"],
                       "The live score strip must not reorder mid-match")
    }

    // MARK: Completion

    func testMatchFinishesAfterTheLastQuestion() {
        let vm = engine(players: 2, questions: 3)
        vm.start()

        for _ in 0..<3 {
            vm.submitAnswer(correctOption)
            vm.continueAfterReveal()
        }

        XCTAssertTrue(vm.phase.isFinished)
        XCTAssertNotNil(vm.finalResult)
    }

    func testLastQuestionIsFlagged() {
        let vm = engine(players: 2, questions: 2)
        vm.start()
        XCTAssertFalse(vm.isLastQuestion)

        vm.submitAnswer(correctOption); vm.continueAfterReveal()

        XCTAssertTrue(vm.isLastQuestion)
        XCTAssertEqual(vm.continueButtonTitle, "See Results")
    }

    func testFinalResultCarriesEveryPlayerAndTheSettings() throws {
        let vm = engine(players: 3, questions: 3)
        vm.start()
        for _ in 0..<3 {
            vm.submitAnswer(correctOption)
            vm.continueAfterReveal()
        }

        let result = try XCTUnwrap(vm.finalResult)

        XCTAssertEqual(result.scores.count, 3)
        XCTAssertEqual(result.settings.category, .generalKnowledge)
        XCTAssertEqual(result.scores.map(\.score).reduce(0, +),
                       3 * MatchScoring.correctAnswerPoints)
    }

    func testWinnerIsTheHighestScorer() throws {
        let vm = engine(players: 2, questions: 4)
        vm.start()
        vm.submitAnswer(correctOption); vm.continueAfterReveal()   // P1 100
        vm.submitAnswer(wrongOption);   vm.continueAfterReveal()   // P2 0
        vm.submitAnswer(correctOption); vm.continueAfterReveal()   // P1 200
        vm.submitAnswer(wrongOption);   vm.continueAfterReveal()   // P2 0

        let result = try XCTUnwrap(vm.finalResult)

        XCTAssertEqual(result.winners.map(\.player.name), ["P1"])
        XCTAssertFalse(result.isDraw)
    }

    func testEqualScoresProduceADraw() throws {
        let vm = engine(players: 2, questions: 2)
        vm.start()
        vm.submitAnswer(correctOption); vm.continueAfterReveal()
        vm.submitAnswer(correctOption); vm.continueAfterReveal()

        let result = try XCTUnwrap(vm.finalResult)

        XCTAssertTrue(result.isDraw)
        XCTAssertEqual(result.winners.count, 2)
    }

    func testAllTimeoutsStillCompleteTheMatchWithZeroScores() throws {
        let vm = engine(players: 2, questions: 2)
        vm.start()
        for _ in 0..<2 {
            for _ in 0..<Difficulty.easy.baseTimeLimit { vm.tick() }
            vm.continueAfterReveal()
        }

        let result = try XCTUnwrap(vm.finalResult)

        XCTAssertTrue(vm.phase.isFinished)
        XCTAssertEqual(result.scores.map(\.score), [0, 0])
    }

    func testSessionWithNoQuestionsFinishesImmediately() {
        let empty = GameSession(players: [Player(name: "P1", colorIndex: 0)],
                                settings: .standard,
                                questions: [])
        let vm = QuizGameViewModel(session: empty, runsCountdown: false)

        vm.start()

        XCTAssertTrue(vm.phase.isFinished, "An unplayable session must not hang on a blank screen")
    }

    // MARK: Progress

    func testProgressRunsFromZeroToOne() {
        let vm = engine(players: 2, questions: 2)
        XCTAssertEqual(vm.progress, 0)

        vm.start()
        XCTAssertEqual(vm.progress, 0)

        vm.submitAnswer(correctOption)
        XCTAssertEqual(vm.progress, 0.5, accuracy: 0.001)

        vm.continueAfterReveal()
        vm.submitAnswer(correctOption)
        vm.continueAfterReveal()
        XCTAssertEqual(vm.progress, 1, accuracy: 0.001)
    }

    func testTimeFractionFallsAsTheClockRuns() {
        let vm = engine(difficulty: .medium)
        vm.start()
        XCTAssertEqual(vm.timeFraction, 1, accuracy: 0.001)

        for _ in 0..<(Difficulty.medium.baseTimeLimit / 2) { vm.tick() }

        XCTAssertEqual(vm.timeFraction, 0.5, accuracy: 0.05)
    }

    // MARK: Shuffled answers keep their mapping

    func testCorrectAnswerIsScoredAfterShuffling() {
        // Builds the match through the repository, so answers really are
        // shuffled, then answers each question by looking up the shuffled index.
        let bank = (1...6).map {
            Question(id: "s\($0)", category: .generalKnowledge, difficulty: .easy,
                     prompt: "P\($0)?", options: ["RIGHT", "w1", "w2", "w3"],
                     correctIndex: 0, explanation: nil)
        }
        let repository = QuestionRepository(
            provider: FixedProvider(result: QuestionBankLoadResult(version: 1,
                                                                   questions: bank,
                                                                   rejected: []))
        )
        _ = try? repository.load()

        var rng = SeededRandomNumberGenerator(seed: 2026)
        let prepared = repository.makeQuestionSet(
            for: QuizSettings(category: .generalKnowledge, questionCount: 6), using: &rng)

        let built = GameSession(players: [Player(name: "Solo", colorIndex: 0)],
                                settings: QuizSettings(category: .generalKnowledge, questionCount: 6),
                                questions: prepared)
        let vm = QuizGameViewModel(session: built, runsCountdown: false)
        vm.start()

        for _ in 0..<6 {
            let index = vm.currentQuestion!.options.firstIndex(of: "RIGHT")!
            vm.submitAnswer(index)
            XCTAssertTrue(vm.phase.outcome?.isCorrect ?? false,
                          "The shuffled index of the right answer must score")
            vm.continueAfterReveal()
        }

        XCTAssertEqual(vm.finalResult?.scores.first?.score, 6 * MatchScoring.correctAnswerPoints)
    }
}

private struct FixedProvider: QuestionProviding {
    let result: QuestionBankLoadResult
    func loadQuestions() throws -> QuestionBankLoadResult { result }
}

// MARK: - Scoring rules

final class MatchScoringTests: XCTestCase {

    func testCorrectAnswerIsWorthOneHundred() {
        XCTAssertEqual(MatchScoring.correctAnswerPoints, 100)
    }

    func testWrongAnswersAndTimeoutsScoreNothing() {
        XCTAssertEqual(MatchScoring.incorrectAnswerPoints, 0)
        XCTAssertEqual(MatchScoring.timeoutPoints, 0)
    }

    func testOutcomePointsFollowTheRules() {
        XCTAssertEqual(TurnOutcome.correct(selectedIndex: 0).pointsAwarded, 100)
        XCTAssertEqual(TurnOutcome.incorrect(selectedIndex: 2).pointsAwarded, 0)
        XCTAssertEqual(TurnOutcome.timedOut.pointsAwarded, 0)
    }

    func testMaximumPointsScalesWithQuestionCount() {
        XCTAssertEqual(MatchScoring.maximumPoints(forQuestionCount: 10), 1000)
        XCTAssertEqual(MatchScoring.maximumPoints(forQuestionCount: 0), 0)
        XCTAssertEqual(MatchScoring.maximumPoints(forQuestionCount: -3), 0)
    }

    func testDifficultyNoLongerAffectsScoreButStillAffectsTime() {
        XCTAssertLessThan(Difficulty.easy.baseTimeLimit, Difficulty.hard.baseTimeLimit)
    }
}
