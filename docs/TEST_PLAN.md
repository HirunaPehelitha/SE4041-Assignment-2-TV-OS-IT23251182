# Brain Battle — Test Plan and Results

**Last executed:** 14 October 2026
**Environment:** Xcode 26.1.1 (17B100), macOS Darwin 25.1.0, Apple TV 4K
(3rd generation) simulator, tvOS 26.1

Every result below was produced by an actual run. Where something was not
executed, it is marked as such rather than assumed to pass.

---

## 1. Test objectives

1. Prove the game rules are correct — scoring, turn order, timing, completion
2. Prove a question can never score twice, however the remote is pressed
3. Prove the correct answer survives shuffling
4. Prove saved data survives relaunch and cannot be corrupted into a crash
5. Prove the leaderboard order is deterministic
6. Prove Adaptive Challenge cannot stall a match or select an invalid question
7. Prove the app degrades honestly when data is missing or malformed

## 2. Unit tests — 287, all passing

```bash
xcodebuild test -project IT23251182-tvOS.xcodeproj \
                -scheme IT23251182-tvOS \
                -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
                -only-testing:IT23251182-tvOSTests
```

**Actual result:** `Executed 287 tests, with 0 failures (0 unexpected)` —
**TEST SUCCEEDED**, 0 compiler warnings.

| File | Tests | Covers |
|---|---:|---|
| `QuestionBankDecoderTests` | 15 | Decoding, malformed JSON, per-entry rejection, duplicate ids, option rules |
| `BundledQuestionBankTests` | 10 | The real shipped `questions.json` |
| `QuestionRepositoryTests` | 16 | Filtering, counting, match-set construction, shuffling |
| `PreparedQuestionTests` | 5 | Correct-answer mapping across 500 seeds |
| `ModelTests` | 23 | Player, settings, results, difficulty |
| `CategorySelectionTests` | 21 | Availability, playability rule, selection hand-off |
| `PlayerSetupTests` | 47 | Roster limits, name validation, avatars, session building, roster persistence |
| `QuizGameEngineTests` | 38 | Answers, timeouts, rapid input, turn rotation, completion |
| `MatchResultsTests` | 37 | Ranking, ties, save-once, Play Again, turn log |
| `PersistenceTests` | 41 | Settings, durations, sound, storage safety, leaderboard ordering |
| `AdaptiveDifficultyTests` | 34 | Bands, bounded weights, selection, disabled behaviour |

### Coverage of the required areas

| Required area | Tests |
|---|---:|
| 1. Question decoding and validation | 28 |
| 2. Player setup validation | 64 |
| 3. Correct and incorrect answers | 51 |
| 4. Timeout behaviour | 23 |
| 5. Turn rotation | 26 |
| 6. Question progression | 44 |
| 7. Match completion | 32 |
| 8. Tie handling | 20 |
| 9. Local persistence | 41 |
| 10. Leaderboard ordering | 10 |
| 11. Adaptive difficulty | 20 |

*(Counts overlap: one test can serve several areas.)*

### Notable cases

| Test | What it proves |
|---|---|
| `testRepeatedPressesScoreOnlyOnce` | 10 rapid presses score once |
| `testTickAfterAnsweringCannotChangeAnything` | 50 stray ticks change nothing |
| `testTickAfterMatchEndsCannotChangeAnything` | The timer cannot touch a finished match |
| `testShuffleKeepsCorrectAnswerAttachedAcrossManySeeds` | 500 seeds, answer never detaches |
| `testRankingIsStableAcrossRepeatedRuns` | 12 identical entries, 20 shuffles, same order |
| `testCorruptedHistoryIsRemovedSoItCannotFailForever` | Bad data is deleted, not re-read |
| `testAbandonedRoundIsNeverStored` | Quitting mid-match saves nothing |
| `testAdaptationCannotStallAfterRepeatedTimeouts` | Adaptive selection always completes |
| `testAFreshViewModelForTheSameMatchStillDoesNotDuplicate` | Save-once survives a view rebuild |

## 3. UI tests — 13 written, **0 executed**

```bash
xcodebuild test … -only-testing:IT23251182-tvOSUITests
```

**Actual result: FAILED TO RUN.**

```
Failed to initialize for UI testing: XCTDaemonErrorDomain Code=18
"Timed out waiting for AX loaded notification"
```

The test runner never starts, so **no UI test has reported a pass or a failure**.

**Diagnosis:** attempted three times — the working simulator, a clean reboot of
it, and a never-used Apple TV 4K @1080p. Identical failure every time. The
accessibility service the runner waits on does not load on this machine. This is
an environment problem, not a project defect.

**Evidence the tests themselves are sound:** `xcodebuild build-for-testing`
reports **TEST BUILD SUCCEEDED**, and all 13 methods are present in the signed
bundle (confirmed with `nm` on
`IT23251182-tvOSUITests.xctest`).

