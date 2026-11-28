---
name: write-spec
description: Draft or revise a Colony spec (specs/NNN-slug/spec.md) with Zak so an implementer lane can build it without guessing. Use when turning a feature, milestone item or design idea into a spec, when splitting work into lanes, or when a lane reports that a spec is wrong.
---

# Writing a spec

A spec is good when an implementer who has never spoken to Zak builds the right thing from it, and a reviewer
can say yes or no to each requirement from the code alone.

## Before writing

- Read `docs/design/plan.md` for what the feature is for, `docs/architecture.md` for the rules it must fit, and
  `specs/README.md` for what has landed and what is in progress.
- Settle the design questions with Zak in conversation first. Ask only what changes the spec; decide the rest
  and say what you decided.
- Check every fact the spec states against the code before showing it: grep each count ("eight guards",
  "30 calls in 20 files") and list the files, and grep `tests/` for every name the spec moves or removes.
  Four of the seven cleanup specs stopped a lane or needed amending for a count or a path a grep would have
  caught.
- Size it: one lane, one pull request a person could review in one sitting. If the Paths list spans unrelated
  folders or the requirements pass about eight, split it.

## Writing it

Copy `specs/TEMPLATE.md` to `specs/NNN-slug/spec.md` (next free number) and add a row to the board.

- **Intent** says what becomes possible, in the player's or the next spec's terms.
- **Requirements** are observable. "After a wipe the party is at the last stable depth with full health", not
  "add a `revive()` method". Give numbers where behaviour depends on them, and say which are tunable data.
- **Interfaces** are exact where other work will depend on them, and silent where it will not. If two lanes
  will meet at an interface, plan to land its stub yourself before spawning either.
- **Acceptance** has one test per requirement. If you cannot say how a requirement would be tested headless,
  either rewrite it until you can or list it for Zak's playtest. Include the failure case, not only the
  success: a requirement about surviving needs a test where the party does not.
- **Out of scope** names the nearby things a keen implementer would be tempted to add.
- **A spec that changes nothing the game does** says so in R1 and says how that is shown (the unedited
  suite, a baseline to compare with). If it makes several variants into one, list what each variant does
  today: "the one intended change" hid a second in spec 076. Old tests that read source text will break on a
  harmless move; name them and say they may follow it.
- **Paths** is the lane's fence. Check it against every spec currently `approved` or `in-progress`: no overlap.
  A spec that adds content (monsters, classes, items) must also fence in the existing tests that count or
  compare *all* of that content (`grep -rn "monster_ids()\|hero_class_ids()" tests/`): spec 013 stopped twice on
  "five monsters" counts in tests 004 and 005 that its Paths did not allow it to touch.
  A spec that adds a saved field must fence in `tests/unit/test_save_progress.gd` (its round trip lists
  every field a loaded hero saves), and one that changes what a hero may take must fence in
  `game/dev/showcase_moments.gd` (its talent moment clicks a tier-2 node): spec 110 had to touch both.
- **Open questions** is where disagreements wait. A spec with one is not ready.

## Approval

Show Zak the spec. When Zak approves, set `Status: approved (date)`, update the board, and commit both to
`dev` as `docs(specs): approve NNN slug`. Only then spawn a lane.

In autonomous mode (see `specs/README.md`) you may set `provisional` yourself. Provisional work reaches `dev`
only during a run Zak has authorised, and never reaches `main` without him.

## When a lane says the spec is wrong

Decide which it is. A change in what the game does goes to Zak. A clarification that any reasonable reader
would agree with is yours: commit it to the spec on `dev`, tell the lane to rebase, and note it in the pull
request so the reviewer reads the same spec the lane built.

- **A spec that adds a key** must list `game/ui/key_book.gd` (its `ROWS` table; a bar window's key is in
  `game/ui/windows/window_book.gd`) and `tests/acceptance/test_030_help_and_hints.gd` (the key's case in
  `_check_entry`) in Paths: the help panel lists every key the game handles and that test fails for one
  that is missing. Lane 033 stopped on this.
