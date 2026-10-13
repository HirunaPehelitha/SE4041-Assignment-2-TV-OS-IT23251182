//
//  ActionCard.swift
//  IT23251182-tvOS
//
//  The home screen's navigation tiles.
//
//  `HomeAction` describes an action as data — including the route it pushes —
//  so the home screen renders a simple array rather than four hand-written
//  copies of the same card. Adding a menu item later is a one-line change.
//

import SwiftUI

struct HomeAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let route: AppRoute
    /// The screen's main call to action. Exactly one action should set this.
    var isPrimary: Bool = false

    /// Spoken by VoiceOver in place of reading the two labels separately.
    var accessibilityLabel: String { "\(title). \(subtitle)" }
}

/// The visual contents of a home action tile. Focus behaviour lives in
/// `BrandCardStyle`; this view only describes what the tile says.
struct ActionCardContent: View {
    let action: HomeAction

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(action.isPrimary ? Brand.accent : Brand.accentMuted)
                    .frame(width: 84, height: 84)

                Image(systemName: action.symbol)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(action.isPrimary ? Brand.onAccent : Brand.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(action.title)
                    .font(BrandFont.cardTitle)
                    .foregroundStyle(Brand.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(action.subtitle)
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)
                    // `reservesSpace` keeps every card exactly two lines tall, so
                    // a one-line subtitle does not sit higher than a wrapped one.
                    // Without it the tiles in the row end up visibly misaligned.
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The visual contents of a category tile on the selection screen.
///
/// Renders a `CategoryAvailability` summary — it never receives questions. The
/// locked and selected states are presentation only; whether a category *is*
/// playable is decided by the view model.
struct CategoryCardContent: View {
    let summary: CategoryAvailability
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 84, height: 84)

                    Image(systemName: summary.isPlayable ? summary.category.symbolName : "lock.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(iconTint)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Brand.accent)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.category.shortName)
                    .font(BrandFont.cardTitle)
                    .foregroundStyle(summary.isPlayable ? Brand.textPrimary : Brand.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(countLabel)
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(summary.isPlayable ? 1.0 : 0.55)
    }

    private var countLabel: String {
        summary.isPlayable ? "\(summary.totalQuestions) questions" : "Not enough questions"
    }

    private var iconBackground: Color {
        summary.isPlayable ? Brand.accentMuted : Color.white.opacity(0.06)
    }

    private var iconTint: Color {
        summary.isPlayable ? Brand.accent : Brand.textTertiary
    }
}
