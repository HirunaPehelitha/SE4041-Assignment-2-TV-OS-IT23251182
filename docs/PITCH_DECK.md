# Brain Battle — Investor Pitch Deck

Ten slides. Speaker notes under each.

**Two conventions used throughout:**
- ✅ **IMPLEMENTED** — working in the prototype, demonstrable now
- 🔶 **PROPOSED** — a commercial plan, not built

**No market-size estimate, revenue forecast, user projection or validation
evidence appears in this deck.** There is no evidence base for any of them. Every
quantitative claim is either measured from the prototype or cited to a source.

---

## Slide 1 — Brain Battle

# BRAIN BATTLE
### Think Fast. Play Together.

**A trivia game for the one screen everyone is already looking at.**

Two to four players. One Apple TV. One remote. No phones, no accounts, no
internet.

*Native tvOS prototype · SE4041 Assignment 2 Part B · IT23251182*

> **Speaker notes:** Open by naming the constraint, because the constraint is
> the product. Most group quiz games need every player to pick up a phone. This
> one needs the remote that is already on the coffee table.

---

## Slide 2 — The problem

### Group trivia at home has a setup tax

Before anyone answers a question, somebody has to:

- find a phone for every player
- get everyone onto the Wi-Fi
- open a browser or install an app
- create or join a session

**For a family evening, that tax is often larger than the game itself.**

Who it excludes:
- children without phones
- guests who will not install anything
- homes with unreliable connectivity

### The opportunity

Quiz games are a large, commercially proven category:

- Kahoot! reached **1 billion cumulative players** (March 2017) and lists
  **12 billion non-unique players as of 2025** [1]
- Trivia Crack reports **600 million+ downloads** and **150 million+ active
  users annually** [2]

> **Speaker notes:** These figures establish that the *category* is real and
> large. They are explicitly **not** a forecast for Brain Battle — I have no
> evidence to make one, and I am not going to invent it.

---

## Slide 3 — The solution *(live demonstration)*

### Pick a category → name the players → pass the remote

| Step | Time |
|---|---|
| Choose from five categories, with a live preview | ~10s |
| Add 2–4 players, names remembered from last time | ~20s |
| Play ten questions, passing the remote | ~4 min |
| Ranked results, saved automatically | — |

**Everything on this slide is ✅ IMPLEMENTED and will be demonstrated live.**

> **Speaker notes:** Run the demo here, not at the end. The product is easier to
> show than to describe. See `VIVA_DEMO_PLAN.md`.

---

## Slide 4 — Who it is for

### Primary: households with an Apple TV and 2–4 people in the room

Families on an evening · friends after dinner · flatmates

**What they need:** something that starts immediately, works for mixed ages, and
needs nothing but the remote.

### Secondary: regional relevance

One of the five categories is **Sri Lankan Culture**, written for this project.
General-knowledge quizzes are usually Western-centric; local content is a genuine
differentiator in that market.

> ⚠️ **Honest limitation:** no user research or playtesting with real players was
> conducted. These are reasoned design assumptions, not validated findings, and I
> will not present them as evidence.

---

## Slide 5 — Features and differentiation

### ✅ Implemented in the prototype

| Feature | Detail |
|---|---|
| Local multiplayer | 2–4 players, turn-based, one shared remote |
| Five categories | 50 original questions, four options each |
| **Adaptive Challenge** | Rule-based difficulty from recent accuracy |
| Countdown timer | Scales with difficulty and a user preference |
| Answer review | Every question, what each player actually chose |
| Leaderboard | All-time standings with a documented ranking rule |
| Full offline operation | No network request exists in the codebase |
| Accessibility | VoiceOver labels, AAA contrast, Reduce Motion |

### The technical differentiator: Adaptive Challenge

Each player's last four answers place them in a band that weights their next
question:

| Recent accuracy | Band | easy / medium / hard |
|---|---|---|
| ≥ 70% | Harder | 1 / 3 / **5** |
| 36–69% | Balanced | 3 / 4 / 3 |
| ≤ 35% | Easier | **5** / 3 / 1 |

**This is a rule-based algorithm, not machine learning.** No model, no training.

Three properties, each unit-tested: *bounded* (no difficulty is ever excluded),
*safe defaults* (under two answers, no adaptation), *cannot stall a match*.

**It is explainable on screen.** A badge shows which way difficulty is leaning
and why — adaptive systems in games are usually invisible, which makes players
suspect them.

> **Speaker notes:** If asked why this matters: a mixed-age family is the exact
> case where a fixed difficulty fails. A child and a parent can share a match
> without one being bored and the other lost.

---

## Slide 6 — Competitor comparison

| | Kahoot! [1] | Trivia Crack [2] | Jackbox [3] | **Brain Battle** |
|---|---|---|---|---|
| Setting | Classroom | Personal mobile | Living room | **Living room** |
| Shared screen | Yes | No | Yes | **Yes** |
| Devices per player | One each | One each | One phone each | **None** |
| Network needed | Yes | Yes | Yes | **No** |
| On Apple TV | No | No | **Yes** | **Yes** |
| Content | User-generated | Publisher | Publisher | Publisher |

### The honest read

**Brain Battle is not the first multiplayer quiz game.** The category is
crowded and long-established.

The position it occupies is narrower: Jackbox proves shared-screen party games
work on Apple TV, but still needs **a phone per player and a network** [3].
Trivia Crack is **not on Apple TV** [2]. Kahoot! is browser-based and
education-first [1].

