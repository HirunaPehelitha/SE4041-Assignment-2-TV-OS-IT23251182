# Brain Battle — Assignment Report

**SE4041 — Mobile Application Design and Development**
**Assignment 2, Part B: Innovative Application for tvOS**
**Student:** IT23251182

---

## 1. Introduction

Brain Battle is a native tvOS trivia game for two to four people sharing one
Apple TV and one remote. It is a working prototype: a complete match can be
played from category selection through to a saved result, and 287 unit tests
cover the rules behind it.

This report describes what was built, why it was designed that way, what was
verified, and what was not. Where something is proposed rather than implemented,
it is labelled as such.

## 2. Problem statement

Group trivia on a television is awkward today.

- **Phone quiz apps** put the game on individual screens. Everyone looks down,
  not at each other, which defeats the point of playing together.
- **Second-screen TV games** need every player to have a phone, install
  something, and join a session before anyone answers a question.
- **Board games** have setup time and physical components.
- **Existing tvOS trivia apps** are commonly single-player or require accounts.

The Apple TV already has what a group quiz needs: a large shared display and a
remote that can be passed around. What has been missing is a game that treats
the remote as the only input and the television as the only screen.

## 3. Solution

Brain Battle is a pass-the-remote quiz:

1. Choose a category from five, with a live preview of what each contains.
2. Add two to four players, each with a name and an avatar.
3. Players take turns. The screen shows whose turn it is before the question.
4. Answer within the countdown. The correct answer and an explanation are shown.
5. The match ends with a ranked scoreboard, saved to the device.

No accounts, no network, no second device. A group can start a match in under a
minute, and a returning group has their names remembered.

## 4. Target audience

**Primary:** households with an Apple TV and two to four people who want a
short, shared game — families on an evening, friends after dinner, flatmates.

**Secondary:** the Sri Lankan Culture category gives the app local relevance in
a market where general-knowledge quizzes are usually Western-centric.

**Design consequences:** the smallest text on screen is 24pt; all contrast
exceeds WCAG AAA; one-handed remote operation; typing is limited to player names
entered once and then remembered.

*No user research or playtesting with real users was carried out. These are
design assumptions, not validated findings.*

## 5. Innovation and differentiation

### Implemented

**Adaptive Challenge** — a rule-based difficulty policy. Each player's last four
answers place them in one of three bands, which weights the choice of their next
question:

| Recent accuracy | Band | Weights easy/medium/hard |
|---|---|---|
| ≥ 70% | Harder | 1 / 3 / 5 |
| 36–69% | Balanced | 3 / 4 / 3 |
| ≤ 35% | Easier | 5 / 3 / 1 |

This is **not machine learning**. It is a fixed set of rules with three
properties: it is *bounded* (no difficulty is ever excluded), it has *safe
defaults* (fewer than two answers means no adaptation), and it *cannot stall a
match* (it only selects from questions already validated for the chosen
category).

Its real innovation is being **explainable**: a badge during play shows which way
difficulty is leaning and why. Adaptive systems in games are usually invisible;
making it legible means players trust it rather than suspect it.

**Genuine television-first design** — the preview panel that updates as focus
moves, difficulty-scaled timers, and avatars that cannot collide are all
decisions that only make sense on a shared screen driven by a remote.

**Honest offline operation** — no account, no network request, no analytics.

### Proposed, not implemented

- Multiple paired remotes via the GameController framework
- Downloadable question packs
- Any form of payment or commercial distribution

## 6. Existing similar apps

Full analysis with sources: [`COMPETITOR_ANALYSIS.md`](COMPETITOR_ANALYSIS.md).
Three products were researched — Kahoot!, Trivia Crack and The Jackbox Party
Pack — each covered for purpose, audience, interaction model, similarities,
differences and differentiation opportunities. In summary:

- **Kahoot!** — a Norwegian game-based learning platform launched in December
  2012, where user-generated quizzes are played through a browser or app. It is
  host-led and multi-device: participants answer on their own devices. It
  reported one billion cumulative players in March 2017, and lists 12 billion
  non-unique players as of 2025. Education-first rather than entertainment-first.
- **Trivia Crack** — Etermax's mobile trivia game (Android October 2013, iOS
  November 2013) with more than 600 million downloads and 150 million active
  users annually, across six categories. Personal, often asynchronous, one
  device per player. **Not available on Apple TV.**
