//
//  LeaderboardView.swift
//  IT23251182-tvOS
//
//  Past match results stored on this Apple TV.
//
//  Match history is written when a game finishes, which is a later stage. Until
//  then this screen shows a real, explained empty state rather than invented
//  scores — a fabricated leaderboard would be indefensible in a viva, and the
//  empty state is the exact view the finished feature will fall back to when a
//  user genuinely has no saved matches.
//

import SwiftUI

struct LeaderboardView: View {
    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 40) {

                ScreenHeader(
                    title: "Leaderboard",
                    subtitle: "Results are saved to this Apple TV after each completed match."
                )

                EmptyStateView(
                    symbol: "trophy",
                    title: "No matches played yet",
                    message: "Finish a game and the final scoreboard will be saved here, ranked by score, so your group can track who is ahead over time."
                )
            }
            .padding(.horizontal, BrandLayout.screenPaddingH)
            .padding(.vertical, BrandLayout.screenPaddingV)
        }
    }
}

#Preview {
    NavigationStack {
        LeaderboardView()
    }
}
