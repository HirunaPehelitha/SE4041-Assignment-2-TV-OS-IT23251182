//
//  CategoryPreviewPanel.swift
//  IT23251182-tvOS
//
//  The live briefing panel on the category screen.
//
//  On tvOS the focused item should explain itself without the player having to
//  commit to it. This panel tracks focus and updates as the remote moves across
//  the row, which is why the app no longer needs a separate detail screen.
//
//  It renders a `CategoryAvailability` and nothing else — no question data.
//

import SwiftUI

struct CategoryPreviewPanel: View {

    let summary: CategoryAvailability
    let isSelected: Bool

    @Environment(\.brandAnimationsEnabled) private var animated

    var body: some View {
        HStack(alignment: .top, spacing: 40) {

            icon

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 18) {
                    Text(summary.category.displayName)
                        .font(BrandFont.title)
                        .foregroundStyle(Brand.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if isSelected {
                        SelectedBadge()
                    }

                    if !summary.isPlayable {
                        LockedBadge()
                    }
                }

                Text(summary.category.blurb)
                    .font(BrandFont.body)
                    .foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let reason = summary.unavailableReason {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(BrandFont.caption)
                        .foregroundStyle(Brand.incorrect)
                        .padding(.top, 4)
                } else {
                    difficultyChips
                }
            }

            Spacer(minLength: 24)

            if summary.isPlayable {
                pointsColumn
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCardSurface()
        // A fast cross-fade keeps the panel feeling attached to the focus ring.
        // Anything slower reads as lag while scrubbing across the row.
        .animation(animated ? .easeOut(duration: 0.16) : nil, value: summary)
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(summary.isPlayable ? Brand.accentMuted : Color.white.opacity(0.06))
                .frame(width: 128, height: 128)

            Image(systemName: summary.category.symbolName)
                .font(.system(size: 62, weight: .semibold))
                .foregroundStyle(summary.isPlayable ? Brand.accent : Brand.textTertiary)
        }
    }

    private var difficultyChips: some View {
        HStack(spacing: 14) {
            ForEach(Difficulty.allCases) { difficulty in
                DifficultyChip(difficulty: difficulty, count: summary.count(for: difficulty))
            }
        }
        .padding(.top, 4)
    }

    private var pointsColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(summary.maximumPoints)")
                .font(BrandFont.metricBig)
                .foregroundStyle(Brand.accent)
            Text("POINTS AVAILABLE")
                .font(BrandFont.caption)
                .tracking(2)
                .foregroundStyle(Brand.textTertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.maximumPoints) points available")
    }
}

/// A read-only count chip. Intentionally not focusable: giving the remote
/// somewhere to land that does nothing creates dead ends in the focus graph.
struct DifficultyChip: View {
    let difficulty: Difficulty
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(difficulty.displayName.uppercased())
                .font(BrandFont.caption)
                .tracking(1.5)
                .foregroundStyle(Brand.textSecondary)
            Text("\(count)")
                .font(BrandFont.label)
                .foregroundStyle(count > 0 ? Brand.accent : Brand.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(Color.white.opacity(0.05))
        )
        .overlay(
            Capsule().strokeBorder(Brand.hairline, lineWidth: 2)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(difficulty.displayName) questions")
    }
}

struct SelectedBadge: View {
    var body: some View {
        Label("SELECTED", systemImage: "checkmark.circle.fill")
            .font(BrandFont.caption)
            .tracking(1.5)
            .foregroundStyle(Brand.onAccent)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Brand.accent))
            .accessibilityHidden(true)   // the card's own label already says this
    }
}

struct LockedBadge: View {
    var body: some View {
        Label("LOCKED", systemImage: "lock.fill")
            .font(BrandFont.caption)
            .tracking(1.5)
            .foregroundStyle(Brand.textSecondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Brand.hairline, lineWidth: 2))
            .accessibilityHidden(true)
    }
}
