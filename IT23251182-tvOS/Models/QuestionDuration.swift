//
//  QuestionDuration.swift
//  IT23251182-tvOS
//
//  How long players get to answer.
//
//  Difficulty sets a base time (easy 15s, medium 20s, hard 25s). This
//  preference shifts all three together, so a group can keep the relative
//  difficulty but play faster or slower to suit who is in the room.
//

import Foundation

enum QuestionDuration: String, CaseIterable, Identifiable, Codable, Equatable {
    case relaxed
    case standard
    case quick

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relaxed:  return "Relaxed"
        case .standard: return "Standard"
        case .quick:    return "Quick"
        }
    }

    var detail: String {
        switch self {
        case .relaxed:  return "Ten extra seconds on every question."
        case .standard: return "The default timings."
        case .quick:    return "Five seconds less. For groups who know their stuff."
        }
    }

    /// Never drops below this, however aggressive the adjustment, so a question
    /// always has enough time to be read aloud.
    static let minimumSeconds = 5

    /// The time allowed for a question of the given difficulty.
    func seconds(for difficulty: Difficulty) -> Int {
        let base = difficulty.baseTimeLimit
        switch self {
        case .relaxed:  return base + 10
        case .standard: return base
        case .quick:    return max(Self.minimumSeconds, base - 5)
        }
    }

    /// Example range shown in Settings, so the choice is concrete.
    var exampleRange: String {
        let easy = seconds(for: .easy)
        let hard = seconds(for: .hard)
        return "\(easy)–\(hard) seconds"
    }
}
