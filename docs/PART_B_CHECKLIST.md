# Part B Assessment Checklist

Maps the evidence to the five Part B criteria and their mark weightings, with
the exact artefact for each. Gaps are marked ❌ rather than argued around.

| Criterion | Marks |
|---|---:|
| Concept Innovation | 25 |
| Prototype Functionality | 25 |
| User Experience Design | 15 |
| Technical Proficiency | 15 |
| Pitch Presentation | 20 |
| **Total** | **100** |

---

## 1. Concept Innovation — 25 marks

*"Highly innovative, original, strong market potential, addresses a unique need
or provides a new kind of experience."*

| ✓ | Evidence | Where |
|---|---|---|
| ✅ | Novel concept for the platform: trivia needing **no second device and no network** | `PITCH_DECK.md` slides 2–3 |
| ✅ | **Adaptive Challenge** — rule-based, bounded, explainable difficulty | `Models/AdaptiveDifficulty.swift`; slide 5 |
| ✅ | On-screen explanation badge — adaptive systems are usually invisible | Live demo, 2:00–3:30 |
| ✅ | **Existing similar apps described and cited** *(explicit brief requirement)* | `COMPETITOR_ANALYSIS.md` |
| ✅ | Regional relevance: Sri Lankan Culture category | `questions.json`, slide 4 |
| ✅ | Market potential argued **without invented statistics** | Slides 2, 7 |
| ✅ | Does **not** claim to be the first multiplayer quiz game | Stated explicitly in both docs |
| ❌ | No user research or validation | Declared in slide 4 and the report |

**Strongest point:** the competitor analysis identifies a position the
researched products genuinely do not occupy — Jackbox is on Apple TV but needs
phones and a network; Trivia Crack is not on Apple TV at all.

---

## 2. Prototype Functionality — 25 marks

*"Effectively demonstrates core functionality, showcasing advanced platform
features."*

| ✓ | Evidence | Where |
|---|---|---|
| ✅ | Complete playable loop: category → setup → match → results → leaderboard | Live demo |
| ✅ | 2–4 local players, turn rotation | `QuizGameViewModel` |
| ✅ | 50 original questions, 5 categories, validated at load | `questions.json` |
| ✅ | Countdown with safe cancellation | Engine; 23 tests |
| ✅ | Scoring that cannot double-count | Two guards; tested with 10 rapid presses |
| ✅ | Answer shuffling that preserves the correct answer | 500-seed test |
| ✅ | Local persistence surviving relaunch | `MatchHistoryStore`; 41 tests |
| ✅ | Leaderboard with a documented deterministic rule | `LeaderboardRanking` |
| ✅ | Answer review showing real recorded answers | `ReviewAnswersView` |
| ✅ | Settings that each change behaviour | 4 working preferences |
| ✅ | **tvOS-specific:** focus engine, `defaultFocus`, remote-driven navigation | Throughout |
| ✅ | **Multi-user experience for tvOS** *(named in the brief)* | Pass-the-remote, 2–4 players |
| ❌ | Multiple simultaneous remotes | Designed for, not built — simulator cannot emulate |
| ❌ | Never run on physical hardware | Simulator only |

**Note on the brief's "multi-user experiences for tvOS":** satisfied by local
pass-the-remote multiplayer. Multi-controller play was deliberately not
attempted because the simulator cannot emulate multiple remotes, so it could
neither be developed nor demonstrated.

---

## 3. User Experience Design — 15 marks

*"Highly engaging, intuitive, excellent use of platform-specific interaction
models."*

| ✓ | Evidence | Where |
|---|---|---|
| ✅ | Focus-first design: every control reachable, nothing dead | `TECHNICAL_DOCUMENTATION.md` §5 |
| ✅ | `defaultFocus` on every screen | All screens |
| ✅ | Unplayable controls disabled so the remote skips them | Locked categories, answered questions |
| ✅ | Live preview panel updating with focus — a television pattern | `CategorySelectView` |
| ✅ | **Measured** contrast: 18.55:1, 9.96:1, 16.37:1 (AAA is 7:1) | Report §8 |
| ✅ | Defect found by measuring: cards at 1.11:1 → hairline borders | Report §12 |
| ✅ | Typography sized for ~3 m viewing (min 24pt) | `BrandTheme` |
| ✅ | VoiceOver labels on every interactive control | Audited in Stage 10 |
| ✅ | Reduce Motion honouring **both** app and system settings | `ContentView` |
| ✅ | Restrained motion — nothing loops while text is being read | Stage 9 |
| ❌ | Focus navigation verified **manually only** | UI tests cannot run |
| ❌ | No usability testing with real users | Declared |

---

## 4. Technical Proficiency — 15 marks

*"Strong technical skill, stable implementation, optimised performance,
appropriate coding standards."*

