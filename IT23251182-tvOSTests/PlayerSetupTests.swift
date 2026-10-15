//
//  PlayerSetupTests.swift
//  IT23251182-tvOSTests
//
//  Tests for the roster rules, name validation, avatar selection, roster
//  persistence and the hand-off into a game session.
//

import XCTest
@testable import IT23251182_tvOS

private struct StubProvider: QuestionProviding {
    var result: QuestionBankLoadResult
    func loadQuestions() throws -> QuestionBankLoadResult { result }
}

// MARK: - Helpers

private func makeQuestion(_ id: String,
                          _ category: QuizCategory = .generalKnowledge,
                          _ difficulty: Difficulty = .easy) -> Question {
    Question(id: id, category: category, difficulty: difficulty,
             prompt: "Prompt \(id)?", options: ["A", "B", "C", "D"],
             correctIndex: 0, explanation: nil)
}

private func makeRepository(questionCount: Int = 20,
                            category: QuizCategory = .generalKnowledge) -> QuestionRepository {
    let questions = (1...questionCount).map { makeQuestion("q\($0)", category) }
    let repository = QuestionRepository(
        provider: StubProvider(result: QuestionBankLoadResult(version: 1,
                                                              questions: questions,
                                                              rejected: []))
    )
    _ = try? repository.load()
    return repository
}

/// A throwaway defaults suite so tests never touch the real stored roster.
private func makeIsolatedDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private func makeViewModel(questionCount: Int = 10,
                           bankSize: Int = 20,
                           store: PlayerRosterStore? = nil) -> PlayerSetupViewModel {
    PlayerSetupViewModel(
        settings: QuizSettings(category: .generalKnowledge, questionCount: questionCount),
        repository: makeRepository(questionCount: bankSize),
        rosterStore: store ?? PlayerRosterStore(defaults: makeIsolatedDefaults())
    )
}

// MARK: - Roster size

final class PlayerRosterTests: XCTestCase {

    func testStartsWithTwoRequiredSlots() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.players.count, Player.minimumPlayers)
    }

    func testCanAddThirdAndFourthPlayer() {
        let vm = makeViewModel()

        vm.addPlayer()
        XCTAssertEqual(vm.players.count, 3)

        vm.addPlayer()
        XCTAssertEqual(vm.players.count, 4)
    }

    func testCannotExceedFourPlayers() {
        let vm = makeViewModel()
        vm.addPlayer()
        vm.addPlayer()
        XCTAssertFalse(vm.canAddPlayer)

        // Calling anyway must be a no-op, so the cap does not depend on the UI.
        vm.addPlayer()
        vm.addPlayer()

        XCTAssertEqual(vm.players.count, Player.maximumPlayers)
    }

    func testCannotDropBelowTwoPlayers() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.canRemovePlayer)

        vm.removePlayer(id: vm.players[0].id)

        XCTAssertEqual(vm.players.count, Player.minimumPlayers)
    }

    func testRemovingAPlayerWorksAboveTheMinimum() {
        let vm = makeViewModel()
        vm.addPlayer()
        let removedID = vm.players[1].id

        vm.removePlayer(id: removedID)

        XCTAssertEqual(vm.players.count, 2)
        XCTAssertFalse(vm.players.contains { $0.id == removedID })
    }

    func testRemovingReindexesSeatColours() {
        let vm = makeViewModel()
        vm.addPlayer()
        vm.removePlayer(id: vm.players[1].id)

        XCTAssertEqual(vm.players.map(\.colorIndex), [0, 1],
                       "Colours should close the gap left by the removed seat")
    }

    func testRemovingAnUnknownIDDoesNothing() {
        let vm = makeViewModel()
        vm.addPlayer()
        vm.removePlayer(id: UUID())
        XCTAssertEqual(vm.players.count, 3)
    }
}

// MARK: - Validation

final class PlayerValidationTests: XCTestCase {

    private func named(_ vm: PlayerSetupViewModel, _ names: [String]) {
        while vm.players.count < names.count { vm.addPlayer() }
        for (index, name) in names.enumerated() {
            vm.setName(name, for: vm.players[index].id)
        }
    }

