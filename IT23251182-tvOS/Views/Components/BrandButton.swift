//
//  BrandButton.swift
//  IT23251182-tvOS
//
//  Focus-aware button styles for the Apple TV remote.
//
//  Why custom styles rather than the stock tvOS button?
//  There is no cursor on tvOS — the user drives a *focus ring* with the remote
//  or a keyboard's arrow keys. The focused control must be unmistakable from
//  across a room. These styles read the `isFocused` environment value, which
//  SwiftUI publishes inside a focusable control's own content, and respond with
//  a lift, a scale and an accent border.
//
//  Note: the nested view must NOT be named `Body` — that name collides with
//  `ButtonStyle`'s associated type and the compiler then demands it be as
//  accessible as the style itself.
//

import SwiftUI

// MARK: - Standard button

struct BrandButtonStyle: ButtonStyle {

    enum Kind {
        case primary    // Accent fill — the main action on a screen.
        case secondary  // Card fill — supporting actions.
    }

    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        FocusAwareLabel(configuration: configuration, kind: kind)
    }

    private struct FocusAwareLabel: View {
        let configuration: Configuration
        let kind: Kind

        @Environment(\.isFocused) private var isFocused
        @Environment(\.brandAnimationsEnabled) private var animated

        var body: some View {
            configuration.label
                .font(BrandFont.label)
                .foregroundStyle(foreground)
                .padding(.horizontal, 44)
                .padding(.vertical, 22)
                .background(
                    RoundedRectangle(cornerRadius: BrandLayout.controlRadius, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrandLayout.controlRadius, style: .continuous)
                        .strokeBorder(border, lineWidth: isFocused ? 4 : 2)
                )
                .shadow(color: .black.opacity(isFocused ? 0.45 : 0.2),
                        radius: isFocused ? 22 : 10, x: 0, y: isFocused ? 12 : 6)
                .scaleEffect(scale)
                .animation(BrandMotion.focus(animated), value: isFocused)
                .animation(BrandMotion.press(animated), value: configuration.isPressed)
        }

        /// With Reduce Motion on, the control still changes colour and border —
        /// focus stays obvious, only the movement is removed.
        private var scale: CGFloat {
            guard animated else { return 1.0 }
            if configuration.isPressed { return 0.96 }
            return isFocused ? 1.06 : 1.0
        }

        private var foreground: Color {
            switch kind {
            case .primary:   return Brand.onAccent
            case .secondary: return isFocused ? Brand.onAccent : Brand.textPrimary
            }
        }

        private var background: Color {
            switch kind {
            case .primary:   return Brand.accent
            case .secondary: return isFocused ? Brand.accent : Brand.card
            }
        }

        private var border: Color {
            isFocused ? Color.white.opacity(0.85) : Brand.hairline
        }
    }
}

// MARK: - Large action / category card

/// The tile treatment shared by the home-screen actions and the category grid.
/// The *style* owns focus behaviour; the caller supplies the content.
struct BrandCardStyle: ButtonStyle {

    /// Marks the screen's main call to action, which keeps a permanent accent
    /// edge so it reads as primary even while something else holds focus.
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        FocusAwareCard(configuration: configuration, isPrimary: isPrimary)
    }

    private struct FocusAwareCard: View {
        let configuration: Configuration
        let isPrimary: Bool

        @Environment(\.isFocused) private var isFocused
        @Environment(\.brandAnimationsEnabled) private var animated

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 34)
                .background(
                    RoundedRectangle(cornerRadius: BrandLayout.cardRadius, style: .continuous)
                        .fill(isFocused ? Brand.cardFocused : Brand.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrandLayout.cardRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                )
                .shadow(color: .black.opacity(isFocused ? 0.5 : 0.25),
                        radius: isFocused ? 30 : 14, x: 0, y: isFocused ? 16 : 8)
                .scaleEffect(scale)
                .animation(BrandMotion.focus(animated), value: isFocused)
                .animation(BrandMotion.press(animated), value: configuration.isPressed)
        }

        private var scale: CGFloat {
            guard animated else { return 1.0 }
            if configuration.isPressed { return 0.97 }
            return isFocused ? 1.05 : 1.0
        }

        private var borderColor: Color {
            if isFocused { return Brand.accent }
            return isPrimary ? Brand.accent.opacity(0.45) : Brand.hairline
        }

        private var borderWidth: CGFloat {
            isFocused ? 5 : (isPrimary ? 3 : 2)
        }
    }
}
