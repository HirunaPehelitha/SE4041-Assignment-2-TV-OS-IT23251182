//
//  QuizGameView.swift
//  IT23251182-tvOS
//
//  The gameplay screen.
//
//  This view contains no game rules. It reads `phase` from `QuizGameViewModel`
//  to decide what to draw, and calls `start()`, `submitAnswer(_:)` and
//  `continueAfterReveal()`. Whether an answer is accepted, what it scores and
//  when the match ends are all decided by the engine.
//

import SwiftUI

struct QuizGameView: View {

    /// Called once, when the match is over, with the final result.
    let onFinished: (MatchResult) -> Void

    @State private var viewModel: QuizGameViewModel

    @Environment(\.brandAnimationsEnabled) private var animated

    /// Focus on the answer options while a question is open.
    @FocusState private var focusedOption: Int?
    /// Focus on the continue button once the answer is revealed.
    @FocusState private var continueFocused: Bool

    /// The player whose score just went up, so the strip can flash their chip.
    /// Cleared when the next question opens.
    @State private var justScoredPlayerID: UUID?

    init(viewModel: QuizGameViewModel, onFinished: @escaping (MatchResult) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            BrandBackground()

            switch viewModel.phase {
            case .ready:
                readyState
            case .asking, .revealing:
                playfield
            case .finished:
                // A brief holding state; the navigation fires from .onChange below.
                ProgressView()
                    .tint(Brand.accent)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.tearDown() }
        // The engine decides the match is over; this view performs the
        // navigation exactly once, rather than the engine knowing about routes.
        .onChange(of: viewModel.phase) { _, newPhase in
            if case .finished(let result) = newPhase {
                onFinished(result)
            }
        }
    }

    // MARK: Ready

    private var readyState: some View {
        VStack(spacing: 24) {
            ProgressView().tint(Brand.accent)
            if let first = viewModel.openingPlayer {
                Text("\(first.name) goes first")
                    .font(BrandFont.heading)
                    .foregroundStyle(Brand.textSecondary)
            }
        }
    }

    // MARK: Playfield

    private var playfield: some View {
        VStack(alignment: .leading, spacing: 0) {

            topBar
                .padding(.bottom, 18)

            progressBar
                .padding(.bottom, 26)

            questionText
                .padding(.bottom, 26)

            answerGrid

            Spacer(minLength: 18)

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, BrandLayout.screenPaddingH)
        .padding(.vertical, BrandLayout.screenPaddingV)
    }

    // MARK: Top bar — whose turn, question number, clock

    private var topBar: some View {
        HStack(alignment: .center, spacing: 28) {

            if let player = viewModel.currentPlayer {
                let color = Brand.playerColor(at: player.colorIndex)

                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.18))
                            .frame(width: 84, height: 84)
                        Image(systemName: player.avatar.symbolName)
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(BrandFont.title)
                            .foregroundStyle(Brand.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Your turn")
                            .font(BrandFont.caption)
                            .foregroundStyle(color)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(player.name)'s turn")
            }

            Spacer()

            if let band = viewModel.currentPerformanceBand {
                // Adaptive Challenge is explainable by design: the player can
                // see which way it is leaning and why, while they play.
                HStack(spacing: 10) {
                    Image(systemName: band.symbolName)
                        .font(.system(size: 24, weight: .semibold))
                    Text(band.displayName)
                        .font(BrandFont.caption)
                        .tracking(1.5)
                }
                .foregroundStyle(Brand.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Brand.accentMuted))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Adaptive challenge: \(band.displayName). \(band.explanation)")
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text("QUESTION")
                    .font(BrandFont.caption)
                    .tracking(3)
                    .foregroundStyle(Brand.textTertiary)
                Text("\(viewModel.questionNumber) of \(viewModel.totalQuestions)")
                    .font(BrandFont.heading)
                    .foregroundStyle(Brand.textPrimary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Question \(viewModel.questionNumber) of \(viewModel.totalQuestions)")

            CountdownRing(secondsRemaining: viewModel.remainingSeconds,
                          fraction: viewModel.timeFraction,
                          isRunning: viewModel.phase.isAsking)
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(Brand.accent)
                    .frame(width: max(0, geometry.size.width * viewModel.progress))
                    .animation(animated ? .easeOut(duration: 0.3) : nil, value: viewModel.progress)
            }
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Match progress")
        .accessibilityValue("\(Int(viewModel.progress * 100)) percent")
    }