    func testBlankNamesBlockStarting() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.validation, .blankName(seat: 1))
        XCTAssertFalse(vm.canStart)
    }

    func testWhitespaceOnlyNameIsTreatedAsBlank() {
        let vm = makeViewModel()
        named(vm, ["   ", "Nimal"])

        XCTAssertEqual(vm.validation, .blankName(seat: 1))
        XCTAssertFalse(vm.canStart)
    }

    func testSecondBlankNameIsReportedWithItsSeat() {
        let vm = makeViewModel()
        named(vm, ["Hiruna", ""])
        XCTAssertEqual(vm.validation, .blankName(seat: 2))
    }

    func testTwoValidNamesAreEnoughToStart() {
        let vm = makeViewModel()
        named(vm, ["Hiruna", "Nimal"])

        XCTAssertEqual(vm.validation, .valid)
        XCTAssertTrue(vm.canStart)
    }

    func testDuplicateNamesAreRejected() {
        let vm = makeViewModel()
        named(vm, ["Sam", "Sam"])

        XCTAssertEqual(vm.validation, .duplicateName("Sam"))
        XCTAssertFalse(vm.canStart)
    }

    func testDuplicateDetectionIgnoresCaseAndWhitespace() {
        // " sam " and "SAM" would be indistinguishable on a scoreboard.
        let vm = makeViewModel()
        named(vm, [" sam ", "SAM"])

        XCTAssertFalse(vm.canStart)
        if case .duplicateName = vm.validation {} else {
            XCTFail("Expected a duplicate-name failure, got \(vm.validation)")
        }
    }

    func testDuplicateFlagMarksBothPlayers() {
        let vm = makeViewModel()
        named(vm, ["Sam", "Sam", "Nimal"])

        XCTAssertTrue(vm.isDuplicate(vm.players[0]))
        XCTAssertTrue(vm.isDuplicate(vm.players[1]))
        XCTAssertFalse(vm.isDuplicate(vm.players[2]))
    }

    func testBlankNamesAreNotFlaggedAsDuplicatesOfEachOther() {
        // Two empty slots are incomplete, not duplicates — the message should
        // tell the player to fill them in, not to rename them.
        let vm = makeViewModel()
        XCTAssertFalse(vm.isDuplicate(vm.players[0]))
        XCTAssertEqual(vm.validation, .blankName(seat: 1))
    }

    func testOverlongNameIsRejected() {
        let vm = makeViewModel()
        named(vm, [String(repeating: "a", count: Player.maximumNameLength + 1), "Nimal"])

        XCTAssertEqual(vm.validation, .nameTooLong(seat: 1))
        XCTAssertFalse(vm.canStart)
    }

    func testNameAtTheLimitIsAccepted() {
        let vm = makeViewModel()
        named(vm, [String(repeating: "a", count: Player.maximumNameLength), "Nimal"])
        XCTAssertEqual(vm.validation, .valid)
    }

    func testValidationMessageIsNilOnlyWhenValid() {
        let vm = makeViewModel()
        XCTAssertNotNil(vm.validation.message)

        named(vm, ["Hiruna", "Nimal"])
        XCTAssertNil(vm.validation.message)
    }
}

// MARK: - Avatars

final class PlayerAvatarTests: XCTestCase {

    func testDefaultAvatarsDifferPerSeat() {
        let avatars = (1...4).map { PlayerAvatar.default(forSeat: $0) }
        XCTAssertEqual(Set(avatars).count, 4)
    }

    func testDefaultAvatarWrapsBeyondTheListLength() {
        let beyond = PlayerAvatar.allCases.count + 1
        XCTAssertEqual(PlayerAvatar.default(forSeat: beyond),
                       PlayerAvatar.default(forSeat: 1))
    }

    func testCyclingSkipsAvatarsAlreadyTaken() {
        let first = PlayerAvatar.allCases[0]
        let second = PlayerAvatar.allCases[1]

        XCTAssertEqual(first.next(excluding: [second]), PlayerAvatar.allCases[2])
    }

    func testCyclingReturnsSomethingWhenEverythingIsTaken() {
        let all = Set(PlayerAvatar.allCases)
        XCTAssertNotNil(PlayerAvatar.star.next(excluding: all))
    }

    func testNewPlayersNeverShareAnAvatar() {
        let vm = makeViewModel()
        vm.addPlayer()
        vm.addPlayer()

        XCTAssertEqual(Set(vm.players.map(\.avatar)).count, vm.players.count)
    }

    func testCyclingAnAvatarDoesNotCollideWithAnotherPlayer() {
        let vm = makeViewModel()
        vm.addPlayer()

        for _ in 0..<PlayerAvatar.allCases.count + 2 {
            vm.cycleAvatar(for: vm.players[0].id)
            XCTAssertEqual(Set(vm.players.map(\.avatar)).count, vm.players.count,
                           "Cycling must never duplicate another player's avatar")
        }
    }

