//
//  MatchStartView.swift
//  IT23251182-tvOS
//
//  The match, as configured and ready to play.
//
//  A last look at the roster before the first question: who is playing, in what
//  order, and how many turns each. Every value is read from the real
//  `GameSession` built by player setup.
//

import SwiftUI

struct MatchStartView: View {

    let session: GameSession
    /// Begins the match.
    let onBegin: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.brandAnimationsEnabled) private var animated
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 0) {

                header
                    .padding(.bottom, 30)

                summaryRow
                    .padding(.bottom, 30)

                SectionLabel(text: "Turn Order")
                    .padding(.bottom, 14)

                turnOrder

                Spacer(minLength: 20)

                Button(action: onBegin) {
                    Label("Begin Match", systemImage: "play.fill")
                }
                .buttonStyle(BrandButtonStyle(kind: .primary))
                .accessibilityHint("Starts the first question")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, BrandLayout.screenPaddingH)
            .padding(.vertical, BrandLayout.screenPaddingV)
        }
        .onAppear { hasAppeared = true }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            ScreenHeader(
                title: "Match Ready",
                subtitle: "\(session.playerCount) players · \(session.categoryDisplayName)"
            )
            Spacer()
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(BrandButtonStyle(kind: .secondary))
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to player setup")
        }
    }

    private var summaryRow: some View {
        HStack(spacing: BrandLayout.gutter) {
            StatPill(value: "\(session.questionCount)", label: "Questions")
            StatPill(value: "\(session.playerCount)", label: "Players")
            StatPill(value: "\(session.maximumPoints)", label: "Points On Offer")
            StatPill(value: session.isTurnCountBalanced ? "Even" : "Uneven", label: "Turns")
            Spacer()
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 0), value: hasAppeared)
    }

    private var turnOrder: some View {
        HStack(alignment: .top, spacing: BrandLayout.gutter) {
            ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                turnCard(player: player, seat: index)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 28)
                    .animation(BrandMotion.entrance(animated, index: index + 1), value: hasAppeared)
            }
            Spacer()
        }
    }

    private func turnCard(player: Player, seat: Int) -> some View {
        let color = Brand.playerColor(at: player.colorIndex)
        let turns = session.turnCount(forSeat: seat)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 72, height: 72)
                    Image(systemName: player.avatar.symbolName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(BrandFont.cardTitle)
                        .foregroundStyle(Brand.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(seat == 0 ? "Goes first" : "Turn \(seat + 1)")
                        .font(BrandFont.caption)
                        .foregroundStyle(color)
                }
            }

            Text("\(turns) \(turns == 1 ? "question" : "questions")")
                .font(BrandFont.caption)
                .foregroundStyle(Brand.textSecondary)
        }
        .frame(width: 330, alignment: .leading)
        .padding(26)
        .brandCardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(player.name), \(seat == 0 ? "goes first" : "turn \(seat + 1)"), \(turns) questions")
    }
}

#Preview {
    NavigationStack {
        MatchStartView(session: GameSession(
            players: [
                Player(name: "Hiruna", colorIndex: 0, avatar: .star),
                Player(name: "Nimal", colorIndex: 1, avatar: .bolt)
            ],
            settings: QuizSettings(category: .sriLankanCulture, questionCount: 10),
            questions: []
        ), onBegin: {})
    }
}
