# Git Commit Plan

## Current repository state — inspected, not assumed

Checked on 14 October 2026:

| | |
|---|---|
| Repository | Initialised, local only |
| Remote | **None configured** — nothing has ever been pushed anywhere |
| Current branch | `feature/stage-7-results` |
| Existing commits | 4, all local |
| Uncommitted | ~35 files (Stages 7–11) |

Existing commits:

```
262e16c Stage 6: playable match engine, quiz screen and results
f58257a Document Stage 5 in the AI usage log
2cf85f7 Stage 5: player setup with validation, avatars and match hand-off
a8f6ea1 Brain Battle: tvOS trivia prototype foundation (Stages 1-4)
```

**Note on history.** Stages 1–4 are one commit because version control was set
up partway through development. Backdating four separate commits afterwards
would have misrepresented how the work actually happened. From Stage 5 onward
each stage has its own commit on its own branch.

Branches present: `main`, `feature/stage-5-player-setup`,
`feature/stage-6-game-engine`, `feature/stage-7-results`.

## What still needs committing

Stages 7 to 11 are uncommitted: the results experience, persistence and
leaderboard, settings, Adaptive Challenge, the QA pass with its UI test target,
and this documentation set.

## Recommended plan

Each step is one commit on its own feature branch, merged to `main` with
`--no-ff` so the branch structure stays visible in the history.

### Step 1 — Stage 7: results experience

```bash
git add IT23251182-tvOS/Models/TurnOutcome.swift \
        IT23251182-tvOS/Models/TurnRecord.swift \
        IT23251182-tvOS/Models/MatchResult.swift \
        IT23251182-tvOS/Models/PreparedQuestion.swift \
        IT23251182-tvOS/Services/MatchHistoryStore.swift \
        IT23251182-tvOS/Views/MatchResultsViewModel.swift \
        IT23251182-tvOS/Views/MatchResultsView.swift \
        IT23251182-tvOS/Views/ReviewAnswersView.swift \
        IT23251182-tvOSTests/MatchResultsTests.swift
git commit -m "Stage 7: results screen, answer review and match history"
```

### Step 2 — merge Stage 7, branch for Stage 8

```bash
git checkout main
git merge --no-ff feature/stage-7-results -m "Merge Stage 7: results experience"
git checkout -b feature/stage-8-persistence
```

### Step 3 — Stage 8: persistence, leaderboard, settings

```bash
git add IT23251182-tvOS/Models/QuestionDuration.swift \
        IT23251182-tvOS/Models/LeaderboardEntry.swift \
        IT23251182-tvOS/Services/SoundEffectPlayer.swift \
        IT23251182-tvOS/Services/AppSettings.swift \
        IT23251182-tvOS/Services/PlayerRosterStore.swift \
        IT23251182-tvOS/Views/LeaderboardViewModel.swift \
        IT23251182-tvOS/Views/LeaderboardView.swift \
        IT23251182-tvOS/Views/SettingsView.swift \
        IT23251182-tvOSTests/PersistenceTests.swift
git commit -m "Stage 8: local persistence, leaderboard and functional settings"
git checkout main && git merge --no-ff feature/stage-8-persistence -m "Merge Stage 8: persistence and settings"
```

### Step 4 — Stage 9: Adaptive Challenge

```bash
git checkout -b feature/stage-9-adaptive-difficulty
git add IT23251182-tvOS/Models/AdaptiveDifficulty.swift \
        IT23251182-tvOS/Models/GameSession.swift \
        IT23251182-tvOS/Views/QuizGameViewModel.swift \
        IT23251182-tvOS/Views/QuizGameView.swift \
        IT23251182-tvOS/Views/Components/AnswerCard.swift \
        IT23251182-tvOSTests/AdaptiveDifficultyTests.swift
git commit -m "Stage 9: rule-based adaptive difficulty and visual polish"
git checkout main && git merge --no-ff feature/stage-9-adaptive-difficulty -m "Merge Stage 9: adaptive challenge"
```

### Step 5 — Stage 10: QA pass and UI test target

```bash
git checkout -b feature/stage-10-qa
git add IT23251182-tvOSUITests/ IT23251182-tvOS.xcodeproj/ \
        IT23251182-tvOS/Views/LeaderboardView.swift
git commit -m "Stage 10: UI test target, QA fixes for name clipping"
git checkout main && git merge --no-ff feature/stage-10-qa -m "Merge Stage 10: quality assurance"
```

### Step 6 — Stage 11: documentation

```bash
git checkout -b feature/stage-11-documentation
git add README.md docs/
git commit -m "Stage 11: submission documentation"
git checkout main && git merge --no-ff feature/stage-11-documentation -m "Merge Stage 11: documentation"
```

### Step 7 — tag the submission

```bash
git tag -a v1.0-submission -m "Brain Battle — SE4041 Assignment 2 Part B submission"
```

## Publishing to GitHub

Nothing has been pushed. When you are ready:

```bash
# Create an empty repository on GitHub first (no README, no .gitignore)
git remote add origin https://github.com/<your-username>/<repo-name>.git
git push -u origin main
git push origin --all      # the feature branches, for the branch history
git push origin --tags
```

**Check before pushing:**

```bash
git status --short                    # should be empty
git log --oneline --graph --all       # history looks as intended
```

`.gitignore` already excludes `DerivedData/`, `xcuserdata/`, `*.xcresult` and
`.DS_Store`, and this was verified — no build output is staged. Shared schemes
*are* committed, so a fresh clone builds and tests with no setup. That was
verified by cloning the repository to a temporary directory and running the full
test suite there.

## Commit message style

Used throughout: a short imperative subject, a blank line, then a body
explaining *why* rather than restating the diff. Commits generated with AI
assistance carry a `Co-Authored-By: Claude` trailer, which is the honest record
and consistent with the AI-disclosure requirement.