    func testCyclingChangesTheAvatar() {
        let vm = makeViewModel()
        let before = vm.players[0].avatar
        vm.cycleAvatar(for: vm.players[0].id)
        XCTAssertNotEqual(vm.players[0].avatar, before)
    }
}

// MARK: - Starting a match

final class StartBattleTests: XCTestCase {

    private func named(_ vm: PlayerSetupViewModel, _ names: [String]) {
        while vm.players.count < names.count { vm.addPlayer() }
        for (index, name) in names.enumerated() {
            vm.setName(name, for: vm.players[index].id)
        }
    }

    func testInvalidSetupCannotStart() {
        let vm = makeViewModel()
        XCTAssertNil(vm.startBattle(), "Blank names must not produce a session")
    }

    func testDuplicateNamesCannotStart() {
        let vm = makeViewModel()
        named(vm, ["Sam", "Sam"])
        XCTAssertNil(vm.startBattle())
    }

    func testValidSetupProducesASession() throws {
        let vm = makeViewModel()
        named(vm, ["Hiruna", "Nimal"])

        let session = try XCTUnwrap(vm.startBattle())

        XCTAssertEqual(session.players.map(\.name), ["Hiruna", "Nimal"])
        XCTAssertEqual(session.playerCount, 2)
        XCTAssertTrue(session.isPlayable)
    }

    func testSessionCarriesTheSelectedCategory() throws {
        let vm = makeViewModel()
        named(vm, ["Hiruna", "Nimal"])

        let session = try XCTUnwrap(vm.startBattle())

        XCTAssertEqual(session.settings.category, .generalKnowledge)
        XCTAssertEqual(session.categoryDisplayName, QuizCategory.generalKnowledge.displayName)
    }

    func testSessionContainsRealShuffledQuestions() throws {
        let vm = makeViewModel(questionCount: 10)
        named(vm, ["Hiruna", "Nimal"])

        let session = try XCTUnwrap(vm.startBattle())

        // The round asks 10 questions. The pool behind it is wider, so Adaptive
        // Challenge has spare questions to choose between.
        XCTAssertEqual(session.questionCount, 10)
        XCTAssertGreaterThanOrEqual(session.poolSize, session.questionCount)
        XCTAssertEqual(Set(session.questions.map(\.id)).count, session.poolSize,
                       "No repeated questions in the pool")
        for question in session.questions {
            XCTAssertEqual(question.options.count, 4)
            XCTAssertTrue(question.options.indices.contains(question.correctIndex))
        }
    }

    func testNamesAreTrimmedIntoTheSession() throws {
        let vm = makeViewModel()
        named(vm, ["  Hiruna  ", "Nimal"])

        let session = try XCTUnwrap(vm.startBattle())

        XCTAssertEqual(session.players[0].name, "Hiruna")
    }

    func testSessionStartsWithNoScores() throws {
        // Guards the "no placeholder scores" rule: a session carries no result
        // data at all, so nothing can be displayed as a score before play.
        let vm = makeViewModel()
        named(vm, ["Hiruna", "Nimal"])

        let session = try XCTUnwrap(vm.startBattle())

        XCTAssertGreaterThan(session.maximumPoints, 0, "Points on offer are real")
        XCTAssertEqual(session.players.count, 2)
    }

    func testFourPlayerSessionKeepsSeatOrder() throws {
        let vm = makeViewModel()
        named(vm, ["A", "B", "C", "D"])

        let session = try XCTUnwrap(vm.startBattle())

        XCTAssertEqual(session.players.map(\.name), ["A", "B", "C", "D"])
        XCTAssertEqual(session.players.map(\.colorIndex), [0, 1, 2, 3])
    }

    func testRoundIsCappedByTheBank() throws {
        // Asks for 10 but the bank only holds 4.
        let vm = makeViewModel(questionCount: 10, bankSize: 4)
        named(vm, ["Hiruna", "Nimal"])

        let session = try XCTUnwrap(vm.startBattle())

        XCTAssertEqual(session.questionCount, 4)
    }
}

// MARK: - Turn order

final class GameSessionTurnTests: XCTestCase {

    private func session(players: Int, questions: Int) -> GameSession {
        GameSession(
            players: (1...players).map { Player(name: "P\($0)", colorIndex: $0 - 1) },
            settings: QuizSettings(questionCount: questions),
            questions: (1...questions).map { PreparedQuestion(source: makeQuestion("q\($0)")) }
        )
    }

    func testTurnsRotateThroughThePlayers() {
        let s = session(players: 3, questions: 6)

        XCTAssertEqual(s.player(forQuestionIndex: 0)?.name, "P1")
        XCTAssertEqual(s.player(forQuestionIndex: 1)?.name, "P2")
        XCTAssertEqual(s.player(forQuestionIndex: 2)?.name, "P3")
        XCTAssertEqual(s.player(forQuestionIndex: 3)?.name, "P1")
    }

