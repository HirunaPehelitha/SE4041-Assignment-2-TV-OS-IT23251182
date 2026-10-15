//
//  MatchHistoryStore.swift
//  IT23251182-tvOS
//
//  Saved match results for this Apple TV.
//
//  The important property is that saving is *idempotent*. The results screen
//  can appear more than once for the same match — the view reloads, the player
//  comes back from Review Answers, SwiftUI re-runs `onAppear` — and none of
//  that may add a second copy of the same game to the history. `MatchResult`
//  already carries a stable `id`, so the store refuses any result it has
//  already recorded.
//

import Foundation

final class MatchHistoryStore {

    private enum Key {
        static let history = "history.matches"
    }

    /// Keeps storage bounded; a party game does not need an unbounded log.
    static let maximumStoredMatches = 50

    private let defaults: UserDefaults

    /// Injected so tests use a throwaway suite rather than the real history.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Set when the last `load()` found unreadable data and discarded it, so
    /// the UI can say so rather than silently showing an empty leaderboard.
    private(set) var didDiscardCorruptedData = false

    /// All saved matches, most recent first.
    ///
    /// Three failure modes are handled explicitly, because all three are real:
    /// the key is missing (first launch), the data is empty, or the data cannot
    /// be decoded (a model change, or a partially written value). None of them
    /// may stop the app working, so each yields an empty history — and in the
    /// corrupted case the bad value is removed so it cannot fail again forever.
    func load() -> [MatchResult] {
        guard let data = defaults.data(forKey: Key.history) else {
            return []            // nothing saved yet
        }
        guard !data.isEmpty else {
            defaults.removeObject(forKey: Key.history)
            return []            // empty value, treat as nothing saved
        }

        do {
            let stored = try JSONDecoder().decode([MatchResult].self, from: data)
            didDiscardCorruptedData = false
            return stored.sorted { $0.playedAt > $1.playedAt }
        } catch {
            // Unreadable. Discard it rather than leaving a value that will fail
            // on every launch from now on.
            defaults.removeObject(forKey: Key.history)
            didDiscardCorruptedData = true
            return []
        }
    }

    /// Saves a completed match.
    ///
    /// - Returns: `true` if it was newly stored, `false` if this exact match was
    ///   already in the history and was therefore ignored.
    @discardableResult
    func save(_ result: MatchResult) -> Bool {
        // An abandoned round never reaches here — the engine only produces a
        // MatchResult in finish(). This is the belt-and-braces check: a result
        // with no players is not a completed match and is never stored.
        guard !result.scores.isEmpty else { return false }

        var history = load()

        guard !history.contains(where: { $0.id == result.id }) else {
            return false
        }

        history.insert(result, at: 0)
        if history.count > Self.maximumStoredMatches {
            history = Array(history.prefix(Self.maximumStoredMatches))
        }

        guard let data = try? JSONEncoder().encode(history) else { return false }
        defaults.set(data, forKey: Key.history)
        return true
    }

    func contains(_ result: MatchResult) -> Bool {
        load().contains { $0.id == result.id }
    }

    func clear() {
        defaults.removeObject(forKey: Key.history)
    }
}
