//
//  MatchResultsTests.swift
//  IT23251182-tvOSTests
//
//  Tests for the end-of-match experience: ranking, ties, saving exactly once,
//  the turn log behind Review Answers, and the Play Again reset.
//

import XCTest
@testable import IT23251182_tvOS

// MARK: - Helpers

private func isolatedDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private func player(_ name: String, seat: Int) -> Player {
    Player(name: name, colorIndex: seat, avatar: PlayerAvatar.default(forSeat: seat + 1))
}

private func score(_ name: String,
                   seat: Int,
                   points: Int,
                   correct: Int = 0,
                   answered: Int = 5) -> PlayerScore {
    PlayerScore(player: player(name, seat: seat),
                score: points, correctCount: correct, answeredCount: answered)
}

private func result(_ scores: [PlayerScore],
                    turns: [TurnRecord] = [],
                    category: QuizCategory = .generalKnowledge) -> MatchResult {
    MatchResult(settings: QuizSettings(category: category, questionCount: 10),
                scores: scores,
                turns: turns)
}

private func stubRepository(questionCount: Int = 20,
                            category: QuizCategory = .generalKnowledge) -> QuestionRepository {
    let questions = (1...questionCount).map {
        Question(id: "r\($0)", category: category, difficulty: .easy,
                 prompt: "Prompt \($0)?", options: ["RIGHT", "w1", "w2", "w3"],
                 correctIndex: 0, explanation: "Because.")
    }
    let repository = QuestionRepository(
        provider: ListProvider(result: QuestionBankLoadResult(version: 1,
                                                              questions: questions,
                                                              rejected: []))
    )
    _ = try? repository.load()
    return repository
}

private struct ListProvider: QuestionProviding {
    let result: QuestionBankLoadResult
    func loadQuestions() throws -> QuestionBankLoadResult { result }
}

private func makeViewModel(_ matchResult: MatchResult,
                           repository: QuestionRepository? = nil,
                           store: MatchHistoryStore? = nil) -> MatchResultsViewModel {
    MatchResultsViewModel(result: matchResult,
                          repository: repository ?? stubRepository(),
                          historyStore: store ?? MatchHistoryStore(defaults: isolatedDefaults()))
}

// MARK: - Ranking and ties

final class ResultsRankingTests: XCTestCase {

    func testNormalWinIsRankedHighestFirst() {
        let vm = makeViewModel(result([
            score("Low", seat: 0, points: 100, correct: 1),
            score("High", seat: 1, points: 400, correct: 4),
            score("Mid", seat: 2, points: 200, correct: 2)
        ]))

        XCTAssertEqual(vm.ranking.map(\.player.name), ["High", "Mid", "Low"])
        XCTAssertEqual(vm.headline, "High Wins")
        XCTAssertFalse(vm.isDraw)
        XCTAssertEqual(vm.topScore, 400)
    }

    func testTwoWayTieIsReportedAsATie() {
        let vm = makeViewModel(result([
            score("A", seat: 0, points: 300, correct: 3),
            score("B", seat: 1, points: 300, correct: 3),
            score("C", seat: 2, points: 100, correct: 1)
        ]))

        XCTAssertTrue(vm.isDraw)
        XCTAssertEqual(Set(vm.winners.map(\.player.name)), ["A", "B"])
        XCTAssertEqual(vm.headline, "A and B Tie")
    }

    func testThreeWayTieListsEveryWinner() {
        let vm = makeViewModel(result([
            score("A", seat: 0, points: 200, correct: 2),
            score("B", seat: 1, points: 200, correct: 2),
            score("C", seat: 2, points: 200, correct: 2),
            score("D", seat: 3, points: 100, correct: 1)
        ]))

        XCTAssertTrue(vm.isDraw)
        XCTAssertEqual(vm.winners.count, 3)
        XCTAssertEqual(vm.headline, "A, B and C Tie")
    }

    func testEverybodyTyingIsSaidPlainly() {
        let vm = makeViewModel(result([
            score("A", seat: 0, points: 100, correct: 1),
            score("B", seat: 1, points: 100, correct: 1)
        ]))

        XCTAssertEqual(vm.headline, "Everybody Ties")
    }

