//
//  HowToPlayView.swift
//  IT23251182-tvOS
//
//  Static rules screen. Content is real and final for the planned gameplay, so
//  the user is never shown "coming soon" text here.
//

import SwiftUI

struct HowToPlayView: View {

    private struct Rule: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let rules: [Rule] = [
        Rule(symbol: "person.3.fill",
             title: "Two to four players",
             detail: "Everyone plays on one Apple TV, passing a single remote between turns. No accounts, no second device, no internet connection."),
        Rule(symbol: "list.number",
             title: "Take it in turns",
             detail: "Players answer in a fixed rotation. The screen always shows whose turn it is before the question is revealed."),
        Rule(symbol: "timer",
             title: "Beat the clock",
             detail: "Easy questions allow 15 seconds, medium 20 and hard 25. Running out of time scores nothing for that turn."),
        Rule(symbol: "star.fill",
             title: "Every correct answer scores",
             detail: "A correct answer is worth 100 points. A wrong answer scores nothing, and there is no penalty — so it is always worth a guess."),
        Rule(symbol: "trophy.fill",
             title: "Highest score wins",
             detail: "After the final round the scoreboard ranks every player, and the completed match is saved to your match history on this Apple TV.")
    ]

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 40) {

                ScreenHeader(
                    title: "How to Play",
                    subtitle: "Brain Battle is a pass-the-remote party quiz for the living room."
                )

                VStack(alignment: .leading, spacing: 26) {
                    ForEach(rules) { rule in
                        RuleRow(symbol: rule.symbol, title: rule.title, detail: rule.detail)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, BrandLayout.screenPaddingH)
            .padding(.vertical, BrandLayout.screenPaddingV)
        }
    }
}

private struct RuleRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Brand.accent)
                .frame(width: 60, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(BrandFont.label)
                    .foregroundStyle(Brand.textPrimary)
                Text(detail)
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        HowToPlayView()
    }
}
