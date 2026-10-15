//
//  ContentView.swift
//  IT23251182-tvOS
//
//  Created by Chandare on 2026-10-12.
//
//  Root view and navigation host for Brain Battle.
//
//  Responsibilities:
//  1. Own the one `QuestionRepository` and the view models that read it, so the
//     bank is parsed once per launch and every screen sees the same data.
//  2. Resolve whether animation should play — our own Reduce Motion preference
//     OR the system accessibility setting — and publish it through the
//     environment, where the button styles and screen entrances read it.
//  3. Own the navigation path and map each `AppRoute` value to its screen.
//     Child views push routes or report a result; only this file knows which
//     view a route builds.
//

import SwiftUI

struct ContentView: View {

    @State private var viewModel: HomeViewModel
    @State private var categorySelection: CategorySelectViewModel
    @State private var settings = AppSettings()

    /// The navigation stack's path. Held here rather than inside a child so a
    /// screen can hand a value back up (the chosen category) and this view can
    /// decide what to push next.
    @State private var path: [AppRoute] = []

    /// Shared by every view model, so the bank is parsed once per launch.
    private let repository: QuestionRepository

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    init() {
        // One repository, shared by every view model. `HomeViewModel` loads it
        // during its own initialisation, so the category view model built on the
        // next line already sees a populated bank.
        let repository = QuestionRepository()
        let home = HomeViewModel(repository: repository)
        self.repository = repository
        _viewModel = State(initialValue: home)
        _categorySelection = State(initialValue: CategorySelectViewModel(repository: repository))
    }

    /// Either switch turns animation off. Honouring the system setting as well
    /// as our own is what makes the app's motion behaviour genuinely accessible
    /// rather than only configurable from inside the app.
    private var animationsEnabled: Bool {
        !(settings.reduceMotion || systemReduceMotion)
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(viewModel: viewModel)
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .environment(settings)
        .environment(\.brandAnimationsEnabled, animationsEnabled)
        // tvOS renders light-on-dark by default, but stating it explicitly means
        // the brand palette is never recoloured by a system appearance change.
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .categorySelect:
            CategorySelectView(viewModel: categorySelection) { chosenSettings in
                // The category screen does not know what comes next; it reports
                // the chosen settings and this view decides where they go.
                path.append(.playerSetup(chosenSettings))
            }

        case .playerSetup(let chosenSettings):
            PlayerSetupView(
                viewModel: PlayerSetupViewModel(settings: chosenSettings,
                                                repository: repository)
            ) { session in
                // Setup reports the built session; this view decides where it goes.
                path.append(.matchReady(session))
            }

        case .matchReady(let session):
            MatchStartView(session: session) {
                path.append(.quiz(session))
            }

        case .quiz(let session):
            QuizGameView(session: session) { result in
                // Replace the stack rather than pushing: a finished match must
                // not be reachable again with the Back button.
                path = [.results(result)]
            }

        case .results(let result):
            MatchResultsView(result: result) {
                path.removeAll()
            }

        case .howToPlay:
            HowToPlayView()

        case .leaderboard:
            LeaderboardView()

        case .settings:
            SettingsView(viewModel: viewModel)
        }
    }
}

#Preview {
    ContentView()
}
