//
//  PreparedQuestion.swift
//  IT23251182-tvOS
//
//  A question with its answer order already shuffled, ready to show on screen.
//

import Foundation

/// A question whose options have been shuffled for display.
///
/// This exists as a separate type from `Question` on purpose. The bank entry is
/// immutable reference data; what the player sees is a *presentation* of it with
/// a different answer order. Keeping them apart means the shuffled index can
/// never be written back over the authoritative one in the JSON, and the view
/// layer cannot accidentally read `Question.correctIndex` and mark the wrong
/// option as right.
struct PreparedQuestion: Identifiable, Equatable {

    /// The original bank entry, kept for its id, category, difficulty and explanation.
    let source: Question
    /// Options in the order they should be displayed.
    let options: [String]
    /// Index of the correct answer *within `options`*.
    let correctIndex: Int

    var id: String { source.id }
    var prompt: String { source.prompt }
    var category: QuizCategory { source.category }
    var difficulty: Difficulty { source.difficulty }
    var explanation: String? { source.explanation }
    var correctAnswer: String { options[correctIndex] }

    func isCorrect(_ selectedIndex: Int) -> Bool { selectedIndex == correctIndex }

    /// Builds an unshuffled presentation, preserving the bank's own order.
    init(source: Question) {
        self.source = source
        self.options = source.options
        self.correctIndex = source.correctIndex
    }

    /// Builds a presentation with the options shuffled by `generator`.
    ///
    /// The shuffle is applied to the *indices*, then the correct answer's new
    /// position is found by locating its old index in that permutation. Moving
    /// the index rather than matching on the answer text means the mapping holds
    /// even if two options were somehow identical.
    init<R: RandomNumberGenerator>(source: Question, shuffledUsing generator: inout R) {
        let order = Array(source.options.indices).shuffled(using: &generator)
        self.source = source
        self.options = order.map { source.options[$0] }
        // `order` is a permutation of `source.options.indices`, and validation
        // guarantees `correctIndex` is within that range, so this always finds a
        // value. The fallback exists only to avoid a force unwrap.
        self.correctIndex = order.firstIndex(of: source.correctIndex) ?? 0
    }
}
