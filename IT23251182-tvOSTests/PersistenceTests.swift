//
//  PersistenceTests.swift
//  IT23251182-tvOSTests
//
//  Tests for local storage, settings, the leaderboard ranking rule, and the
//  behaviour of every store when the saved data is missing, empty or corrupt.
//

import XCTest
@testable import IT23251182_tvOS

// MARK: - Helpers

private func newSuite() -> (UserDefaults, String) {
    let name = "test." + UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (defaults, name)
}

private func makePlayer(_ name: String, seat: Int = 0, avatar: PlayerAvatar = .star) -> Player {
    Player(name: name, colorIndex: seat, avatar: avatar)
}

private func makeScore(_ name: String,
                       seat: Int = 0,
                       points: Int,
                       correct: Int = 0,
                       answered: Int = 5) -> PlayerScore {
    PlayerScore(player: makePlayer(name, seat: seat),
                score: points, correctCount: correct, answeredCount: answered)
}

private func makeMatch(_ scores: [PlayerScore],
                       playedAt: Date = Date(),
                       category: QuizCategory = .generalKnowledge) -> MatchResult {
    MatchResult(playedAt: playedAt,
                settings: QuizSettings(category: category, questionCount: 10),
                scores: scores)
}

// MARK: - Settings persistence

final class SettingsPersistenceTests: XCTestCase {

    func testDefaultsOnFirstLaunch() {
        let (defaults, _) = newSuite()
        let settings = AppSettings(defaults: defaults)

        XCTAssertFalse(settings.reduceMotion)
        XCTAssertTrue(settings.soundEffects, "Sound should be on until deliberately turned off")
        XCTAssertEqual(settings.questionDuration, .standard)
    }

    func testEverySettingSurvivesRelaunch() {
        let (defaults, _) = newSuite()

        let first = AppSettings(defaults: defaults)
        first.reduceMotion = true
        first.soundEffects = false
        first.questionDuration = .quick

        // A second instance over the same storage stands in for a relaunch.
        let second = AppSettings(defaults: defaults)

        XCTAssertTrue(second.reduceMotion)
        XCTAssertFalse(second.soundEffects)
        XCTAssertEqual(second.questionDuration, .quick)
    }

    func testSoundOffIsDistinguishedFromNeverSet() {
        // `bool(forKey:)` returns false for a missing key, which would make a
        // first launch look like "sound deliberately off".
        let (defaults, _) = newSuite()
        let first = AppSettings(defaults: defaults)
        first.soundEffects = false

        XCTAssertFalse(AppSettings(defaults: defaults).soundEffects)
    }

    func testCorruptedDurationFallsBackToTheDefault() {
        let (defaults, _) = newSuite()
        defaults.set("not-a-real-duration", forKey: "settings.questionDuration")

        XCTAssertEqual(AppSettings(defaults: defaults).questionDuration, .standard)
    }

    func testResetRestoresDefaults() {
        let (defaults, _) = newSuite()
        let settings = AppSettings(defaults: defaults)
        settings.reduceMotion = true
        settings.soundEffects = false
        settings.questionDuration = .relaxed

        settings.resetToDefaults()

        XCTAssertFalse(settings.reduceMotion)
        XCTAssertTrue(settings.soundEffects)
        XCTAssertEqual(settings.questionDuration, .standard)
    }
}

// MARK: - Question duration

final class QuestionDurationTests: XCTestCase {

    func testStandardMatchesTheBaseTimes() {
        for difficulty in Difficulty.allCases {
            XCTAssertEqual(QuestionDuration.standard.seconds(for: difficulty),
                           difficulty.baseTimeLimit)
        }
    }

    func testRelaxedAddsTime() {
        XCTAssertEqual(QuestionDuration.relaxed.seconds(for: .easy),
                       Difficulty.easy.baseTimeLimit + 10)
    }

    func testQuickRemovesTime() {
        XCTAssertEqual(QuestionDuration.quick.seconds(for: .hard),
                       Difficulty.hard.baseTimeLimit - 5)
    }

