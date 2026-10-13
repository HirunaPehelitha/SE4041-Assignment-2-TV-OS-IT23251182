//
//  QuestionRepositoryTests.swift
//  IT23251182-tvOSTests
//
//  Tests for filtering, counting and match-set construction.
//

import XCTest
@testable import IT23251182_tvOS

/// A provider that returns a fixed in-memory bank, so repository behaviour can
/// be tested without the app bundle.
private struct StubProvider: QuestionProviding {
    var result: QuestionBankLoadResult
    var error: QuestionBankError?

    func loadQuestions() throws -> QuestionBankLoadResult {
        if let error { throw error }
        return result
    }
}

final class QuestionRepositoryTests: XCTestCase {

    // MARK: Fixtures

    private func question(_ id: String,
                          _ category: QuizCategory,
                          _ difficulty: Difficulty) -> Question {
        Question(id: id,
                 category: category,
                 difficulty: difficulty,
                 prompt: "Prompt \(id)?",
                 options: ["\(id)-A", "\(id)-B", "\(id)-C", "\(id)-D"],
                 correctIndex: 1,
                 explanation: nil)
    }

    private func makeRepository(_ questions: [Question],
                                version: Int = 1) throws -> QuestionRepository {
        let provider = StubProvider(
            result: QuestionBankLoadResult(version: version, questions: questions, rejected: []),
            error: nil
        )
        let repository = QuestionRepository(provider: provider)
        try repository.load()
        return repository
    }

    private var sampleQuestions: [Question] {
        [
            question("s1", .scienceAndNature, .easy),
            question("s2", .scienceAndNature, .medium),
            question("s3", .scienceAndNature, .hard),
            question("c1", .sriLankanCulture, .easy),
            question("c2", .sriLankanCulture, .easy),
            question("k1", .sportsAndCricket, .hard)
        ]
    }

    // MARK: Loading

    func testLoadPopulatesRepository() throws {
        let repository = try makeRepository(sampleQuestions, version: 7)

        XCTAssertTrue(repository.isLoaded)
        XCTAssertEqual(repository.version, 7)
        XCTAssertEqual(repository.allQuestions.count, 6)
    }

    func testLoadPropagatesMissingResourceError() {
        let provider = StubProvider(result: .empty,
                                    error: .resourceMissing(name: "questions"))
        let repository = QuestionRepository(provider: provider)

        XCTAssertThrowsError(try repository.load()) { error in
            XCTAssertEqual(error as? QuestionBankError, .resourceMissing(name: "questions"))
        }
        XCTAssertFalse(repository.isLoaded)
    }

    // MARK: Category filtering

    func testQuestionsInCategory() throws {
        let repository = try makeRepository(sampleQuestions)

        XCTAssertEqual(repository.questions(in: .scienceAndNature).map(\.id), ["s1", "s2", "s3"])
        XCTAssertEqual(repository.questions(in: .sriLankanCulture).map(\.id), ["c1", "c2"])
        XCTAssertTrue(repository.questions(in: .generalKnowledge).isEmpty)
    }

    func testQuestionsInCategoryAndDifficulty() throws {
        let repository = try makeRepository(sampleQuestions)

        XCTAssertEqual(repository.questions(in: .sriLankanCulture, difficulty: .easy).count, 2)
        XCTAssertEqual(repository.questions(in: .sriLankanCulture, difficulty: .hard).count, 0)
        XCTAssertEqual(repository.count(in: .scienceAndNature, difficulty: .medium), 1)
    }

    func testAvailableCategoriesExcludesEmptyOnes() throws {
        let repository = try makeRepository(sampleQuestions)

        // Only three of the five categories have questions in this stub bank.
        XCTAssertEqual(repository.availableCategories,
                       [.sriLankanCulture, .sportsAndCricket, .scienceAndNature])
        XCTAssertFalse(repository.availableCategories.contains(.generalKnowledge))
    }

    func testMaximumPointsUsesDifficultyValues() throws {
        let repository = try makeRepository(sampleQuestions)

        // science: easy 100 + medium 200 + hard 300
        XCTAssertEqual(repository.maximumPoints(in: .scienceAndNature), 600)
        // culture: two easy questions
        XCTAssertEqual(repository.maximumPoints(in: .sriLankanCulture), 200)
    }

