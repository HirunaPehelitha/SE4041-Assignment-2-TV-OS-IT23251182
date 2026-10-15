# Brain Battle — Technical Documentation

Describes the implementation as built. Where a design has a limitation, it is
stated rather than glossed over.

---

## 1. Architecture and design patterns

**MVVM**, with a deliberately strict division:

| Layer | Responsibility | Knows about |
|---|---|---|
| **Models** | Data and the rules that belong to data | Nothing else |
| **Services** | Loading, persistence, audio | Models |
| **View models** | Screen state and decisions | Models, services |
| **Views** | Rendering and reporting intent | Their own view model |

The rule enforced throughout: **a view never makes a decision it could get
wrong.** A view does not score an answer, decide whether a category is playable,
rank a scoreboard or validate a roster. It renders what its view model publishes
and calls a method. This is why 287 unit tests can cover the behaviour without
instantiating a single SwiftUI view.

### Patterns used

- **Repository** — `QuestionRepository` is the only type that knows where
  questions come from. Views receive pre-computed summaries, never `[Question]`.
- **Dependency injection** — every service takes its dependency
  (`QuestionProviding`, `UserDefaults`, `RandomNumberGenerator`, `SoundPlaying`)
  with a production default. Tests substitute stubs; no singletons.
- **Value-typed navigation** — `AppRoute` is a `Hashable` enum. Views push
  *values*, not views.
- **Finite state machine** — `MatchPhase` drives gameplay as one enum rather
  than several booleans that could contradict each other.
- **Policy object** — `AdaptiveDifficultyPolicy` is pure static functions, so
  the adaptive rules are testable in isolation.

### Concurrency

The project builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. UI
isolation comes from SwiftUI's own `@MainActor` on `View`; only
`QuizGameViewModel` is explicitly `@MainActor`, because it owns a timer that
mutates observable state.

This was changed from Xcode 26's `MainActor` default after it caused a concrete
failure: every class got an isolated `deinit`, and releasing one inside XCTest
aborted the test host with a heap error (`swift_task_deinitOnExecutorImpl`).
Marking types `nonisolated` individually became unmanageable, and several cases
were flagged as future Swift 6 errors.

## 2. Models and relationships

```
QuizCategory ──┐
Difficulty ────┼──> Question ──> PreparedQuestion ──> TurnRecord
                                        │                  │
QuizSettings ───────> GameSession <──────┘                  │
                           │                                │
Player ────────────────────┤                                │
                           └──> MatchResult <───────────────┘
                                     │
                                PlayerScore ──> LeaderboardEntry
```

| Model | Purpose |
|---|---|
| `Question` | A bank entry. Stable string id, typed validation |
| `PreparedQuestion` | A question **as displayed**, answer order shuffled |
| `QuizCategory` | Five subjects; raw values match the JSON |
| `Difficulty` | Easy/medium/hard. Sets time, **not** points |
| `MatchScoring` | The single source of scoring truth |
| `Player` | Runtime identity: UUID, name, seat colour, avatar |
| `QuizSettings` | Match configuration; `Codable`, saved with results |
| `GameSession` | Immutable: roster, settings, question pool, round length |
| `MatchPhase` | The gameplay state machine |
| `TurnOutcome` / `TurnRecord` | What happened on one question |
| `MatchResult` | A completed match, including every turn |
| `CategoryAvailability` | What one category can offer; the playability rule |
| `LeaderboardEntry` | A player aggregated across saved matches |
| `AdaptiveDifficultyPolicy` | The rule-based difficulty rules |

### Two separations that matter

**`Question` vs `PreparedQuestion`.** The bank entry is immutable reference
data; what the player sees is a *presentation* with a different answer order.
Keeping them apart means a shuffled index can never be written over the
authoritative one, and a view cannot read `Question.correctIndex` and mark the
wrong option as right.

**Pool vs round length in `GameSession`.** `questions` is the pool;
`plannedQuestionCount` is how many get asked. Originally they were the same, and
that silently broke Adaptive Challenge — with a pool exactly the round length,
every question is asked regardless, so adaptation could only reorder. A test
comparing hard-question counts for strong versus struggling players returned
identical numbers, which is how it was found. The repository now builds a pool
twice the round length.

## 3. Question repository

`questions.json` holds 50 questions: 10 per category, each with exactly four
distinct options, a stable id, a difficulty and an explanation.

### Loading pipeline

