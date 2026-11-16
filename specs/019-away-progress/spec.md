# 019 — Progress while you were away

- **Status:** provisional
- **Milestone:** M3
- **Depends on:** 014
- **Pull request:** —

## Intent

Colony is an idle game: the party should keep working when the game is closed. This spec makes it so. When
the game starts with a save, it works out how long it was closed, plays that time through the real
simulation as fast as it can, and then tells the player what the party did: gold, levels, depth, kills. It is
the same simulation and the same rules as watching, just not drawn.

## Requirements

- **R1. The save knows when it was written.** The main scene stamps each save with the real time it was
  written. The simulation ignores the stamp; a save without one loads as before with no time away.
- **R2. Time away is replayed.** On starting with a save, time away is the real time since the stamp, never
  negative, and at most `MAX_AWAY_SECONDS` (8 hours). If it is at least `MIN_AWAY_SECONDS` (60), the
  simulation is stepped for that much game time before normal play begins. A clock that went backwards
  counts as no time away.
- **R3. It does not freeze the window.** The replay runs in slices of at most 10 milliseconds of work per
  frame, with the world not yet drawn, and shows `Catching up...` with a bar that fills. Eight hours of time
  away finishes in under 60 seconds on this machine; say in your report how long it took.
- **R4. It is the real simulation.** A save replayed for N seconds ends in exactly the state (same state
  hash) as the same save loaded and stepped normally for N seconds.
- **R5. The player is told what happened.** After a replay, a panel in the middle of the screen says how
  long the party was away and what changed: gold gained, levels gained per hero, depth before and after,
  monsters slain, and wipes. It closes on a click or any key, or by itself after 12 seconds. The game is
  already running behind it.
- **R6. Nothing odd afterwards.** After a replay the world, HUD and effects start cleanly: no burst of old
  effects, no coins flying for gold earned while away, the HUD's gold correct at once, and the save timer
  starts fresh.
- **R7. Tests and tools are untouched.** A run with no save store (tests, screenshots, headless) never
  replays anything. The amount of time away can be given to the main scene directly, so tests do not depend
  on the real clock.

## Interfaces

```gdscript
# game/main.gd gains
const MAX_AWAY_SECONDS: float = 8.0 * 3600.0
const MIN_AWAY_SECONDS: float = 60.0
## If set to 0 or more before the scene enters the tree, used as the time away instead of the real clock.
var away_seconds_override: float = -1.0
## True while the replay is running.
func is_catching_up() -> bool

# game/save/away_report.gd
class_name AwayReport
extends RefCounted
var seconds: float
var gold_gained: int
var levels_gained: Dictionary[int, int]   # hero id to levels
var depth_before: int
var depth_after: int
var kills: int
var wipes: int
```

How an `AwayReport` is filled in is the lane's choice. The stamp is a key `saved_at` (seconds since 1970)
that `Main` adds to the dictionary from `Simulation.to_save()` before handing it to the `SaveStore`. `Main`
today creates the driver, world, effects and HUD in `_ready`; with a replay it creates them when the replay
ends. The panel's class and the progress bar are the lane's choice, under `game/hud/`, in the HUD's panel
style (`game/hud/hud_panel.gd`).

## Acceptance

In `tests/acceptance/test_019_away_progress.gd`. Tests give `Main` a `SaveStore` on a per-process path and
set `away_seconds_override`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_saves_are_stamped` | A written save has `saved_at` near now; a save without it loads with no replay |
| R2 | `test_r2_time_away_is_bounded` | 30 s: no replay. 600 s: 6,000 ticks replayed. 100 hours: capped at 8. A stamp in the future: no replay |
| R3 | `test_r3_replay_is_sliced` | During a replay `is_catching_up()` is true over several frames, the world does not exist yet, and the bar's value rises |
| R4 | `test_r4_same_as_playing` | Hash equality with a simulation loaded from the same save and stepped the same ticks |
| R5 | `test_r5_report` | The panel shows after a replay with the right gold, levels, depths, kills and wipes (checked against the simulations); closes on a key and after 12 s; no panel without a replay |
| R6 | `test_r6_clean_start` | After a replay: no live effects, shown gold equals real gold on the first frame, no events pending |
| R7 | `test_r7_no_store_no_replay` | The main scene with no store and with an override still does not replay |

**To look at, and for Zak:** in a throwaway scene you do not commit, show the catching-up bar and the report
panel over the game and take shots. Both must read at 640x360 and look like part of the HUD.

## Out of scope

- Changing the simulation or the save format's version. `saved_at` rides beside the simulation's fields.
- Notifications, a tray icon, or anything while the game is closed.
- Offline rules that differ from online ones (reduced rates, caps other than the 8 hours).
- A setting to turn it off.

## Paths

- `game/main.gd`, `game/main.tscn`
- `game/save/`, `game/hud/` (new files for the bar and the panel only; `hud.gd` only to make the gold correct at once)
- `tests/acceptance/test_019_away_progress.gd`, `tests/unit/test_away*.gd`, `tests/unit/test_main_save.gd`
- `docs/architecture.md` (the "Saving" section), `docs/wiki/index.html`

## Open questions

None.
