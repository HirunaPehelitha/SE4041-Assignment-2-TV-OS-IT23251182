//
//  CategorySelectionTests.swift
//  IT23251182-tvOSTests
//
//  Tests for category availability, the playability rule and the selection
//  hand-off into player setup.
//

import XCTest
@testable import IT23251182_tvOS

private struct StubProvider: QuestionProviding {
    var result: QuestionBankLoadResult
    func loadQuestions() throws -> QuestionBankLoadResult { result }
}

final class CategoryAvailabilityTests: XCTestCase {

    private func summary(total: Int, points: Int = 0,
                         counts: [Difficulty: Int] = [:]) -> CategoryAvailability {
        CategoryAvailability(category: .generalKnowledge,
                             totalQuestions: total,
                             maximumPoints: points,
                             countsByDifficulty: counts)
    }

    func testCategoryAtThresholdIsPlayable() {
        let s = summary(total: CategoryAvailability.minimumPlayableQuestions)
        XCTAssertTrue(s.isPlayable)
        XCTAssertEqual(s.shortfall, 0)
        XCTAssertNil(s.unavailableReason)
    }

    func testCategoryBelowThresholdIsNotPlayable() {
        let s = summary(total: CategoryAvailability.minimumPlayableQuestions - 1)
        XCTAssertFalse(s.isPlayable)
        XCTAssertEqual(s.shortfall, 1)
        XCTAssertNotNil(s.unavailableReason)
    }

    func testEmptyCategoryReportsItsOwnReason() {
        let s = summary(total: 0)
        XCTAssertTrue(s.isEmpty)
        XCTAssertFalse(s.isPlayable)
        XCTAssertEqual(s.unavailableReason, "No questions available yet.")
    }

    func testShortfallMessageIsSingularForOneQuestion() {
        let s = summary(total: CategoryAvailability.minimumPlayableQuestions - 1)
        XCTAssertTrue(s.unavailableReason?.contains("1 more question required") ?? false,
                      "Got: \(s.unavailableReason ?? "nil")")
    }

    func testCountForMissingDifficultyIsZero() {
        let s = summary(total: 3, counts: [.easy: 3])
        XCTAssertEqual(s.count(for: .easy), 3)
        XCTAssertEqual(s.count(for: .hard), 0)
    }
}

final class RepositoryAvailabilityTests: XCTestCase {

    private func question(_ id: String, _ category: QuizCategory, _ difficulty: Difficulty) -> Question {
        Question(id: id, category: category, difficulty: difficulty,
                 prompt: "P \(id)?", options: ["A", "B", "C", "D"],
                 correctIndex: 0, explanation: nil)
    }

    private func repository(_ questions: [Question]) throws -> QuestionRepository {
        let provider = StubProvider(result: QuestionBankLoadResult(version: 1,
                                                                   questions: questions,
                                                                   rejected: []))
        let repository = QuestionRepository(provider: provider)
        try repository.load()
        return repository
    }

    func testAvailabilityCountsByDifficulty() throws {
        let repo = try repository([
            question("a", .scienceAndNature, .easy),
            question("b", .scienceAndNature, .easy),
            question("c", .scienceAndNature, .hard)
        ])

        let summary = repo.availability(of: .scienceAndNature)

        XCTAssertEqual(summary.totalQuestions, 3)
        XCTAssertEqual(summary.count(for: .easy), 2)
        XCTAssertEqual(summary.count(for: .medium), 0)
        XCTAssertEqual(summary.count(for: .hard), 1)
        // Flat scoring: three questions, whatever their difficulty.
        XCTAssertEqual(summary.maximumPoints, 3 * MatchScoring.correctAnswerPoints)
    }

    func testAllCategoryAvailabilityIncludesEmptyCategories() throws {
        let repo = try repository([question("a", .scienceAndNature, .easy)])
        let all = repo.allCategoryAvailability()

        XCTAssertEqual(all.count, QuizCategory.allCases.count,
                       "Empty categories must still be listed so they can be shown locked")
        XCTAssertEqual(all.first { $0.category == .generalKnowledge }?.totalQuestions, 0)
    }

    func testBundledBankMakesEveryCategoryPlayable() throws {
        let repo = QuestionRepository(
            provider: BundleQuestionProvider(bundle: Bundle(for: QuestionRepository.self))
        )
        try repo.load()

        for summary in repo.allCategoryAvailability() {
            XCTAssertTrue(summary.isPlayable,
                          "\(summary.category.displayName) has only \(summary.totalQuestions) questions")
        }
    }
}

final class CategorySelectViewModelTests: XCTestCase {

