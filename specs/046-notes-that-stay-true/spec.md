# 046 — Notes that stay true: fixes from the reviews of the defeat note and the tally

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 041, 045
- **Pull request:** —

## Intent

Reviewers read the defeat note (spec 041, pull request 42) and the party tally (spec 045, pull request 46)
against their specs after they had landed. Both panels can say something false: the defeat note when many
ticks arrive in one frame or the order changes under it, the tally when the game is opened in the middle
of a fight. This spec closes those, and the tests that could not fail. It adds no feature.

## Requirements

### The defeat note

- **R1. The note describes the fight that was lost, whenever it hears of it.** The depth, the safe depth
  and the monsters in the note and in the journal's wipe line are those of the lost fight even when the
  defeat, the wipe and the revival all arrive in one frame (a stall, or 4x speed): they come from the
  events and from state remembered as the events pass, never from the expedition's state after the
  revival. The count of defeats in a row (spec 041 R4) is right in that case too.
- **R2. `Holding` is true or it is not shown.** The Hold button reads `Holding` only while the
  simulation's guardian order is Hold. If the order goes back to Challenge while the note shows, the
  button reads `Hold here` again and works.
- **R3. A click does what was aimed at.** The suggestions do not change while the mouse is over the note,
  and a click acts on the suggestion the button showed when pressed, not on whatever now sits in that
  slot.
- **R4. A panel does not use up the note's time.** The 8 seconds do not run while a panel hides the note,
  so a player who clicks `Train` or `Buy an upgrade` finds the note still there on closing the panel.
- **R5. A defeat the note does not tell leaves the showing note alone.** A wipe too old to be told (after
  a stall) changes neither the lines nor the suggestions of a note already showing.
- **R6. The journal keeps what it said.** The journal's wipe line is the note's first line followed by
  where the party fell back to, as before spec 041: `Beaten by the Slime King on depth 5; falling back to
  depth 4`.

### The tally

- **R7. A fight already under way is a fight.** When the tally starts while the party is fighting (the
  game opened or returned to mid-fight), the panel shows that fight as the current one, never `No fight
  yet` over bars that are not zero, and the session's count of fights includes it.
- **R8. The measures say what they count.** Damage and damage taken count health actually lost, not
  overkill, as healing already counts health actually restored. If the events cannot tell (the amount is
  the whole blow), then the tooltips for `Damage` and `Taken` say that they include overkill; say which
  in your report. No change under `sim/` either way.
- **R9. The help panel's `Q E` row** says the keys change tabs on a hero sheet or the tally.

### Tests that can fail

- **R10.** The tests named in Acceptance exist and each was seen to fail with its behaviour broken.

## Interfaces

None change.

## Acceptance

In `tests/acceptance/test_046_notes_that_stay_true.gd`, plus the amended 041 and 045 tests.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_one_frame_defeat` | A guardian defeat, wipe and revival stepped in one frame: the journal's line, the note's remembered depth and the count on the next defeat |
| R2 | `test_r2_holding_is_true` | Hold pressed, then Challenge set through the orders: `Hold here` again, and it works; the `Holding` tooltip |
| R3 | `test_r3_click_does_what_was_aimed` | Gold spent under the mouse: the row unchanged while hovered; a press acting on the shown suggestion |
| R4 | `test_r4_panel_does_not_use_time` | The note still showing after a panel was open for longer than the linger |
| R5 | `test_r5_old_defeat_leaves_the_note` | A stalled second wipe while a note shows: lines and suggestions unchanged |
| R6 | `test_r6_journal_keeps_what_it_said` | The journal's line with the fall-back |
| R7 | `test_r7_started_mid_fight` | A HUD made while the party is fighting: the fight's line, the bars, the session's count |
| R8 | `test_r8_measures_say_what_they_count` | A killing blow larger than the health left, and a heal on a nearly full hero, against the tally's numbers or the tooltips |
| R9 | `test_r9_help_row` | The row's text |
| R10 | (amended `test_041`, `test_045`) | In 041: an ordinary wipe where some monsters died first names only the living; both reasons true at once gives the guardian's; no Hold when the order is already Hold; `Buy an upgrade` alone. In 045: Healing and Taken on the last-fight span; a wipe leaving the lost fight as the last fight |

## Out of scope

- Any change under `sim/`; new features on either panel.
- Whether an ordinary wipe between two guardian wipes resets the count (left as built).

## Paths

- `game/hud/defeat_note.gd`, `game/hud/tally.gd`, `game/hud/tally_panel.gd`, `game/hud/journal.gd` (the
  wipe line only), `game/hud/hud_tooltip.gd`, `game/hud/help_panel.gd` (the `Q E` row only),
  `game/hud/hud.gd` (only if the tally needs the state at setup)
- `tests/acceptance/test_046_notes_that_stay_true.gd`, `tests/acceptance/test_041_after_a_defeat.gd`,
  `tests/acceptance/test_045_the_party_tally.gd`, `tests/unit/test_hud*.gd`
- `tests/acceptance/test_027_reading_the_party.gd` and `test_030_help_and_hints.gd` only where they assert
  the journal's wipe line or the `Q E` row's text (say which)
- `docs/wiki/index.html` (it says the count shows from the third defeat; it is the second), `docs/style-bible.md`

## Open questions

None.
