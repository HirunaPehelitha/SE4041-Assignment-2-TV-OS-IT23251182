//
//  ReviewAnswersView.swift
//  IT23251182-tvOS
//
//  Every question from the finished match, with what was actually answered.
//
//  This screen reads `TurnRecord`s the engine appended as each turn resolved,
//  so the question text, the answer order the player saw, and the option they
//  chose are all the real thing rather than a reconstruction.
//
//  tvOS note: the list is scrolled with the remote, which means the rows have
//  to be focusable to move at all. Each row is a Button whose action is empty —
//  focus is its only purpose, and that is the one case where a control without
//  an action is correct on this platform.
//

import SwiftUI

struct ReviewAnswersView: View {

    let result: MatchResult

    @Environment(\.dismiss) private var dismiss

    private var turns: [TurnRecord] { result.turns }

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 0) {

                header
                    .padding(.horizontal, BrandLayout.screenPaddingH)
                    .padding(.top, BrandLayout.screenPaddingV)
                    .padding(.bottom, 22)

                if turns.isEmpty {
                    EmptyStateView(
                        symbol: "list.bullet.rectangle",
                        title: "Nothing to review",
                        message: "This match did not record any answers."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(turns) { turn in
                                TurnReviewRow(turn: turn)
                            }
                        }
                        .padding(.horizontal, BrandLayout.screenPaddingH)
                        .padding(.bottom, BrandLayout.screenPaddingV)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            ScreenHeader(
                title: "Review Answers",
                subtitle: "\(turns.count) \(turns.count == 1 ? "question" : "questions") · \(result.settings.categoryDisplayName)"
            )
            Spacer()
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(BrandButtonStyle(kind: .secondary))
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to the results")
        }
    }
}

/// One question, who answered it and what they chose.
private struct TurnReviewRow: View {

    let turn: TurnRecord

    private var color: Color { Brand.playerColor(at: turn.player.colorIndex) }

    private var statusColor: Color {
        turn.isCorrect ? Brand.correct : Brand.incorrect
    }

    private var statusSymbol: String {
        if turn.isCorrect { return "checkmark.circle.fill" }
        return turn.outcome.isTimeout ? "clock.badge.exclamationmark.fill" : "xmark.circle.fill"
    }

    var body: some View {
        Button { } label: {
            VStack(alignment: .leading, spacing: 14) {

                HStack(spacing: 16) {
                    Text("Q\(turn.questionNumber)")
                        .font(BrandFont.caption)
                        .tracking(2)
                        .foregroundStyle(Brand.textTertiary)

                    HStack(spacing: 10) {
                        Image(systemName: turn.player.avatar.symbolName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(color)
                        Text(turn.player.name)
                            .font(BrandFont.caption)
                            .foregroundStyle(Brand.textSecondary)
                    }

                    Spacer()

                    Label {
                        Text(turn.outcome.headline)
                            .font(BrandFont.caption)
                            .foregroundStyle(statusColor)
                    } icon: {
                        Image(systemName: statusSymbol)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(statusColor)
                    }

                    Text(turn.isCorrect ? "+\(turn.pointsAwarded)" : "0")
                        .font(BrandFont.caption)
                        .foregroundStyle(turn.isCorrect ? Brand.accent : Brand.textTertiary)
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }

                Text(turn.question.prompt)
                    .font(BrandFont.label)
                    .foregroundStyle(Brand.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    answerLine(label: "Correct answer",
                               value: turn.correctAnswer,
                               tint: Brand.correct)

                    if let chosen = turn.selectedAnswer, !turn.isCorrect {
                        answerLine(label: "Answered", value: chosen, tint: Brand.incorrect)
                    } else if turn.selectedAnswer == nil {
                        answerLine(label: "Answered", value: "No answer — time ran out",
                                   tint: Brand.textTertiary)
                    }

                    if let explanation = turn.question.explanation {
                        Text(explanation)
                            .font(BrandFont.caption)
                            .foregroundStyle(Brand.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .buttonStyle(BrandRowStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private func answerLine(label: String, value: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(BrandFont.caption)
                .foregroundStyle(Brand.textTertiary)
                .frame(width: 210, alignment: .leading)
            Text(value)
                .font(BrandFont.caption)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accessibilityDescription: String {
        let answered = turn.selectedAnswer ?? "no answer, time ran out"
        return "Question \(turn.questionNumber). \(turn.player.name). \(turn.question.prompt) "
            + "Correct answer \(turn.correctAnswer). Answered \(answered). \(turn.outcome.headline)."
    }
}
