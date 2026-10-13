# Brain Battle

**Think Fast. Play Together.**

A local multiplayer trivia game for Apple TV, built with Swift and SwiftUI for
tvOS. Two to four players share a single Apple TV and pass one remote between
turns. The game runs entirely offline — no accounts, no backend, no network.

Built for **SE4041 — Mobile Application Design and Development, Assignment 2
Part B** (IT23251182).

---

## Requirements

| | |
|---|---|
| Xcode | 26.1.1 or later |
| tvOS deployment target | 26.1 |
| Swift | 5.0 |
| Simulator | Apple TV 4K (3rd generation) |
| Dependencies | **None** — no Swift packages, no CocoaPods, no network calls |

## Build and run

1. Open `IT23251182-tvOS.xcodeproj` in Xcode.
2. Choose the **IT23251182-tvOS** scheme and an **Apple TV 4K (3rd generation)**
   simulator.
3. Press **⌘R**.

From the command line:

```bash
xcodebuild -project IT23251182-tvOS.xcodeproj \
           -scheme IT23251182-tvOS \
           -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
           -configuration Debug build
```

## Run the tests

Press **⌘U** in Xcode, or:

```bash
xcodebuild test -project IT23251182-tvOS.xcodeproj \
                -scheme IT23251182-tvOS \
                -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

The suite currently covers JSON decoding, per-entry validation, duplicate
identifiers, answer-option rules, category filtering, answer shuffling and the
category-selection logic.

## Controls

The app is driven entirely by the Apple TV remote. In the simulator, use the
**arrow keys** to move focus, **Return** to select and **Esc** to go back.

## Project structure

```
IT23251182-tvOS/
├── Models/         Question, QuizCategory, Difficulty, Player,
│                   QuizSettings, MatchResult, PreparedQuestion,
│                   CategoryAvailability
├── Services/       QuestionRepository, AppSettings,
│                   SeededRandomNumberGenerator
├── Navigation/     AppRoute — every screen as a Hashable value
├── Theme/          BrandTheme — colours, type scale, layout, motion
├── Views/          Screens and their view models
│   └── Components/ Reusable focus-aware controls
└── Resources/      questions.json — the bundled question bank
```

## Architecture

**MVVM.** Views render state and report intent; view models own the rules;
services own the data. No view holds question data or filters the bank — screens
receive pre-computed summaries, so the counting happens once.

A few decisions worth noting:

- **Navigation is data-driven.** `AppRoute` is a `Hashable` enum used with
  `navigationDestination(for:)`. Routes carry their payload, so
  `PlayerSetupView` cannot be constructed without a chosen category — the
  hand-off is enforced by the compiler rather than a runtime check.
- **Invalid questions are rejected individually.** A malformed entry in
  `questions.json` is discarded with a reason and reported, instead of aborting
  the whole file. One bad question can never stop the app from launching.
- **Shuffling cannot detach an answer.** `PreparedQuestion` is a separate type
  from `Question`: the bank entry stays immutable and the shuffled presentation
  permutes option *indices*, so the correct answer moves with its option.
- **Data types are `nonisolated`.** The project builds with Xcode 26's
  MainActor-by-default isolation; repositories and models opt out of it because
  they hold no UI state.

## Question bank

`Resources/questions.json` holds 50 original questions across five categories:
Sri Lankan Culture, Sports & Cricket, Science & Nature, Movies & Entertainment,
and General Knowledge. Each entry has exactly four distinct options, a stable
identifier, a difficulty, and an explanation shown after the answer.

The file is included in the app target automatically — the project uses Xcode's
file-system synchronized groups, so anything placed in `IT23251182-tvOS/` is
part of the target with no manual step.

## AI-assisted development

This project was developed with AI assistance, as permitted by the assignment
brief. See [`docs/AI-USAGE.md`](docs/AI-USAGE.md) for the record of how it was
used.
