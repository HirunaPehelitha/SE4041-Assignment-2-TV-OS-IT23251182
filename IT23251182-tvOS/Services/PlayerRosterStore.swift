//
//  PlayerRosterStore.swift
//  IT23251182-tvOS
//
//  Remembers the last roster so a returning group does not retype their names.
//
//  Deliberately small: it stores names and avatars only, as JSON in
//  `UserDefaults`. It is not a save-game and holds no scores. A failure to read
//  or write is swallowed and treated as "no saved roster" — a convenience
//  feature must never block someone from starting a match.
//

import Foundation

final class PlayerRosterStore {

    private enum Key {
        static let roster = "roster.lastUsed"
    }

    private let defaults: UserDefaults

    /// Injected so tests can use a throwaway suite instead of the real one.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Saves the roster. Only players with a usable name are stored, so a
    /// half-filled setup screen cannot overwrite a good saved roster.
    func save(_ players: [Player]) {
        let usable = players.filter(\.hasValidName)
        guard !usable.isEmpty else { return }

        if let data = try? JSONEncoder().encode(usable) {
            defaults.set(data, forKey: Key.roster)
        }
    }

    /// The last saved roster, or an empty array if there is none or it cannot
    /// be read (for example after a model change).
    func load() -> [Player] {
        guard let data = defaults.data(forKey: Key.roster), !data.isEmpty else {
            return []
        }

        do {
            let players = try JSONDecoder().decode([Player].self, from: data)
            // Guard against a stored roster larger than the game now supports.
            return Array(players.prefix(Player.maximumPlayers))
        } catch {
            // Unreadable, most likely because the Player model changed. Drop it
            // so the next save starts clean; a forgotten roster is a minor
            // inconvenience, a crash on launch is not.
            defaults.removeObject(forKey: Key.roster)
            return []
        }
    }

    func clear() {
        defaults.removeObject(forKey: Key.roster)
    }
}
