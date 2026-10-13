//
//  CategorySelectViewModel.swift
//  IT23251182-tvOS
//
//  State owner for the category-selection screen.
//
//  The view holds no question data and performs no filtering. It renders
//  `availability` and reports two things back: which card the remote is
//  currently on (`highlight`) and which card the player pressed (`select`).
//  Every rule — what is playable, what the preview shows, what settings get
//  handed to player setup — lives here and is unit-testable without SwiftUI.
//
//  `nonisolated` for the same reason as `QuestionRepository`: this type is
//  exercised directly by unit tests, and the project's MainActor-by-default
//  isolation gives plain classes an isolated deinit that aborts under XCTest.
//

import Foundation
import Observation

@Observable
nonisolated final class CategorySelectViewModel {

    // MARK: State

    /// Summaries for every category, built once when the screen appears.
    private(set) var availability: [CategoryAvailability] = []

    /// The category the remote is currently focused on. Drives the live preview
    /// panel, and changes as the player moves across the row.
    var highlightedCategory: QuizCategory?

    /// The category the player actually chose. Survives navigating forward to
    /// player setup and back again, so returning shows what was picked.
    private(set) var selectedCategory: QuizCategory?

    /// How many questions a match from this screen will contain.
    let questionCount: Int

    // MARK: Dependencies

    private let repository: QuestionRepository

    init(repository: QuestionRepository,
         questionCount: Int = QuizSettings.defaultQuestionCount) {
        self.repository = repository
        self.questionCount = questionCount
        reload()
    }

    // MARK: Loading

    func reload() {
        availability = repository.allCategoryAvailability()
        // Start the preview on the first category that can actually be played,
        // so the panel never opens showing a locked subject.
        if highlightedCategory == nil {
            highlightedCategory = firstPlayableCategory
        }
    }

    // MARK: Derived values

    var firstPlayableCategory: QuizCategory? {
        availability.first(where: \.isPlayable)?.category
    }

    var hasAnyPlayableCategory: Bool {
        availability.contains(where: \.isPlayable)
    }

    var playableCount: Int {
        availability.filter(\.isPlayable).count
    }

    var lockedCount: Int {
        availability.filter { !$0.isPlayable }.count
    }

    /// The summary shown in the preview panel.
    var highlightedAvailability: CategoryAvailability? {
        guard let highlightedCategory else { return nil }
        return availability.first { $0.category == highlightedCategory }
    }

    func availability(for category: QuizCategory) -> CategoryAvailability? {
        availability.first { $0.category == category }
    }

    func isSelected(_ category: QuizCategory) -> Bool {
        selectedCategory == category
    }

    // MARK: Selection

    /// Records a choice and returns the settings to carry into player setup,
    /// or `nil` if the category cannot be played.
    ///
    /// Returning the settings rather than storing them somewhere global keeps
    /// the hand-off explicit: the caller pushes the route with this value, so
    /// the next screen cannot be reached without a category attached.
    @discardableResult
    func select(_ category: QuizCategory) -> QuizSettings? {
        guard let summary = availability(for: category), summary.isPlayable else {
            return nil
        }
        selectedCategory = category
        return settings(for: summary)
    }

    /// Builds the match configuration for a category.
    ///
    /// The round is capped at what the category can actually supply, so a
    /// ten-question round is never requested from a category holding six.
    func settings(for summary: CategoryAvailability) -> QuizSettings {
        QuizSettings(
            category: summary.category,
            difficulties: Set(Difficulty.allCases),
            questionCount: min(questionCount, summary.longestPossibleRound)
        )
    }

    /// Accessibility description for one card, spoken as a single phrase.
    func accessibilityLabel(for summary: CategoryAvailability) -> String {
        if let reason = summary.unavailableReason {
            return "\(summary.category.displayName). Locked. \(reason)"
        }
        let selected = isSelected(summary.category) ? " Currently selected." : ""
        return "\(summary.category.displayName). \(summary.totalQuestions) questions available.\(selected)"
    }
}
