//
//  QuestionRepository.swift
//  IT23251182-tvOS
//
//  Loads, validates and serves the bundled question bank.
//
//  Design notes for the viva:
//  * `QuestionProviding` is a protocol, so a view model or test can be handed a
//    stub bank instead of reading the app bundle.
//  * Decoding is a pure function over `Data` (`QuestionBankDecoder.decode`), so
//    tests can feed it an inline JSON string — no simulator, no bundle.
//  * Malformed entries are rejected *individually*, with a reason. One bad
//    question can never stop the app from launching.
//  * Nothing here touches the network. The bank is a file inside the app.
//

import Foundation

// MARK: - Load result

/// Why a specific entry in the bank was discarded.
struct RejectedQuestion: Equatable {
    let id: String
    let reason: String
}

/// The outcome of loading the bank.
struct QuestionBankLoadResult: Equatable {
    let version: Int
    let questions: [Question]
    let rejected: [RejectedQuestion]

    static let empty = QuestionBankLoadResult(version: 0, questions: [], rejected: [])

    var rejectedIDs: [String] { rejected.map(\.id) }
}

// MARK: - Errors

enum QuestionBankError: LocalizedError, Equatable {
    case resourceMissing(name: String)
    case unreadable(reason: String)
    case malformedJSON(reason: String)
    case noValidQuestions

    var errorDescription: String? {
        switch self {
        case .resourceMissing(let name):
            return "Could not find \(name).json in the app bundle. Check that the file is a member of the app target."
        case .unreadable(let reason):
            return "The question bank could not be read: \(reason)"
        case .malformedJSON(let reason):
            return "The question bank is not valid JSON: \(reason)"
        case .noValidQuestions:
            return "The question bank loaded but contained no usable questions."
        }
    }
}

// MARK: - Provider abstraction

protocol QuestionProviding {
    func loadQuestions() throws -> QuestionBankLoadResult
}

// MARK: - Transfer objects

/// Mirrors the JSON exactly, using `String` for the enum fields.
///
/// Decoding straight into `Question` would make a single unrecognised category
/// abort the whole file. Decoding into this intermediate shape first lets each
/// entry be mapped and validated on its own.
private struct QuestionBankFile: Decodable {
    let version: Int
    let questions: [QuestionDTO]
}

/// Why one entry could not be turned into a `Question`. A typed error rather
/// than a bare string, because `Result`'s failure type must conform to `Error`.
private struct QuestionMappingFailure: Error, Equatable {
    let reason: String
}

private struct QuestionDTO: Decodable {
    let id: String
    let category: String
    let difficulty: String
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String?

    /// Converts to a domain `Question`, or explains why it cannot.
    func toDomain() -> Result<Question, QuestionMappingFailure> {
        guard let category = QuizCategory(rawValue: category) else {
            return .failure(QuestionMappingFailure(reason: "unknown category '\(category)'"))
        }
        guard let difficulty = Difficulty(rawValue: difficulty) else {
            return .failure(QuestionMappingFailure(reason: "unknown difficulty '\(difficulty)'"))
        }

        let question = Question(
            id: id,
            category: category,
            difficulty: difficulty,
            prompt: prompt,
            options: options,
            correctIndex: correctIndex,
            explanation: explanation
        )

        if let failure = question.validationFailure {
            return .failure(QuestionMappingFailure(reason: failure.rawValue))
        }
        return .success(question)
    }
}

// MARK: - Decoder (pure and unit-testable)

enum QuestionBankDecoder {

    /// Decodes and validates raw question-bank bytes.
    /// - Throws: `.malformedJSON` if the file cannot be parsed at all,
    ///           `.noValidQuestions` if nothing survived validation.
    static func decode(data: Data) throws -> QuestionBankLoadResult {
        let file: QuestionBankFile
        do {
            file = try JSONDecoder().decode(QuestionBankFile.self, from: data)
        } catch {
            throw QuestionBankError.malformedJSON(reason: error.localizedDescription)
        }

        var accepted: [Question] = []
        var rejected: [RejectedQuestion] = []
        var seenIDs = Set<String>()

        for dto in file.questions {
            // A duplicate id would make answer tracking ambiguous mid-match, so
            // the first entry wins and later ones are reported.
            guard !seenIDs.contains(dto.id) else {
                rejected.append(RejectedQuestion(id: dto.id, reason: "duplicate identifier"))
                continue
            }

            switch dto.toDomain() {
            case .success(let question):
                seenIDs.insert(question.id)
                accepted.append(question)
            case .failure(let failure):
                rejected.append(RejectedQuestion(id: dto.id, reason: failure.reason))
            }
        }

        guard !accepted.isEmpty else { throw QuestionBankError.noValidQuestions }

        return QuestionBankLoadResult(version: file.version,
                                      questions: accepted,
                                      rejected: rejected)
    }
}

