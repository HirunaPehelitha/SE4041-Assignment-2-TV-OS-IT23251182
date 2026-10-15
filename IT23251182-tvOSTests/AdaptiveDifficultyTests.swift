//
//  AdaptiveDifficultyTests.swift
//  IT23251182-tvOSTests
//
//  Tests for the rule-based Adaptive Challenge policy, and for the guarantee
//  that the core game is unaffected when it is switched off or when a player
//  has too little history to judge.
//

import XCTest
@testable import IT23251182_tvOS

// MARK: - The policy itself

final class AdaptiveDifficultyPolicyTests: XCTestCase {

    // MARK: Bands

    func testNoHistoryIsSteady() {
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: []), .steady)
    }

    func testTooLittleHistoryIsSteadyEvenIfPerfect() {
        // One lucky answer must not immediately ramp the difficulty up.
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: [true]), .steady)
    }

    func testTooLittleHistoryIsSteadyEvenIfAllWrong() {
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: [false]), .steady)
    }

    func testStrongRecentAccuracyIsStrong() {
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: [true, true, true, true]), .strong)
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: [true, true, true]), .strong)
    }

    func testWeakRecentAccuracyIsStruggling() {
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: [false, false, false, false]), .struggling)
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: [false, false, false, true]), .struggling)
    }

    func testMixedAccuracyIsSteady() {
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: [true, false, true, false]), .steady)
    }

    func testOnlyRecentAnswersCount() {
        // A bad start followed by a strong run should read as strong: the
        // window is the last four answers, not the whole match.
        let history = [false, false, false, false, true, true, true, true]
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: history), .strong)
    }

    func testRecoveryIsPossibleWithinOneWindow() {
        let history = [true, true, true, true, false, false, false, false]
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: history), .struggling)
    }

    // MARK: Weights are bounded

    func testNoDifficultyIsEverImpossible() {
        for band in PerformanceBand.allCases {
            for difficulty in Difficulty.allCases {
                XCTAssertGreaterThanOrEqual(
                    AdaptiveDifficultyPolicy.weight(for: difficulty, band: band), 1,
                    "\(band) must still allow \(difficulty)")
            }
        }
    }

    func testStrongPlayersFavourHarderQuestions() {
        let weights = AdaptiveDifficultyPolicy.weights(for: .strong)
        XCTAssertGreaterThan(weights[.hard] ?? 0, weights[.easy] ?? 0)
    }

    func testStrugglingPlayersFavourEasierQuestions() {
        let weights = AdaptiveDifficultyPolicy.weights(for: .struggling)
        XCTAssertGreaterThan(weights[.easy] ?? 0, weights[.hard] ?? 0)
    }

    func testSteadyIsBalanced() {
        let weights = AdaptiveDifficultyPolicy.weights(for: .steady)
        XCTAssertEqual(weights[.easy], weights[.hard], "A balanced mixture should not lean either way")
    }

    // MARK: Selection

    private func question(_ id: String, _ difficulty: Difficulty) -> PreparedQuestion {
        PreparedQuestion(source: Question(
            id: id, category: .generalKnowledge, difficulty: difficulty,
            prompt: "P?", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: nil))
    }

    func testSelectionReturnsNilOnlyForAnEmptyPool() {
        var rng = SeededRandomNumberGenerator(seed: 1)
        XCTAssertNil(AdaptiveDifficultyPolicy.selectIndex(from: [], band: .steady, using: &rng))
    }

    func testSelectionAlwaysReturnsAValidIndex() {
        let pool = [question("a", .easy), question("b", .medium), question("c", .hard)]

        for seed in UInt64(1)...200 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            for band in PerformanceBand.allCases {
                let index = AdaptiveDifficultyPolicy.selectIndex(from: pool, band: band, using: &rng)
                XCTAssertNotNil(index)
                XCTAssertTrue(pool.indices.contains(index!), "seed \(seed), band \(band)")
            }
        }
    }

    func testSingleQuestionPoolAlwaysSelectsIt() {
        let pool = [question("only", .hard)]
        for band in PerformanceBand.allCases {
            var rng = SeededRandomNumberGenerator(seed: 5)
            XCTAssertEqual(AdaptiveDifficultyPolicy.selectIndex(from: pool, band: band, using: &rng), 0)
        }
    }

    /// The statistical claim behind the feature, checked over many draws.
    func testStrongBandPicksHardQuestionsMoreOftenThanStrugglingBand() {
        let pool = [question("e", .easy), question("m", .medium), question("h", .hard)]
        let draws = 3_000

        func hardShare(band: PerformanceBand, seed: UInt64) -> Double {
            var rng = SeededRandomNumberGenerator(seed: seed)
            var hard = 0
            for _ in 0..<draws {
                if let index = AdaptiveDifficultyPolicy.selectIndex(from: pool, band: band, using: &rng),
                   pool[index].difficulty == .hard {
                    hard += 1
                }
            }
            return Double(hard) / Double(draws)
        }

        let strong = hardShare(band: .strong, seed: 77)
        let struggling = hardShare(band: .struggling, seed: 77)

        XCTAssertGreaterThan(strong, struggling + 0.2,
                             "Strong players should see noticeably more hard questions")
        XCTAssertGreaterThan(struggling, 0.0,
                             "Hard questions must remain possible — the policy is bounded")
    }

    func testSelectionIsReproducibleForAGivenSeed() {
        let pool = [question("e", .easy), question("m", .medium), question("h", .hard)]

        var a = SeededRandomNumberGenerator(seed: 2026)
        var b = SeededRandomNumberGenerator(seed: 2026)
        let first = (0..<50).map { _ in AdaptiveDifficultyPolicy.selectIndex(from: pool, band: .strong, using: &a) }
        let second = (0..<50).map { _ in AdaptiveDifficultyPolicy.selectIndex(from: pool, band: .strong, using: &b) }

        XCTAssertEqual(first, second)
    }
}