    private var questionText: some View {
        Text(viewModel.currentQuestion?.prompt ?? "")
            .font(BrandFont.title)
            .foregroundStyle(Brand.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Answers

    private var answerGrid: some View {
        let options = viewModel.currentQuestion?.options ?? []
        let letters = ["A", "B", "C", "D"]

        return VStack(spacing: 16) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                AnswerCard(
                    letter: letters.indices.contains(index) ? letters[index] : "\(index + 1)",
                    text: option,
                    state: state(for: index)
                ) {
                    viewModel.submitAnswer(index)
                }
                .focused($focusedOption, equals: index)
                // Once an answer is in, the options stop being focusable, so a
                // second press cannot land on another option at all.
                .disabled(!viewModel.phase.isAsking)
            }
        }
        .defaultFocus($focusedOption, 0)
        // Returns focus to the first option when a new question appears.
        .onChange(of: viewModel.currentQuestionIndex) { _, _ in
            if viewModel.phase.isAsking { focusedOption = 0 }
        }
    }

    /// Translates the engine's phase into how each card should look.
    private func state(for index: Int) -> AnswerCardState {
        guard let outcome = viewModel.phase.outcome,
              let question = viewModel.currentQuestion else {
            return .selectable
        }
        if index == question.correctIndex { return .correct }
        if index == outcome.selectedIndex { return .chosenIncorrect }
        return .dimmed
    }

    // MARK: Bottom bar — feedback, standings, continue

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 18) {

            if let outcome = viewModel.phase.outcome {
                feedback(for: outcome)
            }

            HStack(alignment: .center, spacing: BrandLayout.gutter) {
                ScoreStrip(standings: viewModel.standings,
                           currentPlayerID: viewModel.currentPlayer?.id,
                           justScoredPlayerID: justScoredPlayerID)

                Spacer()

                if viewModel.phase.isRevealing {
                    Button {
                        viewModel.continueAfterReveal()
                    } label: {
                        Label(viewModel.continueButtonTitle,
                              systemImage: viewModel.isLastQuestion ? "flag.checkered" : "arrow.right")
                    }
                    .buttonStyle(BrandButtonStyle(kind: .primary))
                    .focused($continueFocused)
                    .accessibilityHint(viewModel.isLastQuestion
                                       ? "Ends the match and shows the results"
                                       : "Passes the remote to the next player")
                }
            }
        }
        // Moving focus onto the continue button is what stops a player who was
        // mashing the remote from immediately skipping the reveal.
        .onChange(of: viewModel.phase.isRevealing) { _, revealing in
            if revealing { continueFocused = true }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            // Flash only on a correct answer; a wrong one has its own feedback.
            if case .revealing(_, let outcome) = newPhase, outcome.isCorrect {
                justScoredPlayerID = viewModel.currentPlayer?.id
            } else if newPhase.isAsking {
                justScoredPlayerID = nil
            }
        }
    }

    private func feedback(for outcome: TurnOutcome) -> some View {
        let color: Color = outcome.isCorrect ? Brand.correct : Brand.incorrect
        let symbol = outcome.isCorrect
            ? "checkmark.circle.fill"
            : (outcome == .timedOut ? "clock.badge.exclamationmark.fill" : "xmark.circle.fill")

        return HStack(alignment: .firstTextBaseline, spacing: 16) {
            Label {
                Text(outcome.headline)
                    .font(BrandFont.heading)
                    .foregroundStyle(color)
            } icon: {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(color)
            }

            Text(outcome.isCorrect
                 ? "+\(outcome.pointsAwarded) points"
                 : "No points this turn")
                .font(BrandFont.caption)
                .foregroundStyle(Brand.textSecondary)

            if let explanation = viewModel.currentQuestion?.explanation {
                Text(explanation)
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