    func testQuickNeverGoesBelowTheFloor() {
        for difficulty in Difficulty.allCases {
            XCTAssertGreaterThanOrEqual(QuestionDuration.quick.seconds(for: difficulty),
                                        QuestionDuration.minimumSeconds)
        }
    }

    func testHarderQuestionsKeepMoreTimeAtEverySetting() {
        for duration in QuestionDuration.allCases {
            XCTAssertLessThan(duration.seconds(for: .easy), duration.seconds(for: .hard),
                              "\(duration.displayName) should preserve relative difficulty")
        }
    }
}

@MainActor
final class QuestionDurationAffectsGameplayTests: XCTestCase {

    private func engine(_ duration: QuestionDuration) -> QuizGameViewModel {
        let question = PreparedQuestion(source: Question(
            id: "q1", category: .generalKnowledge, difficulty: .medium,
            prompt: "P?", options: ["a", "b", "c", "d"], correctIndex: 0, explanation: nil))
        let session = GameSession(players: [makePlayer("A")],
                                  settings: QuizSettings(questionCount: 1),
                                  questions: [question])
        return QuizGameViewModel(session: session,
                                 questionDuration: duration,
                                 runsCountdown: false)
    }

    func testTheSettingChangesTheCountdown() {
        let relaxed = engine(.relaxed)
        let quick = engine(.quick)
        relaxed.start()
        quick.start()

        XCTAssertEqual(relaxed.remainingSeconds, Difficulty.medium.baseTimeLimit + 10)
        XCTAssertEqual(quick.remainingSeconds, Difficulty.medium.baseTimeLimit - 5)
        XCTAssertGreaterThan(relaxed.remainingSeconds, quick.remainingSeconds)
    }

    func testTimeoutHappensAfterTheConfiguredTime() {
        let quick = engine(.quick)
        quick.start()
        let limit = QuestionDuration.quick.seconds(for: .medium)

        for _ in 0..<(limit - 1) { quick.tick() }
        XCTAssertTrue(quick.phase.isAsking, "Should still be running one tick short")

        quick.tick()
        XCTAssertEqual(quick.phase.outcome, .timedOut)
    }
}

// MARK: - Sound

/// Records what the engine asked to play, without touching audio hardware.
private final class SoundSpy: SoundPlaying {
    private(set) var played: [SoundEffect] = []
    func play(_ effect: SoundEffect) { played.append(effect) }
}

@MainActor
final class SoundEffectTests: XCTestCase {

    private func engine(sounds: SoundPlaying?) -> QuizGameViewModel {
        let questions = (1...2).map { index in
            PreparedQuestion(source: Question(
                id: "q\(index)", category: .generalKnowledge, difficulty: .easy,
                prompt: "P?", options: ["RIGHT", "b", "c", "d"],
                correctIndex: 0, explanation: nil))
        }
        let session = GameSession(players: [makePlayer("A")],
                                  settings: QuizSettings(questionCount: 2),
                                  questions: questions)
        return QuizGameViewModel(session: session, sounds: sounds, runsCountdown: false)
    }

    func testCorrectAnswerPlaysTheCorrectSound() {
        let spy = SoundSpy()
        let vm = engine(sounds: spy)
        vm.start()
        vm.submitAnswer(0)

        XCTAssertEqual(spy.played, [.correct])
    }

    func testWrongAnswerAndTimeoutPlayTheirOwnSounds() {
        let spy = SoundSpy()
        let vm = engine(sounds: spy)
        vm.start()
        vm.submitAnswer(1)
        vm.continueAfterReveal()
        for _ in 0..<Difficulty.easy.baseTimeLimit { vm.tick() }

        XCTAssertEqual(spy.played, [.incorrect, .timeout])
    }

    func testRepeatedPressesPlayTheSoundOnce() {
        let spy = SoundSpy()
        let vm = engine(sounds: spy)
        vm.start()
        for _ in 0..<8 { vm.submitAnswer(0) }

        XCTAssertEqual(spy.played.count, 1)
    }