    private func question(_ id: String, _ category: QuizCategory, _ difficulty: Difficulty = .easy) -> Question {
        Question(id: id, category: category, difficulty: difficulty,
                 prompt: "P \(id)?", options: ["A", "B", "C", "D"],
                 correctIndex: 0, explanation: nil)
    }

    /// A bank where Science is playable (6) and Sports is not (2).
    private func mixedViewModel(questionCount: Int = 10) throws -> CategorySelectViewModel {
        var questions = (1...6).map { question("s\($0)", .scienceAndNature) }
        questions += (1...2).map { question("k\($0)", .sportsAndCricket) }

        let provider = StubProvider(result: QuestionBankLoadResult(version: 1,
                                                                   questions: questions,
                                                                   rejected: []))
        let repository = QuestionRepository(provider: provider)
        try repository.load()
        return CategorySelectViewModel(repository: repository, questionCount: questionCount)
    }

    func testListsEveryCategoryIncludingLockedOnes() throws {
        let vm = try mixedViewModel()
        XCTAssertEqual(vm.availability.count, QuizCategory.allCases.count)
    }

    func testPlayableAndLockedCounts() throws {
        let vm = try mixedViewModel()
        XCTAssertEqual(vm.playableCount, 1)
        XCTAssertEqual(vm.lockedCount, QuizCategory.allCases.count - 1)
    }

    func testHighlightStartsOnFirstPlayableCategory() throws {
        let vm = try mixedViewModel()
        XCTAssertEqual(vm.highlightedCategory, .scienceAndNature)
        XCTAssertEqual(vm.highlightedAvailability?.category, .scienceAndNature)
    }

    func testSelectingAPlayableCategoryReturnsSettings() throws {
        let vm = try mixedViewModel()

        let settings = vm.select(.scienceAndNature)

        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?.category, .scienceAndNature)
        XCTAssertEqual(vm.selectedCategory, .scienceAndNature)
        XCTAssertTrue(vm.isSelected(.scienceAndNature))
    }

    func testSelectingALockedCategoryIsRefused() throws {
        let vm = try mixedViewModel()

        let settings = vm.select(.sportsAndCricket)

        XCTAssertNil(settings, "A locked category must not produce match settings")
        XCTAssertNil(vm.selectedCategory, "Selection must not be recorded")
    }

    func testSelectingAnEmptyCategoryIsRefused() throws {
        let vm = try mixedViewModel()
        XCTAssertNil(vm.select(.generalKnowledge))
    }

    func testRoundLengthIsCappedToWhatTheCategoryHolds() throws {
        // Asks for 10 questions, but Science only has 6.
        let vm = try mixedViewModel(questionCount: 10)

        let settings = vm.select(.scienceAndNature)

        XCTAssertEqual(settings?.questionCount, 6,
                       "A round must never request more questions than exist")
    }

    func testRoundLengthIsKeptWhenCategoryHasEnough() throws {
        let vm = try mixedViewModel(questionCount: 4)
        XCTAssertEqual(vm.select(.scienceAndNature)?.questionCount, 4)
    }

    func testSettingsCarryAllDifficultiesByDefault() throws {
        let vm = try mixedViewModel()
        let settings = vm.select(.scienceAndNature)
        XCTAssertTrue(settings?.includesAllDifficulties ?? false)
    }

    func testSelectionSurvivesReload() throws {
        let vm = try mixedViewModel()
        vm.select(.scienceAndNature)

        vm.reload()

        XCTAssertEqual(vm.selectedCategory, .scienceAndNature,
                       "Returning from player setup should still show the chosen category")
    }

    func testAccessibilityLabelDescribesLockedCategory() throws {
        let vm = try mixedViewModel()
        guard let locked = vm.availability(for: .sportsAndCricket) else {
            return XCTFail("missing summary")
        }

        let label = vm.accessibilityLabel(for: locked)

        XCTAssertTrue(label.contains("Locked"), label)
    }

    func testAccessibilityLabelMentionsSelection() throws {
        let vm = try mixedViewModel()
        vm.select(.scienceAndNature)
        guard let summary = vm.availability(for: .scienceAndNature) else {
            return XCTFail("missing summary")
        }

        XCTAssertTrue(vm.accessibilityLabel(for: summary).contains("Currently selected"))
    }

    func testNoPlayableCategoriesIsDetected() throws {
        let provider = StubProvider(result: QuestionBankLoadResult(
            version: 1,
            questions: [question("only", .generalKnowledge)],
            rejected: []
        ))
        let repository = QuestionRepository(provider: provider)
        try repository.load()
        let vm = CategorySelectViewModel(repository: repository)

        XCTAssertFalse(vm.hasAnyPlayableCategory)
        XCTAssertNil(vm.firstPlayableCategory)
        XCTAssertNil(vm.highlightedCategory)
    }
}
