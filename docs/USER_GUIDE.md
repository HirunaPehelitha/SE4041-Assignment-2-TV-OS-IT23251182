# Brain Battle — User Guide

**Think Fast. Play Together.**

Everything in this guide describes the app as built. Nothing here is planned or
hypothetical.

---

## 1. Launching the app

Open Brain Battle from the Apple TV home screen. The app opens on the main menu
with four options:

| Option | What it does |
|---|---|
| **Play Game** | Starts a new match |
| **How to Play** | The rules, turn order, scoring and timings |
| **Leaderboard** | Past results and all-time standings on this Apple TV |
| **Settings** | Preferences, instructions, about and data information |

**Play Game** already has the focus ring when the app opens, so you can press
**Select** straight away.

Along the bottom you will see how many questions and categories are loaded. If
that strip is missing and an error appears instead, the question bank could not
be read — see *Troubleshooting*.

**Moving around:** press **left** and **right** on the remote to move the focus
ring, **Select** to choose, and **Menu** to go back. On the simulator these are
the arrow keys, **Return** and **Esc**.

## 2. Selecting a category

Choosing **Play Game** opens *Choose a Category*.

Five categories are available: Sri Lankan Culture, Sports & Cricket, Science &
Nature, Movies & Entertainment, and General Knowledge.

The large panel above the row describes whichever category currently has focus —
its description, how many questions it holds at each difficulty, and the points
on offer. **Move across the row to compare categories without committing to
one**; the panel updates as you go.

Press **Select** on a category to choose it. A tick appears on the card, so if
you come back later you can see what you picked.

A category with fewer than five questions appears **locked**, dimmed with a
padlock, and the remote skips over it. The footer tells you how many categories
are playable.

Press **Back** (or the **Menu** button) to return to the main menu.

## 3. Configuring players

*Player Setup* opens with **two player slots**, which is the minimum.

Each slot has its own colour down the left edge and a **PLAYER 1 / PLAYER 2**
label, so the slots stay distinguishable from across the room.

**To set an avatar:** focus the avatar button and press **Select**. It moves to
the next available symbol. Avatars already taken by another player are skipped,
so two players can never end up with the same one.

**To enter a name:** focus the name field and press **Select**. The tvOS
full-screen keyboard opens. Type the name and confirm.

**To add a third or fourth player:** focus the **Add Player** card and press
**Select**. The card disappears once four players are added.

**To remove a player:** a **Remove** button appears on each slot once you have
more than two players.

The top of the screen shows the category you chose, the number of questions and
how many turns each player will get.

### What stops you starting

**Start Battle** stays dim until the setup is valid. A message explains why:

| Message | Fix |
|---|---|
| "Player N needs a name." | That slot is empty or contains only spaces |
| "Player N's name is longer than 14 characters." | Shorten it |
| "Two players are both called …" | Give them different names |

Duplicate names are compared ignoring capitals and spaces, so "Sam" and " sam "
count as the same name. This is deliberate: two identical rows on a scoreboard
cannot be told apart from a sofa.

If the number of questions does not divide evenly between the players, an
information line says so — the earlier seats take one extra turn.

Once valid, **Start Battle** becomes bright. Press it.

Your names and avatars are remembered for next time, so a returning group does
not retype them.

## 4. Playing a match

Press **Begin Match** on the Match Ready screen, which shows the turn order and
how many questions each player will face.

During a question you see:

- **Top left** — whose turn it is, with their avatar and colour
- **Top right** — the question number, the countdown ring, and (if Adaptive
  Challenge is on) a badge reading *Easier*, *Balanced* or *Harder*
- **Below that** — a progress bar for the whole match
- **Middle** — the question and four answer cards, A to D
- **Bottom** — every player's running score

**To answer:** move the focus ring to an answer and press **Select**.

Once you answer — or the timer runs out — the question freezes. The correct
answer turns green with a tick. If you picked a wrong one, yours turns red.
The explanation appears beneath, along with whether you scored.

Pressing extra buttons at this point does nothing; your first answer is final.

Press the button at the bottom right to continue. It names who is next
("Next: Nimal"), which is your cue to **pass the remote**. On the final
question it reads **See Results**.

**If you run out of time**, the turn scores nothing and play moves on. The
countdown turns amber and then red as it gets low.

## 5. Understanding scoring

The rules are simple and the same for everyone:

| Outcome | Points |
|---|---|
| Correct answer | **100** |
| Wrong answer | **0** |
| Ran out of time | **0** |

There is **no penalty** for a wrong answer, so it is always worth guessing.

A question can only ever score once, however many times a button is pressed.

**Difficulty does not change the points.** What it changes is how long you get:

| Difficulty | Standard time |
|---|---|
| Easy | 15 seconds |
| Medium | 20 seconds |
| Hard | 25 seconds |

These shift together with the **Question Time** setting.

### Results

At the end you see the final ranking, each player's score, and how many of their
questions they got right.

If two or more players finish level, the app says so — "A and B Tie" or
"Everybody Ties" — and every tied player is marked as a winner. It does not pick
one arbitrarily.

From here you can:

- **Play Again** — a new match with the same players and category, scores reset
  and questions freshly shuffled
- **Review Answers** — every question, who answered it, what they chose, the
  correct answer and the explanation
- **Return Home** — back to the main menu

The result is saved automatically. A small "Saved" label confirms it. Going into
Review Answers and back does not save it a second time.

## 6. Viewing the leaderboard

**Leaderboard** from the main menu shows two tables.

**All-time standings** ranks every player who has ever played on this Apple TV.
Players are matched by name, ignoring capitals, so the same person keeps one row
across evenings. The ranking rule, in order:

1. Total points, highest first
2. Wins, highest first
3. Accuracy, highest first
4. Fewer matches played
5. Name, A to Z

The last step guarantees the order never changes between launches.

**Recent matches** lists each saved match with its category, date, question
count and final scores, with a trophy on the winner and a TIE badge on drawn
matches.

**Clear History** deletes every saved match. It asks for confirmation first and
tells you how many will be deleted. This cannot be undone.

If nothing has been played, the screen explains that results appear here after a
completed match. Abandoning a match part-way does not save anything.

## 7. Using settings

### Gameplay

**Adaptive Challenge** *(on by default)* — chooses each question from the
player's recent accuracy. A good run brings harder questions; a difficult run
brings easier ones. It is a fixed set of rules, not machine learning, and the
badge during play always shows which way it is leaning. Turn it off to play a
straightforward shuffled round.

**Sound Effects** *(on by default)* — short tones for right, wrong and
out-of-time.

**Question Time** — three options, shown with their actual timings:

| Setting | Range |
|---|---|
| Relaxed | 25–35 seconds |
| Standard | 15–25 seconds |
| Quick | 10–20 seconds |

Harder questions always keep more time than easy ones.

### Accessibility

**Reduce Motion** — switches off entrance and focus animations throughout the
app. The focus ring still changes colour and border, so nothing becomes harder
to see. If tvOS Reduce Motion is already on system-wide, the app follows it and
says so.

### Instructions, About and Your data

**How to Play** opens the rules. **About** shows the version and what the app is.

**Your data** describes exactly what is stored: completed match results, the
last roster of names and avatars, and your preferences. Everything stays on this
Apple TV. There are no accounts, no network requests and no analytics.

## Troubleshooting

**"Question bank unavailable" on the main menu** — `questions.json` is missing
from the app bundle. Rebuild the app.

**No categories are playable** — every category needs at least five questions.

**The app will not start a match** — check the message under the player slots.

**Sound is not playing** — check Sound Effects in Settings, and that your
Apple TV or simulator is not muted.