    func testEngineRunsWithoutASoundPlayer() {
        let vm = engine(sounds: nil)
        vm.start()
        vm.submitAnswer(0)
        XCTAssertTrue(vm.phase.isRevealing, "Sound must never be required for play")
    }

    func testGeneratedToneIsAValidWavFile() {
        let data = SoundEffectPlayer.waveform(for: .correct)

        XCTAssertGreaterThan(data.count, 44, "Should be a header plus samples")
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
    }
}

// MARK: - Storage safety

final class StorageSafetyTests: XCTestCase {

    func testMissingHistoryReadsAsEmpty() {
        let (defaults, _) = newSuite()
        XCTAssertTrue(MatchHistoryStore(defaults: defaults).load().isEmpty)
    }

    func testEmptyStoredDataReadsAsEmpty() {
        let (defaults, _) = newSuite()
        defaults.set(Data(), forKey: "history.matches")

        XCTAssertTrue(MatchHistoryStore(defaults: defaults).load().isEmpty)
    }

    func testCorruptedHistoryIsDiscardedSafely() {
        let (defaults, _) = newSuite()
        defaults.set(Data("this is not json".utf8), forKey: "history.matches")
        let store = MatchHistoryStore(defaults: defaults)

        XCTAssertTrue(store.load().isEmpty, "Unreadable data must not crash or throw")
        XCTAssertTrue(store.didDiscardCorruptedData)
    }

    func testCorruptedHistoryIsRemovedSoItCannotFailForever() {
        let (defaults, _) = newSuite()
        defaults.set(Data("broken".utf8), forKey: "history.matches")
        let store = MatchHistoryStore(defaults: defaults)
        _ = store.load()

        // The bad value is gone, and a new match saves normally afterwards.
        XCTAssertTrue(store.save(makeMatch([makeScore("A", points: 100, correct: 1)])))
        XCTAssertEqual(store.load().count, 1)
    }

    func testCorruptedRosterIsDiscardedSafely() {
        let (defaults, _) = newSuite()
        defaults.set(Data("not a roster".utf8), forKey: "roster.lastUsed")
        let store = PlayerRosterStore(defaults: defaults)

        XCTAssertTrue(store.load().isEmpty)
        store.save([makePlayer("A")])
        XCTAssertEqual(store.load().map(\.name), ["A"])
    }

