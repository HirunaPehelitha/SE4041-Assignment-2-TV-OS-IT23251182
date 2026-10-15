//
//  MatchResultsView.swift
//  IT23251182-tvOS
//
//  The final scoreboard.
//
//  Every number here was produced by actually playing: the engine built this
//  `MatchResult` from real answers. Nothing on this screen is sample data.
//

import SwiftUI

struct MatchResultsView: View {

    let result: MatchResult
    /// Returns to the main menu, clearing the match from the navigation stack.
    let onFinish: () -> Void

    @Environment(\.brandAnimationsEnabled) private var animated
    @State private var hasAppeared = false

    @FocusState private var doneFocused: Bool

    private var ranking: [PlayerScore] { result.ranking }

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 0) {

                header
                    .padding(.bottom, 26)

                podium

                Spacer(minLength: 20)

                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, BrandLayout.screenPaddingH)
            .padding(.vertical, BrandLayout.screenPaddingV)
        }
        .onAppear {
            hasAppeared = true
            doneFocused = true
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 10) {
                Text(result.isDraw ? "It's a Draw" : "\(ranking.first?.player.name ?? "") Wins")
                    .font(BrandFont.title)
                    .foregroundStyle(Brand.accent)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(BrandFont.body)
                    .foregroundStyle(Brand.textSecondary)
            }
            Spacer()
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 0), value: hasAppeared)
    }

    private var subtitle: String {
        let questions = result.totalQuestionsAsked
        let label = questions == 1 ? "question" : "questions"
        return "\(result.settings.categoryDisplayName) · \(questions) \(label)"
    }

    private var podium: some View {
        HStack(alignment: .top, spacing: BrandLayout.gutter) {
            ForEach(Array(ranking.enumerated()), id: \.element.id) { position, entry in
                resultCard(entry: entry, position: position)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 30)
                    .animation(BrandMotion.entrance(animated, index: position + 1), value: hasAppeared)
            }
            Spacer()
        }
    }

    private func resultCard(entry: PlayerScore, position: Int) -> some View {
        let color = Brand.playerColor(at: entry.player.colorIndex)
        let isWinner = result.winners.contains(entry)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 76, height: 76)
                    Image(systemName: entry.player.avatar.symbolName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.player.name)
                        .font(BrandFont.cardTitle)
                        .foregroundStyle(Brand.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(positionLabel(position))
                        .font(BrandFont.caption)
                        .foregroundStyle(color)
                }

                Spacer()

                if isWinner {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Brand.accent)
                        .accessibilityHidden(true)
                }
            }

            Text("\(entry.score)")
                .font(BrandFont.metricBig)
                .foregroundStyle(Brand.accent)
                .monospacedDigit()

            Text("\(entry.correctCount) of \(entry.answeredCount) correct")
                .font(BrandFont.caption)
                .foregroundStyle(Brand.textSecondary)
        }
        .frame(width: 340, alignment: .leading)
        .padding(28)
        .brandCardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(positionLabel(position)), \(entry.player.name), \(entry.score) points, \(entry.correctCount) of \(entry.answeredCount) correct")
    }

    private func positionLabel(_ position: Int) -> String {
        switch position {
        case 0: return result.isDraw ? "Tied first" : "1st place"
        case 1: return "2nd place"
        case 2: return "3rd place"
        default: return "4th place"
        }
    }

    private var footer: some View {
        HStack(spacing: BrandLayout.gutter) {
            Button(action: onFinish) {
                Label("Back to Menu", systemImage: "house.fill")
            }
            .buttonStyle(BrandButtonStyle(kind: .primary))
            .focused($doneFocused)
            .accessibilityHint("Returns to the main menu")

            Spacer()

            Text("Saving results to this Apple TV arrives in the next stage.")
                .font(BrandFont.caption)
                .foregroundStyle(Brand.textTertiary)
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 5), value: hasAppeared)
    }
}
