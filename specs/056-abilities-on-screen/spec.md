# 056 — Abilities on screen

- **Status:** landed (provisional: not yet reviewed by Zak) (direction agreed with Zak 2026-11-17; text not yet read by him)
- **Milestone:** M6
- **Depends on:** 010, 027, 045, 050, 051
- **Pull request:** [#57](https://github.com/zakpruitt/colony/pull/57)

## Intent

Heroes now use abilities, but a fight looks as it did: the knight's Shield Bash is drawn as an ordinary
swing and a stunned monster just stands there. Zak asked that every skill "add an effect or action the
character can do", and an action nobody can see is not one. This spec makes each ability and status
readable in a fight, with the plainest means.

## Requirements

- **R1. An ability is announced.** When a fighter uses an action or a passive fires, the ability's name
  rises over the fighter in the hero's or monster's colour, briefly, and never more than two names stack
  over one fighter.
- **R2. An action looks different from a strike.** The fighter's wind-up for an action is marked (a
  bright outline or flash for its length), and when it lands each kind of effect has its own plain look:
  heavy damage a larger hit spark; damage to many a ring from the target or the fighter; a heal the
  existing heal effect on everyone healed; a push a visible slide; a revive the fallen hero standing up.
- **R3. Statuses can be seen** on whoever has one, for as long as it lasts, and are gone the frame it
  ends: stunned (stars circling the head, the sprite still); taunting (a mark over it); shielded (an
  outline that fades as the shield is used); burning, bleeding and chilled (a tint and small motes,
  orange, red and pale blue, and their damage numbers in that colour); mending (green motes rising);
  hasted and slowed (small arrows up and down); mighty and weakened (a small sword, bright or broken);
  marked (a target mark); nimble and untouchable (the sprite half faded).
- **R4. Misses and blocks are told.** A strike that misses shows `Miss`; damage a shield absorbs shows
  `Blocked` and no damage number.
- **R5. The frames show it.** A hero's frame shows up to three small status icons, and its tooltip names
  each status with the seconds left.
- **R6. The tally knows abilities.** The tally's line for a hero can be opened to show damage and healing
  by ability (`Whirlwind 412`, `Strikes 950`, `Bleeding 88`), from the same events it already counts.
- **R7. True in a crowded frame.** Statuses follow events in order: a frame holding a status's start and
  end shows nothing left over; a fight that ends takes every status mark with it; nothing is drawn on a
  monster sprite that has gone.
- **R8. Still readable.** In a fight with four heroes with full trees and five monsters, no name or
  number covers a health bar for more than a moment, and at 4x the names still show.
- **R9. In the showcase.** One moment per class shows a hero using its actions against monsters, and one
  shows every status on a row of fighters, labelled.

## Interfaces

None in `sim/`. `game/effects/combat_effects.gd` (947 lines) is near gdlint's 1000: the new work goes in
new files (`game/effects/ability_effects.gd`, `game/effects/status_marks.gd`). New pictures are small
and plain (stars, arrows, marks: 8x8 or less), from the master palette.

## Acceptance

In `tests/acceptance/test_056_abilities_on_screen.gd`, one test per requirement named `test_rN_…`. R3
checks every status, begun and ended by real battle events. R7 delivers a whole fight's events in one
frame. R8 measures rectangles in the busy fight frame by frame.

**To look at, and for Zak:** a sequence (`--count`) of each class's moment and the row of statuses,
cropped and enlarged 3x. Can you tell what each hero just did, and which monster is stunned, burning or
marked, without reading the journal? Describe every shot. Say which looks are weakest.

## Out of scope

- New sounds (existing ones may be reused). New sprites beyond the small marks. Any rule under `sim/`.
- The tree on the sheet (spec 055).

## Paths

- `game/effects/`, `game/world/`, `game/entities/`, `game/dev/showcase.gd`
- `game/hud/hero_frame.gd`, `game/hud/tally.gd`, `game/hud/tally_panel.gd` and new files beside them
- `assets/`
- `tests/acceptance/test_056_abilities_on_screen.gd`, `tests/unit/`
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
