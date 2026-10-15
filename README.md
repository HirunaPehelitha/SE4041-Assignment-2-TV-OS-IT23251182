# Brain Battle

**Think Fast. Play Together.**

A local multiplayer trivia game for Apple TV, built with Swift and SwiftUI for
tvOS. Two to four players share a single Apple TV and pass one remote between
turns. The game runs entirely offline — no accounts, no backend, no network
requests.

Built for **SE4041 — Mobile Application Design and Development, Assignment 2
Part B** (IT23251182).

---

## Purpose and target audience

Living-room trivia is usually either a phone app that everyone plays hunched
over their own screen, or a board game nobody wants to set up. Brain Battle puts
the quiz on the television — the screen a group is already looking at — and
needs nothing but the remote that came with the Apple TV.

**Who it is for**

- Families and friends already sitting together in front of a television
- Groups of two to four who want something that starts in under a minute
- Households with an Apple TV and no desire to install anything on phones,
  create accounts, or connect to a service

The design follows from that: large type readable from a sofa, focus
navigation driven by the remote's directional pad, and no text entry beyond
typing player names once.

## Features

Everything listed here is implemented and working in the prototype.

| Feature | Detail |
|---|---|
| Local multiplayer | Two to four players, turn-based, one shared remote |
| Five categories | Sri Lankan Culture, Sports & Cricket, Science & Nature, Movies & Entertainment, General Knowledge |
| 50 original questions | Four distinct options each, three difficulties, an explanation per question |
| Adaptive Challenge | Rule-based difficulty adjustment from recent accuracy (not machine learning) |
| Countdown timer | Per-question, length set by difficulty and the Question Time preference |
| Answer feedback | Correct answer revealed, explanation shown, synthesised feedback tones |
| Player avatars | Eight SF Symbol avatars, automatically kept distinct between players |
| Results and review | Final rankings, tie handling, per-player accuracy, and a question-by-question review of what each player actually answered |
| Leaderboard | All-time player standings plus match history, with Clear History |
| Local persistence | Match results, last roster and preferences saved on the device |
| Settings | Adaptive Challenge, sound effects, question duration, Reduce Motion |
| Accessibility | VoiceOver labels throughout, AAA text contrast, full Reduce Motion support |

## Technology stack

| | |
|---|---|
| Language | Swift 5 |
| UI | SwiftUI |
| State | Observation framework (`@Observable`), MVVM |
| Persistence | `Codable` models in `UserDefaults` |
| Audio | AVFoundation, with tones synthesised in code |
| Testing | XCTest (287 unit tests), XCUITest (13 UI tests — see limitations) |
| Dependencies | **None.** No Swift packages, no CocoaPods, no third-party code |

## Requirements

| | |
|---|---|
| Xcode | 26.1.1 or later |
| tvOS deployment target | 26.1 |
| Swift | 5.0 |
| Simulator | Apple TV 4K (3rd generation) |
| Network | Not required at any point |

## Build and run

1. Open `IT23251182-tvOS.xcodeproj` in Xcode.
2. Select the **IT23251182-tvOS** scheme and an **Apple TV 4K (3rd generation)**
   simulator.
3. Press **⌘R**.

From the command line:

```bash
xcodebuild -project IT23251182-tvOS.xcodeproj \
           -scheme IT23251182-tvOS \
           -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
           -configuration Debug build
```

### Running the tests

Unit tests (all 287 pass):

```bash
xcodebuild test -project IT23251182-tvOS.xcodeproj \
                -scheme IT23251182-tvOS \
                -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
                -only-testing:IT23251182-tvOSTests
```

In Xcode, **⌘U** runs both test bundles. See *Known limitations* regarding the
UI test bundle.

### Controls

The app is driven entirely by the Apple TV remote. In the simulator, use the
**arrow keys** to move focus, **Return** to select and **Esc** for Menu/back.

## Project structure

```
IT23251182-tvOS/
├── Models/          Question, QuizCategory, Difficulty, PreparedQuestion,
│                    Player, PlayerAvatar, QuizSettings, GameSession,
│                    MatchResult, TurnRecord, TurnOutcome, MatchScoring,
│                    CategoryAvailability, LeaderboardEntry,
│                    QuestionDuration, AdaptiveDifficulty
├── Services/        QuestionRepository, AppSettings, MatchHistoryStore,
│                    PlayerRosterStore, SoundEffectPlayer,
│                    SeededRandomNumberGenerator
├── Navigation/      AppRoute — every screen expressed as a value
├── Theme/           BrandTheme — palette, type scale, layout, motion
├── Views/           Screens and their view models
│   └── Components/  Reusable focus-aware controls
└── Resources/       questions.json — the bundled question bank

IT23251182-tvOSTests/     287 unit tests
IT23251182-tvOSUITests/   13 XCUIRemote tests (see limitations)
```

Roughly 6,700 lines of application Swift and 3,600 lines of test Swift.

The project uses Xcode's **file-system synchronized groups**, so any file added
to the `IT23251182-tvOS/` folder becomes part of the target automatically. There
is no manual "Add to target" step, and `questions.json` is bundled without
configuration.

## Documentation

| Document | Contents |
|---|---|
| [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) | How to play, screen by screen |
| [`docs/TECHNICAL_DOCUMENTATION.md`](docs/TECHNICAL_DOCUMENTATION.md) | Architecture, models, game-state lifecycle, persistence, error handling |
| [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md) | Test objectives, every result, known defects |
| [`docs/ASSIGNMENT_REPORT.md`](docs/ASSIGNMENT_REPORT.md) | Full academic report |
| [`docs/AI_USAGE_LOG.md`](docs/AI_USAGE_LOG.md) | Record of AI assistance and verification |
| [`docs/COMPETITOR_ANALYSIS.md`](docs/COMPETITOR_ANALYSIS.md) | Researched, cited comparison with Kahoot!, Trivia Crack and Jackbox |
| [`docs/PITCH_DECK.md`](docs/PITCH_DECK.md) | Ten-slide investor pitch with speaker notes |
| [`docs/VIVA_DEMO_PLAN.md`](docs/VIVA_DEMO_PLAN.md) | Five-minute demonstration script |
| [`docs/PART_B_CHECKLIST.md`](docs/PART_B_CHECKLIST.md) | Evidence mapped to the five assessment criteria |
| [`docs/COMMIT_PLAN.md`](docs/COMMIT_PLAN.md) | Incremental Git commit plan |

## Known limitations

These are real and verified, not hypothetical.

1. **UI tests do not execute on the development machine.** The 13 XCUITest cases
   compile and code-sign correctly, but the tvOS test runner fails to start with
   `Timed out waiting for AX loaded notification`. This was reproduced on three
   simulators including a never-used one, so it is an environment problem rather
   than a project defect — but it means **no UI test has ever reported a pass**,
   and they must not be presented as passing.
2. **Focus navigation is verified manually only.** tvOS rejects synthetic touch
   input, so automated focus testing was exactly what the UI tests would have
   provided.
3. **Audio output is unverified.** The generated tone data is tested as valid
   WAV and the call sites are tested, but whether sound is audible has not been
   confirmed.
4. **Simulator only.** The app has never been run on physical Apple TV hardware.
5. **One remote only.** Multi-controller play via the GameController framework
   is designed for but not implemented; the simulator cannot emulate multiple
   remotes, so it could not be developed or demonstrated.
6. **Release configuration is build-verified, not run-verified.** All runtime
   testing was done in Debug.
7. **Question bank is fixed at 50 questions.** There is no in-app editor and no
   downloadable content.
8. **No online features of any kind.** No accounts, no sync, no leaderboards
   beyond the single device.
