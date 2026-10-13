//
//  QuestionBankDecoderTests.swift
//  IT23251182-tvOSTests
//
//  Tests for decoding and per-entry validation of the question bank.
//
//  These exercise `QuestionBankDecoder.decode(data:)` directly with inline JSON.
//  Because decoding is a pure function over `Data`, none of this needs the app
//  bundle, a simulator screen, or any network access.
//

import XCTest
@testable import IT23251182_tvOS

final class QuestionBankDecoderTests: XCTestCase {

    // MARK: Helpers

    /// Builds a single well-formed question entry, with fields overridable so a
    /// test can make exactly one thing invalid.
    private func entry(id: String = "t-01",
                       category: String = "scienceAndNature",
                       difficulty: String = "easy",
                       prompt: String = "Sample prompt?",
                       options: [String] = ["A", "B", "C", "D"],
                       correctIndex: Int = 0,
                       explanation: String? = "Because.") -> String {
        let opts = options.map { "\"\($0)\"" }.joined(separator: ", ")
        let expl = explanation.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "id": "\(id)",
          "category": "\(category)",
          "difficulty": "\(difficulty)",
          "prompt": "\(prompt)",
          "options": [\(opts)],
          "correctIndex": \(correctIndex),
          "explanation": \(expl)
        }
        """
    }

    private func bank(version: Int = 1, entries: [String]) -> Data {
        Data("""
        { "version": \(version), "questions": [\(entries.joined(separator: ","))] }
        """.utf8)
    }

    // MARK: Happy path

    func testDecodesValidBank() throws {
        let data = bank(version: 2, entries: [
            entry(id: "a-1"),
            entry(id: "a-2", category: "sriLankanCulture", difficulty: "hard", correctIndex: 3)
        ])

        let result = try QuestionBankDecoder.decode(data: data)

        XCTAssertEqual(result.version, 2)
        XCTAssertEqual(result.questions.count, 2)
        XCTAssertTrue(result.rejected.isEmpty)
        XCTAssertEqual(result.questions[0].id, "a-1")
        XCTAssertEqual(result.questions[1].category, .sriLankanCulture)
        XCTAssertEqual(result.questions[1].difficulty, .hard)
        XCTAssertEqual(result.questions[1].correctAnswer, "D")
    }

    func testDecodesOptionalExplanationAsNil() throws {
        let data = bank(entries: [entry(explanation: nil)])
        let result = try QuestionBankDecoder.decode(data: data)
        XCTAssertNil(result.questions[0].explanation)
    }

    // MARK: Malformed input

    func testMalformedJSONThrows() {
        let data = Data("{ this is not json".utf8)

        XCTAssertThrowsError(try QuestionBankDecoder.decode(data: data)) { error in
            guard let bankError = error as? QuestionBankError,
                  case .malformedJSON = bankError else {
                return XCTFail("Expected .malformedJSON, got \(error)")
            }
        }
    }

    func testMissingRequiredFieldThrowsMalformed() {
        // No "options" key at all — this is a structural failure, not a single
        // bad entry, so the whole file is rejected.
        let data = Data("""
        { "version": 1, "questions": [
          { "id": "x", "category": "scienceAndNature", "difficulty": "easy",
            "prompt": "P", "correctIndex": 0 }
        ] }
        """.utf8)

        XCTAssertThrowsError(try QuestionBankDecoder.decode(data: data))
    }

    func testBankWithNoValidQuestionsThrows() {
        let data = bank(entries: [entry(id: "bad", options: ["A", "B"])])

        XCTAssertThrowsError(try QuestionBankDecoder.decode(data: data)) { error in
            XCTAssertEqual(error as? QuestionBankError, .noValidQuestions)
        }
    }

    // MARK: Per-entry rejection

    func testUnknownCategoryIsRejectedWithoutFailingTheFile() throws {
        let data = bank(entries: [
            entry(id: "good"),
            entry(id: "bad", category: "astrophysics")
        ])

        let result = try QuestionBankDecoder.decode(data: data)

        XCTAssertEqual(result.questions.map(\.id), ["good"])
        XCTAssertEqual(result.rejected.count, 1)
        XCTAssertEqual(result.rejected[0].id, "bad")
        XCTAssertTrue(result.rejected[0].reason.contains("unknown category"))
    }

    func testUnknownDifficultyIsRejected() throws {
        let data = bank(entries: [entry(id: "good"), entry(id: "bad", difficulty: "impossible")])
        let result = try QuestionBankDecoder.decode(data: data)

        XCTAssertEqual(result.questions.map(\.id), ["good"])
        XCTAssertTrue(result.rejected[0].reason.contains("unknown difficulty"))
    }

    func testDuplicateIdentifierKeepsFirstAndRejectsSecond() throws {
        let data = bank(entries: [
            entry(id: "dup", prompt: "First"),
            entry(id: "dup", prompt: "Second"),
            entry(id: "unique")
        ])

        let result = try QuestionBankDecoder.decode(data: data)

        XCTAssertEqual(result.questions.count, 2)
        XCTAssertEqual(result.questions[0].prompt, "First", "The first entry should win")
        XCTAssertEqual(result.rejected.count, 1)
        XCTAssertEqual(result.rejected[0].id, "dup")
        XCTAssertEqual(result.rejected[0].reason, "duplicate identifier")
    }

    // MARK: Answer-option validation

    func testTooFewOptionsIsRejected() throws {
        let data = bank(entries: [entry(id: "good"), entry(id: "three", options: ["A", "B", "C"])])
        let result = try QuestionBankDecoder.decode(data: data)

        XCTAssertEqual(result.rejected.map(\.id), ["three"])
        XCTAssertEqual(result.rejected[0].reason,
                       Question.ValidationFailure.wrongOptionCount.rawValue)
    }

    func testTooManyOptionsIsRejected() throws {
        let data = bank(entries: [entry(id: "good"), entry(id: "five", options: ["A", "B", "C", "D", "E"])])
        let result = try QuestionBankDecoder.decode(data: data)
        XCTAssertEqual(result.rejected.map(\.id), ["five"])
    }

    func testDuplicateOptionsAreRejected() throws {
        // Two identical options would make the "correct" one ambiguous to the
        // player once the answer order is shuffled.
        let data = bank(entries: [entry(id: "good"), entry(id: "dupopt", options: ["A", "A", "C", "D"])])
        let result = try QuestionBankDecoder.decode(data: data)

        XCTAssertEqual(result.rejected.map(\.id), ["dupopt"])
        XCTAssertEqual(result.rejected[0].reason,
                       Question.ValidationFailure.duplicateOptions.rawValue)
    }

    func testBlankOptionIsRejected() throws {
        let data = bank(entries: [entry(id: "good"), entry(id: "blank", options: ["A", "   ", "C", "D"])])
        let result = try QuestionBankDecoder.decode(data: data)
        XCTAssertEqual(result.rejected.map(\.id), ["blank"])
        XCTAssertEqual(result.rejected[0].reason,
                       Question.ValidationFailure.blankOption.rawValue)
    }

    func testCorrectIndexOutOfRangeIsRejected() throws {
        let data = bank(entries: [entry(id: "good"), entry(id: "oob", correctIndex: 4)])
        let result = try QuestionBankDecoder.decode(data: data)

        XCTAssertEqual(result.rejected.map(\.id), ["oob"])
        XCTAssertEqual(result.rejected[0].reason,
                       Question.ValidationFailure.correctIndexOutOfRange.rawValue)
    }

    func testNegativeCorrectIndexIsRejected() throws {
        let data = bank(entries: [entry(id: "good"), entry(id: "neg", correctIndex: -1)])
        let result = try QuestionBankDecoder.decode(data: data)
        XCTAssertEqual(result.rejected.map(\.id), ["neg"])
    }

    func testEmptyPromptIsRejected() throws {
        let data = bank(entries: [entry(id: "good"), entry(id: "nop", prompt: "   ")])
        let result = try QuestionBankDecoder.decode(data: data)
        XCTAssertEqual(result.rejected.map(\.id), ["nop"])
        XCTAssertEqual(result.rejected[0].reason,
                       Question.ValidationFailure.emptyPrompt.rawValue)
    }
}
