//
//  GameSession.swift
//  IT23251182-tvOS
//
//  Everything a match needs in order to be played.
//
//  A session is *immutable*: the roster, the settings and the exact question
//  set are fixed the moment "Start Battle" is pressed. Nothing here records
//  scores or progress — that mutable play state belongs to the match engine,
//  which is built on top of a session rather than inside it.
//
//  Keeping it immutable is what lets it travel as a navigation route value, and
//  means a match can be rebuilt or replayed exactly from the same session.
//

import Foundation

struct GameSession: Identifiable, Equatable, Hashable {

    let id: UUID
    /// Turn order. Index 0 takes the first question.
    let players: [Player]
    let settings: QuizSettings
    /// The pool of questions available to this match, already shuffled, with
    /// their answer order shuffled too.
    ///
    /// This can be **larger** than the number actually asked. Adaptive Challenge
    /// needs room to choose: if the pool were exactly the round length, every
    /// question would be asked regardless and adaptation could only change the
    /// order, not which questions a player actually faces.
    let questions: [PreparedQuestion]

    /// How many questions this match will ask. Defaults to the whole pool,
    /// which is the non-adaptive behaviour.
    let plannedQuestionCount: Int

    let startedAt: Date

    init(id: UUID = UUID(),
         players: [Player],
         settings: QuizSettings,
         questions: [PreparedQuestion],
         plannedQuestionCount: Int? = nil,
         startedAt: Date = Date()) {
        self.id = id
        self.players = players
        self.settings = settings
        self.questions = questions
        self.plannedQuestionCount = plannedQuestionCount ?? questions.count
        self.startedAt = startedAt
    }

    // MARK: Derived values

    var playerCount: Int { players.count }

    /// Questions actually asked — never more than the pool can supply.
    var questionCount: Int { min(plannedQuestionCount, questions.count) }

    /// Spare questions the adaptive policy can choose between.
    var poolSize: Int { questions.count }

    var categoryDisplayName: String { settings.categoryDisplayName }

    /// Highest score a single player could reach if they answered every
    /// question in the match correctly.
    var maximumPoints: Int {
        MatchScoring.maximumPoints(forQuestionCount: questionCount)
    }

    /// Which player answers question `index`, rotating through the roster.
    /// Returns `nil` only for an out-of-range index or an empty roster.
    func player(forQuestionIndex index: Int) -> Player? {
        guard !players.isEmpty, index >= 0, index < questionCount else { return nil }
        return players[index % players.count]
    }

    /// How many questions each player is asked. A round that does not divide
    /// evenly gives the earlier seats one extra turn, which the setup screen
    /// warns about so it is never a surprise.
    func turnCount(forSeat seat: Int) -> Int {
        guard !players.isEmpty, seat >= 0, seat < players.count else { return 0 }
        let base = questionCount / players.count
        let remainder = questionCount % players.count
        return base + (seat < remainder ? 1 : 0)
    }

    /// True when every player is asked the same number of questions.
    var isTurnCountBalanced: Bool {
        guard !players.isEmpty else { return false }
        return questionCount % players.count == 0
    }

    /// A session with no questions cannot be played, whatever the roster says.
    var isPlayable: Bool {
        !players.isEmpty && !questions.isEmpty
    }
}
