//
//  NavigationUITests.swift
//  IT23251182-tvOSUITests
//
//  End-to-end navigation and gameplay flows, driven through the Apple TV remote.
//
//  These use `XCUIRemote`, which is the only way to exercise tvOS focus
//  navigation automatically — the simulator rejects synthetic touches, and
//  focus movement cannot be reproduced any other way. Each test therefore
//  verifies something unit tests structurally cannot: that the focus engine
//  actually reaches a control and that pressing it goes where it should.
//

import XCTest

final class NavigationUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Generous because a tvOS focus change plus a navigation push is not
    /// instant on a simulator under load.
    private let timeout: TimeInterval = 20

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: Helpers

    private var remote: XCUIRemote { XCUIRemote.shared }

    /// Moves right until the named element is focused, or fails.
    @discardableResult
    private func focusElement(named identifier: String, maxPresses: Int = 8) -> Bool {
        for _ in 0..<maxPresses {
            let element = app.descendants(matching: .any)[identifier]
            if element.exists && element.hasFocus { return true }
            remote.press(.right)
            usleep(400_000)
        }
        return app.descendants(matching: .any)[identifier].hasFocus
    }

    private func waitForText(_ text: String) -> Bool {
        app.staticTexts[text].waitForExistence(timeout: timeout)
    }

    // MARK: Launch

    func testAppLaunchesToTheHomeScreen() {
        XCTAssertTrue(waitForText("BRAIN"), "The home screen should appear on launch")
        XCTAssertTrue(app.staticTexts["BATTLE"].exists)
    }

    func testHomeScreenShowsEveryMenuAction() {
        XCTAssertTrue(waitForText("BRAIN"))

        for action in ["Play Game", "How to Play", "Leaderboard", "Settings"] {
            XCTAssertTrue(app.descendants(matching: .any)[action].waitForExistence(timeout: timeout),
                          "\(action) should be on the home screen")
        }
    }

    func testPlayGameHasFocusOnLaunch() {
        XCTAssertTrue(waitForText("BRAIN"))

        let play = app.descendants(matching: .any)["Play Game. Start a match for 2–4 players"]
        XCTAssertTrue(play.waitForExistence(timeout: timeout))
        XCTAssertTrue(play.hasFocus, "Play Game should hold focus when the app opens")
    }

    // MARK: Navigation flows

    func testPlayGameOpensCategorySelection() {
        XCTAssertTrue(waitForText("BRAIN"))

        remote.press(.select)

        XCTAssertTrue(waitForText("Choose a Category"),
                      "Play Game should open the category screen")
    }

    func testCategorySelectionLeadsToPlayerSetup() {
        XCTAssertTrue(waitForText("BRAIN"))
        remote.press(.select)                     // Play Game
        XCTAssertTrue(waitForText("Choose a Category"))

        remote.press(.select)                     // first category

        XCTAssertTrue(waitForText("Player Setup"),
                      "Choosing a category should open player setup")
    }

    func testMenuButtonReturnsFromCategorySelection() {
        XCTAssertTrue(waitForText("BRAIN"))
        remote.press(.select)
        XCTAssertTrue(waitForText("Choose a Category"))

        remote.press(.menu)

        XCTAssertTrue(waitForText("BRAIN"), "Menu should return to the home screen")
    }

    func testHowToPlayOpensAndReturns() {
        XCTAssertTrue(waitForText("BRAIN"))

        remote.press(.right)                      // move off Play Game
        usleep(500_000)
        remote.press(.select)

        XCTAssertTrue(waitForText("How to Play"))

        remote.press(.menu)
        XCTAssertTrue(waitForText("BRAIN"))
    }

    func testLeaderboardOpens() {
        XCTAssertTrue(waitForText("BRAIN"))

        remote.press(.right)
        usleep(400_000)
        remote.press(.right)
        usleep(400_000)
        remote.press(.select)

        XCTAssertTrue(waitForText("Leaderboard"))
    }

    func testSettingsOpensAndShowsItsSections() {
        XCTAssertTrue(waitForText("BRAIN"))

        for _ in 0..<3 { remote.press(.right); usleep(400_000) }
        remote.press(.select)

        XCTAssertTrue(waitForText("Settings"))
        XCTAssertTrue(app.staticTexts["GAMEPLAY"].waitForExistence(timeout: timeout))
    }

    // MARK: Focus navigation

    func testFocusMovesAcrossTheHomeMenu() {
        XCTAssertTrue(waitForText("BRAIN"))

        let play = app.descendants(matching: .any)["Play Game. Start a match for 2–4 players"]
        XCTAssertTrue(play.waitForExistence(timeout: timeout))
        XCTAssertTrue(play.hasFocus)

        remote.press(.right)
        usleep(500_000)

        XCTAssertFalse(play.hasFocus, "Pressing right should move focus off Play Game")
    }

    func testFocusSkipsNothingReachableOnTheHomeRow() {
        // Walk right across the row and back; the first card should regain focus.
        XCTAssertTrue(waitForText("BRAIN"))
        let play = app.descendants(matching: .any)["Play Game. Start a match for 2–4 players"]
        XCTAssertTrue(play.waitForExistence(timeout: timeout))

        for _ in 0..<3 { remote.press(.right); usleep(350_000) }
        for _ in 0..<3 { remote.press(.left); usleep(350_000) }

        XCTAssertTrue(play.hasFocus, "Focus should return to the first card")
    }

    // MARK: Gameplay

    func testPlayerSetupBlocksStartUntilNamesAreEntered() {
        XCTAssertTrue(waitForText("BRAIN"))
        remote.press(.select)
        XCTAssertTrue(waitForText("Choose a Category"))
        remote.press(.select)
        XCTAssertTrue(waitForText("Player Setup"))

        // With both slots empty the validation message must be showing.
        XCTAssertTrue(app.staticTexts["Player 1 needs a name."].waitForExistence(timeout: timeout),
                      "An empty roster should explain why the match cannot start")
    }

    func testCategoryScreenShowsThePreviewPanel() {
        XCTAssertTrue(waitForText("BRAIN"))
        remote.press(.select)
        XCTAssertTrue(waitForText("Choose a Category"))

        // The preview panel describes whichever category holds focus.
        XCTAssertTrue(app.staticTexts["Sri Lankan Culture"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["POINTS AVAILABLE"].exists)
    }
}