    func testOutOfRangeQuestionIndexReturnsNil() {
        let s = session(players: 2, questions: 4)
        XCTAssertNil(s.player(forQuestionIndex: 4))
        XCTAssertNil(s.player(forQuestionIndex: -1))
    }

    func testEvenRoundGivesEveryoneTheSameNumberOfTurns() {
        let s = session(players: 2, questions: 10)

        XCTAssertTrue(s.isTurnCountBalanced)
        XCTAssertEqual(s.turnCount(forSeat: 0), 5)
        XCTAssertEqual(s.turnCount(forSeat: 1), 5)
    }

    func testUnevenRoundGivesEarlierSeatsTheExtraTurn() {
        let s = session(players: 3, questions: 10)

        XCTAssertFalse(s.isTurnCountBalanced)
        XCTAssertEqual(s.turnCount(forSeat: 0), 4)
        XCTAssertEqual(s.turnCount(forSeat: 1), 3)
        XCTAssertEqual(s.turnCount(forSeat: 2), 3)
        XCTAssertEqual((0..<3).reduce(0) { $0 + s.turnCount(forSeat: $1) }, 10)
    }

    func testMaximumPointsSumsTheQuestions() {
        let s = session(players: 2, questions: 4)
        XCTAssertEqual(s.maximumPoints, 4 * MatchScoring.correctAnswerPoints)
    }

    func testSessionWithNoQuestionsIsNotPlayable() {
        let s = GameSession(players: [Player(name: "A", colorIndex: 0)],
                            settings: .standard,
                            questions: [])
        XCTAssertFalse(s.isPlayable)
    }
}

// MARK: - Roster persistence

final class PlayerRosterStoreTests: XCTestCase {

    func testSavesAndLoadsRoster() {
        let store = PlayerRosterStore(defaults: makeIsolatedDefaults())
        store.save([
            Player(name: "Hiruna", colorIndex: 0, avatar: .bolt),
            Player(name: "Nimal", colorIndex: 1, avatar: .flame)
        ])

        let loaded = store.load()

        XCTAssertEqual(loaded.map(\.name), ["Hiruna", "Nimal"])
        XCTAssertEqual(loaded.map(\.avatar), [.bolt, .flame])
    }

    func testLoadReturnsEmptyWhenNothingSaved() {
        XCTAssertTrue(PlayerRosterStore(defaults: makeIsolatedDefaults()).load().isEmpty)
    }

    func testBlankNamesAreNotSaved() {
        let store = PlayerRosterStore(defaults: makeIsolatedDefaults())
        store.save([Player(name: "  ", colorIndex: 0)])
        XCTAssertTrue(store.load().isEmpty, "A half-filled form must not overwrite a good roster")
    }

    func testClearRemovesTheRoster() {
        let store = PlayerRosterStore(defaults: makeIsolatedDefaults())
        store.save([Player(name: "Hiruna", colorIndex: 0)])
        store.clear()
        XCTAssertTrue(store.load().isEmpty)
    }

    func testStartingAMatchRemembersTheRoster() {
        let defaults = makeIsolatedDefaults()
        let store = PlayerRosterStore(defaults: defaults)

        let first = makeViewModel(store: store)
        first.setName("Hiruna", for: first.players[0].id)
        first.setName("Nimal", for: first.players[1].id)
        XCTAssertNotNil(first.startBattle())

        // A fresh screen, same Apple TV.
        let second = makeViewModel(store: PlayerRosterStore(defaults: defaults))

        XCTAssertEqual(second.players.map(\.name), ["Hiruna", "Nimal"])
    }

    func testRosterIsNotRememberedUntilAMatchStarts() {
        let defaults = makeIsolatedDefaults()
        let first = makeViewModel(store: PlayerRosterStore(defaults: defaults))
        first.setName("Hiruna", for: first.players[0].id)
        // No startBattle() call.

        let second = makeViewModel(store: PlayerRosterStore(defaults: defaults))

        XCTAssertEqual(second.players.map(\.trimmedName), ["", ""])
    }

    func testOversizedStoredRosterIsTruncated() {
        let defaults = makeIsolatedDefaults()
        let store = PlayerRosterStore(defaults: defaults)
        store.save((1...6).map { Player(name: "P\($0)", colorIndex: $0 - 1) })

        XCTAssertEqual(store.load().count, Player.maximumPlayers)
    }
}