    func testTiedPlayersShareFirstPosition() {
        let vm = makeViewModel(result([
            score("A", seat: 0, points: 300, correct: 3),
            score("B", seat: 1, points: 300, correct: 3),
            score("C", seat: 2, points: 100, correct: 1)
        ]))

        XCTAssertEqual(vm.positionLabel(0), "Tied 1st")
        XCTAssertEqual(vm.positionLabel(1), "Tied 1st")
        XCTAssertEqual(vm.positionLabel(2), "3rd place")
    }

    func testNonTiedPositionsAreOrdinal() {
        let vm = makeViewModel(result([
            score("A", seat: 0, points: 400, correct: 4),
            score("B", seat: 1, points: 300, correct: 3),
            score("C", seat: 2, points: 200, correct: 2),
            score("D", seat: 3, points: 100, correct: 1)
        ]))

        XCTAssertEqual(vm.positionLabel(0), "1st place")
        XCTAssertEqual(vm.positionLabel(1), "2nd place")
        XCTAssertEqual(vm.positionLabel(2), "3rd place")
        XCTAssertEqual(vm.positionLabel(3), "4th place")
    }

    func testFourPlayerRankingOrdersEveryone() {
        let vm = makeViewModel(result([
            score("P1", seat: 0, points: 100, correct: 1),
            score("P2", seat: 1, points: 400, correct: 4),
            score("P3", seat: 2, points: 0),
            score("P4", seat: 3, points: 250, correct: 2)
        ]))

        XCTAssertEqual(vm.ranking.map(\.player.name), ["P2", "P4", "P1", "P3"])
        XCTAssertTrue(vm.isWinner(vm.ranking[0]))
        XCTAssertFalse(vm.isWinner(vm.ranking[1]))
    }

    func testZeroScoreMatchStillProducesARanking() {
        let vm = makeViewModel(result([
            score("A", seat: 0, points: 0, answered: 3),
            score("B", seat: 1, points: 0, answered: 3)
        ]))

        XCTAssertEqual(vm.ranking.count, 2)
        XCTAssertTrue(vm.isDraw, "Two players on zero have genuinely tied")
    }
}

// MARK: - Statistics

final class ResultsStatisticsTests: XCTestCase {

    func testQuestionsCompletedComesFromTheTurnLogWhenPresent() {
        let turns = (1...7).map { index in
            TurnRecord(questionNumber: index,
                       question: PreparedQuestion(source: Question(
                           id: "q\(index)", category: .generalKnowledge, difficulty: .easy,
                           prompt: "P?", options: ["a", "b", "c", "d"],
                           correctIndex: 0, explanation: nil)),
                       player: player("A", seat: 0),
                       outcome: .correct(selectedIndex: 0))
        }
        let vm = makeViewModel(result([score("A", seat: 0, points: 700, correct: 7, answered: 7)],
                                      turns: turns))

        XCTAssertEqual(vm.questionsCompleted, 7)
    }

    func testStatisticsAggregateAcrossPlayers() {
        let vm = makeViewModel(result([
            score("A", seat: 0, points: 300, correct: 3, answered: 5),
            score("B", seat: 1, points: 200, correct: 2, answered: 5)
        ]))

        XCTAssertEqual(vm.totalCorrectAnswers, 5)
        XCTAssertEqual(vm.overallAccuracyPercent, 50)   // 5 correct of 10 answered
    }

    func testAccuracyIsZeroRatherThanCrashingOnAnEmptyMatch() {
        let vm = makeViewModel(result([score("A", seat: 0, points: 0, answered: 0)]))
        XCTAssertEqual(vm.overallAccuracyPercent, 0)
        XCTAssertEqual(vm.accuracyPercent(for: vm.ranking[0]), 0)
    }

    func testPerPlayerAccuracyLabel() {
        let vm = makeViewModel(result([score("A", seat: 0, points: 300, correct: 3, answered: 4)]))
        XCTAssertEqual(vm.accuracyLabel(for: vm.ranking[0]), "3 of 4 correct")
        XCTAssertEqual(vm.accuracyPercent(for: vm.ranking[0]), 75)
    }

