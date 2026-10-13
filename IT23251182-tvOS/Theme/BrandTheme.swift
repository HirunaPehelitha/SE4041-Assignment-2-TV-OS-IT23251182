//
//  BrandTheme.swift
//  IT23251182-tvOS
//
//  Brain Battle — central design system.
//
//  Every colour, font size, radius and spacing value in the app is declared
//  here exactly once. No view hard-codes a colour or a font size, so the entire
//  product can be re-skinned from this single file.
//

import SwiftUI

// MARK: - Hex support

extension Color {
    /// Builds a colour from a 24-bit RGB hex literal, e.g. `Color(hex: 0xDFFF45)`.
    ///
    /// The brand is specified in hex, so expressing it in hex here removes the
    /// rounding errors that creep in when converting to 0...1 components by hand.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xFF) / 255.0,
            green:   Double((hex >> 8)  & 0xFF) / 255.0,
            blue:    Double( hex        & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Palette

/// Brand palette: deep navy-black surfaces with a luminous lime accent.
///
/// Contrast was measured against WCAG 2.1, all on the base background:
/// white 18.55:1, secondary 9.96:1, accent 16.37:1 — every pair exceeds AAA (7:1).
enum Brand {

    // Surfaces
    static let background    = Color(hex: 0x10131C)   // base screen
    static let card          = Color(hex: 0x191E2B)   // elevated card
    static let cardFocused   = Color(hex: 0x222838)   // card while focused

    /// Cards sit only 1.11:1 above the background, which is far too little to
    /// read as an edge on a television. Every card therefore also draws this
    /// hairline border — the separation comes from the stroke, not the fill.
    static let hairline      = Color.white.opacity(0.10)
    static let hairlineStrong = Color.white.opacity(0.18)

    // Accent
    static let accent        = Color(hex: 0xDFFF45)   // primary accent
    static let accentMuted   = Color(hex: 0xDFFF45).opacity(0.16)

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color(hex: 0xB7BECE)
    static let textTertiary  = Color(hex: 0xB7BECE).opacity(0.60)

    /// Text drawn on top of an accent-filled surface.
    static let onAccent      = Color(hex: 0x10131C)

    /// One colour per player seat, used to tell the slots apart at a glance.
    /// Each is bright enough to read against both card fills on a television.
    static let playerColors: [Color] = [
        Color(hex: 0xDFFF45),   // lime   — seat 1
        Color(hex: 0x5AC8FA),   // sky    — seat 2
        Color(hex: 0xFF9F45),   // amber  — seat 3
        Color(hex: 0xC792EA)    // violet — seat 4
    ]

    /// Wraps rather than trapping, so an unexpected seat index cannot crash a view.
    static func playerColor(at index: Int) -> Color {
        playerColors[((index % playerColors.count) + playerColors.count) % playerColors.count]
    }

    // Semantic feedback (used by gameplay in a later stage)
    static let correct       = Color(hex: 0x3ECF8E)
    static let incorrect     = Color(hex: 0xFF5C5C)
}

// MARK: - Typography

/// Type scale. tvOS lays out in 1920x1080 points and is read from roughly three
/// metres away, so the smallest token here is still 24pt — about the size of a
/// headline on an iPhone. Nothing in the app is allowed to be smaller.
enum BrandFont {
    static let hero      = Font.system(size: 92, weight: .heavy,    design: .rounded)
    static let title     = Font.system(size: 56, weight: .bold,     design: .rounded)
    static let heading   = Font.system(size: 38, weight: .semibold, design: .rounded)
    static let cardTitle = Font.system(size: 34, weight: .semibold, design: .rounded)
    static let body      = Font.system(size: 30, weight: .regular,  design: .rounded)
    static let label     = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let caption   = Font.system(size: 24, weight: .medium,   design: .rounded)
    static let metricBig = Font.system(size: 64, weight: .heavy,    design: .rounded)
}

// MARK: - Layout

enum BrandLayout {
    static let screenPaddingH: CGFloat = 90
    static let screenPaddingV: CGFloat = 70
    static let cardRadius:     CGFloat = 28
    static let controlRadius:  CGFloat = 20
    static let gutter:         CGFloat = 28
}

// MARK: - Motion

/// Whether decorative animation should play.
///
/// Driven by the user's own "Reduce Motion" switch in Settings *or* the system
/// accessibility setting — either one turns animation off. Components read this
/// instead of animating unconditionally, which is what makes the Settings
/// toggle produce a visible effect across the whole app.
private struct BrandAnimationsEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var brandAnimationsEnabled: Bool {
        get { self[BrandAnimationsEnabledKey.self] }
        set { self[BrandAnimationsEnabledKey.self] = newValue }
    }
}

enum BrandMotion {
    /// Focus response. Must stay quick — on tvOS this fires on every remote swipe.
    static func focus(_ enabled: Bool) -> Animation? {
        enabled ? .easeOut(duration: 0.18) : nil
    }

    /// Press feedback.
    static func press(_ enabled: Bool) -> Animation? {
        enabled ? .easeOut(duration: 0.12) : nil
    }

    /// Staggered entrance for a list of items.
    static func entrance(_ enabled: Bool, index: Int) -> Animation? {
        enabled ? .easeOut(duration: 0.45).delay(0.12 + Double(index) * 0.07) : nil
    }
}

// MARK: - Background

/// The standard Brain Battle backdrop.
///
/// A flat near-black fills unevenly on a large OLED panel, so two very soft
/// radial blooms give the screen depth without introducing visible banding.
struct BrandBackground: View {
    var body: some View {
        ZStack {
            Brand.background

            RadialGradient(
                colors: [Brand.accent.opacity(0.10), .clear],
                center: UnitPoint(x: 0.08, y: 0.04),
                startRadius: 0,
                endRadius: 1200
            )

            RadialGradient(
                colors: [Color(hex: 0x2A3350).opacity(0.55), .clear],
                center: UnitPoint(x: 1.0, y: 1.0),
                startRadius: 0,
                endRadius: 1100
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card surface

/// The shared card treatment: fill, hairline border and restrained shadow.
/// Used by every elevated surface so they cannot drift apart visually.
struct BrandCardSurface: ViewModifier {
    var isFocused: Bool = false
    var radius: CGFloat = BrandLayout.cardRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isFocused ? Brand.cardFocused : Brand.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        isFocused ? Brand.accent : Brand.hairline,
                        lineWidth: isFocused ? 5 : 2
                    )
            )
            .shadow(color: .black.opacity(isFocused ? 0.5 : 0.25),
                    radius: isFocused ? 30 : 14, x: 0, y: isFocused ? 16 : 8)
    }
}

extension View {
    func brandCardSurface(isFocused: Bool = false,
                          radius: CGFloat = BrandLayout.cardRadius) -> some View {
        modifier(BrandCardSurface(isFocused: isFocused, radius: radius))
    }
}