**The no-second-device, no-network trivia experience on Apple TV is a position
the researched competitors do not occupy.**

### What competitors do better

- Kahoot!: user-generated content at enormous scale
- Jackbox: private answers enable bluffing games Brain Battle cannot do
- Trivia Crack: remote and asynchronous play
- All three: far larger question libraries

> **Speaker notes:** Lead with what they do better. It is more persuasive than
> pretending the product wins everywhere, and an examiner will find these gaps
> anyway.

---

## Slide 7 — Proposed revenue model

> 🔶 **ENTIRELY PROPOSED. Nothing on this slide is implemented.** The prototype
> contains no payment code, no StoreKit integration, no advertising and no
> commercial distribution.

### Premium quiz packs — one-off purchases

| Tier | Content | Model |
|---|---|---|
| **Base game** | 5 categories, 50 questions | Free |
| **Themed packs** | e.g. Sri Lankan Heritage, Cricket, Film & Music | Paid, one-off |
| **Seasonal packs** | Occasional topical sets | Paid, one-off |

### Why one-off purchases rather than ads or subscription

- **No advertising.** A family game interrupted by adverts is a worse product,
  and advertising requires the network connection the product deliberately avoids.
- **No consumables.** Trivia Crack's coin model [2] rewards paying mid-game;
  that conflicts with a fair shared-screen match.
- **One purchase serves the household** — the same logic as Jackbox needing only
  one copy for a whole group [3].

### Technical feasibility

StoreKit has been available on tvOS since tvOS 9.0, and non-consumable products
— bought once, never expiring, restorable across devices — are a documented
product type [4]. A quiz pack maps directly onto a non-consumable.

> **Speaker notes:** Be explicit that this is a plan. If asked "did you build
> payments?" the answer is no, and the deck says so in three places.

---

## Slide 8 — Go-to-market

> 🔶 **PROPOSED. No commercial distribution has taken place.** The app has never
> been submitted to the App Store and has only ever run on a simulator.

### Phase 1 — Launch the base game free on the tvOS App Store

The tvOS App Store is a far less crowded shelf than iOS. A free, complete game
with no adverts and no account is unusually easy to recommend.

### Phase 2 — Regional positioning

Lead with the Sri Lankan Culture category in the Sri Lankan market, where
local-content quiz games are not well served. Local relevance is cheaper to
market than general knowledge.

### Phase 3 — First paid pack

Ship one themed pack only after the free game has real usage, so the first
purchase decision is made by people who already play.

### Phase 4 — Capability expansion

Multi-remote play (see Slide 9) widens the product from turn-based to
simultaneous, which is the largest single gameplay improvement available.

**Cost structure:** one developer, no servers, no backend, no third-party
dependencies. The entire running cost of the current product is the Apple
Developer Program membership.

---

## Slide 9 — Impact and roadmap

### Potential impact

- **Screen time that faces outward.** Everyone looks at one screen and at each
  other, rather than down at separate phones.
- **Genuinely inclusive.** Works for players with no phone — children, older
  relatives, guests.
- **Local culture on the television.** The Sri Lankan Culture category puts
  regional knowledge into a format usually dominated by Western general knowledge.
- **Accessible by construction.** VoiceOver throughout, AAA contrast, full
  Reduce Motion support.

*These are design intentions. No impact has been measured, because no user
testing has been conducted.*

### Roadmap

**Near term — 🔶 proposed**
- Multi-remote play via the GameController framework, so all players answer
  simultaneously. *Designed for; not built — the simulator cannot emulate
  multiple remotes, so it could not be developed or demonstrated.*
- A larger question bank
- Physical Apple TV testing

**Longer term — 🔶 proposed**
- Premium quiz packs via StoreKit [4]
- Team mode for larger groups
- A question editor

---

## Slide 10 — Closing

# Brain Battle
### Think Fast. Play Together.

**The value proposition in one line:**
A complete trivia match for two to four people, started in under a minute, using
nothing but the Apple TV remote.

### What exists today — ✅ verified

| | |
|---|---|
| Playable prototype | Category → setup → match → results → leaderboard |
| Unit tests | **287 passing**, 0 warnings |
| Question bank | 50 original questions, 5 categories |
| Innovation | Rule-based, explainable Adaptive Challenge |
| Dependencies | **None** |
| Network requests | **None** |

### What does not exist — 🔶 honest

Payments · online multiplayer · commercial distribution · multi-remote support ·
user research

### The ask

Feedback on whether the *no-second-device* position is strong enough to build a
commercial product around — and on which themed pack a household would actually
pay for first.

> **Speaker notes:** Close on the question, not a claim. The strongest thing to
> say about this project is not a market forecast — it is that a test caught the
> Adaptive Challenge feature being nearly inert before anyone demonstrated it.

---

## References

1. Wikipedia, *Kahoot!* — https://en.wikipedia.org/wiki/Kahoot!
2. Wikipedia, *Trivia Crack* — https://en.wikipedia.org/wiki/Trivia_Crack
3. Wikipedia, *The Jackbox Party Pack* — https://en.wikipedia.org/wiki/The_Jackbox_Party_Pack
4. Apple Inc., *StoreKit* documentation — https://developer.apple.com/documentation/storekit

Full analysis with all sources: [`COMPETITOR_ANALYSIS.md`](COMPETITOR_ANALYSIS.md)
