# Five-Minute Viva Demonstration Plan

**Goal:** show a complete working product and one piece of real engineering
evidence, without running out of time or being caught claiming something untrue.

---

## Before you start — 10 minutes earlier

| ✓ | Task |
|---|---|
| ☐ | Simulator **already booted** — cold boot takes over a minute |
| ☐ | App **already built and installed** (⌘R once, then quit) |
| ☐ | Settings: Adaptive Challenge **ON**, Sound **ON**, Question Time **Quick** |
| ☐ | Play one throwaway match so the Leaderboard is not empty |
| ☐ | Simulator window maximised, Mac notifications off |
| ☐ | Xcode open on `QuizGameViewModel.swift` in a second tab |
| ☐ | Test Navigator (⌘6) ready, tests already run and green |

> **Question Time = Quick** shortens every countdown by 5 seconds. Over ten
> questions that is most of a minute saved.

---

## The five minutes

### 0:00–0:30 — Frame it (30s)

> "Brain Battle is a trivia game for two to four people sharing one Apple TV.
> The constraint that defines it: no phones, no accounts, no internet. Just the
> remote already on the table. Everything I'm about to show runs offline."

Home screen visible. **Do not read the slides.**

### 0:30–1:15 — Category selection (45s)

Press **Select** on Play Game. Move **right** across the categories.

> "The panel updates as focus moves, so a group can compare subjects before
> committing. That's a television pattern — on a phone you'd tap into each one."

Stop on **Sri Lankan Culture**.

> "Five categories, fifty original questions. This one is deliberate: general
> knowledge quizzes are usually Western-centric."

Press **Select**.

### 1:15–2:00 — Player setup (45s)

> "Two slots minimum, four maximum. Each has its own colour and avatar — the
> avatar cycler skips anything another player already has, so they can't collide."

Names should already be remembered. If not, type one short name.

> "Names are remembered between matches. Start Battle stays disabled until the
> setup is valid — blank names, duplicates and over-long names are each refused
> with a specific reason."

**If time is tight:** skip typing, use the remembered roster, go straight on.

Press **Start Battle** → **Begin Match**.

### 2:00–3:30 — Gameplay (90s) · *the core of the demo*

Answer **question 1 correctly**.

> "Correct answer, hundred points, explanation shown. The score chip flashes."

Answer **question 2 correctly** too.

**Point at the badge, top right.**

> "That badge is the innovation. After two answers it reads *Harder* — the
> player's recent accuracy has moved them into a band that weights their next
> question toward harder ones. It's a rule-based algorithm, not machine
> learning: three bands, fixed weights, and no difficulty is ever excluded.
> Crucially it's *explainable* — the player can see which way it's leaning."

**Let question 3 time out.** Say nothing while the ring turns amber, then red.

> "Timeout scores nothing, the question freezes, and the correct answer is
> revealed anyway so the group still learns it."

Answer the rest quickly to finish the match.

### 3:30–4:15 — Results and persistence (45s)

> "Ranked results, per-player accuracy. Ties are handled properly — every tied
> player is marked a winner rather than the app picking one."

Press **Review Answers**.

> "Every question, who answered it, and what they actually chose. That's a
> stored record from the match, not a reconstruction."

Press **Menu**, then **Return Home** → **Leaderboard**.

> "All-time standings across every match saved on this device. Ranked by points,
> then wins, then accuracy, then fewest matches, then name — that last step
> makes the order fully deterministic. All stored locally in UserDefaults.
> There is no cloud, no account and no network request anywhere in the codebase."

### 4:15–5:00 — The engineering evidence (45s) · *do not skip this*

Switch to Xcode. Show the Test Navigator: **287 tests, all green.**

> "287 unit tests, zero warnings in Debug and Release."

**Then tell the 29-versus-29 story:**

> "The most useful thing a test did on this project: I wrote one comparing how
> many hard questions a strong player sees versus a struggling one. It returned
> twenty-nine versus twenty-nine. Identical.
>
> The feature was nearly inert. A match consumed its whole question list, so
> every question got asked regardless of what the policy decided — adaptation
> could only reorder, never actually choose. I fixed it by separating the
> question pool from the round length, so a ten-question match now draws from
> about twenty.
>
> Without that test the feature would have looked implemented and done almost
> nothing — and I'd have demonstrated it to you today without knowing."

**Close:**

> "I should be straight about one limitation: thirteen UI tests are written and
> compile, but the tvOS test runner won't start on my machine. They've never
> reported a pass, so I don't claim they do."

---

## Timing discipline

| Segment | Budget | Cut first if behind |
|---|---|---|
| Framing | 0:30 | — |
| Category | 0:45 | Shorten the browse |
| Player setup | 0:45 | **Skip typing names** |
| Gameplay | 1:30 | Protect this |
| Results | 0:45 | Skip Review Answers |
| Evidence | 0:45 | **Never cut this** |

**If you fall badly behind:** abandon the match mid-way and go straight to the
Leaderboard with the pre-played result, then to the tests. A finished match is
less important than the evidence segment.

---

## Likely questions

**"Is the adaptive difficulty machine learning?"**
> No. Three bands, fixed weights, a four-answer window. No model, no training.
> I can show you the whole policy — it's about forty lines.

**"How do you know it works?"**
> A statistical test over several seeds, plus tests that it can't stall a match,
> can't pick an invalid question, and doesn't adapt on fewer than two answers.
> And the 29-versus-29 test that caught it not working.

**"Why not Core Data or SwiftData?"**
> The whole dataset is under 150 KB and is never queried or filtered. UserDefaults
> is native, synchronous and needs no schema. SwiftData would add a container and
> a migration story to store a small array. If history grew to thousands of
> entries, that's when I'd move.

**"Why does difficulty not change the score?"**
> It did earlier — 100/200/300. The flat rule was specified later, so I unified
> it into one `MatchScoring` type and updated the How to Play text and category
> screens with it. Difficulty still controls thinking time.

**"Did you test on a real Apple TV?"**
> No. Simulator only. That's in my limitations.

**"Could four people play at once?"**
> Not in this build. tvOS supports multiple controllers via GameController, and
> the input is abstracted for it, but the simulator can't emulate multiple
> remotes — so I couldn't develop or demonstrate it, and I won't claim it.

**"What's the weakest part?"**
> Two things. The UI tests have never executed. And there's no user testing at
> all — my target-audience reasoning is a design assumption, not a finding.

---

## Rules for the demo

1. **Never claim the UI tests pass.** They have never run.
2. **Never say "machine learning."**
3. **Never claim payments, online multiplayer or App Store distribution exist.**
4. If something breaks, say what you expected and move on. Do not improvise an
   explanation.
5. If you don't know, say so and say how you'd find out.
