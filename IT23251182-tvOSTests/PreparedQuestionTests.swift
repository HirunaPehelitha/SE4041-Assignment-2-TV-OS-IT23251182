//
//  PreparedQuestionTests.swift
//  IT23251182-tvOSTests
//
//  The most important guarantee in the whole data layer: shuffling the answer
//  options must never detach the correct answer from its option.
//

import XCTest
@testable import IT23251182_tvOS

final class PreparedQuestionTests: XCTestCase {

    private let sample = Question(
        id: "p-1",
        category: .generalKnowledge,
        difficulty: .medium,
        prompt: "Which is correct?",
        options: ["Wrong one", "Wrong two", "RIGHT", "Wrong three"],
        correctIndex: 2,
        explanation: "Because RIGHT is right."
    )

    func testUnshuffledInitPreservesBankOrder() {
        let prepared = PreparedQuestion(source: sample)

        XCTAssertEqual(prepared.options, sample.options)
        XCTAssertEqual(prepared.correctIndex, sample.correctIndex)
        XCTAssertEqual(prepared.correctAnswer, "RIGHT")
    }

    func testShuffleKeepsCorrectAnswerAttachedAcrossManySeeds() {
        for seed in UInt64(1)...500 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let prepared = PreparedQuestion(source: sample, shuffledUsing: &rng)

            XCTAssertEqual(prepared.options.count, 4, "seed \(seed)")
            XCTAssertEqual(Set(prepared.options), Set(sample.options),
                           "Shuffling must not add or lose options (seed \(seed))")
            XCTAssertEqual(prepared.correctAnswer, "RIGHT",
                           "correctIndex must still point at the right answer (seed \(seed))")
        }
    }

    func testShuffleActuallyChangesOrderForSomeSeed() {
        let moved = (UInt64(1)...50).contains { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            return PreparedQuestion(source: sample, shuffledUsing: &rng).options != sample.options
        }
        XCTAssertTrue(moved, "Answer order should vary between matches")
    }

    func testCorrectIndexMovesWithTheAnswer() {
        // Find a seed that actually moves the answer, then verify both the index
        // and the text agree afterwards.
        for seed in UInt64(1)...100 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let prepared = PreparedQuestion(source: sample, shuffledUsing: &rng)
            if prepared.correctIndex != sample.correctIndex {
                XCTAssertEqual(prepared.options[prepared.correctIndex], "RIGHT")
                XCTAssertTrue(prepared.isCorrect(prepared.correctIndex))
                XCTAssertFalse(prepared.isCorrect((prepared.correctIndex + 1) % 4))
                return
            }
        }
        XCTFail("No seed in range moved the correct answer")
    }

    func testPassThroughPropertiesComeFromSource() {
        var rng = SeededRandomNumberGenerator(seed: 3)
        let prepared = PreparedQuestion(source: sample, shuffledUsing: &rng)

        XCTAssertEqual(prepared.id, "p-1")
        XCTAssertEqual(prepared.prompt, "Which is correct?")
        XCTAssertEqual(prepared.category, .generalKnowledge)
        XCTAssertEqual(prepared.difficulty, .medium)
        XCTAssertEqual(prepared.explanation, "Because RIGHT is right.")
    }
}
