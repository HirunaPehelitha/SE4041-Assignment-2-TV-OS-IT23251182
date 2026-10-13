//
//  Question.swift
//  IT23251182-tvOS
//
//  A single trivia question, plus the validation rules that protect gameplay
//  from a malformed entry in the JSON question bank.
//

import Foundation

/// One multiple-choice question as stored in the bank.
///
/// `id` is a human-readable stable identifier from the JSON (e.g. "slc-01")
/// rather than a generated UUID, so a rejected question can be traced straight
/// back to the entry in `questions.json` that produced it, and so an id stays
/// the same across launches and app versions.
struct Question: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let category: QuizCategory
    let difficulty: Difficulty
    let prompt: String
    let options: [String]
    /// Zero-based index into `options` identifying the correct answer.
    let correctIndex: Int
    /// Optional note shown after the answer is revealed.
    let explanation: String?

    /// Every question must offer exactly this many choices.
    static let requiredOptionCount = 4

    /// Safe because `isValid` guarantees `correctIndex` is in range, and the
    /// repository never publishes a question that failed validation.
    var correctAnswer: String { options[correctIndex] }

    /// Why a question may be rejected. Returned rather than a bare `Bool` so
    /// the repository can report *what* was wrong with a specific entry.
    enum ValidationFailure: String, Equatable {
        case emptyIdentifier    = "identifier is empty"
        case emptyPrompt        = "prompt is empty"
        case wrongOptionCount   = "must have exactly 4 options"
        case blankOption        = "an option is blank"
        case duplicateOptions   = "options are not all distinct"
        case correctIndexOutOfRange = "correctIndex is out of range"
    }

    /// The single structural guarantee the rest of the app relies on.
    ///
    /// Distinct options matter for more than tidiness: answer order is shuffled
    /// before display, and two identical options would make the "correct" one
    /// ambiguous to the player even though the index still resolves.
    var validationFailure: ValidationFailure? {
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyIdentifier
        }
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyPrompt
        }
        if options.count != Self.requiredOptionCount {
            return .wrongOptionCount
        }
        if options.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return .blankOption
        }
        if Set(options).count != options.count {
            return .duplicateOptions
        }
        if !options.indices.contains(correctIndex) {
            return .correctIndexOutOfRange
        }
        return nil
    }

    var isValid: Bool { validationFailure == nil }
}