    func testSubtitleNamesTheCategoryAndQuestionCount() {
        let vm = makeViewModel(result([score("A", seat: 0, points: 100, correct: 1, answered: 3)]))
        XCTAssertTrue(vm.subtitle.contains(QuizCategory.generalKnowledge.displayName))
        XCTAssertTrue(vm.subtitle.contains("completed"))
    }
}

// MARK: - Saving exactly once

final class MatchHistoryStoreTests: XCTestCase {

    func testSavesAndReloadsAMatch() {
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        let match = result([score("A", seat: 0, points: 300, correct: 3)])

        XCTAssertTrue(store.save(match))

        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, match.id)
    }

    func testSavingTheSameMatchTwiceIsRefused() {
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        let match = result([score("A", seat: 0, points: 300, correct: 3)])

        XCTAssertTrue(store.save(match))
        XCTAssertFalse(store.save(match), "The same completed game must not be stored twice")
        XCTAssertEqual(store.load().count, 1)
    }

    func testDifferentMatchesAreBothStored() {
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        store.save(result([score("A", seat: 0, points: 100, correct: 1)]))
        store.save(result([score("B", seat: 0, points: 200, correct: 2)]))

        XCTAssertEqual(store.load().count, 2)
    }

    func testHistoryIsMostRecentFirst() {
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        let older = MatchResult(playedAt: Date(timeIntervalSince1970: 1_000),
                                settings: .standard,
                                scores: [score("Old", seat: 0, points: 100)])
        let newer = MatchResult(playedAt: Date(timeIntervalSince1970: 2_000),
                                settings: .standard,
                                scores: [score("New", seat: 0, points: 100)])

        store.save(older)
        store.save(newer)

        XCTAssertEqual(store.load().first?.scores.first?.player.name, "New")
    }

    func testHistoryIsCapped() {
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        for index in 0..<(MatchHistoryStore.maximumStoredMatches + 5) {
            store.save(MatchResult(playedAt: Date(timeIntervalSince1970: Double(index)),
                                   settings: .standard,
                                   scores: [score("P\(index)", seat: 0, points: 100)]))
        }

        XCTAssertEqual(store.load().count, MatchHistoryStore.maximumStoredMatches)
    }

    func testTurnsSurviveBeingStored() throws {
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        let question = PreparedQuestion(source: Question(
            id: "q1", category: .generalKnowledge, difficulty: .medium,
            prompt: "Which one?", options: ["RIGHT", "a", "b", "c"],
            correctIndex: 0, explanation: "Because."))
        let turn = TurnRecord(questionNumber: 1,
                              question: question,
                              player: player("A", seat: 0),
                              outcome: .incorrect(selectedIndex: 2))

        store.save(result([score("A", seat: 0, points: 0, answered: 1)], turns: [turn]))

        let loaded = try XCTUnwrap(store.load().first)
        XCTAssertEqual(loaded.turns.count, 1)
        XCTAssertEqual(loaded.turns[0].question.prompt, "Which one?")
        XCTAssertEqual(loaded.turns[0].selectedAnswer, "b")
        XCTAssertEqual(loaded.turns[0].correctAnswer, "RIGHT")
    }

    func testClearEmptiesTheHistory() {
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        store.save(result([score("A", seat: 0, points: 100)]))
        store.clear()
        XCTAssertTrue(store.load().isEmpty)
    }
}

final class ResultsSavingTests: XCTestCase {

    func testResultIsSavedOnTheFirstCall() {
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        let vm = makeViewModel(result([score("A", seat: 0, points: 300, correct: 3)]), store: store)

        XCTAssertFalse(vm.isSaved)
        XCTAssertTrue(vm.recordResultIfNeeded())
        XCTAssertTrue(vm.isSaved)
        XCTAssertEqual(store.load().count, 1)
    }

    func testRepeatedCallsDoNotSaveAgain() {
        // The results screen reappears when returning from Review Answers, so
        // onAppear can fire several times for one match.
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        let vm = makeViewModel(result([score("A", seat: 0, points: 300, correct: 3)]), store: store)

        vm.recordResultIfNeeded()
        for _ in 0..<10 { XCTAssertFalse(vm.recordResultIfNeeded()) }

        XCTAssertEqual(store.load().count, 1, "The same game must appear once in history")
    }

