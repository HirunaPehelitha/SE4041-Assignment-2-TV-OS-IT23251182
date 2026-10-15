//
//  PlayerSetupViewModel.swift
//  IT23251182-tvOS
//
//  State and rules for the player-setup screen.
//
//  Every validation rule lives here, not in the view, so each one can be tested
//  without SwiftUI. The view renders `players` and `validation`, and calls
//  `startBattle` — which returns a session only when the setup is actually
//  valid, so an invalid match cannot be started even if the button were somehow
//  reachable.
//

import Foundation
import Observation

/// Why a setup cannot be started. Ordered by what the player should fix first.
enum PlayerSetupValidation: Equatable {
    case valid
    case tooFewPlayers(needed: Int)
    case blankName(seat: Int)
    case nameTooLong(seat: Int)
    case duplicateName(String)
    case noQuestions

    var isValid: Bool { self == .valid }

    /// Shown under the roster. `nil` when there is nothing to fix.
    var message: String? {
        switch self {
        case .valid:
            return nil
        case .tooFewPlayers(let needed):
            return "Add at least \(needed) players to start a battle."
        case .blankName(let seat):
            return "Player \(seat) needs a name."
        case .nameTooLong(let seat):
            return "Player \(seat)'s name is longer than \(Player.maximumNameLength) characters."
        case .duplicateName(let name):
            return "Two players are both called \u{201C}\(name)\u{201D}. Give them different names so the scoreboard is clear."
        case .noQuestions:
            return "This category does not have enough questions for a match."
        }
    }
}

@Observable
final class PlayerSetupViewModel {

    // MARK: State

    /// The roster being edited. Always between two and four entries.
    private(set) var players: [Player]

    /// The match configuration carried in from category selection.
    let settings: QuizSettings

    // MARK: Dependencies

    private let repository: QuestionRepository
    private let rosterStore: PlayerRosterStore

    init(settings: QuizSettings,
         repository: QuestionRepository,
         rosterStore: PlayerRosterStore = PlayerRosterStore()) {
        self.settings = settings
        self.repository = repository
        self.rosterStore = rosterStore

        // Start from the last roster this Apple TV used, topped up to the
        // minimum. A returning group gets their names back; a new one gets two
        // empty slots.
        let remembered = rosterStore.load()
        var seeded: [Player] = []
        for (offset, saved) in remembered.prefix(Player.maximumPlayers).enumerated() {
            seeded.append(Player(name: saved.trimmedName,
                                 colorIndex: offset,
                                 avatar: saved.avatar))
        }
        while seeded.count < Player.minimumPlayers {
            seeded.append(Player.empty(seat: seeded.count + 1))
        }
        self.players = seeded
    }

    // MARK: Roster editing

    var canAddPlayer: Bool { players.count < Player.maximumPlayers }
    var canRemovePlayer: Bool { players.count > Player.minimumPlayers }

    /// Adds a seat. Silently does nothing at the maximum, so the cap holds even
    /// if a caller forgets to check `canAddPlayer`.
    func addPlayer() {
        guard canAddPlayer else { return }
        let seat = players.count + 1
        players.append(Player(name: "",
                              colorIndex: players.count,
                              avatar: nextFreeAvatar(forSeat: seat)))
    }

    /// Removes a seat, never dropping below the two-player minimum.
    func removePlayer(id: UUID) {
        guard canRemovePlayer, players.contains(where: { $0.id == id }) else { return }
        players.removeAll { $0.id == id }
        reindexColours()
    }

    func setName(_ name: String, for id: UUID) {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        // Trim as we store: a name that is only spaces is a blank name, and
        // trailing spaces would make two identical names look different.
        players[index].name = String(name.prefix(Player.maximumNameLength * 2))
    }

    /// Moves a player to the next avatar that nobody else is using.
    func cycleAvatar(for id: UUID) {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        let taken = Set(players.enumerated().compactMap { $0.offset == index ? nil : $0.element.avatar })
        players[index].avatar = players[index].avatar.next(excluding: taken)
    }

    /// Colours follow seat order, so removing the second of three players
    /// leaves the remaining two with the first two colours rather than a gap.
    private func reindexColours() {
        for index in players.indices {
            players[index].colorIndex = index
        }
    }

    private func nextFreeAvatar(forSeat seat: Int) -> PlayerAvatar {
        let taken = Set(players.map(\.avatar))
        let preferred = PlayerAvatar.default(forSeat: seat)
        return taken.contains(preferred) ? preferred.next(excluding: taken) : preferred
    }

    // MARK: Validation

    /// The first problem with the current setup, or `.valid`.
    var validation: PlayerSetupValidation {
        guard players.count >= Player.minimumPlayers else {
            return .tooFewPlayers(needed: Player.minimumPlayers)
        }

        for (index, player) in players.enumerated() {
            let seat = index + 1
            if player.trimmedName.isEmpty { return .blankName(seat: seat) }
            if player.trimmedName.count > Player.maximumNameLength {
                return .nameTooLong(seat: seat)
            }
        }

        // Case-insensitive: two rows reading "Sam" and "sam" would be
        // indistinguishable on a scoreboard across the room.
        var seen = Set<String>()
        for player in players {
            if !seen.insert(player.nameKey).inserted {
                return .duplicateName(player.trimmedName)
            }
        }

        if availableQuestionCount < 1 { return .noQuestions }

        return .valid
    }

    var canStart: Bool { validation.isValid }

    func isDuplicate(_ player: Player) -> Bool {
        guard !player.trimmedName.isEmpty else { return false }
        return players.filter { $0.nameKey == player.nameKey }.count > 1
    }

    // MARK: Match information

    private var availableQuestionCount: Int {
        min(settings.questionCount, repository.questions(matching: settings).count)
    }

    var questionCount: Int { availableQuestionCount }

    /// True when the round does not divide evenly between the players.
    var hasUnevenTurns: Bool {
        guard !players.isEmpty else { return false }
        return availableQuestionCount % players.count != 0
    }

    var turnsDescription: String {
        guard !players.isEmpty else { return "" }
        let base = availableQuestionCount / players.count
        return hasUnevenTurns
            ? "\(base)–\(base + 1) turns each"
            : "\(base) turns each"
    }

    // MARK: Starting

    /// Builds the session for the configured match.
    ///
    /// Returns `nil` when the setup is invalid — the single gate that stops an
    /// unplayable match from starting, regardless of what the UI allows.
    func startBattle() -> GameSession? {
        guard canStart else { return nil }

        // A pool wider than the round, so Adaptive Challenge has a real choice.
        // The round length itself is unchanged.
        let questions = repository.makeAdaptivePool(for: settings)
        guard !questions.isEmpty else { return nil }

        // Names are trimmed on the way into the match so the scoreboard shows
        // exactly what validation checked.
        let roster = players.enumerated().map { index, player in
            Player(id: player.id,
                   name: player.trimmedName,
                   colorIndex: index,
                   avatar: player.avatar)
        }

        rosterStore.save(roster)

        return GameSession(players: roster,
                           settings: settings,
                           questions: questions,
                           plannedQuestionCount: availableQuestionCount)
    }
}