- **The Jackbox Party Pack** — the closest structural competitor, and already on
  Apple TV. The host device runs the game on a television while players join
  from phone browsers via a room code, with no installation needed. It requires
  an internet connection during play.

Brain Battle's distinguishing position is the *input model*: one shared screen
and one shared remote, with **no second device and no network at all**. Jackbox
proves the shared-screen model works on Apple TV but retains both dependencies;
Trivia Crack is absent from the platform; Kahoot! is browser-based and
education-first.

**Brain Battle is not the first multiplayer quiz game**, and no such claim is
made anywhere in this submission. The category is large and long-established.
What the research supports is narrower: the no-second-device, no-network trivia
experience on Apple TV is a position the researched competitors do not occupy.

Competitors also do things Brain Battle does not: Kahoot!'s user-generated
content, Jackbox's private per-player answers, and Trivia Crack's remote play
are all genuine advantages it lacks.

## 7. Requirements

### Functional

| # | Requirement | Status |
|---|---|---|
| F1 | 2–4 local players, turn-based | ✅ |
| F2 | Category selection from the bundled bank | ✅ |
| F3 | 10-question matches, or fewer if unavailable | ✅ |
| F4 | Four options, one correct, shuffled | ✅ |
| F5 | 100 points correct; 0 wrong; 0 timeout | ✅ |
| F6 | Countdown per question | ✅ |
| F7 | A question never scores twice | ✅ |
| F8 | Ranked results with tie handling | ✅ |
| F9 | Results saved locally, exactly once | ✅ |
| F10 | Leaderboard with a deterministic order | ✅ |
| F11 | Settings that each change behaviour | ✅ |
| F12 | Adaptive difficulty | ✅ |
| F13 | Review of actual answers given | ✅ |
| F14 | Multiple simultaneous remotes | ❌ Proposed |

### Non-functional

| # | Requirement | Status |
|---|---|---|
| N1 | Fully offline | ✅ No network code exists |
| N2 | No third-party dependencies | ✅ |
| N3 | Readable from ~3 m | ✅ Minimum 24pt |
| N4 | WCAG AAA text contrast | ✅ Measured: 18.55:1, 9.96:1, 16.37:1 |
| N5 | VoiceOver support | ✅ Labels throughout |
| N6 | Reduce Motion honoured | ✅ App setting OR system setting |
| N7 | Survives corrupt stored data | ✅ Tested |
| N8 | Testable without the UI | ✅ 287 tests, no view instantiated |

## 8. UI/UX design

**Brand:** dark interface (`#10131C`), elevated cards (`#191E2B`), luminous lime
accent (`#DFFF45`), white primary text, `#B7BECE` secondary.

Contrast was measured, not assumed: white 18.55:1, secondary 9.96:1, accent
16.37:1 against the background — all above the AAA threshold of 7:1.

Measuring also exposed a defect: cards sit only **1.11:1** above the background,
far too little to read as an edge on a television. Every card therefore draws a
hairline border; the separation comes from the stroke, not the fill.

**Focus design.** With no cursor, the focus ring is the entire interface. The
focused control gets a 5pt accent border, a lifted fill, a subtle scale and a
shadow. Unplayable controls are disabled so the remote skips them;
non-interactive content is never focusable, so there are no dead ends.

**Typography.** tvOS lays out in 1920×1080 points and is read from a sofa, so
the smallest token is 24pt and the hero is 92pt.

**Motion.** Entrance animations stagger; focus responds in 180ms; the category
preview cross-fades in 160ms, deliberately fast because it fires on every swipe.
All of it is gated on a Reduce Motion value combining the app's own setting with
the system one.

## 9. Architecture

**MVVM**, with one rule enforced throughout: *a view never makes a decision it
could get wrong*. Views do not score answers, rank scoreboards, validate rosters
or decide playability. This is why 287 tests run without instantiating a view.

Key patterns: a **repository** as the only source of question data;
**dependency injection** everywhere (no singletons); **value-typed navigation**
where routes carry their payload so a screen cannot be built without its data;
and a **finite state machine** (`MatchPhase`) for gameplay instead of booleans
that could contradict each other.

Full detail is in `TECHNICAL_DOCUMENTATION.md`.

## 10. Implementation

Roughly 6,700 lines of application Swift and 3,600 of tests, built across eleven
stages, each verified before the next began.

Notable decisions:

- **`Question` vs `PreparedQuestion`** — the bank entry stays immutable; the
  shuffled presentation is a separate type, so a shuffled index can never
  overwrite the authoritative one.
