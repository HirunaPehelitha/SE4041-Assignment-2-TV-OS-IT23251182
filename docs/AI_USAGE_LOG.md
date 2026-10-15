# AI-Assisted Development Record

The assignment brief permits AI tools provided the interactions are documented
and their contribution explained. This is that record.

**Tool:** Claude (Anthropic), via Claude Code in the terminal
**Period:** 12–14 October 2026
**Model of working:** one development stage per prompt, each built and tested
before the next began

> **Keep this current.** Add an entry for each further stage, including the
> prompt given and what was changed afterwards.

---

## How it was used

I wrote a prompt for each stage describing what I wanted. The assistant
inspected the existing project, produced the code, then built it and ran the
tests on the Apple TV simulator before reporting back. I verified each stage
myself before approving the next.

Standing instructions given throughout:

- Work in small sequential stages; never generate the whole app at once
- Inspect existing files before changing them; never assume a file exists
- No non-functional buttons, fabricated results or incomplete navigation
- Never claim the app builds or tests pass without actually verifying it
- Explain decisions in terms I can defend in a viva

## What I accepted, and what I checked

All generated code was accepted into the project after I reviewed it and ran the
build. My verification at each stage was: run the app on the simulator, confirm
the screens behave as described, and run the test suite.

The assistant was not permitted to commit or publish anything. At the time of
writing, **no code has been pushed to any remote**; all commits are local.

---

## Stage log

### Stage 1 — Project foundation and brand shell
**Prompt:** Inspect the workspace, confirm the Xcode and simulator setup, choose
a deployment target, set up the app entry point, a HomeView and root navigation,
and the initial background and typography.

**Produced:** `BrandTheme`; `Question`, `QuizCategory`, `Difficulty`; a bundled
JSON question bank; a loader; the home screen; a value-based `NavigationStack`.

**Problems found during the stage:** a nested type named `Body` collided with
`ButtonStyle`'s associated type; a launch crash caused by installing over a
stale build.

### Stage 2 — Design system and home screen
**Prompt:** Build a reusable colour and typography system to a supplied palette
(`#10131C`, `#191E2B`, `#DFFF45`), reusable buttons and cards, a background, the
title and tagline, and four working home-screen actions.

**Produced:** the palette with measured contrast ratios, `BrandButtonStyle` /
`BrandCardStyle` / `BrandRowStyle`, `ActionCard`, `BrandToggleRow`, Leaderboard
and Settings screens.

**Problems found:** card fills measured only 1.11:1 against the background and
needed hairline borders; home cards were unequal heights; a focused tvOS
`Toggle` made secondary text unreadable and was replaced with a custom control.

### Stage 3 — Data models, repository and tests
**Prompt:** Models for Question, QuizCategory, Player, MatchResult and
QuizSettings; at least 50 original questions across five named categories;
strongly typed decoding with error handling; a validating repository; question
and answer shuffling; tests.

**Produced:** the models plus `PreparedQuestion`, `QuestionRepository`,
`SeededRandomNumberGenerator`, the 50-question bank, and a new unit test target
with 70 tests.

**Problems found:** `Result<Question, String>` does not compile (`String` is not
an `Error`); every repository test aborted with `SIGABRT` because Xcode 26 gives
classes an isolated `deinit` — resolved by marking the repository `nonisolated`.

### Stage 4 — Category selection
**Prompt:** The real category screen: five categories from the repository,
distinct cards, focus navigation, animation, current selection shown, a Back
action, Play Game connected, selection passed to player setup, categories with
too few questions handled, no question data duplicated in views.

**Produced:** `CategoryAvailability`, `CategorySelectViewModel`,
`CategoryPreviewPanel`, a rewritten `CategorySelectView`, `PlayerSetupView`.
Tests rose to 91.

**Problems found:** the footer floated mid-screen because several `Spacer`s
shared the slack; two actor-isolation warnings.

### Stage 5 — Player setup
**Prompt:** Two to four players: two required slots, add a third or fourth, an
avatar selector, a tvOS-compatible name field, distinct slots, a category
summary, Start Battle and Back. Validate at least two players, reject blank
names, handle duplicates predictably, cap at four, prevent starting when
invalid. Pass category and players into the game session. No fake gameplay.

**Produced:** `PlayerAvatar`, extended `Player`, `GameSession`,
`PlayerRosterStore`, `PlayerSetupViewModel`, `PlayerSlotCard`, rewritten
`PlayerSetupView`, `MatchStartView`. Tests rose to 138.

