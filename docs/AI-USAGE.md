# AI-Assisted Development Record

The assignment brief permits the use of AI tools provided the interactions are
documented and their contribution explained. This file is that record.

**Tool used:** Claude (Anthropic), via Claude Code in the terminal.
**Period:** 12–13 October 2026.

> **Keep this file up to date.** Add an entry for each further stage, including
> the prompt you gave and what you changed afterwards. A grader may ask you to
> show it alongside your commit history.

---

## How it was used

Development ran as a sequence of stages. For each stage I wrote a prompt
describing what I wanted, the assistant inspected the existing project, produced
the code, then built and tested it on the Apple TV simulator before reporting
back. I verified every stage myself on the simulator before approving the next.

Standing instructions given to the assistant throughout:

- Work in small sequential stages; never generate the whole app at once.
- Inspect existing files before changing them; never assume a file exists.
- No non-functional buttons, fabricated results or incomplete navigation.
- Never claim the app builds or tests pass without actually verifying it.
- Explain decisions in terms I can defend in a viva.

---

## Stage log

### Stage 1 — Project foundation and brand shell
**Prompt:** Inspect the workspace, confirm the Xcode and simulator setup, choose
a deployment target, set up the app entry point, a HomeView and root navigation,
and the initial background and typography.

**Produced:** `BrandTheme`, the `Question`/`QuizCategory`/`Difficulty` models, a
bundled JSON question bank, a question-bank loader, the home screen, and a
value-based `NavigationStack` router.

**Issues found and fixed during the stage:** a compile error where a nested type
named `Body` collided with `ButtonStyle`'s associated type; a launch crash caused
by installing over a stale build.

### Stage 2 — Design system and home screen
**Prompt:** Build a reusable colour and typography system to a supplied palette
(`#10131C`, `#191E2B`, `#DFFF45`), reusable buttons and cards, a screen
background, the title and tagline, and four working home-screen actions.

**Produced:** the brand palette with measured contrast ratios, `BrandButtonStyle`
/ `BrandCardStyle` / `BrandRowStyle`, `ActionCard`, `BrandToggleRow`, and the
Leaderboard and Settings screens.

**Issues found and fixed:** card fills sat only 1.11:1 above the background and
needed a hairline border to be visible on a television; home-screen cards were
unequal heights because one subtitle wrapped; a focused SwiftUI `Toggle` on tvOS
is drawn with the system's light focus appearance, which made secondary text
unreadable, so it was replaced with a custom control.

### Stage 3 — Data models, repository and tests
**Prompt:** Create models for Question, QuizCategory, Player, MatchResult and
QuizSettings; a bundled bank of at least 50 original questions across five named
categories; strongly typed decoding with error handling; a validating
repository; question and answer shuffling; and tests.

**Produced:** the five models plus `PreparedQuestion`, `QuestionRepository`,
`SeededRandomNumberGenerator`, a 50-question bank, and a new unit-test target
with 70 tests.

**Issues found and fixed:** `Result<Question, String>` does not compile because
`String` is not an `Error`; and every repository test aborted with `SIGABRT`
because Xcode 26 gives classes an isolated `deinit` under its
MainActor-by-default setting — resolved by marking the repository `nonisolated`.

### Stage 4 — Category selection
**Prompt:** Build the real category-selection screen: five categories from the
repository, distinct cards, focus navigation, focus and selection animation, the
current selection shown, a Back action, Play Game connected, the selection passed
into player setup, categories with too few questions handled, and no question
data duplicated in views.

**Produced:** `CategoryAvailability`, `CategorySelectViewModel`,
`CategoryPreviewPanel`, a rewritten `CategorySelectView`, and `PlayerSetupView`.
Test count rose to 91.

**Issues found and fixed:** the footer floated mid-screen because several
`Spacer`s shared the slack; two actor-isolation warnings of the same kind as
Stage 3.

---

## What I reviewed and verified myself

- Every stage was built and run on the Apple TV 4K simulator before being
  accepted.
- The assistant could not drive the Apple TV remote (tvOS rejects synthetic
  input), so all focus movement, selection and back-navigation was tested
  manually by me.
- I checked the factual accuracy of the question bank.
- I read the explanations for each design decision so that I can defend them.