    func testAFreshViewModelForTheSameMatchStillDoesNotDuplicate() {
        // A rebuilt view (new view model, same match) must also be refused.
        let defaults = isolatedDefaults()
        let match = result([score("A", seat: 0, points: 300, correct: 3)])

        let first = makeViewModel(match, store: MatchHistoryStore(defaults: defaults))
        first.recordResultIfNeeded()

        let second = makeViewModel(match, store: MatchHistoryStore(defaults: defaults))
        XCTAssertFalse(second.recordResultIfNeeded())

        XCTAssertEqual(MatchHistoryStore(defaults: defaults).load().count, 1)
    }

    func testSavingDoesNotChangeTheScores() {
        let store = MatchHistoryStore(defaults: isolatedDefaults())
        let match = result([score("A", seat: 0, points: 300, correct: 3)])
        let vm = makeViewModel(match, store: store)

        vm.recordResultIfNeeded()
        vm.recordResultIfNeeded()

        XCTAssertEqual(vm.ranking.map(\.score), [300], "Saving must never award points")
        XCTAssertEqual(store.load().first?.scores.map(\.score), [300])
    }
}

// MARK: - Play Again

final class PlayAgainTests: XCTestCase {

    func testRematchKeepsThePlayersAndSettings() throws {
        let match = result([
            score("A", seat: 0, points: 300, correct: 3),
            score("B", seat: 1, points: 100, correct: 1)
        ])
        let vm = makeViewModel(match)

        let session = try XCTUnwrap(vm.makeRematchSession())

        XCTAssertEqual(session.players.map(\.name), ["A", "B"])
        XCTAssertEqual(session.settings, match.settings)
    }

    func testRematchUsesSeatOrderNotFinishingOrder() throws {
        // The loser of the last match should not be promoted to going first
        // just because the scoreboard was sorted.
        let match = result([
            score("A", seat: 0, points: 100, correct: 1),
            score("B", seat: 1, points: 400, correct: 4)
        ])
        let vm = makeViewModel(match)

        let session = try XCTUnwrap(vm.makeRematchSession())

        XCTAssertEqual(session.players.map(\.name), ["A", "B"])
    }

    func testRematchIsAGenuinelyNewSession() throws {
        let vm = makeViewModel(result([score("A", seat: 0, points: 300, correct: 3)]))

        let first = try XCTUnwrap(vm.makeRematchSession())
        let second = try XCTUnwrap(vm.makeRematchSession())

        XCTAssertNotEqual(first.id, second.id, "Each rematch must be its own session")
    }

    @MainActor
    func testRematchStartsWithNoScores() throws {
        let vm = makeViewModel(result([score("A", seat: 0, points: 300, correct: 3)]))
        let session = try XCTUnwrap(vm.makeRematchSession())

        // The engine is main-actor isolated, so this test is too.
        let engine = QuizGameViewModel(session: session, runsCountdown: false)

        XCTAssertEqual(engine.standings.map(\.score), [0],
                       "Play Again must reset every score to zero")
    }

    func testRematchHasFreshQuestions() throws {
        let vm = makeViewModel(result([score("A", seat: 0, points: 300, correct: 3)]))
        let session = try XCTUnwrap(vm.makeRematchSession())

        XCTAssertFalse(session.questions.isEmpty)
        XCTAssertEqual(Set(session.questions.map(\.id)).count, session.questions.count)
    }

    func testPlayAgainIsUnavailableWhenTheBankCannotSupplyQuestions() {
        let emptyRepository = QuestionRepository(
            provider: ListProvider(result: QuestionBankLoadResult(version: 1,
                                                                  questions: [],
                                                                  rejected: []))
        )
        let vm = makeViewModel(result([score("A", seat: 0, points: 100, correct: 1)]),
                               repository: emptyRepository)

        XCTAssertFalse(vm.canPlayAgain)
        XCTAssertNil(vm.makeRematchSession())
    }
}

// MARK: - Review Answers

@MainActor
final class ReviewAnswersTests: XCTestCase {

