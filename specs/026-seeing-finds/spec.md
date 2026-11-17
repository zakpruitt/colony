# 026 — Seeing finds: the party at work

- **Status:** draft
- **Milestone:** M4
- **Depends on:** 008, 010, 011, 021, 025
- **Pull request:** —

## Intent

Spec 025 lets the party work on finds, but on screen a find is an empty chamber where the party stands still
for a few seconds. This spec shows it: the find is there to be seen before the party arrives, one hero steps
forward and visibly works, and success, failure and a trade level-up each have their moment. Art is
placeholder by decision (`docs/design/world.md`): four small props and nothing else new.

## Requirements

Everything follows `docs/style-bible.md`.

- **R1. A find can be seen waiting.** A chamber holding a find shows its prop on the floor near the middle
  of the chamber, from as far away as monsters are shown: a chest for the trapped cache, a glinting rock for
  the ore vein, a standing stone for the rune stone, a plant for the herb patch. Four 16x16 or 24x24 props,
  baked and lint clean; no other new sprites.
- **R2. The worker steps forward and works.** While the party works a find, the worker stands at the prop,
  apart from the others, and plays their attack animation on a slow repeat; the rest idle. A small progress
  bar above the prop fills with `work_progress()`.
- **R3. Success and failure look different.** On success the prop bursts into a few particles in its own
  colours, and a floating label names the result in the reward's colour (`DISARMED`, `MINED`, `READ`,
  `GATHERED`); the usual coins, XP and heal effects follow from the usual events. On failure the label is
  red (`SPRUNG!` for the trap, `FUMBLED` otherwise); a sprung trap also shakes the camera and flashes the
  heroes as a hit does. Either way the prop is gone afterwards and stays gone until the chamber refills.
- **R4. A trade level-up is marked.** The hero gets a floating label with the trade and new level
  (`TRAPWORK 3`) and the `level_up` sound plays.
- **R5. The HUD says what is happening.** The status line reads `Working` with the find's name while the
  party works. Each hero frame shows that hero's trade and its level, legibly, without growing the frame.
- **R6. Sounds reuse what exists.** A soft repeating `ui_click` while working (within the sound player's
  limits), `coin` and `heal` from their usual events, `hero_hurt` on a sprung trap. No new sounds.
- **R7. Old events show nothing.** After a stall or time away, find events that are not recent start no
  labels, particles, shakes or sounds, and props match what the simulation holds now.
- **R8. The showcase includes it.** `game/dev/showcase.tscn` gains labelled moments for a success, a sprung
  trap and a trade level-up.

## Interfaces

No new public classes are required. `World` draws props from `Expedition.find_in`, and the effects, HUD and
sound player follow `FIND_STARTED`, `FIND_ENDED` and `TRADE_LEVEL_UP` through `World.sim_event`.

## Acceptance

In `tests/acceptance/test_026_seeing_finds.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_props_wait_in_chambers` | Each find's prop on the floor line of its chamber; none where there is no find |
| R2 | `test_r2_worker_steps_forward` | The worker at the prop and animating, the others idle, the bar following progress |
| R3 | `test_r3_success_and_failure` | The label text and colour for each find and outcome, particles on success, shake and flash on a sprung trap, the prop gone |
| R4 | `test_r4_trade_level_up` | The label and the sound |
| R5 | `test_r5_hud` | The status line; each frame's trade and level, inside the frame's rectangle |
| R6 | `test_r6_sounds` | The sounds started for working, success and a sprung trap |
| R7 | `test_r7_old_events_show_nothing` | Nothing started for old events; props match the simulation |
| R8 | `test_r8_showcase` | The three moments are in the showcase's list and run without errors |

**To look at, and for Zak:** run the showcase and take shots of each find waiting, the worker at work, a
success, a sprung trap and a trade level-up. Crop and enlarge. Can you tell at a glance what the party is
doing and how it went? Describe the shots in your report.

## Out of scope

- The simulation (spec 025).
- New character art, new animations, new sounds, or more than the four props.
- The away report mentioning finds.

## Paths

- `assets/sprites/props/` (four new props)
- `game/world/`, `game/effects/`, `game/hud/`, `game/audio/sound_player.gd`, `game/dev/showcase.gd`
- `tests/acceptance/test_026_seeing_finds.gd`, `tests/unit/test_world*.gd`, `tests/unit/test_hud*.gd`
- Existing world, effects, HUD or showcase tests only where they count children, moments or sprites (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None beyond spec 025's.
