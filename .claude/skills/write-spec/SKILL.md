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
- **Paths** is the lane's fence. Check it against every spec currently `approved` or `in-progress`: no overlap.
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
