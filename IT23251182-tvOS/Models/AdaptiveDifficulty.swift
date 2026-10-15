//
//  AdaptiveDifficulty.swift
//  IT23251182-tvOS
//
//  Adaptive Challenge — a rule-based difficulty policy.
//
//  This is **not** machine learning. There is no model, no training and nothing
//  learned. It is a small set of fixed, readable rules: look at a player's last
//  few answers, decide which of three bands they are in, and weight the choice
//  of the next question accordingly. Every decision can be explained in one
//  sentence, which is why the quiz screen can show the player which band they
//  are in while they play.
//
//  Three properties the policy guarantees:
//
//  1. **Bounded.** No difficulty is ever excluded. Even a struggling player can
//     still draw a hard question, and a strong player still sees easy ones. The
//     weights shift the odds; they never close a door.
//  2. **Safe defaults.** Fewer than `minimumAnswersBeforeAdapting` answers means
//     no adaptation at all — a balanced mixture, exactly as if the feature were
//     off. A player's first turns are never judged on one lucky guess.
//  3. **Cannot stall a match.** Selection only ever chooses among questions
//     already in the session, which were validated and filtered to the chosen
//     category when the match was built. If weighting somehow degenerates, it
//     falls back to the first remaining question, so a match always continues.
//

import Foundation

/// How a player has been doing recently.
enum PerformanceBand: String, CaseIterable, Equatable {
    case struggling
    case steady
    case strong

    var displayName: String {
        switch self {
        case .struggling: return "Easier"
        case .steady:     return "Balanced"
        case .strong:     return "Harder"
        }
    }

    /// Shown beside the badge so the adjustment is never mysterious.
    var explanation: String {
        switch self {
        case .struggling: return "Recent answers were tough — leaning easier."
        case .steady:     return "A balanced mix of difficulties."
        case .strong:     return "On a good run — leaning harder."
        }
    }

    var symbolName: String {
        switch self {
        case .struggling: return "arrow.down.circle.fill"
        case .steady:     return "equal.circle.fill"
        case .strong:     return "arrow.up.circle.fill"
        }
    }
}

enum AdaptiveDifficultyPolicy {

    // MARK: Tunable rules

    /// Answers needed before the policy adapts at all.
    static let minimumAnswersBeforeAdapting = 2

    /// Only the most recent answers count, so a player who improves is not held
    /// back by a bad start — and one who coasts is not carried by an early run.
    static let recentWindow = 4

    /// At or above this recent accuracy, a player is doing well.
    static let strongThreshold = 0.70
    /// At or below this, they are finding it hard.
    static let strugglingThreshold = 0.35

    // MARK: Band

    /// Classifies a player from their recent answers, most recent last.
    /// `true` means correct; a timeout counts as incorrect.
    static func band(for recentAnswers: [Bool]) -> PerformanceBand {
        let window = Array(recentAnswers.suffix(recentWindow))

        // Safe default: too little history to judge.
        guard window.count >= minimumAnswersBeforeAdapting else { return .steady }

        let accuracy = Double(window.filter { $0 }.count) / Double(window.count)

        if accuracy >= strongThreshold { return .strong }
        if accuracy <= strugglingThreshold { return .struggling }
        return .steady
    }

    // MARK: Weights

    /// Relative selection weights per difficulty. Every value is at least 1, so
    /// no difficulty is ever impossible — that is the "bounded" part of the
    /// policy and the reason a match keeps its variety.
    static func weights(for band: PerformanceBand) -> [Difficulty: Int] {
        switch band {
        case .struggling: return [.easy: 5, .medium: 3, .hard: 1]
        case .steady:     return [.easy: 3, .medium: 4, .hard: 3]
        case .strong:     return [.easy: 1, .medium: 3, .hard: 5]
        }
    }

    static func weight(for difficulty: Difficulty, band: PerformanceBand) -> Int {
        weights(for: band)[difficulty] ?? 1
    }

    // MARK: Selection

    /// Chooses the next question from those still unused.
    ///
    /// - Parameters:
    ///   - candidates: the questions left in this match. Already validated and
    ///     already filtered to the chosen category when the session was built,
    ///     so anything picked here is guaranteed usable.
    ///   - band: the current player's band.
    /// - Returns: the index *within `candidates`*, or `nil` only when there are
    ///   no candidates at all.
    static func selectIndex<R: RandomNumberGenerator>(
        from candidates: [PreparedQuestion],
        band: PerformanceBand,
        using generator: inout R
    ) -> Int? {
        guard !candidates.isEmpty else { return nil }

        let weights = candidates.map { weight(for: $0.difficulty, band: band) }
        let total = weights.reduce(0, +)

        // Defensive: weights are always >= 1, so this cannot normally happen.
        // Falling back to the first candidate keeps the match moving rather
        // than returning nil and stalling the round.
        guard total > 0 else { return 0 }

        var roll = Int.random(in: 0..<total, using: &generator)
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll < 0 { return index }
        }
        return candidates.indices.last
    }
}
