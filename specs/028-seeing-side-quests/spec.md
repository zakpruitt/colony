# 028 — Seeing side quests and microskills

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M4
- **Depends on:** 008, 010, 011, 021, 025, 026, 027
- **Pull request:** [#31](https://github.com/zakpruitt/colony/pull/31)

## Intent

Spec 025 put side quests and microskills in the simulation, but on screen a side quest is an empty chamber
where the party stands still, and nothing says a hero has learned anything. This spec shows it all: the
quest waits in its chamber, the hero with the microskill steps forward and works, a quest the party cannot
do says what it needs, and the hero sheet and journal list microskills. The player should come away knowing
what happened and what a different party could have done. Art is placeholder by decision
(`docs/design/world.md`): five small props and nothing else new.

## Requirements

Everything follows `docs/style-bible.md`.

- **R1. A side quest can be seen waiting.** A chamber holding a side quest shows its prop on the floor near
  the middle of the chamber, from as far away as monsters are shown: a chest, a door, a small figure sitting
  down, a standing stone, a wire between two pegs. Five plain props (16x16 or 24x24), baked and lint clean;
  no other new sprites. A cleared quest's prop is gone until the chamber refills.
- **R2. The worker steps forward and works.** While the party works a quest, the worker stands at the prop,
  apart from the others, and plays their attack animation on a slow repeat; the rest idle. A small progress
  bar above the prop fills with `work_progress()`, and the microskill's name shows above the worker
  (`Lockpicker`).
- **R3. Done looks like a win.** When a quest is done the prop bursts into a few particles in its own
  colours and a floating label says what happened in the reward's colour (`Chest opened`, `Door forced`,
  `Wanderer mended`, `Runes read`, `Trap disarmed`); the usual coin and XP effects follow from the usual
  events.
- **R4. A miss says what was needed.** When the party passes a quest it cannot do, a small label rises from
  the prop: `Needs Lockpicker` (the microskill's name), in a muted colour, once per visit. A sprung tripwire
  instead shows `Sprung!` in red, shakes the camera and flashes the heroes as a hit does.
- **R5. Learning a microskill is marked.** The hero gets a floating label (`Learned Lockpicker`), the
  `level_up` sound plays, and the journal gains a line (`Rogue learned Lockpicker`).
- **R6. The journal and status line know about quests.** The journal gains lines for a quest done (with
  its reward) and for a miss (with what was needed); the status line reads `Working: <quest name>` while
  the party works.
- **R7. The hero sheet lists microskills.** A `Microskills` section shows each microskill the hero's class
  can learn: the ones they have in white with the one-line description, the ones to come in grey with the
  level (`Trapspotter, level 6`). The sheet still fits (spec 026's R7) for all four heroes.
- **R8. One word for one thing.** The depth panel's older `Stable N` label (the depth the party falls back
  to) now reads `Safe N`, so it is not confused with spec 027's `Stable in m:ss`.
- **R9. Sounds reuse what exists.** A soft repeating `ui_click` while working (within the sound player's
  limits), `hero_hurt` on a sprung tripwire. No new sounds.
- **R10. Old events show nothing.** Quest events that are not recent start no labels, particles, shakes or
  sounds (they still reach the journal), and props match what the simulation holds now.
- **R11. The showcase includes it.** `game/dev/showcase.tscn` gains labelled moments for a quest done, a
  miss, a sprung tripwire and a microskill learned.

## Interfaces

No new public classes are required. `World` draws props from `Expedition.side_quest_in`; the effects, HUD,
journal and sound player follow `SIDE_QUEST_STARTED`, `SIDE_QUEST_DONE`, `SIDE_QUEST_MISSED` and
`MICROSKILL_LEARNED` through `World.sim_event`. `HeroSheet.line` gains `&"microskills"` (the section's text,
one microskill per line).

## Acceptance

In `tests/acceptance/test_028_seeing_side_quests.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_props_wait_in_chambers` | Each quest's prop on the floor line of its chamber; none where there is no quest; gone once cleared |
| R2 | `test_r2_worker_steps_forward` | The worker at the prop and animating, the others idle, the bar following progress, the microskill's name |
| R3 | `test_r3_done_looks_like_a_win` | The label text and colour for each quest, particles in the prop's colours |
| R4 | `test_r4_a_miss_says_what_was_needed` | The label for a miss, once per visit; the red label, shake and flash for a sprung tripwire |
| R5 | `test_r5_learning_is_marked` | The label, the sound and the journal line |
| R6 | `test_r6_journal_and_status` | The journal lines and the status line |
| R7 | `test_r7_sheet_lists_microskills` | Learned and upcoming for each class, before and after the level; the sheet's rectangle |
| R8 | `test_r8_safe_depth` | The label's text |
| R9 | `test_r9_sounds` | The sounds started for working and a sprung tripwire |
| R10 | `test_r10_old_events_show_nothing` | Nothing started for old events; the journal still has them; props match the simulation |
| R11 | `test_r11_showcase` | The four moments are in the showcase's list and run without errors |

**To look at, and for Zak:** run the showcase and take shots of each quest waiting, the worker at work, a
quest done, a miss, a sprung tripwire, and the hero sheet's microskills for the rogue. Crop and enlarge. Can
you tell at a glance what the party is doing, how it went, and what it could not do? Describe the shots.

## Out of scope

- The simulation (spec 025): no rule or data change.
- New character art, new animations, new sounds, or more than the five props.
- The away report mentioning side quests.

## Paths

- `assets/sprites/props/` (five new props)
- `game/world/`, `game/effects/`, `game/hud/`, `game/audio/sound_player.gd`, `game/dev/showcase.gd`
- `tests/acceptance/test_028_seeing_side_quests.gd`, `tests/unit/test_world*.gd`, `tests/unit/test_hud*.gd`
- Existing world, effects, HUD, journal, sheet or showcase tests only where they count children, moments,
  sprites or lines, or assert the `Stable N` label (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