    // MARK: Settings filtering

    func testSettingsFilterByCategory() throws {
        let repository = try makeRepository(sampleQuestions)
        let settings = QuizSettings(category: .scienceAndNature)

        XCTAssertEqual(repository.questions(matching: settings).map(\.id), ["s1", "s2", "s3"])
    }

    func testSettingsFilterByDifficulty() throws {
        let repository = try makeRepository(sampleQuestions)
        let settings = QuizSettings(category: nil, difficulties: [.easy])

        XCTAssertEqual(Set(repository.questions(matching: settings).map(\.id)),
                       ["s1", "c1", "c2"])
    }

    func testSettingsFilterByCategoryAndDifficultyCombined() throws {
        let repository = try makeRepository(sampleQuestions)
        let settings = QuizSettings(category: .scienceAndNature, difficulties: [.medium, .hard])

        XCTAssertEqual(Set(repository.questions(matching: settings).map(\.id)), ["s2", "s3"])
    }

    func testNilCategoryMeansMixedRound() throws {
        let repository = try makeRepository(sampleQuestions)
        let settings = QuizSettings(category: nil)

        XCTAssertEqual(repository.questions(matching: settings).count, 6)
    }

    // MARK: Building a match

    func testQuestionSetIsTrimmedToRequestedCount() throws {
        let repository = try makeRepository(sampleQuestions)
        var rng = SeededRandomNumberGenerator(seed: 42)
        let settings = QuizSettings(category: nil, questionCount: 4)

        let set = repository.makeQuestionSet(for: settings, using: &rng)

        XCTAssertEqual(set.count, 4)
    }

    func testQuestionSetReturnsFewerWhenFilterIsNarrow() throws {
        let repository = try makeRepository(sampleQuestions)
        var rng = SeededRandomNumberGenerator(seed: 1)
        // Only two questions match, but ten were requested.
        let settings = QuizSettings(category: .sriLankanCulture, questionCount: 10)

        let set = repository.makeQuestionSet(for: settings, using: &rng)

        XCTAssertEqual(set.count, 2, "Should return what exists rather than padding with repeats")
    }

    func testQuestionSetNeverRepeatsAQuestion() throws {
        let repository = try makeRepository(sampleQuestions)
        var rng = SeededRandomNumberGenerator(seed: 99)
        let settings = QuizSettings(category: nil, questionCount: 6)

        let set = repository.makeQuestionSet(for: settings, using: &rng)

        XCTAssertEqual(Set(set.map(\.id)).count, set.count)
    }

    func testQuestionSetRespectsSettingsFilter() throws {
        let repository = try makeRepository(sampleQuestions)
        var rng = SeededRandomNumberGenerator(seed: 5)
        let settings = QuizSettings(category: .scienceAndNature, difficulties: [.hard], questionCount: 10)

        let set = repository.makeQuestionSet(for: settings, using: &rng)

        XCTAssertEqual(set.map(\.id), ["s3"])
        XCTAssertTrue(set.allSatisfy { $0.difficulty == .hard })
    }

    // MARK: Shuffling

    func testSameSeedProducesSameOrder() throws {
        let repository = try makeRepository(sampleQuestions)
        let settings = QuizSettings(category: nil, questionCount: 6)

        var rngA = SeededRandomNumberGenerator(seed: 2024)
        var rngB = SeededRandomNumberGenerator(seed: 2024)

        let first = repository.makeQuestionSet(for: settings, using: &rngA).map(\.id)
        let second = repository.makeQuestionSet(for: settings, using: &rngB).map(\.id)

        XCTAssertEqual(first, second, "A seeded generator must be reproducible")
    }

    func testQuestionOrderIsActuallyShuffled() throws {
        // Build a larger bank so that matching the original order by chance is
        // vanishingly unlikely, then assert at least one seed reorders it.
        let many = (1...20).map { question("q\($0)", .generalKnowledge, .easy) }
        let repository = try makeRepository(many)
        let settings = QuizSettings(category: nil, questionCount: 20)
        let bankOrder = many.map(\.id)

        let reordered = (1...5).contains { seed in
            var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
            return repository.makeQuestionSet(for: settings, using: &rng).map(\.id) != bankOrder
        }

        XCTAssertTrue(reordered, "Question order should not match the bank order")
    }
}