// MARK: - The engine with adaptation on

@MainActor
final class AdaptiveEngineTests: XCTestCase {

    private func question(_ id: String, _ difficulty: Difficulty) -> PreparedQuestion {
        PreparedQuestion(source: Question(
            id: id, category: .sriLankanCulture, difficulty: difficulty,
            prompt: "Prompt \(id)?", options: ["RIGHT", "w1", "w2", "w3"],
            correctIndex: 0, explanation: nil))
    }

    /// A mixed-difficulty pool in a single category.
    ///
    /// `roundLength` is deliberately smaller than the pool: that gap is what
    /// lets the policy choose *which* questions get asked, not merely their
    /// order. With a pool exactly the size of the round, every question would be
    /// asked whatever the policy decided.
    private func session(players: Int = 1,
                         perDifficulty: Int = 6,
                         roundLength: Int? = nil) -> GameSession {
        var questions: [PreparedQuestion] = []
        for difficulty in Difficulty.allCases {
            for index in 1...perDifficulty {
                questions.append(question("\(difficulty.rawValue)-\(index)", difficulty))
            }
        }
        let length = roundLength ?? (questions.count / 3)
        return GameSession(
            players: (1...players).map { Player(name: "P\($0)", colorIndex: $0 - 1) },
            settings: QuizSettings(category: .sriLankanCulture, questionCount: length),
            questions: questions,
            plannedQuestionCount: length
        )
    }

    private func engine(players: Int = 1,
                        adaptive: Bool = true,
                        seed: UInt64 = 42,
                        roundLength: Int? = nil) -> QuizGameViewModel {
        QuizGameViewModel(session: session(players: players, roundLength: roundLength),
                          adaptiveDifficultyEnabled: adaptive,
                          generator: SeededRandomNumberGenerator(seed: seed),
                          runsCountdown: false)
    }

    private var correctOption: Int { 0 }
    private var wrongOption: Int { 1 }

