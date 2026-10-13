//
//  ModelTests.swift
//  IT23251182-tvOSTests
//
//  Tests for Player, QuizSettings and MatchResult.
//

import XCTest
@testable import IT23251182_tvOS

final class PlayerTests: XCTestCase {

    func testValidName() {
        XCTAssertTrue(Player(name: "Chandare", colorIndex: 0).hasValidName)
    }

    func testBlankNameIsInvalid() {
        XCTAssertFalse(Player(name: "   ", colorIndex: 0).hasValidName)
        XCTAssertFalse(Player(name: "", colorIndex: 0).hasValidName)
    }

    func testOverlongNameIsInvalid() {
        let long = String(repeating: "a", count: Player.maximumNameLength + 1)
        XCTAssertFalse(Player(name: long, colorIndex: 0).hasValidName)
    }

    func testNameAtLimitIsValid() {
        let exact = String(repeating: "a", count: Player.maximumNameLength)
        XCTAssertTrue(Player(name: exact, colorIndex: 0).hasValidName)
    }

    func testTrimmedNameStripsWhitespace() {
        XCTAssertEqual(Player(name: "  Nimal \n", colorIndex: 1).trimmedName, "Nimal")
    }

    func testPlayersWithSameNameAreDistinctIdentities() {
        // Two people may genuinely choose the same name; identity is the UUID.
        let a = Player(name: "Sam", colorIndex: 0)
        let b = Player(name: "Sam", colorIndex: 1)
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertNotEqual(a, b)
    }

    func testDefaultSeatName() {
        XCTAssertEqual(Player.defaultName(forSeat: 3), "Player 3")
    }
}

final class QuizSettingsTests: XCTestCase {

    private func question(_ category: QuizCategory, _ difficulty: Difficulty) -> Question {
        Question(id: "q", category: category, difficulty: difficulty,
                 prompt: "P?", options: ["A", "B", "C", "D"],
                 correctIndex: 0, explanation: nil)
    }

    func testDefaultsToMixedCategoryAndAllDifficulties() {
        let settings = QuizSettings()
        XCTAssertNil(settings.category)
        XCTAssertTrue(settings.includesAllDifficulties)
        XCTAssertEqual(settings.questionCount, QuizSettings.defaultQuestionCount)
        XCTAssertEqual(settings.categoryDisplayName, "Mixed Categories")
    }

    func testEmptyDifficultySetIsTreatedAsNoFilter() {
        // A settings bug must not produce a match with zero playable questions.
        let settings = QuizSettings(difficulties: [])
        XCTAssertEqual(settings.effectiveDifficulties, Set(Difficulty.allCases))
        XCTAssertTrue(settings.matches(question(.generalKnowledge, .hard)))
    }

    func testQuestionCountIsClampedToMinimum() {
        XCTAssertEqual(QuizSettings(questionCount: 0).questionCount, QuizSettings.minimumQuestionCount)
        XCTAssertEqual(QuizSettings(questionCount: -5).questionCount, QuizSettings.minimumQuestionCount)
    }

    func testMatchesRespectsCategory() {
        let settings = QuizSettings(category: .sportsAndCricket)
        XCTAssertTrue(settings.matches(question(.sportsAndCricket, .easy)))
        XCTAssertFalse(settings.matches(question(.scienceAndNature, .easy)))
    }

    func testMatchesRespectsDifficulty() {
        let settings = QuizSettings(difficulties: [.hard])
        XCTAssertTrue(settings.matches(question(.generalKnowledge, .hard)))
        XCTAssertFalse(settings.matches(question(.generalKnowledge, .easy)))
    }

    func testIsCodableRoundTrip() throws {
        let original = QuizSettings(category: .moviesAndEntertainment,
                                    difficulties: [.easy, .hard],
                                    questionCount: 15)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(QuizSettings.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

final class MatchResultTests: XCTestCase {

    private func score(_ name: String, _ points: Int, correct: Int = 0, answered: Int = 10) -> PlayerScore {
        PlayerScore(player: Player(name: name, colorIndex: 0),
                    score: points, correctCount: correct, answeredCount: answered)
    }

    func testRankingSortsByScoreDescending() {
        let result = MatchResult(settings: .standard,
                                 scores: [score("Low", 100), score("High", 900), score("Mid", 500)])

        XCTAssertEqual(result.ranking.map(\.player.name), ["High", "Mid", "Low"])
    }

    func testRankingBreaksScoreTiesByCorrectCount() {
        let result = MatchResult(settings: .standard,
                                 scores: [score("Fewer", 600, correct: 2),
                                          score("More", 600, correct: 5)])

        XCTAssertEqual(result.ranking.first?.player.name, "More")
    }

    func testWinnerIsHighestScorer() {
        let result = MatchResult(settings: .standard,
                                 scores: [score("A", 300), score("B", 800)])

        XCTAssertEqual(result.winners.map(\.player.name), ["B"])
        XCTAssertFalse(result.isDraw)
    }

    func testDrawReportsEveryTiedPlayer() {
        // The results screen must be able to say "it's a tie" rather than
        // picking an arbitrary winner.
        let result = MatchResult(settings: .standard,
                                 scores: [score("A", 700, correct: 3),
                                          score("B", 700, correct: 3),
                                          score("C", 100)])

        XCTAssertTrue(result.isDraw)
        XCTAssertEqual(Set(result.winners.map(\.player.name)), ["A", "B"])
    }

    func testEmptyScoresHaveNoWinner() {
        let result = MatchResult(settings: .standard, scores: [])
        XCTAssertTrue(result.winners.isEmpty)
        XCTAssertFalse(result.isDraw)
    }

    func testAccuracyIsCorrectFraction() {
        XCTAssertEqual(score("A", 0, correct: 5, answered: 10).accuracy, 0.5, accuracy: 0.0001)
    }

    func testAccuracyIsZeroWhenNothingAnswered() {
        // Guards against dividing by zero if a match is abandoned immediately.
        XCTAssertEqual(score("A", 0, correct: 0, answered: 0).accuracy, 0)
    }

    func testIsCodableRoundTrip() throws {
        let original = MatchResult(settings: QuizSettings(category: .sriLankanCulture),
                                   scores: [score("A", 400, correct: 2), score("B", 100)])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MatchResult.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

final class DifficultyTests: XCTestCase {

    func testPointsIncreaseWithDifficulty() {
        XCTAssertLessThan(Difficulty.easy.basePoints, Difficulty.medium.basePoints)
        XCTAssertLessThan(Difficulty.medium.basePoints, Difficulty.hard.basePoints)
    }

    func testTimeLimitIncreasesWithDifficulty() {
        XCTAssertLessThan(Difficulty.easy.timeLimit, Difficulty.medium.timeLimit)
        XCTAssertLessThan(Difficulty.medium.timeLimit, Difficulty.hard.timeLimit)
    }

    func testIsSortableEasiestFirst() {
        XCTAssertEqual([Difficulty.hard, .easy, .medium].sorted(), [.easy, .medium, .hard])
    }
}
