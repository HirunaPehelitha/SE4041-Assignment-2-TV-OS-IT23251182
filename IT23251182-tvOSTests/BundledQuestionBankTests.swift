//
//  BundledQuestionBankTests.swift
//  IT23251182-tvOSTests
//
//  Tests the real shipped questions.json rather than a fixture.
//
//  This is the test that catches a content mistake before a viva demo: a typo in
//  a category name, a question with three options, a duplicated id pasted while
//  editing, or the resource being dropped from the app target entirely.
//

import XCTest
@testable import IT23251182_tvOS

final class BundledQuestionBankTests: XCTestCase {

    /// The bundle that actually contains the app's resources. Resolved from a
    /// type in the app module rather than `Bundle.main`, which differs between
    /// the test runner and the host app.
    private var appBundle: Bundle { Bundle(for: QuestionRepository.self) }

    private func loadBundledBank() throws -> QuestionBankLoadResult {
        let provider = BundleQuestionProvider(resourceName: "questions", bundle: appBundle)
        return try provider.loadQuestions()
    }

    func testBundledResourceExistsInAppTarget() {
        XCTAssertNotNil(appBundle.url(forResource: "questions", withExtension: "json"),
                        "questions.json is missing from the app bundle — check target membership")
    }

    func testBundledBankLoadsWithNoRejectedQuestions() throws {
        let result = try loadBundledBank()

        XCTAssertTrue(result.rejected.isEmpty,
                      "Rejected entries: \(result.rejected.map { "\($0.id): \($0.reason)" })")
    }

    func testBundledBankHasAtLeastFiftyQuestions() throws {
        let result = try loadBundledBank()
        XCTAssertGreaterThanOrEqual(result.questions.count, 50)
    }

    func testEveryCategoryIsRepresented() throws {
        let result = try loadBundledBank()
        let present = Set(result.questions.map(\.category))

        for category in QuizCategory.allCases {
            XCTAssertTrue(present.contains(category),
                          "\(category.displayName) has no questions in the bundled bank")
        }
    }

    func testEveryBundledQuestionPassesValidation() throws {
        let result = try loadBundledBank()

        for question in result.questions {
            XCTAssertNil(question.validationFailure,
                         "\(question.id): \(question.validationFailure?.rawValue ?? "")")
            XCTAssertEqual(question.options.count, Question.requiredOptionCount, question.id)
            XCTAssertEqual(Set(question.options).count, 4, "\(question.id) has repeated options")
        }
    }

    func testAllIdentifiersAreUnique() throws {
        let result = try loadBundledBank()
        let ids = result.questions.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate identifiers in the bundled bank")
    }

    func testEveryQuestionHasAnExplanation() throws {
        let result = try loadBundledBank()

        for question in result.questions {
            let explanation = question.explanation?.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(explanation?.isEmpty ?? true, "\(question.id) has no explanation")
        }
    }

    func testCorrectAnswerPositionsAreSpreadAcrossOptions() throws {
        // If every correct answer sat at the same index, players could win by
        // always choosing that position once the shuffle is removed.
        let result = try loadBundledBank()
        let positions = Set(result.questions.map(\.correctIndex))

        XCTAssertEqual(positions, [0, 1, 2, 3])
    }

    func testRepositoryExposesAllFiveCategories() throws {
        let repository = QuestionRepository(
            provider: BundleQuestionProvider(resourceName: "questions", bundle: appBundle)
        )
        try repository.load()

        XCTAssertEqual(repository.availableCategories.count, QuizCategory.allCases.count)
        for category in QuizCategory.allCases {
            XCTAssertGreaterThan(repository.count(in: category), 0, category.displayName)
        }
    }

    func testMissingResourceProducesAClearError() {
        let provider = BundleQuestionProvider(resourceName: "does-not-exist", bundle: appBundle)

        XCTAssertThrowsError(try provider.loadQuestions()) { error in
            XCTAssertEqual(error as? QuestionBankError, .resourceMissing(name: "does-not-exist"))
            let message = (error as? LocalizedError)?.errorDescription ?? ""
            XCTAssertTrue(message.contains("does-not-exist"), "Error should name the missing file")
        }
    }
}