// MARK: - Bundle-backed provider

nonisolated struct BundleQuestionProvider: QuestionProviding {
    let resourceName: String
    let bundle: Bundle

    init(resourceName: String = "questions", bundle: Bundle = .main) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    func loadQuestions() throws -> QuestionBankLoadResult {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw QuestionBankError.resourceMissing(name: resourceName)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw QuestionBankError.unreadable(reason: error.localizedDescription)
        }
        return try QuestionBankDecoder.decode(data: data)
    }
}

// MARK: - Repository

/// The app's single entry point to question data: filtering, counting and
/// building the shuffled set of questions a match will actually use.
///
/// Explicitly `nonisolated`. This project builds with Xcode 26's
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise bind this
/// class — and its deinitialiser — to the main actor. The repository holds no UI
/// state and performs pure data work, so tying it to the main thread is both
/// unnecessary and limiting: keeping it nonisolated leaves the door open to
/// loading a larger bank off the main thread in future.
nonisolated final class QuestionRepository {

    private(set) var allQuestions: [Question] = []
    private(set) var version: Int = 0
    private(set) var rejected: [RejectedQuestion] = []

    private let provider: QuestionProviding

    init(provider: QuestionProviding = BundleQuestionProvider()) {
        self.provider = provider
    }

    /// Reads the bank. Throws if it is missing, unreadable or unusable.
    @discardableResult
    func load() throws -> QuestionBankLoadResult {
        let result = try provider.loadQuestions()
        allQuestions = result.questions
        version = result.version
        rejected = result.rejected
        return result
    }

    // MARK: Queries

    var isLoaded: Bool { !allQuestions.isEmpty }

    /// Categories that actually contain at least one question, so the UI can
    /// never offer a category that leads to an empty match.
    var availableCategories: [QuizCategory] {
        QuizCategory.allCases.filter { category in
            allQuestions.contains { $0.category == category }
        }
    }

    func questions(in category: QuizCategory) -> [Question] {
        allQuestions.filter { $0.category == category }
    }

    func questions(in category: QuizCategory, difficulty: Difficulty) -> [Question] {
        allQuestions.filter { $0.category == category && $0.difficulty == difficulty }
    }

    /// Every question eligible under these settings, in bank order.
    func questions(matching settings: QuizSettings) -> [Question] {
        allQuestions.filter { settings.matches($0) }
    }

    func count(in category: QuizCategory) -> Int {
        questions(in: category).count
    }

    func count(in category: QuizCategory, difficulty: Difficulty) -> Int {
        questions(in: category, difficulty: difficulty).count
    }

    /// Highest score obtainable if every question in a category were answered
    /// correctly.
    func maximumPoints(in category: QuizCategory) -> Int {
        questions(in: category).reduce(0) { $0 + $1.difficulty.basePoints }
    }

    // MARK: Availability

    /// Builds the summary the category screen renders for one category.
    ///
    /// Computed here, not in a view, so the counting happens once against the
    /// bank rather than being repeated by whatever is on screen.
    func availability(of category: QuizCategory) -> CategoryAvailability {
        let matching = questions(in: category)

        var counts: [Difficulty: Int] = [:]
        for question in matching {
            counts[question.difficulty, default: 0] += 1
        }

        return CategoryAvailability(
            category: category,
            totalQuestions: matching.count,
            maximumPoints: matching.reduce(0) { $0 + $1.difficulty.basePoints },
            countsByDifficulty: counts
        )
    }

    /// Summaries for every category in the app, including any that are empty.
    ///
    /// Empty categories are deliberately *included* rather than filtered out:
    /// the selection screen shows them locked with an explanation, which is more
    /// honest than silently hiding a subject the player expected to see.
    func allCategoryAvailability() -> [CategoryAvailability] {
        QuizCategory.allCases.map { availability(of: $0) }
    }

    // MARK: Building a match

    /// Builds the question set for a match: filtered, shuffled, trimmed to the
    /// requested length, and with each question's answers shuffled too.
    ///
    /// Returns fewer than `settings.questionCount` when the filter does not
    /// match enough questions — the caller is expected to check the count rather
    /// than the repository silently padding the round with repeats.
    func makeQuestionSet<R: RandomNumberGenerator>(
        for settings: QuizSettings,
        using generator: inout R
    ) -> [PreparedQuestion] {
        let eligible = questions(matching: settings).shuffled(using: &generator)
        let chosen = eligible.prefix(settings.questionCount)
        return chosen.map { PreparedQuestion(source: $0, shuffledUsing: &generator) }
    }

    /// Convenience overload using the system random source, for normal play.
    func makeQuestionSet(for settings: QuizSettings) -> [PreparedQuestion] {
        var generator = SystemRandomNumberGenerator()
        return makeQuestionSet(for: settings, using: &generator)
    }
}