```
Bundle → Data → QuestionBankFile → [QuestionDTO] → validate → [Question]
                                        │
                                        └── rejected: [RejectedQuestion]
```

`QuestionDTO` decodes category and difficulty as `String`, not as enums. This is
the key decision: decoding straight into `Question` would make **one** unknown
category abort the entire file. Instead each entry is mapped and validated
individually, and a bad one is rejected *with a reason* while the rest load.

Validation (`Question.ValidationFailure`) rejects: empty id, empty prompt, not
exactly four options, a blank option, **duplicate options**, and a
`correctIndex` out of range. Duplicate options matter because answer order is
shuffled — two identical options would make "the correct one" ambiguous to the
player even though the index still resolves.

Duplicate ids are rejected too; the first entry wins.

`QuestionBankDecoder.decode(data:)` is a **pure function over `Data`**, so tests
feed it inline JSON with no bundle and no simulator.

### Shuffling

`PreparedQuestion.init(source:shuffledUsing:)` permutes the option **indices**,
then finds the correct answer's new position within that permutation. Moving the
index rather than matching on answer text means the mapping holds even if two
options were somehow identical. Verified across 500 seeds.

## 4. Navigation

`AppRoute` is a `Hashable` enum; `ContentView` owns the `NavigationStack` path
and is the only file that maps a route to a view.

```
Home ─> categorySelect ─> playerSetup(QuizSettings) ─> matchReady(GameSession)
                                                              │
                                        results(MatchResult) <─ quiz(GameSession)
                                                 │
                                                 └─> reviewAnswers(MatchResult)
```

**Routes carry their payload.** `playerSetup` carries `QuizSettings`, `quiz`
carries `GameSession`, `results` carries `MatchResult`. These are non-optional
`let` properties on the destination views, so a screen literally cannot be
constructed without its data. The hand-off is enforced by the compiler rather
than by a runtime check.

Child screens never navigate. They report a result upward
(`onCategoryChosen`, `onStart`, `onFinished`, `onPlayAgain`) and `ContentView`
decides what to push. On finishing a match the path is **replaced**
(`path = [.results(result)]`) rather than appended, so a completed match cannot
be re-entered with the Back button.

## 5. Focus handling

tvOS has no cursor. Everything is the focus ring, which creates specific
obligations:

- **Custom `ButtonStyle`s read `@Environment(\.isFocused)`** inside a nested
  view, because that is where SwiftUI publishes it. `BrandButtonStyle`,
  `BrandCardStyle`, `BrandRowStyle` and `AnswerCardStyle` all do this.
  The nested view must not be called `Body` — that name collides with
  `ButtonStyle`'s associated type.
- **`defaultFocus`** sets where focus starts on each screen, rather than letting
  tvOS choose.
- **Unplayable controls are `.disabled`, not hidden.** A disabled control is
  skipped by the focus engine, so the remote can never land on something that
  would do nothing. Locked categories and answered questions both use this.
- **Non-interactive content is never focusable.** Difficulty chips and stat
  pills are plain views; giving the remote somewhere to land that does nothing
  creates dead ends.
- **One deliberate exception:** rows in the leaderboard and Review Answers are
  `Button`s with empty actions. A tvOS `ScrollView` can only be scrolled by
  moving focus, so list rows *must* be focusable. This is commented in both files.
- **A focused `Toggle` could not be used.** tvOS draws it with the system's light
  focus appearance, overriding the card styling and dropping secondary text to
  roughly 1.5:1 contrast. `BrandToggleRow` is built from a `Button` instead and
  re-declares its accessibility value.

## 6. Game-state lifecycle

```
ready ──start()──> asking(turn) ──submitAnswer()/tick()──> revealing(turn, outcome)
                      ▲                                            │
                      └────────── continueAfterReveal() ───────────┤
                                                                   │
                                                          finished(MatchResult)
```

Four properties, each tested:

1. **One enum, not several flags.** A question is either being asked or being
   revealed. "Is input frozen?" is not a separate boolean that could disagree —
   answering is simply only legal in `.asking`.
2. **Double scoring has two independent guards.** The phase check prevents it,
   and `scoredQuestionIDs` prevents it again. A scoring bug is invisible until
   the final scoreboard is wrong, so it is worth two locks.
3. **Advancing is an explicit press.** In a pass-the-remote game the players need
   an unhurried moment to hand the remote over, and it removes a second timer
   that could race the first.
4. **An abandoned match produces nothing.** A `MatchResult` is only created in
   `finish()`. Backing out mid-match leaves no result, so nothing can be saved.

