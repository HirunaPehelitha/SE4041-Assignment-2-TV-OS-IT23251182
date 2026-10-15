//
//  LeaderboardEntry.swift
//  IT23251182-tvOS
//
//  One player's record across every saved match on this Apple TV.
//
//  Players are aggregated by **name**, not by id. A `Player` gets a fresh UUID
//  each time the setup screen is filled in, so the same person playing on two
//  evenings would otherwise appear twice. Names are compared case- and
//  whitespace-insensitively, which is also exactly the rule player setup uses
//  to reject duplicates within a single match.
//

import Foundation

struct LeaderboardEntry: Identifiable, Equatable, Hashable {

    /// The name as it was most recently entered, for display.
    let name: String
    /// Lower-cased, trimmed name used for grouping and as a stable identity.
    let nameKey: String
    let avatar: PlayerAvatar
    let colorIndex: Int

    var totalPoints: Int
    var matchesPlayed: Int
    var wins: Int
    var totalCorrect: Int
    var totalAnswered: Int

    var id: String { nameKey }

    var accuracy: Double {
        guard totalAnswered > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAnswered)
    }

    var accuracyPercent: Int { Int((accuracy * 100).rounded()) }

    var averagePoints: Int {
        guard matchesPlayed > 0 else { return 0 }
        return Int((Double(totalPoints) / Double(matchesPlayed)).rounded())
    }
}

enum LeaderboardRanking {

    /// The documented ranking rule, applied in this order:
    ///
    /// 1. **Total points**, highest first — the headline measure.
    /// 2. **Wins**, highest first — rewards winning over merely scoring.
    /// 3. **Accuracy**, highest first — separates players level on both.
    /// 4. **Fewer matches played** — the same points in fewer games ranks higher.
    /// 5. **Name, A to Z** — a final tiebreak so the order is *fully*
    ///    deterministic. Without it, two identical records could swap places
    ///    between launches and the board would look unstable.
    ///
    /// Every step compares a stored integer or string, so the result never
    /// depends on dictionary ordering or on when the data was read.
    static func sorted(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        entries.sorted { lhs, rhs in
            if lhs.totalPoints != rhs.totalPoints { return lhs.totalPoints > rhs.totalPoints }
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            if lhs.accuracy != rhs.accuracy { return lhs.accuracy > rhs.accuracy }
            if lhs.matchesPlayed != rhs.matchesPlayed { return lhs.matchesPlayed < rhs.matchesPlayed }
            return lhs.nameKey < rhs.nameKey
        }
    }

    /// Builds the all-time table from saved matches.
    static func entries(from matches: [MatchResult]) -> [LeaderboardEntry] {
        var byKey: [String: LeaderboardEntry] = [:]

        // Oldest first, so the display name and avatar end up being the most
        // recent ones a player used.
        for match in matches.sorted(by: { $0.playedAt < $1.playedAt }) {
            let winnerIDs = Set(match.winners.map(\.id))

            for score in match.scores {
                let key = score.player.nameKey
                guard !key.isEmpty else { continue }

                var entry = byKey[key] ?? LeaderboardEntry(
                    name: score.player.trimmedName,
                    nameKey: key,
                    avatar: score.player.avatar,
                    colorIndex: score.player.colorIndex,
                    totalPoints: 0, matchesPlayed: 0, wins: 0,
                    totalCorrect: 0, totalAnswered: 0
                )

                entry = LeaderboardEntry(
                    name: score.player.trimmedName,
                    nameKey: key,
                    avatar: score.player.avatar,
                    colorIndex: score.player.colorIndex,
                    totalPoints: entry.totalPoints + score.score,
                    matchesPlayed: entry.matchesPlayed + 1,
                    wins: entry.wins + (winnerIDs.contains(score.id) ? 1 : 0),
                    totalCorrect: entry.totalCorrect + score.correctCount,
                    totalAnswered: entry.totalAnswered + score.answeredCount
                )

                byKey[key] = entry
            }
        }

        return sorted(Array(byKey.values))
    }
}
