//
//  PlayerSetupView.swift
//  IT23251182-tvOS
//
//  Player setup: who is playing, and what they are called.
//
//  The view renders the roster and the current validation state. It makes no
//  rules of its own — "Start Battle" asks the view model for a session and only
//  navigates if it gets one back, so an invalid setup cannot start a match.
//

import SwiftUI

struct PlayerSetupView: View {

    /// Called with the built session when a match is actually started.
    let onStart: (GameSession) -> Void

    @State private var viewModel: PlayerSetupViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.brandAnimationsEnabled) private var animated

    @State private var hasAppeared = false

    init(viewModel: PlayerSetupViewModel, onStart: @escaping (GameSession) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onStart = onStart
    }

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 0) {

                header
                    .padding(.bottom, 26)

                categorySummary
                    .padding(.bottom, 26)

                SectionLabel(text: "Players")
                    .padding(.bottom, 14)

                playerRow

                Spacer(minLength: 20)

                footer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, BrandLayout.screenPaddingH)
            .padding(.vertical, BrandLayout.screenPaddingV)
        }
        .onAppear { hasAppeared = true }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            ScreenHeader(
                title: "Player Setup",
                subtitle: "Two to four players share one remote and take turns."
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

    // MARK: Selected category

    /// Everything here comes from the `QuizSettings` handed in by the category
    /// screen — it is the visible proof the selection travelled.
    private var categorySummary: some View {
        HStack(spacing: BrandLayout.gutter) {
            if let category = viewModel.settings.category {
                HStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Brand.accentMuted)
                            .frame(width: 72, height: 72)
                        Image(systemName: category.symbolName)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Brand.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                            .font(BrandFont.heading)
                            .foregroundStyle(Brand.textPrimary)
                        Text(viewModel.turnsDescription)
                            .font(BrandFont.caption)
                            .foregroundStyle(Brand.textSecondary)
                    }
                }
                .padding(24)
                .brandCardSurface()
                .accessibilityElement(children: .combine)
            }

            StatPill(value: "\(viewModel.questionCount)", label: "Questions")
            StatPill(value: "\(viewModel.players.count)", label: "Players")
            Spacer()
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 0), value: hasAppeared)
    }

    // MARK: Roster

    private var playerRow: some View {
        HStack(alignment: .top, spacing: BrandLayout.gutter) {
            ForEach(Array(viewModel.players.enumerated()), id: \.element.id) { index, player in
                PlayerSlotCard(
                    player: player,
                    seat: index + 1,
                    isDuplicate: viewModel.isDuplicate(player),
                    canRemove: viewModel.canRemovePlayer,
                    onNameChange: { viewModel.setName($0, for: player.id) },
                    onCycleAvatar: { viewModel.cycleAvatar(for: player.id) },
                    onRemove: { viewModel.removePlayer(id: player.id) }
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 30)
                .animation(BrandMotion.entrance(animated, index: index + 1), value: hasAppeared)
            }

            if viewModel.canAddPlayer {
                addPlayerCard
            }
        }
    }

    private var addPlayerCard: some View {
        Button {
            viewModel.addPlayer()
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(Brand.accent)
                Text("Add Player")
                    .font(BrandFont.cardTitle)
                    .foregroundStyle(Brand.textPrimary)
                Text("Up to \(Player.maximumPlayers)")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        .buttonStyle(BrandCardStyle())
        .accessibilityLabel("Add player")
        .accessibilityHint("Adds another player, up to \(Player.maximumPlayers)")
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 18) {

            if let message = viewModel.validation.message {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.incorrect)
                    .accessibilityLabel("Cannot start: \(message)")
            } else if viewModel.hasUnevenTurns {
                // Not an error, but the players deserve to know before they start.
                Label("\(viewModel.questionCount) questions do not divide evenly — earlier seats take one extra turn.",
                      systemImage: "info.circle.fill")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)
            }

            HStack(spacing: BrandLayout.gutter) {
                Button {
                    // The view model is the gate: it returns a session only when
                    // the setup is genuinely valid.
                    if let session = viewModel.startBattle() {
                        onStart(session)
                    }
                } label: {
                    Label("Start Battle", systemImage: "play.fill")
                }
                .buttonStyle(BrandButtonStyle(kind: .primary))
                .disabled(!viewModel.canStart)
                .opacity(viewModel.canStart ? 1 : 0.45)
                .accessibilityLabel("Start Battle")
                .accessibilityHint(viewModel.canStart
                                   ? "Starts the match"
                                   : viewModel.validation.message ?? "Setup is incomplete")

                Spacer()
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 6), value: hasAppeared)
    }
}

#Preview {
    NavigationStack {
        PlayerSetupView(
            viewModel: PlayerSetupViewModel(
                settings: QuizSettings(category: .sriLankanCulture, questionCount: 10),
                repository: PreviewSupport.loadedRepository()
            ),
            onStart: { _ in }
        )
    }
}