    func testPartiallyValidJSONIsRejectedWholesale() {
        // JSON that parses but is not a [MatchResult].
        let (defaults, _) = newSuite()
        defaults.set(Data(#"{"unexpected": true}"#.utf8), forKey: "history.matches")

        XCTAssertTrue(MatchHistoryStore(defaults: defaults).load().isEmpty)
    }

    func testAbandonedRoundIsNeverStored() {
        // A result with no players is not a completed match.
        let (defaults, _) = newSuite()
        let store = MatchHistoryStore(defaults: defaults)

        XCTAssertFalse(store.save(MatchResult(settings: .standard, scores: [])))
        XCTAssertTrue(store.load().isEmpty)
    }
}

@MainActor
final class AbandonedMatchTests: XCTestCase {

    func testQuittingMidMatchProducesNoResultToSave() {
        let questions = (1...4).map { index in
            PreparedQuestion(source: Question(
                id: "q\(index)", category: .generalKnowledge, difficulty: .easy,
                prompt: "P?", options: ["RIGHT", "b", "c", "d"],
                correctIndex: 0, explanation: nil))
        }
        let session = GameSession(players: [makePlayer("A"), makePlayer("B", seat: 1)],
                                  settings: QuizSettings(questionCount: 4),
                                  questions: questions)
        let vm = QuizGameViewModel(session: session, runsCountdown: false)

        vm.start()
        vm.submitAnswer(0)
        vm.continueAfterReveal()
        vm.tearDown()        // the player backs out of the match

        XCTAssertNil(vm.finalResult, "An abandoned round must not produce a completed result")
        XCTAssertFalse(vm.phase.isFinished)
    }
}

// MARK: - Leaderboard ranking

final class LeaderboardRankingTests: XCTestCase {

    private func entry(_ name: String,
                       points: Int,
                       wins: Int = 0,
                       played: Int = 1,
                       correct: Int = 0,
                       answered: Int = 10) -> LeaderboardEntry {
        LeaderboardEntry(name: name, nameKey: name.lowercased(), avatar: .star, colorIndex: 0,
                         totalPoints: points, matchesPlayed: played, wins: wins,
                         totalCorrect: correct, totalAnswered: answered)
    }

    func testRanksByTotalPointsFirst() {
        let sorted = LeaderboardRanking.sorted([
            entry("Low", points: 100), entry("High", points: 900), entry("Mid", points: 500)
        ])
        XCTAssertEqual(sorted.map(\.name), ["High", "Mid", "Low"])
    }

    func testWinsBreakAPointsTie() {
        let sorted = LeaderboardRanking.sorted([
            entry("FewWins", points: 500, wins: 1), entry("ManyWins", points: 500, wins: 3)
        ])
        XCTAssertEqual(sorted.first?.name, "ManyWins")
    }

    func testAccuracyBreaksAPointsAndWinsTie() {
        let sorted = LeaderboardRanking.sorted([
            entry("Sloppy", points: 500, wins: 1, correct: 5, answered: 20),
            entry("Sharp", points: 500, wins: 1, correct: 5, answered: 10)
        ])
        XCTAssertEqual(sorted.first?.name, "Sharp")
    }

    func testFewerMatchesWinsWhenEverythingElseIsLevel() {
        let sorted = LeaderboardRanking.sorted([
            entry("Many", points: 500, wins: 1, played: 5, correct: 5, answered: 10),
            entry("Few", points: 500, wins: 1, played: 2, correct: 5, answered: 10)
        ])
        XCTAssertEqual(sorted.first?.name, "Few")
    }

    func testNameIsTheFinalDeterministicTiebreak() {
        let identicalA = entry("Zoe", points: 500, wins: 1, played: 2, correct: 5, answered: 10)
        let identicalB = entry("Amal", points: 500, wins: 1, played: 2, correct: 5, answered: 10)

        // Sorting the same pair either way round must give the same answer.
        XCTAssertEqual(LeaderboardRanking.sorted([identicalA, identicalB]).map(\.name), ["Amal", "Zoe"])
        XCTAssertEqual(LeaderboardRanking.sorted([identicalB, identicalA]).map(\.name), ["Amal", "Zoe"])
    }

    func testRankingIsStableAcrossRepeatedRuns() {
        let entries = (1...12).map { entry("P\($0)", points: 300, wins: 1, played: 2) }
        let first = LeaderboardRanking.sorted(entries).map(\.name)

        for _ in 0..<20 {
            XCTAssertEqual(LeaderboardRanking.sorted(entries.shuffled()).map(\.name), first,
                           "Order must not depend on input order or dictionary iteration")
        }
    }
}

final class LeaderboardAggregationTests: XCTestCase {

    func testAggregatesAcrossMatches() {
        let matches = [
            makeMatch([makeScore("Hiruna", points: 300, correct: 3, answered: 5),
                       makeScore("Nimal", seat: 1, points: 100, correct: 1, answered: 5)]),
            makeMatch([makeScore("Hiruna", points: 200, correct: 2, answered: 5),
                       makeScore("Nimal", seat: 1, points: 400, correct: 4, answered: 5)])
        ]

        let entries = LeaderboardRanking.entries(from: matches)
        let hiruna = entries.first { $0.name == "Hiruna" }

        XCTAssertEqual(hiruna?.totalPoints, 500)
        XCTAssertEqual(hiruna?.matchesPlayed, 2)
        XCTAssertEqual(hiruna?.totalCorrect, 5)
        XCTAssertEqual(hiruna?.accuracyPercent, 50)
    }

    func testWinsAreCounted() {
        let matches = [
            makeMatch([makeScore("A", points: 300, correct: 3), makeScore("B", seat: 1, points: 100, correct: 1)]),
            makeMatch([makeScore("A", points: 500, correct: 5), makeScore("B", seat: 1, points: 100, correct: 1)])
        ]

        let entries = LeaderboardRanking.entries(from: matches)
        XCTAssertEqual(entries.first { $0.name == "A" }?.wins, 2)
        XCTAssertEqual(entries.first { $0.name == "B" }?.wins, 0)
    }

    func testATiedMatchCountsAWinForEveryTiedPlayer() {
        let matches = [makeMatch([makeScore("A", points: 300, correct: 3),
                                  makeScore("B", seat: 1, points: 300, correct: 3)])]

        let entries = LeaderboardRanking.entries(from: matches)
        XCTAssertEqual(entries.first { $0.name == "A" }?.wins, 1)
        XCTAssertEqual(entries.first { $0.name == "B" }?.wins, 1)
    }

    func testSamePlayerIsGroupedRegardlessOfCase() {
        // Player ids are regenerated each match, so grouping is by name.
        let matches = [
            makeMatch([makeScore("Hiruna", points: 300, correct: 3)]),
            makeMatch([makeScore(" hiruna ", points: 200, correct: 2)])
        ]

        let entries = LeaderboardRanking.entries(from: matches)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].totalPoints, 500)
        XCTAssertEqual(entries[0].matchesPlayed, 2)
    }