## 7. Scoring and timer behaviour

### Scoring

All scoring flows through `MatchScoring`: 100 for a correct answer, 0 for a
wrong answer, 0 for a timeout. Difficulty affects time, not points.

*(This changed during development. Earlier stages weighted points by difficulty,
100/200/300. When the flat rule was specified it was unified into
`MatchScoring`, and the How to Play text and the category screens' "points
available" were updated with it, so the app has one source of truth.)*

Scoring happens in exactly one place — `resolve(questionIndex:outcome:)` — which
also appends the `TurnRecord` and the adaptive-policy data point inside the same
guard, so the scoreboard, the turn log and the policy can never disagree.

### Timer

The countdown is a cancellable `Task` that sleeps one second at a time. Three
independent protections:

1. It is **cancelled on every phase change**.
2. `tick()` **refuses to act outside `.asking`**, so a tick arriving after the
   phase changed does nothing.
3. `tearDown()` is called from `onDisappear`, so a dismissed screen leaves
   nothing running.

Tested with 50 stray ticks after answering and after match completion.

`runsCountdown: false` lets tests drive `tick()` by hand, so timeout behaviour is
verified exactly and instantly rather than by waiting on a real clock.

## 8. Adaptive Challenge

A rule-based policy. **No model, no training, nothing learned.**

| Recent accuracy (last 4 answers) | Band | Weights easy/medium/hard |
|---|---|---|
| ≥ 70% | Harder | 1 / 3 / **5** |
| 36–69% | Balanced | 3 / 4 / 3 |
| ≤ 35% | Easier | **5** / 3 / 1 |

Three guarantees:

- **Bounded** — every weight is ≥ 1, so no difficulty is ever excluded
- **Safe defaults** — fewer than two answers means no adaptation at all
- **Cannot stall or pick an invalid question** — selection only chooses from
  questions already in the session, which were validated and category-filtered
  when the match was built; it falls back to the first remaining question if
  weighting ever degenerates

Each player's history is tracked separately. Timeouts count as incorrect. The
quiz screen shows the current band with a VoiceOver explanation, so the feature
is explainable while it runs.

## 9. Persistence

`Codable` models in `UserDefaults`, three keys:

| Key | Contents |
|---|---|
| `history.matches` | Completed matches, capped at 50, most recent first |
| `roster.lastUsed` | Last roster's names and avatars |
| `settings.*` | Reduce Motion, sound, question duration, adaptive difficulty |

**Why `UserDefaults` is adequate here:** the dataset is well under 150 KB, read
once per screen, and never queried or filtered in a way needing indexing. It is
native, synchronous, needs no schema or migration tooling, and is included in
device backups. Core Data or SwiftData would add a model file, a container and a
migration story to store a small array. If history grew into thousands of
entries or needed searching, that would be the point to move to SwiftData.

**This is local storage on one device. It is not cloud synchronisation** — there
is no account, no network request and no iCloud involvement.

### Save-once

`MatchResult` carries a stable `id`. The results screen can appear several times
for the same match (returning from Review Answers re-fires `onAppear`), so
saving is guarded twice: `MatchResultsViewModel.isSaved` stops repeat calls
within one screen, and `MatchHistoryStore.save` refuses an id it already holds —
which also catches a *rebuilt* view model.

## 10. Error handling

Every failure path is explicit and tested.

| Failure | Behaviour |
|---|---|
| `questions.json` missing | `QuestionBankError.resourceMissing`, named in the message; the home screen shows a retry |
| Unparseable JSON | `.malformedJSON`; the app still launches |
| One bad question | Rejected individually with a reason; the rest load |
| No valid questions | `.noValidQuestions` |
| Stored key missing | Treated as empty — first launch is not an error |
| Stored data empty | Key removed, treated as nothing saved |
| **Stored data corrupt** | Discarded **and the bad value deleted**, so it cannot fail on every launch forever; the leaderboard reports it |
| Unknown stored setting | Falls back to the default |
| Audio unavailable | Silently skipped — sound is feedback, never a requirement |
| Category too small | Shown locked with an explanation, not hidden |
| Empty session | Finishes immediately rather than hanging on a blank screen |

One subtlety worth noting: `UserDefaults.bool(forKey:)` returns `false` for a
missing key, which would have made a first launch look like "sound deliberately
off". `AppSettings` checks for key presence instead.

**There are no force unwraps, `try!` or `fatalError` calls in application code.**
