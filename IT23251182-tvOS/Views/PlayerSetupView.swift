//
//  PlayerSetupView.swift
//  IT23251182-tvOS
//
//  Player setup — the screen the chosen category is handed to.
//
//  Scope note: this stage delivers the hand-off and the player-count control,
//  which are real and working. Entering player names and starting the match
//  arrive with the game engine in the next stage, so there is deliberately no
//  "Start Match" button here yet — a button that cannot start a match would be
//  worse than no button at all.
//

import SwiftUI

struct PlayerSetupView: View {

    /// The configuration carried in from the category screen. A `let` with no
    /// default: this screen cannot be constructed without a category attached.
    let settings: QuizSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.brandAnimationsEnabled) private var animated

    @State private var playerCount: Int = Player.minimumPlayers
    @State private var hasAppeared = false

    @FocusState private var focusedCount: Int?

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 40) {

                header

                matchSummary

                playerCountSection

                Spacer()

                Text("Player names and the match itself arrive with the game engine in the next stage.")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textTertiary)
            }
            .padding(.horizontal, BrandLayout.screenPaddingH)
            .padding(.vertical, BrandLayout.screenPaddingV)
        }
        .onAppear { hasAppeared = true }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            ScreenHeader(
                title: "Player Setup",
                subtitle: "How many people are playing on this Apple TV?"
            )
            Spacer()
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(BrandButtonStyle(kind: .secondary))
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to category selection")
        }
    }

    /// Proof that the selection actually travelled: every value here comes from
    /// the `QuizSettings` built on the previous screen.
    private var matchSummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionLabel(text: "Selected Match")

            HStack(spacing: BrandLayout.gutter) {
                if let category = settings.category {
                    HStack(spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Brand.accentMuted)
                                .frame(width: 80, height: 80)
                            Image(systemName: category.symbolName)
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Brand.accent)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.displayName)
                                .font(BrandFont.heading)
                                .foregroundStyle(Brand.textPrimary)
                            Text(category.blurb)
                                .font(BrandFont.caption)
                                .foregroundStyle(Brand.textSecondary)
                        }
                    }
                    .padding(28)
                    .brandCardSurface()
                    .accessibilityElement(children: .combine)
                }

                StatPill(value: "\(settings.questionCount)", label: "Questions")
                StatPill(value: settings.includesAllDifficulties ? "All" : "\(settings.effectiveDifficulties.count)",
                         label: "Difficulties")
                Spacer()
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 0), value: hasAppeared)
    }

    private var playerCountSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionLabel(text: "Players")

            HStack(spacing: BrandLayout.gutter) {
                ForEach(Player.minimumPlayers...Player.maximumPlayers, id: \.self) { count in
                    Button {
                        playerCount = count
                    } label: {
                        VStack(spacing: 8) {
                            Text("\(count)")
                                .font(BrandFont.metricBig)
                                .foregroundStyle(playerCount == count ? Brand.accent : Brand.textPrimary)
                            Text(count == 1 ? "player" : "players")
                                .font(BrandFont.caption)
                                .foregroundStyle(Brand.textSecondary)
                        }
                        .frame(width: 180)
                    }
                    .buttonStyle(BrandCardStyle(isPrimary: playerCount == count))
                    .focused($focusedCount, equals: count)
                    .accessibilityLabel("\(count) players")
                    .accessibilityValue(playerCount == count ? "Selected" : "Not selected")
                }
                Spacer()
            }
            .defaultFocus($focusedCount, Player.minimumPlayers)
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 1), value: hasAppeared)
    }
}

#Preview {
    NavigationStack {
        PlayerSetupView(settings: QuizSettings(category: .sriLankanCulture, questionCount: 10))
    }
}