    // MARK: Safety guarantees

    func testEveryServedQuestionBelongsToTheChosenCategory() {
        let vm = engine()
        vm.start()

        while !vm.phase.isFinished {
            XCTAssertEqual(vm.currentQuestion?.category, .sriLankanCulture)
            vm.submitAnswer(correctOption)
            vm.continueAfterReveal()
        }
    }

    func testNoQuestionIsServedTwice() {
        let vm = engine()
        vm.start()

        var seen: [String] = []
        while !vm.phase.isFinished {
            seen.append(vm.currentQuestion?.id ?? "?")
            vm.submitAnswer(correctOption)
            vm.continueAfterReveal()
        }

        XCTAssertEqual(Set(seen).count, seen.count, "Adaptive selection must not repeat a question")
    }

    func testMatchAsksExactlyThePlannedNumberOfQuestions() throws {
        let vm = engine()
        let planned = vm.totalQuestions
        vm.start()

        var asked = 0
        while !vm.phase.isFinished {
            asked += 1
            vm.submitAnswer(correctOption)
            vm.continueAfterReveal()
        }

        XCTAssertEqual(asked, planned, "Adaptation must never shorten or extend a match")
        XCTAssertEqual(try XCTUnwrap(vm.finalResult).turns.count, planned)
    }

    func testRoundIsShorterThanThePoolSoSelectionIsMeaningful() {
        let built = session()
        XCTAssertLessThan(built.questionCount, built.poolSize,
                          "The policy needs spare questions to choose between")
    }

    func testAdaptationCannotStallAfterAllWrongAnswers() {
        let vm = engine()
        vm.start()

        var guard_ = 0
        while !vm.phase.isFinished && guard_ < 200 {
            vm.submitAnswer(wrongOption)
            vm.continueAfterReveal()
            guard_ += 1
        }

        XCTAssertTrue(vm.phase.isFinished)
    }

    func testAdaptationCannotStallAfterRepeatedTimeouts() {
        let vm = engine()
        vm.start()

        var guard_ = 0
        while !vm.phase.isFinished && guard_ < 200 {
            for _ in 0..<QuestionDuration.standard.seconds(for: .hard) { vm.tick() }
            vm.continueAfterReveal()
            guard_ += 1
        }

        XCTAssertTrue(vm.phase.isFinished)
    }

    // MARK: Band tracking

    func testBandStartsSteadyWithNoHistory() {
        let vm = engine()
        vm.start()
        XCTAssertEqual(vm.currentPerformanceBand, .steady)
    }

    func testBandBecomesStrongAfterAGoodRun() {
        let vm = engine()
        vm.start()
        for _ in 0..<3 {
            vm.submitAnswer(correctOption)
            vm.continueAfterReveal()
        }

        XCTAssertEqual(vm.currentPerformanceBand, .strong)
    }

    func testBandBecomesStrugglingAfterABadRun() {
        let vm = engine()
        vm.start()
        for _ in 0..<3 {
            vm.submitAnswer(wrongOption)
            vm.continueAfterReveal()
        }

        XCTAssertEqual(vm.currentPerformanceBand, .struggling)
    }

    func testTimeoutsCountAgainstThePlayer() {
        let vm = engine()
        vm.start()
        for _ in 0..<3 {
            for _ in 0..<QuestionDuration.standard.seconds(for: .hard) { vm.tick() }
            vm.continueAfterReveal()
        }

        XCTAssertEqual(vm.currentPerformanceBand, .struggling)
    }