| Test | Intended coverage |
|---|---|
| `testAppLaunchesToTheHomeScreen` | Launch |
| `testHomeScreenShowsEveryMenuAction` | Menu completeness |
| `testPlayGameHasFocusOnLaunch` | Default focus |
| `testPlayGameOpensCategorySelection` | Navigation |
| `testCategorySelectionLeadsToPlayerSetup` | Navigation + hand-off |
| `testMenuButtonReturnsFromCategorySelection` | Back navigation |
| `testHowToPlayOpensAndReturns` | Navigation round trip |
| `testLeaderboardOpens` | Navigation |
| `testSettingsOpensAndShowsItsSections` | Navigation + content |
| `testFocusMovesAcrossTheHomeMenu` | Focus movement |
| `testFocusSkipsNothingReachableOnTheHomeRow` | Focus returns |
| `testPlayerSetupBlocksStartUntilNamesAreEntered` | Validation in UI |
| `testCategoryScreenShowsThePreviewPanel` | Live preview panel |

**These must not be described as passing in any submission.**

## 4. Manual tests

Performed by running the app on the simulator and inspecting screenshots.

### Verified — evidence captured

| # | Test | Outcome |
|---|---|---|
| M1 | App launches to home; bank loads | ✅ "50 Questions · 5 Categories · v2" |
| M2 | Category preview updates with focus | ✅ Sri Lankan Culture, 1,800 pts, 4/4/2 |
| M3 | Locked category when under-supplied | ✅ Verified by temporarily trimming the bank; showed padlock, "Not enough questions", footer "3 playable / 2 locked"; bank restored |
| M4 | Category selection reaches player setup | ✅ Category, round length and difficulties carried across |
| M5 | Player setup opens with 2 slots, distinct colours | ✅ Lime/sky edges, Star/Bolt avatars |
| M6 | Start Battle blocked while invalid | ✅ "Player 1 needs a name.", button dimmed |
| M7 | Match Ready shows turn order | ✅ 3 players, 4+3+3 = 10 turns, 2000 points |
| M8 | Gameplay renders with a live countdown | ✅ 15 → 10 → 0 observed |
| M9 | **Timeout end-to-end** | ✅ Clock reached 0, correct answer revealed green, others dimmed, "Out of time / No points", explanation shown, focus moved to "Next: Nimal" |
| M10 | Results with a tie | ✅ "Everybody Ties", both "Tied 1st", both trophies, 2 of 6 = 33% |
| M11 | Review Answers shows real answers | ✅ Actual wrong pick ("Vesak"), timeout shown as "No answer — time ran out" |
| M12 | Leaderboard persists across launches | ✅ Match played manually in one session appeared in a later launch |
| M13 | Leaderboard ranking tiebreak | ✅ Two players level on points and wins; accuracy (80% vs 50%) broke the tie |
| M14 | Case-insensitive player grouping | ✅ "hiruna" and "Hiruna" merged into one row, 2 played |
| M15 | Settings render and persist | ✅ All sections; values survived relaunch |
| M16 | Adaptive badge with little history | ✅ Showed "Balanced" for a player with one answer — the safe-default rule |

### Not verified

| # | Test | Why |
|---|---|---|
| M17 | Focus movement with the remote | tvOS rejects synthetic input; UI tests blocked |
| M18 | tvOS full-screen keyboard for names | Requires real remote input |
| M19 | Sound output audible | Data validated as WAV; audibility not confirmable here |
| M20 | Physical Apple TV behaviour | No device available |
| M21 | Release configuration at runtime | Build-verified only |

## 5. Expected vs actual

| Objective | Expected | Actual |
|---|---|---|
| Game rules correct | All engine tests pass | ✅ 38/38 |
| No double scoring | Repeated input scores once | ✅ Verified |
| Shuffle preserves answer | True for all seeds | ✅ 500 seeds |
| Persistence survives relaunch | Data reloads | ✅ Unit + manual (M12) |
| Corrupt data safe | No crash, bad value removed | ✅ Verified |
| Leaderboard deterministic | Same order every run | ✅ 20 shuffles |
| Adaptive cannot stall | Match always completes | ✅ Verified |
| Navigation flows work | UI tests pass | ❌ **Unexecuted** |

## 6. Known defects and limitations

### Resolved during QA

| Defect | Resolution |
|---|---|
| Player names clipped in 3 places | Added `minimumScaleFactor(0.7)` to leaderboard rows, match chips and the score strip |
| Isolated `deinit` aborted the test host | Project switched to `nonisolated` default isolation |
| Adaptive difficulty was inert | Separated question pool from round length; found by a test returning 29 vs 29 |
| Focused `Toggle` unreadable on tvOS | Replaced with `BrandToggleRow` |
| Cards invisible against the background (1.11:1) | Hairline borders added |
| Unequal home card heights | `lineLimit(2, reservesSpace: true)` |

### Open

| # | Limitation | Impact |
|---|---|---|
| L1 | UI tests cannot execute | Navigation and focus unverified by automation |
| L2 | Focus navigation manual only | Regressions would not be caught automatically |
| L3 | Audio unverified | Sound may not be audible |
| L4 | Simulator only | Device behaviour unknown |
| L5 | Single remote only | Multi-controller designed for, not implemented |
| L6 | Fixed 50-question bank | No editor, no downloadable content |
| L7 | Release not run-tested | Debug only |

**No known functional defects are open.** Every limitation above is a gap in
verification or scope, not a known broken behaviour.
