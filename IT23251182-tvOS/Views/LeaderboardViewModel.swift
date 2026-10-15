//
//  LeaderboardViewModel.swift
//  IT23251182-tvOS
//
//  State for the leaderboard screen.
//
//  Owns reading the saved history, building the all-time table and clearing it.
//  The view renders what this publishes and asks for a reload when it appears,
//  so a match finished moments ago is already on the board.
//

import Foundation
import Observation

@Observable
final class LeaderboardViewModel {

    private(set) var matches: [MatchResult] = []
    private(set) var entries: [LeaderboardEntry] = []
    /// True when the last load found unreadable stored data and discarded it.
    private(set) var didRecoverFromCorruptedData = false

    private let store: MatchHistoryStore

    init(store: MatchHistoryStore) {
        self.store = store
        reload()
    }

    func reload() {
        matches = store.load()
        entries = LeaderboardRanking.entries(from: matches)
        didRecoverFromCorruptedData = store.didDiscardCorruptedData
    }

    var isEmpty: Bool { matches.isEmpty }

    var matchCountLabel: String {
        "\(matches.count) \(matches.count == 1 ? "match" : "matches") played on this Apple TV"
    }

    var totalQuestionsAnswered: Int {
        entries.reduce(0) { $0 + $1.totalAnswered }
    }

    var leaderName: String? { entries.first?.name }

    /// Deletes every saved match. Irreversible, which is why the screen asks
    /// for confirmation before calling it.
    func clearHistory() {
        store.clear()
        reload()
    }
}