| ✓ | Evidence | Where |
|---|---|---|
| ✅ | MVVM with strict separation — views make no decisions | `TECHNICAL_DOCUMENTATION.md` §1 |
| ✅ | **287 unit tests passing**, 0 warnings in Debug **and** Release | Test Navigator |
| ✅ | Dependency injection throughout; no singletons | All services |
| ✅ | Finite state machine for gameplay, not booleans | `MatchPhase` |
| ✅ | Value-typed navigation; routes carry payloads | `AppRoute` |
| ✅ | Per-entry validation: one bad question cannot stop launch | `QuestionBankDecoder` |
| ✅ | Corrupt stored data handled and removed | `MatchHistoryStore`; tested |
| ✅ | **No force unwraps, `try!` or `fatalError` in app code** | Verified by audit |
| ✅ | Deterministic testing via seeded RNG and injectable countdown | `SeededRandomNumberGenerator` |
| ✅ | No third-party dependencies | — |
| ✅ | Real defects found and fixed by tests | Report §12 |
| ❌ | 13 UI tests written but **never executed** | Environment failure |
| ❌ | Release configuration build-verified, not run-verified | Debug only |

**Strongest point:** the 29-versus-29 failure. A test caught Adaptive Challenge
being structurally inert before it was ever demonstrated. That is the single
best piece of evidence that the testing is real rather than decorative.

---

## 5. Pitch Presentation — 20 marks

*"Professional, persuasive; clearly explains value proposition, market
potential, business strategy."*

| ✓ | Required element | Where |
|---|---|---|
| ✅ | Value proposition | Slides 1, 10 |
| ✅ | Target market | Slide 4 |
| ✅ | **Premium quiz-pack revenue model** | Slide 7 |
| ✅ | Go-to-market strategy | Slide 8 |
| ✅ | Potential impact | Slide 9 |
| ✅ | Future opportunities | Slide 9 |
| ✅ | Competitor comparison with citations | Slide 6; `COMPETITOR_ANALYSIS.md` |
| ✅ | Implemented vs proposed clearly separated (✅ / 🔶) | Throughout |
| ✅ | Technical feasibility of the revenue model cited | StoreKit on tvOS |
| ✅ | **No invented statistics, forecasts or validation** | Stated explicitly |
| ✅ | Five-minute demonstration plan with timings | `VIVA_DEMO_PLAN.md` |
| ✅ | Anticipated questions with honest answers | `VIVA_DEMO_PLAN.md` |

---

## Submission guidelines compliance

| ✓ | Requirement | Status |
|---|---|---|
| ✅ | Individual work | Yes |
| ⚠️ | **GitHub repository** | Local repo with branches; **nothing pushed yet** — see `COMMIT_PLAN.md` |
| ✅ | Clear commit messages, feature branches | 4 commits; plan for the rest |
| ✅ | Well-commented code | Throughout |
| ✅ | README with build/run instructions | `README.md` |
| ✅ | **AI-assisted development documented** | `AI_USAGE_LOG.md` |
| ✅ | Original work | All code and questions written for this project |
| ✅ | Ready for viva | `VIVA_DEMO_PLAN.md` |

> ⚠️ **Action required before submission:** the repository has **no remote and
> has never been pushed**. Follow `COMMIT_PLAN.md` to commit Stages 7–12 and
> publish to GitHub.

---

## Remaining work and limitations — consolidated

### Must do before submission

1. **Commit Stages 7–12 and push to GitHub** — currently local only
2. Decide whether to fold the competitor analysis into `ASSIGNMENT_REPORT.md` §6
3. Rehearse the demo against a clock at least twice

### Should do if time allows

4. Try the UI tests on another machine — they may simply work elsewhere
5. Test on a physical Apple TV
6. Expand the question bank beyond 50

### Honest limitations to state, not hide

| # | Limitation | Where declared |
|---|---|---|
| L1 | **13 UI tests have never executed** | README, TEST_PLAN, report, demo plan |
| L2 | Focus navigation verified manually only | TEST_PLAN M17 |
| L3 | Audio output never confirmed audible | TEST_PLAN M19 |
| L4 | Never run on physical hardware | README, report |
| L5 | Single remote only; multi-controller not built | Slides 5, 9; report |
| L6 | 50 questions, no editor, no downloadable packs | README |
| L7 | **No user research or playtesting** | Slide 4, report §4 |
| L8 | No payments, online multiplayer or distribution | Slides 7, 8, 10 |
| L9 | Release config build-verified, not run-verified | TEST_PLAN M21 |
| L10 | Leaderboard groups by name — two people sharing a name share a row | Report §13 |

**There are no known open functional defects.** Every limitation above is a gap
in verification or scope, not a known broken behaviour.
