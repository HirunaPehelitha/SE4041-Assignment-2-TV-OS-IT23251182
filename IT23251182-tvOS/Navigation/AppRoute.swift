//
//  AppRoute.swift
//  IT23251182-tvOS
//
//  Every screen the user can navigate to, expressed as a value.
//
//  Using a `Hashable` enum with SwiftUI's `navigationDestination(for:)` keeps
//  navigation data-driven: a view pushes a *value*, never a view. Adding a
//  screen means adding a case here plus one line in ContentView's destination
//  builder, so the whole navigation graph stays readable in one place.
//
//  Note that `playerSetup` carries its `QuizSettings`. The chosen category is
//  part of the route itself, so that screen is unreachable without one — the
//  compiler enforces the hand-off rather than a runtime check.
//

import Foundation

enum AppRoute: Hashable {
    case categorySelect              // "Play Game" — choose a subject
    case playerSetup(QuizSettings)   // carries the chosen category forward
    case howToPlay
    case leaderboard
    case settings
}