    func testEachPlayerIsTrackedSeparately() throws {
        // P1 answers everything right, P2 everything wrong.
        let vm = engine(players: 2)
        vm.start()

        for _ in 0..<6 {
            let isP1 = vm.currentPlayer?.name == "P1"
            vm.submitAnswer(isP1 ? correctOption : wrongOption)
            vm.continueAfterReveal()
        }

        let p1 = try XCTUnwrap(vm.session.players.first { $0.name == "P1" })
        let p2 = try XCTUnwrap(vm.session.players.first { $0.name == "P2" })

        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: vm.recentAnswers(for: p1)), .strong)
        XCTAssertEqual(AdaptiveDifficultyPolicy.band(for: vm.recentAnswers(for: p2)), .struggling)
    }

    func testRepeatedPressesDoNotSkewTheHistory() throws {
        let vm = engine()
        vm.start()
        for _ in 0..<10 { vm.submitAnswer(correctOption) }

        let player = try XCTUnwrap(vm.session.players.first)
        XCTAssertEqual(vm.recentAnswers(for: player).count, 1,
                       "One answered question must contribute one data point")
    }

    // MARK: Effect on what gets served

    func testAStrongPlayerSeesHarderQuestionsThanAStrugglingOne() {
        func hardCount(alwaysCorrect: Bool, seed: UInt64) -> Int {
            let vm = engine(seed: seed)
            vm.start()
            var hard = 0
            // Skip the opening questions, which are steady for everyone.
            var turn = 0
            while !vm.phase.isFinished {
                // The opening turns are steady for everyone, so they are not
                // evidence either way.
                if turn >= AdaptiveDifficultyPolicy.minimumAnswersBeforeAdapting,
                   vm.currentQuestion?.difficulty == .hard {
                    hard += 1
                }
                vm.submitAnswer(alwaysCorrect ? correctOption : wrongOption)
                vm.continueAfterReveal()
                turn += 1
            }
            return hard
        }

        // Averaged over several seeds: a single match is a small sample.
        let seeds: [UInt64] = [11, 22, 33, 44, 55, 66, 77, 88]
        let strongTotal = seeds.reduce(0) { $0 + hardCount(alwaysCorrect: true, seed: $1) }
        let strugglingTotal = seeds.reduce(0) { $0 + hardCount(alwaysCorrect: false, seed: $1) }

        XCTAssertGreaterThan(strongTotal, strugglingTotal,
                             "Strong play should bring harder questions forward")
    }

    // MARK: Switched off

    func testDisabledAdaptationServesTheSessionOrder() {
        let vm = engine(adaptive: false, roundLength: 18)
        vm.start()

        var served: [String] = []
        while !vm.phase.isFinished {
            served.append(vm.currentQuestion?.id ?? "?")
            vm.submitAnswer(correctOption)
            vm.continueAfterReveal()
        }

        XCTAssertEqual(served, vm.session.questions.map(\.id),
                       "With adaptation off the engine must play the order it was given")
    }

    func testDisabledAdaptationHidesTheBand() {
        let vm = engine(adaptive: false)
        vm.start()
        XCTAssertNil(vm.currentPerformanceBand, "No badge should appear when the feature is off")
    }

    func testDisabledAdaptationStillScoresAndCompletesNormally() throws {
        let vm = engine(players: 2, adaptive: false)
        vm.start()

        while !vm.phase.isFinished {
            vm.submitAnswer(correctOption)
            vm.continueAfterReveal()
        }

        let result = try XCTUnwrap(vm.finalResult)
        XCTAssertEqual(result.scores.map(\.score).reduce(0, +),
                       vm.totalQuestions * MatchScoring.correctAnswerPoints)
    }

    func testCorrectAnswerMappingSurvivesAdaptiveSelection() {
        // The right answer must still be the right answer whichever question
        // the policy chooses.
        let vm = engine()
        vm.start()

        while !vm.phase.isFinished {
            let question = vm.currentQuestion!
            let rightIndex = question.options.firstIndex(of: "RIGHT")!
            vm.submitAnswer(rightIndex)
            XCTAssertTrue(vm.phase.outcome?.isCorrect ?? false)
            vm.continueAfterReveal()
        }

        XCTAssertEqual(vm.standings.first?.score,
                       vm.totalQuestions * MatchScoring.correctAnswerPoints)
    }
}
