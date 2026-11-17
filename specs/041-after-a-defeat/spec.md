# 041 — After a defeat: what went wrong and what to do

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M5
- **Depends on:** 020, 027, 029, 035, 037, 038, 039
- **Pull request:** [#42](https://github.com/zakpruitt/colony/pull/42)

## Intent

With the livelier start (spec 036) a new party meets the first guardian after about nine minutes and then
loses to it, again and again, for about twelve minutes unless the player buys upgrades, trains heroes or
sets the Hold order. The game says `WIPED` and nothing more. A wipe is the moment the player most wants to
know what went wrong and what they can do about it. This spec adds a short defeat note that says who beat
the party and offers the things that would help, each one click away. It changes no rule.

## Requirements

Everything follows `docs/style-bible.md`; drawn in code, no new sprites.

- **R1. A defeat note.** When the party is wiped, a small note appears in the upper middle of the screen
  and stays until 8 seconds after the heroes stand again (spec 038), then fades; it does not
  fade while the mouse is over it, and a new fight does not hide it. (Amended by the lead: the first
  wording hid it when the heroes stood, about five seconds, too short to read it and click.) Its first line says what beat the party
  and where: `Beaten by the Slime King on depth 5`, or for ordinary monsters `Beaten on depth 7 by 3
  ogres` (the monsters alive when the last hero fell, grouped by name).
- **R2. It says why, when it can.** A second line gives the plainest true reason, the first that applies:
  1. A guardian: `Heroes are level 6; it is balanced for about 9` (the lowest hero level, and the same
     rule the goals tracker uses), when the lowest level is below that.
  2. The party is deeper than its safe depth by 2 or more: `Depth 7 is 3 below the safe depth`.
  3. Otherwise no second line.
- **R3. It offers what would help.** Under it, up to three suggestions, each a button, the first three
  that apply in this order:
  1. `Train <hero>` when gold affords a training for any hero: opens that hero's sheet on the Training
     tab (the hero with the cheapest affordable training).
  2. `Buy an upgrade` when gold affords a camp upgrade: opens the shop.
  3. `Hold here` when the party was beaten by a guardian and the order is Challenge: sets the guardian
     order to Hold through the simulation's command, and the button then reads `Holding`.
  (Amended by the lead: a fourth suggestion, `Go up a depth`, is removed. A wipe already sends the party
  back to its safe depth, and the button sent it deeper than doing nothing.)
  With none applicable the note shows only its lines.
- **R4. Repeated defeats are counted.** From the second wipe in a row to the same guardian (no victory
  over it between), the first line ends with the count: `Beaten by the Slime King on depth 5 (3 times)`.
  The count is the view's own and starts again when the game is loaded.
- **R5. It explains itself and stays out of the way.** Each button has a tooltip (spec 030) of one
  sentence. The note never covers the depth panel, goals, top-right controls, ladder, party frames or the
  fallen heroes' chamber centre line (it sits above the `WIPED` text, not on it). It hides while the shop,
  a hero sheet, the journal, help, orders or the away report is open, and never appears for wipes that
  happened while the game was away.
- **R6. The journal keeps it.** The journal's line for a wipe carries the same first line as the note.
- **R7. Nothing else changes.** No change under `sim/`; the state hash of a run with no clicks is
  unchanged.

## Interfaces

```gdscript
# game/hud/defeat_note.gd
class_name DefeatNote
extends Control
func setup(simulation: Simulation, world: World, hud: Hud) -> void
func advance(delta: float) -> void
func is_shown() -> bool
func lines() -> Array[String]          # the first line, and the second when there is one
func suggestions() -> Array[String]    # the button texts showing, in order
func press(index: int) -> void         # what clicking that button does

# game/hud/hud.gd gains
var defeat_note: DefeatNote
```

The guardian's balanced level is the rule in `Goals` (guardian depth + 4): use that one definition, do not
copy the number.

## Acceptance

In `tests/acceptance/test_041_after_a_defeat.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_defeat_note` | The note and its first line for a guardian wipe and an ordinary one; shown until the heroes stand, then gone |
| R2 | `test_r2_says_why` | Each of the three cases |
| R3 | `test_r3_offers_help` | Each suggestion from a simulation put in that situation, what pressing it does, the order, at most three, none |
| R4 | `test_r4_repeats_are_counted` | The count on the second and third wipe; reset by a victory |
| R5 | `test_r5_out_of_the_way` | Tooltips; rectangles against the listed HUD parts; hidden with each panel open; nothing after time away |
| R6 | `test_r6_journal` | The journal's line |
| R7 | `test_r7_nothing_else_changes` | Hashes with and without the note watching, no clicks |

**To look at, and for Zak:** shots of a guardian wipe with gold to spend, a third wipe in a row, and an
ordinary wipe (a throwaway scene; do not commit it). Crop and enlarge. Does it tell a new player what to do
without nagging? Describe the shots.

## Out of scope

- Any rule change; automatic responses to a defeat; new sprites or sounds.
- Advice about pace or party make-up.

## Paths

- `game/hud/defeat_note.gd`, `game/hud/hud.gd`, `game/hud/hud_tooltip.gd`, `game/hud/journal.gd` (the wipe
  line only), `game/hud/goals.gd` (only to make the balanced-level rule public)
- `tests/acceptance/test_041_after_a_defeat.gd`, `tests/unit/test_hud*.gd`
- Existing HUD tests only where they count HUD children, walk every HUD child's rectangle, or assert the
  journal's wipe line (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
