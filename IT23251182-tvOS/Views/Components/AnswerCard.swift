//
//  AnswerCard.swift
//  IT23251182-tvOS
//
//  One of the four answer options, plus the countdown ring and score strip.
//

import SwiftUI

/// How an answer option should be drawn right now. Derived from the engine's
/// phase — the card itself decides nothing.
enum AnswerCardState: Equatable {
    /// The question is open and this option can be chosen.
    case selectable
    /// Revealed: this is the right answer.
    case correct
    /// Revealed: the player chose this and it was wrong.
    case chosenIncorrect
    /// Revealed: not chosen, not correct.
    case dimmed
}

struct AnswerCard: View {

    let letter: String
    let text: String
    let state: AnswerCardState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(badgeFill)
                        .frame(width: 64, height: 64)
                    if let symbol = badgeSymbol {
                        Image(systemName: symbol)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Brand.onAccent)
                    } else {
                        Text(letter)
                            .font(BrandFont.label)
                            .foregroundStyle(badgeTextColor)
                    }
                }

                Text(text)
                    .font(BrandFont.label)
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(AnswerCardStyle(state: state))
        .accessibilityLabel("\(letter). \(text)")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        switch state {
        case .selectable:      return ""
        case .correct:         return "Correct answer"
        case .chosenIncorrect: return "Your answer, incorrect"
        case .dimmed:          return ""
        }
    }

    private var badgeSymbol: String? {
        switch state {
        case .correct:         return "checkmark"
        case .chosenIncorrect: return "xmark"
        default:               return nil
        }
    }

    private var badgeFill: Color {
        switch state {
        case .correct:         return Brand.correct
        case .chosenIncorrect: return Brand.incorrect
        case .selectable:      return Color.white.opacity(0.10)
        case .dimmed:          return Color.white.opacity(0.05)
        }
    }

    private var badgeTextColor: Color {
        state == .dimmed ? Brand.textTertiary : Brand.textPrimary
    }

    private var textColor: Color {
        switch state {
        case .dimmed: return Brand.textTertiary
        default:      return Brand.textPrimary
        }
    }
}

/// Focus treatment for an answer option, with revealed states overriding it —
/// once the answer is out, the correct option must read as correct whether or
/// not the remote happens to be resting on it.
struct AnswerCardStyle: ButtonStyle {
    let state: AnswerCardState

    func makeBody(configuration: Configuration) -> some View {
        FocusAwareAnswer(configuration: configuration, state: state)
    }

    private struct FocusAwareAnswer: View {
        let configuration: Configuration
        let state: AnswerCardState

        @Environment(\.isFocused) private var isFocused
        @Environment(\.brandAnimationsEnabled) private var animated

        var body: some View {
            configuration.label
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: BrandLayout.cardRadius, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrandLayout.cardRadius, style: .continuous)
                        .strokeBorder(border, lineWidth: borderWidth)
                )
                .scaleEffect(scale)
                .animation(BrandMotion.focus(animated), value: isFocused)
                .animation(BrandMotion.focus(animated), value: state)
                .animation(BrandMotion.press(animated), value: configuration.isPressed)
        }

        private var fill: Color {
            switch state {
            case .correct:         return Brand.correct.opacity(0.22)
            case .chosenIncorrect: return Brand.incorrect.opacity(0.22)
            case .dimmed:          return Brand.card.opacity(0.6)
            case .selectable:      return isFocused ? Brand.cardFocused : Brand.card
            }
        }

        private var border: Color {
            switch state {
            case .correct:         return Brand.correct
            case .chosenIncorrect: return Brand.incorrect
            case .dimmed:          return Brand.hairline
            case .selectable:      return isFocused ? Brand.accent : Brand.hairline
            }
        }

        private var borderWidth: CGFloat {
            switch state {
            case .correct, .chosenIncorrect: return 5
            case .dimmed:                    return 2
            case .selectable:                return isFocused ? 5 : 2
            }
        }

        private var scale: CGFloat {
            guard animated, state == .selectable else { return 1.0 }
            if configuration.isPressed { return 0.98 }
            return isFocused ? 1.03 : 1.0
        }
    }
}

// MARK: - Countdown

/// Circular countdown. Turns amber then red as time runs out, so the state is
/// readable from across a room without reading the number.
struct CountdownRing: View {
    let secondsRemaining: Int
    let fraction: Double
    let isRunning: Bool

    @Environment(\.brandAnimationsEnabled) private var animated

    private var tint: Color {
        if !isRunning { return Brand.textTertiary }
        if fraction <= 0.25 { return Brand.incorrect }
        if fraction <= 0.5 { return Color(hex: 0xFF9F45) }
        return Brand.accent
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 12)

            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(animated ? .linear(duration: 0.9) : nil, value: fraction)

            VStack(spacing: -2) {
                Text("\(max(0, secondsRemaining))")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                Text("SEC")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Brand.textTertiary)
            }
        }
        .frame(width: 132, height: 132)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRunning ? "\(max(0, secondsRemaining)) seconds remaining" : "Timer stopped")
    }
}

// MARK: - Score strip

/// Compact live standings, shown throughout the match.
struct ScoreStrip: View {
    let standings: [PlayerScore]
    let currentPlayerID: UUID?

    var body: some View {
        HStack(spacing: 16) {
            ForEach(standings) { entry in
                let isCurrent = entry.player.id == currentPlayerID
                let color = Brand.playerColor(at: entry.player.colorIndex)

                HStack(spacing: 12) {
                    Image(systemName: entry.player.avatar.symbolName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(color)
                    Text(entry.player.name)
                        .font(BrandFont.caption)
                        .foregroundStyle(isCurrent ? Brand.textPrimary : Brand.textSecondary)
                        .lineLimit(1)
                    Text("\(entry.score)")
                        .font(BrandFont.caption)
                        .foregroundStyle(color)
                        .monospacedDigit()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(isCurrent ? color.opacity(0.16) : Color.white.opacity(0.04))
                )
                .overlay(
                    Capsule().strokeBorder(isCurrent ? color : Brand.hairline,
                                           lineWidth: isCurrent ? 3 : 2)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(entry.player.name) \(entry.score) points\(isCurrent ? ", taking this turn" : "")")
            }
        }
    }
}
