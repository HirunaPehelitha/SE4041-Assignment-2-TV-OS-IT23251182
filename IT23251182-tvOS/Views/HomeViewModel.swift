//
//  HomeViewModel.swift
//  IT23251182-tvOS
//
//  View model backing the home, category and settings screens (the "VM" in MVVM).
//
//  It owns loading the bank through `QuestionRepository` and exposes only the
//  derived values the views need. The views hold no business logic and never
//  touch `Bundle`, `JSONDecoder` or the file system themselves.
//

import Foundation
import Observation

@Observable
final class HomeViewModel {

    // MARK: Published state
    private(set) var bankVersion: Int = 0
    private(set) var rejected: [RejectedQuestion] = []
    private(set) var loadErrorMessage: String?

    // MARK: Dependencies
    private let repository: QuestionRepository

    /// The repository is injected so a test (or a SwiftUI preview) can supply a
    /// stub bank instead of the real bundled file.
    init(repository: QuestionRepository = QuestionRepository()) {
        self.repository = repository
        load()
    }

    // MARK: Loading

    func load() {
        do {
            try repository.load()
            bankVersion = repository.version
            rejected = repository.rejected
            loadErrorMessage = nil
        } catch {
            bankVersion = 0
            rejected = []
            loadErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    // MARK: Derived values used by the views

    var hasQuestions: Bool { repository.isLoaded }

    var totalQuestionCount: Int { repository.allQuestions.count }

    var rejectedCount: Int { rejected.count }

    var availableCategories: [QuizCategory] { repository.availableCategories }

    func questionCount(in category: QuizCategory) -> Int {
        repository.count(in: category)
    }

    func questionCount(in category: QuizCategory, difficulty: Difficulty) -> Int {
        repository.count(in: category, difficulty: difficulty)
    }

    func maximumPoints(in category: QuizCategory) -> Int {
        repository.maximumPoints(in: category)
    }
}
