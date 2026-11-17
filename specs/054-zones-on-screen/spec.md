# 054 — Zones on screen: walking on, not climbing down

- **Status:** provisional (direction agreed with Zak 2026-11-17; text not yet read by him)
- **Milestone:** M6
- **Depends on:** 006, 008, 012, 018, 048, 049
- **Pull request:** —

## Intent

Zak: "rather than going down the ladder, I'd almost prefer it were going into a new zone each time you go
from one depth to the other", so that it does not "feel like you just are ever-going down". Today the
party climbs down a shaft and the camera follows it into the rock below. After this spec the party walks
out through a doorway and arrives in the next zone, each area looks like its own place, and nothing on
screen says "down".

## Requirements

- **R1. Out through a doorway.** Where a stage had a shaft, it shows a doorway in the chamber's far wall.
  When the party moves to another stage it walks into the doorway and is gone; it does not move down or
  up, and the camera does not travel vertically.
- **R2. A short crossing.** While the party is between stages the screen dims to dark, a title names
  where it is arriving (`Mossy Hollow 4`), and the screen opens on the party stepping out of a doorway
  in the new zone. The crossing lasts as long as the simulation takes to change stage and no longer; at
  4x it is shorter but still shows the title.
- **R3. Going back is the same.** Returning to an earlier stage (a lower target, or after a wipe once
  the party has stood up) uses the doorway the party came in by, with the same crossing.
- **R4. A journey reads as a journey.** Travelling to another area dims the same way and holds a title
  with both names (`Leaving Mossy Hollow` then `The Claypits 1`) for the journey's ten seconds.
- **R5. Each area is its own place.** Each area has its own colouring of rock, floor and light, chosen
  from the master palette, different enough to tell the four apart in a shot at a glance. Within an
  area, later stages are the same place, a little darker or deeper in tone.
- **R6. Nothing says "down".** Text and help say stage, zone and area, further and back; no "deeper",
  "descend", "climb", "depth" or "shaft" is shown to the player. The ladder at the right is headed by
  the area's name and lists stages; its arrows and hints say further and back.
- **R7. True in a crowded frame.** A frame that steps many ticks (a whole crossing, or several) shows the
  zone the party is in at the end, with no crossing left half played and no sprite left from the zone
  before.
- **R8. The wipe still reads.** After a wipe the camera's travel to where the party stands up (spec 048)
  becomes a crossing when the party revives in another stage: hold on the fallen, dim, title, open on
  the heroes standing up.
- **R9. In the showcase.** The showcase's moments for changing stage show the crossing, and one new
  moment shows the four areas' looks in turn.

## Interfaces

None in `sim/` beyond reading what is there. If the view needs the simulation to say something it does
not (for example which doorway the party arrives by), add a read-only function and say so; rules and the
state hash must not change, and the recorded-hash tests pass unchanged.

## Acceptance

In `tests/acceptance/test_054_zones_on_screen.gd`, plus older view tests amended where they assert the
climb (say which).

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_out_through_a_doorway` | The doorway's place; through a change of stage, hero sprites' and the camera's vertical position never leave the zone's band |
| R2 | `test_r2_a_short_crossing` | The dimming, the title's text, its end with the simulation's, at 1x and 4x |
| R3 | `test_r3_going_back` | A lower target and a revival |
| R4 | `test_r4_a_journey` | The two titles over the ten seconds |
| R5 | `test_r5_its_own_place` | The four areas' colours all differ and are palette colours; stage 1 and stage 6 of one area are nearer each other than two areas are |
| R6 | `test_r6_nothing_says_down` | Every text the HUD, help, journal, goals and notes can show, searched for the listed words |
| R7 | `test_r7_true_in_a_crowded_frame` | 300 ticks across two changes of stage before one frame |
| R8 | `test_r8_the_wipe_still_reads` | The sequence's order and the camera at each step |
| R9 | (`test_showcase`) | The moments exist and run |

**To look at, and for Zak:** a sequence (`--count`) of a crossing at 1x; one still of each area, and the
four cropped side by side and enlarged; a wipe that revives a stage back. Does it read as going on into
a new place? Describe every shot.

## Out of scope

- New tiles, props or monsters: colour and light only, and the plainest doorway (art is placeholder).
- The map (spec 053); any rule under `sim/`.

## Paths

- `game/world/`, `game/ambience/`, `game/effects/`, `game/entities/`, `game/dev/showcase.gd`
- `game/hud/` (texts for R6, the title for R2 and R4; another lane is adding the map there, so keep
  changes to existing files small)
- `assets/` (a doorway sprite and palette use, following the style bible)
- `sim/` (read-only additions only)
- `tests/`
- `docs/architecture.md`, `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
