//
//  MatchResultsView.swift
//  IT23251182-tvOS
//
//  The end-of-match scoreboard.
//
//  Every number comes from the `MatchResult` the engine produced from actual
//  play. The view performs no scoring and no ranking of its own — it renders
//  what `MatchResultsViewModel` publishes and reports which button was pressed.
//

import SwiftUI

struct MatchResultsView: View {

    let onPlayAgain: (GameSession) -> Void
    let onReviewAnswers: (MatchResult) -> Void
    let onReturnHome: () -> Void

    @State private var viewModel: MatchResultsViewModel

    @Environment(\.brandAnimationsEnabled) private var animated

    @State private var hasAppeared = false
    /// Drives the winner's entrance. Separate from `hasAppeared` so the
    /// celebration can be delayed slightly behind the cards.
    @State private var winnerRevealed = false

    @FocusState private var focusedAction: ResultsAction?

    private enum ResultsAction: Hashable {
        case playAgain, review, home
    }

    init(viewModel: MatchResultsViewModel,
         onPlayAgain: @escaping (GameSession) -> Void,
         onReviewAnswers: @escaping (MatchResult) -> Void,
         onReturnHome: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onPlayAgain = onPlayAgain
        self.onReviewAnswers = onReviewAnswers
        self.onReturnHome = onReturnHome
    }

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 22)

                statsRow
                    .padding(.bottom, 24)

                scoreboard

                Spacer(minLength: 20)

                actions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, BrandLayout.screenPaddingH)
            .padding(.vertical, BrandLayout.screenPaddingV)
        }
        .onAppear {
            // Safe to call every time this screen appears: the view model and
            // the store each refuse a match that is already recorded.
            viewModel.recordResultIfNeeded()

            hasAppeared = true
            focusedAction = viewModel.canPlayAgain ? .playAgain : .home

            guard animated else {
                winnerRevealed = true
                return
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.25)) {
                winnerRevealed = true
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 18) {
                    Image(systemName: viewModel.isDraw ? "equal.circle.fill" : "trophy.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(Brand.accent)
                        // Restrained: the trophy settles into place once. No
                        // looping, nothing that keeps moving while people read.
                        .scaleEffect(winnerRevealed ? 1 : 0.6)
                        .opacity(winnerRevealed ? 1 : 0)
                        .accessibilityHidden(true)

                    Text(viewModel.headline)
                        .font(BrandFont.title)
                        .foregroundStyle(Brand.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityAddTraits(.isHeader)
                }

                Text(viewModel.subtitle)
                    .font(BrandFont.body)
                    .foregroundStyle(Brand.textSecondary)
            }

            Spacer()

            if viewModel.isSaved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textTertiary)
                    .accessibilityLabel("Result saved to this Apple TV")
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 0), value: hasAppeared)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: BrandLayout.gutter) {
            StatPill(value: "\(viewModel.questionsCompleted)", label: "Questions")
            StatPill(value: "\(viewModel.totalCorrectAnswers)", label: "Correct")
            StatPill(value: "\(viewModel.overallAccuracyPercent)%", label: "Accuracy")
            StatPill(value: "\(viewModel.topScore)", label: "Top Score")
            Spacer()
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 1), value: hasAppeared)
    }

    // MARK: Scoreboard

    private var scoreboard: some View {
        HStack(alignment: .top, spacing: BrandLayout.gutter) {
            ForEach(Array(viewModel.ranking.enumerated()), id: \.element.id) { index, entry in
                resultCard(entry: entry, position: index)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 28)
                    .animation(BrandMotion.entrance(animated, index: index + 2), value: hasAppeared)
            }
            Spacer()
        }
    }

    private func resultCard(entry: PlayerScore, position: Int) -> some View {
        let color = Brand.playerColor(at: entry.player.colorIndex)
        let isWinner = viewModel.isWinner(entry)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isWinner ? 0.26 : 0.16))
                        .frame(width: 76, height: 76)
                    Image(systemName: entry.player.avatar.symbolName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.player.name)
                        .font(BrandFont.cardTitle)
                        .foregroundStyle(Brand.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(viewModel.positionLabel(position))
                        .font(BrandFont.caption)
                        .foregroundStyle(color)
                }

                Spacer()

                if isWinner {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Brand.accent)
                        .accessibilityHidden(true)
                }
            }

            Text("\(entry.score)")
                .font(BrandFont.metricBig)
                .foregroundStyle(isWinner ? Brand.accent : Brand.textPrimary)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.accuracyLabel(for: entry))
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)
                accuracyBar(fraction: entry.accuracy, color: color)
            }
        }
        .frame(width: 330, alignment: .leading)
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: BrandLayout.cardRadius, style: .continuous)
                .fill(Brand.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandLayout.cardRadius, style: .continuous)
                .strokeBorder(isWinner ? Brand.accent : Brand.hairline,
                              lineWidth: isWinner ? 4 : 2)
        )
        // The winner's card lifts very slightly. That is the whole celebration.
        .scaleEffect(isWinner && winnerRevealed ? 1.03 : 1.0)
        .shadow(color: isWinner ? Brand.accent.opacity(winnerRevealed ? 0.25 : 0) : .black.opacity(0.25),
                radius: isWinner ? 26 : 14, x: 0, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.positionLabel(position)), \(entry.player.name), \(entry.score) points, \(viewModel.accuracyLabel(for: entry))")
    }

    private func accuracyBar(fraction: Double, color: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: BrandLayout.gutter) {

            if viewModel.canPlayAgain {
                Button {
                    // A new session every time: new id, newly shuffled questions,
                    // scores back to zero.
                    if let session = viewModel.makeRematchSession() {
                        onPlayAgain(session)
                    }
                } label: {
                    Label("Play Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BrandButtonStyle(kind: .primary))
                .focused($focusedAction, equals: .playAgain)
                .accessibilityHint("Starts a new match with the same players and category")
            }

            // Shown only when the match actually stored its turns, so the
            // control never leads to an empty screen.
            if viewModel.canReviewAnswers {
                Button {
                    onReviewAnswers(viewModel.result)
                } label: {
                    Label("Review Answers", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(BrandButtonStyle(kind: .secondary))
                .focused($focusedAction, equals: .review)
                .accessibilityHint("Shows every question and what each player answered")
            }

            Button(action: onReturnHome) {
                Label("Return Home", systemImage: "house.fill")
            }
            .buttonStyle(BrandButtonStyle(kind: .secondary))
            .focused($focusedAction, equals: .home)
            .accessibilityHint("Returns to the main menu")

            Spacer()
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 6), value: hasAppeared)
    }
}
