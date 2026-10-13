//
//  BrandComponents.swift
//  IT23251182-tvOS
//
//  Shared presentation pieces: the wordmark, screen headers, stat pills and the
//  load-failure state. Factored out so screens stay small and consistent.
//

import SwiftUI

// MARK: - Wordmark

/// The Brain Battle lockup: badge, name and tagline.
struct BrandLockup: View {
    var showTagline: Bool = true

    var body: some View {
        HStack(spacing: 30) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Brand.accent)
                    .frame(width: 110, height: 110)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Brand.onAccent)
            }
            .shadow(color: Brand.accent.opacity(0.35), radius: 34, x: 0, y: 14)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    Text("BRAIN").foregroundStyle(Brand.textPrimary)
                    Text("BATTLE").foregroundStyle(Brand.accent)
                }
                .font(BrandFont.hero)

                if showTagline {
                    Text("Think Fast. Play Together.")
                        .font(BrandFont.body)
                        .foregroundStyle(Brand.textSecondary)
                }
            }
        }
        // VoiceOver reads one phrase instead of spelling out two separate words.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showTagline
                            ? "Brain Battle. Think fast, play together."
                            : "Brain Battle")
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Headers

/// Standard secondary-screen header: large title with a supporting subtitle.
struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BrandFont.title)
                .foregroundStyle(Brand.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(BrandFont.body)
                    .foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Small all-caps section label used above a group of content.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(BrandFont.caption)
            .tracking(4)
            .foregroundStyle(Brand.textTertiary)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Stats

/// A compact value/label pill, e.g. "24 / QUESTIONS".
struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(BrandFont.heading)
                .foregroundStyle(Brand.accent)
            Text(label.uppercased())
                .font(BrandFont.caption)
                .tracking(2)
                .foregroundStyle(Brand.textTertiary)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
        .brandCardSurface(radius: BrandLayout.controlRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Empty & failure states

/// Shown when a screen has nothing to display yet. An explicit, explained empty
/// state is honest; a blank screen looks like a bug.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 26) {
            Image(systemName: symbol)
                .font(.system(size: 92, weight: .semibold))
                .foregroundStyle(Brand.accent.opacity(0.85))

            Text(title)
                .font(BrandFont.heading)
                .foregroundStyle(Brand.textPrimary)

            Text(message)
                .font(BrandFont.body)
                .foregroundStyle(Brand.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 1000)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Shown if the question bank cannot be loaded.
struct LoadFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(Brand.incorrect)

            Text("Question bank unavailable")
                .font(BrandFont.title)
                .foregroundStyle(Brand.textPrimary)

            Text(message)
                .font(BrandFont.body)
                .foregroundStyle(Brand.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 1100)

            Button("Try Again", action: retry)
                .buttonStyle(BrandButtonStyle(kind: .primary))
                .accessibilityHint("Reloads the question bank from the app bundle")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