- **Shuffling permutes indices, not text** — the correct answer moves with its
  option by construction. Verified across 500 seeds.
- **Per-entry validation** — one malformed question is rejected with a reason;
  the rest of the bank still loads.
- **Two guards on double scoring** — the phase check and a set of scored
  question ids.
- **Explicit advance between questions** — gives players time to pass the remote
  and removes a second timer that could race the first.

## 11. Testing

287 unit tests, all passing, with zero compiler warnings in Debug and Release.
13 UI tests are written and compile but **cannot execute** on the development
machine; they have never reported a pass. Manual verification was done by
screenshot evidence.

Full detail, including every manual test and its outcome, is in `TEST_PLAN.md`.

## 12. Challenges and solutions

**Adaptive difficulty was inert.** A test comparing hard-question counts for a
strong versus a struggling player returned **29 versus 29**. The cause was
structural: the match consumed its entire question list, so every question was
asked regardless of the policy — adaptation could only reorder. Fixed by
separating the question *pool* from the *round length*. Without that test the
feature would have looked implemented and done almost nothing.

**Every repository test aborted with `SIGABRT` and no message.** Xcode 26 sets
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, giving every class an isolated
`deinit`; releasing one inside XCTest corrupted the heap. Copying the setting to
the test target did not help. Resolved by switching the project to `nonisolated`
isolation — also the better design, since data types hold no UI state.

**A focused `Toggle` was unreadable.** tvOS draws it with the system's light
focus appearance, overriding the card styling and dropping secondary text to
about 1.5:1. Replaced with a `Button`-based control that keeps the brand palette
and re-declares its accessibility value.

**Cards were invisible.** Measuring contrast showed card fill at 1.11:1 against
the background. Solved with hairline borders rather than by changing the
specified palette.

**The timer had to be provably safe.** Three independent protections: cancelled
on every phase change, `tick()` refuses to act outside `.asking`, and teardown on
disappear. Tested with 50 stray ticks after answering and after completion.

**Timeouts could not be tested against a real clock.** The engine takes
`runsCountdown: false` so tests drive `tick()` by hand — exact and instant.

**tvOS rejects synthetic input.** Screens behind a navigation push were verified
by temporarily seeding the navigation path, screenshotting, then reverting.

## 13. Limitations

1. **UI tests have never executed** — runner fails with `Timed out waiting for AX
   loaded notification` on three different simulators
2. **Focus navigation verified manually only**
3. **Audio output unverified**
4. **Simulator only** — never run on Apple TV hardware
5. **Single remote** — multi-controller designed for, not built
6. **50 questions, fixed** — no editor, no downloadable packs
7. **No user testing** — no playtesting with real players was conducted
8. **Release configuration build-verified, not run-verified**
9. **Leaderboard groups players by name**, so two different people using the same
   name share a row

## 14. Future work

**Near term:** resolve the UI test environment; multi-remote support via
GameController; a larger question bank; physical device testing.

**Longer term (proposed, none implemented):** downloadable question packs;
team mode; a question editor; accessibility review with real VoiceOver users.

## 15. Conclusion

Brain Battle is a working tvOS prototype that demonstrates a genuine
television-first multiplayer experience, an explainable rule-based adaptive
difficulty system, and an architecture that separates rules from presentation
well enough to be tested without a user interface.

Its strongest technical claim is not the feature list but the verification
behind it: 287 passing tests, measured accessibility contrast, and defects —
including one that made a headline feature nearly inert — found and fixed by
tests rather than discovered in a demonstration.

Its honest weakness is that automated UI testing could not be executed in this
environment, so navigation and focus behaviour rest on manual verification.

## 16. References

Documentation relevant to the frameworks and platform conventions used:

1. Apple Inc. *SwiftUI Documentation.* developer.apple.com/documentation/swiftui
2. Apple Inc. *Human Interface Guidelines — tvOS.*
   developer.apple.com/design/human-interface-guidelines/designing-for-tvos
3. Apple Inc. *Observation Framework.*
   developer.apple.com/documentation/observation
4. Apple Inc. *XCTest.* developer.apple.com/documentation/xctest
5. Apple Inc. *UserDefaults.*
   developer.apple.com/documentation/foundation/userdefaults
6. W3C. *Web Content Accessibility Guidelines (WCAG) 2.1* — contrast ratios used
   as the accessibility target. w3.org/TR/WCAG21

Question content was written for this project. Factual answers were checked
against general reference knowledge; the bank contains no copied question text.
