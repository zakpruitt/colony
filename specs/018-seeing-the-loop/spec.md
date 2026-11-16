# 018 — Seeing the loop: zoom, a showcase, and fixing what it shows

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 008, 010, 011, 012, 015
- **Pull request:** —

## Intent

The whole loop is on screen now, but some of its best moments have never been looked at by anyone: a climb
down the ladder, a level up, a wipe and revival, a depth becoming stable, the party resting. They are rare in
the first minutes of play, so no screenshot has caught them. This spec builds a showcase that plays each
moment on demand, uses it to look at every one, and fixes what looks wrong. It also adds the one view control
the game is missing: a closer zoom, because at the normal view heroes are 16 pixels tall.

## Requirements

- **R1. Zoom.** The `Z` key switches the world between the normal view and a 2x view centred on the party.
  The change eases over about 0.25 seconds and ends on an exact whole zoom. The HUD does not zoom. In the 2x
  view the camera follows the party as before and everything stays on whole pixels. Effects that fly to the
  HUD (coins) still land on the coin icon at either zoom.
- **R2. A showcase plays the moments.** `game/dev/showcase.tscn` runs a real simulation and a real `Main`,
  and steers it (by setting state through the simulation's own classes, not by faking pictures) through, in
  order and each labelled on screen: travelling in a tunnel, a fight with a crit, a monster's death with
  coins and XP, a heal, a level up, resting, a climb down, a climb up, a wipe, the revival, a depth becoming
  stable, and one fight in each deeper band (clay, stone, deep). A full pass takes under 90 seconds.
- **R3. Every moment has been looked at and reads.** For each moment in R2, a stranger shown one screenshot
  can tell what is happening. Fix what fails that test, within the Paths. The known weak points to check:
  - damage numbers stacking into an unreadable pile when several monsters hit one hero;
  - numbers rising far above the fight and trailing off screen;
  - the party on the ladder (it should be centred on it, not in the wall);
  - `LEVEL UP`, `WIPED` and `DEPTH n STABLE` text: size, placement, readable over light and dark;
  - the revival light and the resting `z`s: visible at all at 640x360?;
  - fights in the stone and deep bands: can you see the monsters against the dark?
- **R4. Nothing is left running.** The showcase is a development scene: the game's main scene does not load
  it, and it never touches the real save.
- **R5. Numbers stay readable under pressure.** With five monsters hitting one hero for ten seconds, at every
  moment no two damage numbers overlap by more than a third of their area, and no number is drawn outside
  the screen.

## Interfaces

```gdscript
# game/world/world_camera.gd gains
func set_zoom_level(level: int) -> void     # 1 or 2; eases to it
func zoom_level() -> int
```

The showcase's own classes are the lane's choice, under `game/dev/`.

## Acceptance

In `tests/acceptance/test_018_seeing_the_loop.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_zoom` | `Z` toggles; after 0.3 s zoom is exactly 2 then exactly 1; the HUD layer's transform is unchanged; a coin's target in world space still maps to the HUD coin icon at 2x |
| R2 | `test_r2_showcase_plays_every_moment` | Driven by `advance`, the showcase reports each named moment in order and finishes; during each, the matching state or event is really present in its simulation (for example state CLIMBING during the climb, a LEVEL_UP event during the level up) |
| R4 | `test_r4_showcase_is_separate` | The main scene has no showcase node; the showcase's `Main` has no save store |
| R5 | `test_r5_numbers_stay_readable` | The overlap and on-screen statements over a scripted ten seconds |

R3 is judged by eye. Take `python tools/dev.py shot --scene=res://game/dev/showcase.tscn --name=show
--seconds=1 --count=90` (adjust to cover the pass), look at every moment, cropping and enlarging, and in your
report give one line per moment: what you saw, what you changed, what still looks weak.

## Out of scope

- The simulation: no rule, data or position changes. If a moment looks wrong because of where the simulation
  puts something, report it.
- The HUD's layout and the shop.
- New effects that no requirement of spec 010 asked for. Retiming, resizing, recolouring and repositioning
  existing ones is the job.

## Paths

- `game/dev/`
- `game/world/world_camera.gd`, `game/world/world.gd` (zoom and input only)
- `game/effects/`
- `game/ambience/` (brightness and tint numbers only, if R3's dark-band check needs it)
- `tests/acceptance/test_018_seeing_the_loop.gd`, `tests/unit/test_effects*.gd`
- An existing effects or ambience test only where it asserts a number this spec retunes (say which)
- `CLAUDE.md` (the showcase command in "Commands"), `docs/wiki/index.html`

## Open questions

None.
