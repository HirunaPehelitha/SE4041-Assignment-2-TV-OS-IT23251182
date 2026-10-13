//
//  BrandToggleRow.swift
//  IT23251182-tvOS
//
//  A focusable on/off row built from a Button.
//
//  Why not SwiftUI's `Toggle`?
//  On tvOS a focused `Toggle` is drawn with the system's own light focus
//  appearance — a near-white capsule. That overrides the card styling and drops
//  our secondary text to roughly 1.5:1 against the fill, which is unreadable on
//  a television. Driving the control from a `Button` keeps the brand palette and
//  its measured AAA contrast in every state, at the cost of re-declaring the
//  accessibility traits ourselves, which is done below.
//

import SwiftUI

struct BrandToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var accessibilityHintText: String? = nil

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            RowContent(title: title, subtitle: subtitle, isOn: isOn)
        }
        .buttonStyle(BrandRowStyle())
        // The button is presented to VoiceOver as a single switch-like control
        // whose spoken value tracks the state.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(accessibilityHintText ?? subtitle)
        .accessibilityAddTraits(.isButton)
    }

    private struct RowContent: View {
        let title: String
        let subtitle: String
        let isOn: Bool

        var body: some View {
            HStack(alignment: .center, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(BrandFont.label)
                        .foregroundStyle(Brand.textPrimary)
                    Text(subtitle)
                        .font(BrandFont.caption)
                        .foregroundStyle(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 24)

                SwitchIndicator(isOn: isOn)
            }
        }
    }

    /// A hand-drawn switch so the on/off state uses the brand accent rather than
    /// the system tint, and stays legible against our own card fill.
    private struct SwitchIndicator: View {
        let isOn: Bool

        @Environment(\.brandAnimationsEnabled) private var animated

        var body: some View {
            HStack(spacing: 20) {
                Text(isOn ? "ON" : "OFF")
                    .font(BrandFont.caption)
                    .tracking(2)
                    .foregroundStyle(isOn ? Brand.accent : Brand.textTertiary)
                    .frame(width: 70, alignment: .trailing)

                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Brand.accent : Color.white.opacity(0.18))
                        .frame(width: 104, height: 54)

                    Circle()
                        .fill(isOn ? Brand.onAccent : Brand.textPrimary)
                        .frame(width: 42, height: 42)
                        .padding(.horizontal, 6)
                }
                .animation(BrandMotion.focus(animated), value: isOn)
            }
        }
    }
}

/// Focus treatment for a full-width settings row.
struct BrandRowStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        FocusAwareRow(configuration: configuration)
    }

    private struct FocusAwareRow: View {
        let configuration: Configuration

        @Environment(\.isFocused) private var isFocused
        @Environment(\.brandAnimationsEnabled) private var animated

        var body: some View {
            configuration.label
                .padding(.horizontal, 36)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandCardSurface(isFocused: isFocused)
                .scaleEffect(scale)
                .animation(BrandMotion.focus(animated), value: isFocused)
                .animation(BrandMotion.press(animated), value: configuration.isPressed)
        }

        /// A full-width row scales far less than a tile — a 5% lift on a
        /// 1700pt-wide control reads as the layout jumping, not as focus.
        private var scale: CGFloat {
            guard animated else { return 1.0 }
            if configuration.isPressed { return 0.99 }
            return isFocused ? 1.015 : 1.0
        }
    }
}
