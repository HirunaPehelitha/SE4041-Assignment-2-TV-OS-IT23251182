//
//  LeaderboardView.swift
//  IT23251182-tvOS
//
//  All-time standings and match history for this Apple TV.
//
//  Two tables: players ranked across every saved match by the documented rule
//  in `LeaderboardRanking`, and the matches themselves, most recent first.
//

import SwiftUI

struct LeaderboardView: View {

    @State private var viewModel: LeaderboardViewModel
    @State private var isConfirmingClear = false

    init(store: MatchHistoryStore) {
        _viewModel = State(initialValue: LeaderboardViewModel(store: store))
    }

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 0) {

                header
                    .padding(.horizontal, BrandLayout.screenPaddingH)
                    .padding(.top, BrandLayout.screenPaddingV)
                    .padding(.bottom, 22)

                if viewModel.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
        }
        // Reloaded on appear so a match finished moments ago is already here.
        .onAppear { viewModel.reload() }
        .alert("Clear match history?", isPresented: $isConfirmingClear) {
            Button("Cancel", role: .cancel) { }
            Button("Clear History", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("This permanently deletes all \(viewModel.matches.count) saved matches from this Apple TV. It cannot be undone.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            ScreenHeader(
                title: "Leaderboard",
                subtitle: viewModel.isEmpty
                    ? "Results are saved to this Apple TV after each completed match."
                    : viewModel.matchCountLabel
            )

            Spacer()

            if !viewModel.isEmpty {
                Button {
                    isConfirmingClear = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .buttonStyle(BrandButtonStyle(kind: .secondary))
                .accessibilityHint("Deletes every saved match. Asks for confirmation first.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 28) {
            EmptyStateView(
                symbol: "trophy",
                title: "No matches played yet",
                message: "Finish a game and the final scoreboard is saved here, so your group can track who is ahead over time."
            )

            if viewModel.didRecoverFromCorruptedData {
                Label("Previously saved results could not be read and were cleared.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.incorrect)
            }
        }
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "All-time standings")
                    ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRow(entry: entry, position: index + 1)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "Recent matches")
                    ForEach(viewModel.matches) { match in
                        MatchHistoryRow(match: match)
                    }
                }

                Text("Ranked by total points, then wins, then accuracy, then fewest matches played, then name.")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textTertiary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, BrandLayout.screenPaddingH)
            .padding(.bottom, BrandLayout.screenPaddingV)
        }
    }
}

// MARK: - All-time row

private struct LeaderboardRow: View {

    let entry: LeaderboardEntry
    let position: Int

    private var color: Color { Brand.playerColor(at: entry.colorIndex) }

    var body: some View {
        Button { } label: {
            HStack(spacing: 24) {
                Text("\(position)")
                    .font(BrandFont.heading)
                    .foregroundStyle(position == 1 ? Brand.accent : Brand.textTertiary)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .leading)

                ZStack {
                    Circle().fill(color.opacity(0.18)).frame(width: 62, height: 62)
                    Image(systemName: entry.avatar.symbolName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(color)
                }

                Text(entry.name)
                    .font(BrandFont.label)
                    .foregroundStyle(Brand.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                statColumn("\(entry.totalPoints)", "POINTS", tint: Brand.accent)
                statColumn("\(entry.wins)", "WINS")
                statColumn("\(entry.matchesPlayed)", "PLAYED")
                statColumn("\(entry.accuracyPercent)%", "ACCURACY")
            }
        }
        .buttonStyle(BrandRowStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Position \(position). \(entry.name). \(entry.totalPoints) points, \(entry.wins) wins from \(entry.matchesPlayed) matches, \(entry.accuracyPercent) percent accuracy.")
    }

    private func statColumn(_ value: String, _ label: String, tint: Color = Brand.textPrimary) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(BrandFont.label)
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(BrandFont.caption)
                .tracking(1.5)
                .foregroundStyle(Brand.textTertiary)
        }
        .frame(width: 150, alignment: .trailing)
    }
}

// MARK: - Match row

private struct MatchHistoryRow: View {

    let match: MatchResult

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        Button { } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    Image(systemName: match.settings.category?.symbolName ?? "square.grid.2x2.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Brand.accent)

                    Text(match.settings.categoryDisplayName)
                        .font(BrandFont.label)
                        .foregroundStyle(Brand.textPrimary)

                    if match.isDraw {
                        Text("TIE")
                            .font(BrandFont.caption)
                            .tracking(2)
                            .foregroundStyle(Brand.onAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Brand.accent))
                    }

                    Spacer()

                    Text("\(match.totalQuestionsAsked) questions")
                        .font(BrandFont.caption)
                        .foregroundStyle(Brand.textTertiary)

                    Text(Self.dateFormatter.string(from: match.playedAt))
                        .font(BrandFont.caption)
                        .foregroundStyle(Brand.textTertiary)
                }

                HStack(spacing: 14) {
                    ForEach(match.ranking) { entry in
                        let color = Brand.playerColor(at: entry.player.colorIndex)
                        let isWinner = match.winners.contains(entry)

                        HStack(spacing: 10) {
                            Image(systemName: isWinner ? "trophy.fill" : entry.player.avatar.symbolName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(isWinner ? Brand.accent : color)
                            Text(entry.player.name)
                                .font(BrandFont.caption)
                                .foregroundStyle(Brand.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(entry.score)")
                                .font(BrandFont.caption)
                                .foregroundStyle(isWinner ? Brand.accent : color)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.05)))
                        .overlay(Capsule().strokeBorder(
                            isWinner ? Brand.accent.opacity(0.6) : Brand.hairline, lineWidth: 2))
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(BrandRowStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let summary = match.ranking.map { "\($0.player.name) \($0.score)" }.joined(separator: ", ")
        return "\(match.settings.categoryDisplayName), \(Self.dateFormatter.string(from: match.playedAt)). \(summary)."
    }
}
