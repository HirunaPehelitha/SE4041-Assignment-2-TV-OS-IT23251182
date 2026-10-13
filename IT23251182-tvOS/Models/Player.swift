//
//  Player.swift
//  IT23251182-tvOS
//
//  A participant in a local match.
//

import Foundation

/// One player sharing the Apple TV.
///
/// `id` is a `UUID` generated on the device — unlike `Question`, a player is
/// created at runtime rather than read from a fixed data file, and two players
/// may legitimately choose the same display name.
struct Player: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    /// Index into the UI's player colour palette. Stored rather than derived so
    /// a player keeps the same colour even if the turn order changes.
    var colorIndex: Int

    init(id: UUID = UUID(), name: String, colorIndex: Int) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
    }

    /// Brain Battle supports two to four players sharing one remote.
    static let minimumPlayers = 2
    static let maximumPlayers = 4
    /// Guards the UI against a name that would overflow a scoreboard row.
    static let maximumNameLength = 14

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasValidName: Bool {
        let trimmed = trimmedName
        return !trimmed.isEmpty && trimmed.count <= Self.maximumNameLength
    }

    /// Fallback label used if a player is left unnamed, so the scoreboard never
    /// shows a blank row.
    static func defaultName(forSeat seat: Int) -> String { "Player \(seat)" }
}
