//
//  PlayerAvatar.swift
//  IT23251182-tvOS
//
//  The symbol a player is identified by on screen.
//
//  SF Symbols rather than bundled images: they are vector, already installed on
//  every Apple TV, scale cleanly to the sizes a television needs, and add
//  nothing to the app's download size. They also inherit the brand tint without
//  needing a separate asset per colour.
//

import Foundation

enum PlayerAvatar: String, CaseIterable, Identifiable, Codable, Equatable, Hashable {
    case star
    case bolt
    case flame
    case leaf
    case crown
    case pawprint
    case moon
    case sun

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .star:     return "star.fill"
        case .bolt:     return "bolt.fill"
        case .flame:    return "flame.fill"
        case .leaf:     return "leaf.fill"
        case .crown:    return "crown.fill"
        case .pawprint: return "pawprint.fill"
        case .moon:     return "moon.fill"
        case .sun:      return "sun.max.fill"
        }
    }

    /// Spoken by VoiceOver and used in the avatar button's accessibility value.
    var displayName: String {
        switch self {
        case .star:     return "Star"
        case .bolt:     return "Bolt"
        case .flame:    return "Flame"
        case .leaf:     return "Leaf"
        case .crown:    return "Crown"
        case .pawprint: return "Paw print"
        case .moon:     return "Moon"
        case .sun:      return "Sun"
        }
    }

    /// The avatar given to the player in a particular seat by default.
    /// Wraps if there are ever more seats than avatars.
    static func `default`(forSeat seat: Int) -> PlayerAvatar {
        let all = allCases
        return all[max(0, seat - 1) % all.count]
    }

    /// The next avatar in the list, skipping any already taken by another
    /// player, so cycling can never produce two identical avatars in one match.
    /// Falls back to the plain next avatar if every option is taken.
    func next(excluding taken: Set<PlayerAvatar>) -> PlayerAvatar {
        let all = Self.allCases
        guard let start = all.firstIndex(of: self) else { return self }

        for step in 1...all.count {
            let candidate = all[(start + step) % all.count]
            if !taken.contains(candidate) { return candidate }
        }
        return all[(start + 1) % all.count]
    }
}
