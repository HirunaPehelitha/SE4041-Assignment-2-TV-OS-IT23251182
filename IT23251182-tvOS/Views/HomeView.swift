//
//  HomeView.swift
//  IT23251182-tvOS
//
//  The Brain Battle home screen: brand lockup, four navigation actions and a
//  live summary of the loaded question bank.
//
//  The screen is assembled from reusable pieces (`BrandLockup`, `ActionCardContent`,
//  `StatPill`) and renders its menu from an array of `HomeAction` values, so the
//  view body stays short and nothing is duplicated four times.
//

import SwiftUI

struct HomeView: View {

    /// Injected by `ContentView`, which owns the single shared instance so the
    /// question bank is read from disk once per launch.
    let viewModel: HomeViewModel

    @Environment(\.brandAnimationsEnabled) private var animated

    /// Drives the staggered entrance. Flipped once in `onAppear`.
    @State private var hasAppeared = false

    /// Tracks which action tile holds the remote's focus so we can tell tvOS
    /// where focus should start.
    @FocusState private var focusedAction: String?

    private var actions: [HomeAction] {
        [
            HomeAction(id: "play",
                       title: "Play Game",
                       subtitle: "Start a match for 2–4 players",
                       symbol: "play.fill",
                       route: .categorySelect,
                       isPrimary: true),
            HomeAction(id: "how",
                       title: "How to Play",
                       subtitle: "Rules, scoring and timings",
                       symbol: "questionmark.circle.fill",
                       route: .howToPlay),
            HomeAction(id: "leaderboard",
                       title: "Leaderboard",
                       subtitle: "Past results on this Apple TV",
                       symbol: "trophy.fill",
                       route: .leaderboard),
            HomeAction(id: "settings",
                       title: "Settings",
                       subtitle: "Preferences and app information",
                       symbol: "gearshape.fill",
                       route: .settings)
        ]
    }

    var body: some View {
        ZStack {
            BrandBackground()

            if viewModel.hasQuestions {
                content
            } else {
                LoadFailureView(
                    message: viewModel.loadErrorMessage ?? "No questions were found.",
                    retry: { viewModel.load() }
                )
                .padding(.horizontal, BrandLayout.screenPaddingH)
            }
        }
        .onAppear { hasAppeared = true }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {

            BrandLockup()
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 28)
                .animation(BrandMotion.entrance(animated, index: 0), value: hasAppeared)

            Spacer(minLength: 54)

            SectionLabel(text: "Main Menu")
                .padding(.bottom, 18)
                .opacity(hasAppeared ? 1 : 0)
                .animation(BrandMotion.entrance(animated, index: 1), value: hasAppeared)

            actionRow

            Spacer(minLength: 54)

            footer
                .opacity(hasAppeared ? 1 : 0)
                .animation(BrandMotion.entrance(animated, index: 6), value: hasAppeared)
        }
        .padding(.horizontal, BrandLayout.screenPaddingH)
        .padding(.vertical, BrandLayout.screenPaddingV)
    }

    // MARK: Menu

    private var actionRow: some View {
        HStack(spacing: BrandLayout.gutter) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                NavigationLink(value: action.route) {
                    ActionCardContent(action: action)
                }
                .buttonStyle(BrandCardStyle(isPrimary: action.isPrimary))
                .focused($focusedAction, equals: action.id)
                .accessibilityLabel(action.accessibilityLabel)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 36)
                .animation(BrandMotion.entrance(animated, index: index + 2), value: hasAppeared)
            }
        }
        // Room for the focused card to scale up without being clipped.
        .padding(.vertical, 22)
        // Tells tvOS which control owns focus when the screen first appears,
        // instead of letting it choose for us.
        .defaultFocus($focusedAction, "play")
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: BrandLayout.gutter) {
            StatPill(value: "\(viewModel.totalQuestionCount)", label: "Questions")
            StatPill(value: "\(viewModel.availableCategories.count)", label: "Categories")
            StatPill(value: "v\(viewModel.bankVersion)", label: "Bank")

            if viewModel.rejectedCount > 0 {
                StatPill(value: "\(viewModel.rejectedCount)", label: "Skipped")
            }

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(viewModel: HomeViewModel())
    }
}