    private func playedMatch(players: Int = 2, questions: Int = 4) -> QuizGameViewModel {
        let roster = (1...players).map { player("P\($0)", seat: $0 - 1) }
        let prepared = (1...questions).map { index in
            PreparedQuestion(source: Question(
                id: "q\(index)", category: .generalKnowledge, difficulty: .easy,
                prompt: "Prompt \(index)?", options: ["RIGHT", "w1", "w2", "w3"],
                correctIndex: 0, explanation: "Explained."))
        }
        let session = GameSession(players: roster,
                                  settings: QuizSettings(category: .generalKnowledge,
                                                         questionCount: questions),
                                  questions: prepared)
        return QuizGameViewModel(session: session, runsCountdown: false)
    }

    func testEveryAnsweredQuestionIsRecorded() throws {
        let engine = playedMatch(questions: 4)
        engine.start()
        for _ in 0..<4 {
            engine.submitAnswer(0)
            engine.continueAfterReveal()
        }

        let match = try XCTUnwrap(engine.finalResult)

        XCTAssertEqual(match.turns.count, 4)
        XCTAssertTrue(match.canReviewAnswers)
        XCTAssertEqual(match.turns.map(\.questionNumber), [1, 2, 3, 4])
    }

    func testTurnRecordsTheActualChosenAnswer() throws {
        let engine = playedMatch(questions: 2)
        engine.start()
        engine.submitAnswer(2)          // "w2" — wrong
        engine.continueAfterReveal()
        engine.submitAnswer(0)          // "RIGHT"
        engine.continueAfterReveal()

        let match = try XCTUnwrap(engine.finalResult)

        XCTAssertEqual(match.turns[0].selectedAnswer, "w2")
        XCTAssertFalse(match.turns[0].isCorrect)
        XCTAssertEqual(match.turns[0].correctAnswer, "RIGHT")

        XCTAssertEqual(match.turns[1].selectedAnswer, "RIGHT")
        XCTAssertTrue(match.turns[1].isCorrect)
    }

    func testTurnRecordsWhichPlayerAnswered() throws {
        let engine = playedMatch(players: 2, questions: 4)
        engine.start()
        for _ in 0..<4 {
            engine.submitAnswer(0)
            engine.continueAfterReveal()
        }

        let match = try XCTUnwrap(engine.finalResult)

        XCTAssertEqual(match.turns.map(\.player.name), ["P1", "P2", "P1", "P2"])
    }

    func testTimeoutIsRecordedWithNoChosenAnswer() throws {
        let engine = playedMatch(questions: 2)
        engine.start()
        for _ in 0..<Difficulty.easy.baseTimeLimit { engine.tick() }
        engine.continueAfterReveal()
        engine.submitAnswer(0)
        engine.continueAfterReveal()

        let match = try XCTUnwrap(engine.finalResult)

        XCTAssertNil(match.turns[0].selectedAnswer)
        XCTAssertTrue(match.turns[0].outcome.isTimeout)
        XCTAssertEqual(match.turns[0].pointsAwarded, 0)
    }

    func testRepeatedPressesRecordOnlyOneTurn() throws {
        let engine = playedMatch(questions: 2)
        engine.start()
        for _ in 0..<10 { engine.submitAnswer(0) }
        engine.continueAfterReveal()
        engine.submitAnswer(0)
        engine.continueAfterReveal()

        let match = try XCTUnwrap(engine.finalResult)

        XCTAssertEqual(match.turns.count, 2, "A mashed remote must not duplicate the turn log")
    }

    func testReviewIsHiddenWhenNoTurnsWereRecorded() {
        let vm = makeViewModel(result([score("A", seat: 0, points: 100, correct: 1)]))
        XCTAssertFalse(vm.canReviewAnswers, "The control must be omitted rather than lead nowhere")
    }

    func testNoPointsAreAwardedAfterCompletion() throws {
        let engine = playedMatch(questions: 2)
        engine.start()
        engine.submitAnswer(0); engine.continueAfterReveal()
        engine.submitAnswer(0); engine.continueAfterReveal()
        let finalScores = engine.standings.map(\.score)

        // Everything the remote or the clock could still send.
        for _ in 0..<20 {
            engine.submitAnswer(0)
            engine.tick()
            engine.continueAfterReveal()
        }

        XCTAssertEqual(engine.standings.map(\.score), finalScores)
        XCTAssertEqual(try XCTUnwrap(engine.finalResult).turns.count, 2)
    }
}