**Problems found:** piecemeal `nonisolated` marking became unmanageable, so the
project default actor isolation was switched to `nonisolated`; a stale
DerivedData directory left by a temporary clone meant the simulator was running
an old build — caught by comparing the built dylib timestamp to the clock.

### Stage 6 — Game engine and quiz screen
**Prompt:** Core gameplay: turn-based play, ten questions, 100 points for
correct and none otherwise, a question never scoring twice, a countdown with
safe cancellation, frozen input after answering, feedback, correct last-question
handling, controlled transition to results. Business logic out of the view.

**Produced:** `MatchScoring`, `QuizGameViewModel` with a `MatchPhase` lifecycle,
`QuizGameView`, `AnswerCard` with countdown ring and score strip,
`MatchResultsView`. Tests rose to 175.

**Issue I had to decide:** the flat 100-point rule in this stage contradicted the
difficulty-weighted scoring built earlier. I confirmed the flat rule; it was
unified into `MatchScoring` and the How to Play text, the category screens and
two tests were updated to match.

### Stage 7 — Results experience
**Prompt:** Polished results: winner or tie presentation, rankings, avatars,
scores, statistics, questions completed, Play Again, Return Home, Review Answers
if complete. Rankings from actual game state, accurate ties, no double-saving,
no points after completion, restrained winner animation, working navigation,
correct Play Again reset.

**Produced:** `TurnOutcome` and `TurnRecord` extracted so the engine logs every
answered question; `MatchHistoryStore` with idempotent saving;
`MatchResultsViewModel`; rewritten `MatchResultsView`; `ReviewAnswersView`;
leaderboard reading real history. Tests rose to 212.

### Stage 8 — Persistence, leaderboard and settings
**Prompt:** Local persistence with safe handling of missing, empty and corrupted
data; save each match once; never save abandoned rounds; a leaderboard with a
documented deterministic rule, empty state and Clear History with confirmation;
settings for sound, question duration, instructions, about and an honest local
data description.

**Produced:** `QuestionDuration`, `LeaderboardEntry` with a documented ranking
rule, `SoundEffectPlayer` (tones synthesised in code), `LeaderboardViewModel`,
rewritten Leaderboard and Settings. Tests rose to 253.

**Problem found:** `UserDefaults.bool(forKey:)` returns false for a missing key,
which would have made a first launch look like "sound deliberately off".

### Stage 9 — Adaptive Challenge and visual polish
**Prompt:** An explainable rule-based difficulty adjustment from recent
performance, bounded, with sensible defaults and no possibility of selecting an
invalid question or stalling a match. Visual refinement. Not machine learning.

**Produced:** `AdaptiveDifficultyPolicy`, engine support for adaptive selection,
a live explanation badge, a Settings toggle, score-change and countdown polish.
Tests rose to 287.

**The significant problem of the project.** A test comparing hard-question counts
for a strong versus a struggling player returned **29 versus 29** — identical.
The feature was nearly inert: because a match consumed its entire question list,
every question was asked regardless of what the policy decided, so adaptation
could only change the order. Fixed by separating the question *pool* from the
*round length*. Without that test the feature would have appeared to work.

### Stage 10 — Quality assurance pass
**Prompt:** Inspect the project for defects across twelve categories, complete
unit tests for eleven areas, add UI tests, report what passed, failed and
remains unexecuted, and never fabricate results.

**Produced:** clean Debug and Release builds (0 errors, 0 warnings); a static
audit; a UI test target with 13 XCUIRemote tests.

**Defects fixed:** player names clipped in three places (added
`minimumScaleFactor`).

**Honest outcome:** the UI tests **do not execute**. The tvOS test runner fails
with `Timed out waiting for AX loaded notification` on three different
simulators. They compile and sign, but no UI test has reported a pass, and this
is recorded as such everywhere.

### Stage 11 — Submission documentation
**Prompt:** Prepare README, user guide, technical documentation, test plan,
assignment report and this AI usage log from the actual implementation, plus a
`.gitignore` and a commit plan. Do not fabricate anything.

**Produced:** this set of documents, written from facts gathered out of the
repository (file counts, test counts, build settings, git state) rather than
from memory.

---

## What I verified myself

- Every stage was built and run on the Apple TV 4K simulator before acceptance
- The assistant could not drive the Apple TV remote (tvOS rejects synthetic
  input), so all focus movement, text entry and back-navigation was tested
  manually by me
- I checked the factual accuracy of the question bank
- I played a complete match manually; it appeared correctly in the leaderboard
- I read the explanation given for each design decision so that I can defend it

## What remains unverified by anyone

- UI tests have never run
- Audio output has never been confirmed audible
- The app has never run on physical Apple TV hardware