    func testEmptyHistoryProducesNoEntries() {
        XCTAssertTrue(LeaderboardRanking.entries(from: []).isEmpty)
    }
}

// MARK: - Leaderboard view model

final class LeaderboardViewModelTests: XCTestCase {

    func testStartsEmptyWithNoSavedMatches() {
        let (defaults, _) = newSuite()
        let vm = LeaderboardViewModel(store: MatchHistoryStore(defaults: defaults))

        XCTAssertTrue(vm.isEmpty)
        XCTAssertTrue(vm.entries.isEmpty)
    }

    func testReloadPicksUpAMatchFinishedAfterwards() {
        let (defaults, _) = newSuite()
        let store = MatchHistoryStore(defaults: defaults)
        let vm = LeaderboardViewModel(store: store)
        XCTAssertTrue(vm.isEmpty)

        store.save(makeMatch([makeScore("A", points: 300, correct: 3)]))
        vm.reload()

        XCTAssertFalse(vm.isEmpty)
        XCTAssertEqual(vm.leaderName, "A")
    }

    func testClearHistoryEmptiesEverything() {
        let (defaults, _) = newSuite()
        let store = MatchHistoryStore(defaults: defaults)
        store.save(makeMatch([makeScore("A", points: 300, correct: 3)]))
        store.save(makeMatch([makeScore("B", points: 100, correct: 1)]))

        let vm = LeaderboardViewModel(store: store)
        XCTAssertEqual(vm.matches.count, 2)

        vm.clearHistory()

        XCTAssertTrue(vm.isEmpty)
        XCTAssertTrue(vm.entries.isEmpty)
        XCTAssertTrue(store.load().isEmpty, "Clearing must remove the stored data, not just the view")
    }

    func testHistorySurvivesARelaunch() {
        let (defaults, _) = newSuite()
        MatchHistoryStore(defaults: defaults).save(makeMatch([makeScore("A", points: 300, correct: 3)]))

        // A fresh store and view model over the same storage.
        let reopened = LeaderboardViewModel(store: MatchHistoryStore(defaults: defaults))

        XCTAssertEqual(reopened.matches.count, 1)
        XCTAssertEqual(reopened.entries.first?.name, "A")
    }

    func testMatchCountLabelIsSingularForOne() {
        let (defaults, _) = newSuite()
        let store = MatchHistoryStore(defaults: defaults)
        store.save(makeMatch([makeScore("A", points: 100, correct: 1)]))

        XCTAssertTrue(LeaderboardViewModel(store: store).matchCountLabel.contains("1 match played"))
    }
}
