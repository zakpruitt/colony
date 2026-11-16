# 001 — Simulation clock and background ticking

- **Status:** approved (2026-11-16)
- **Milestone:** M0
- **Depends on:** none
- **Pull request:** —

## Intent

Colony is played by leaving it running, so the simulation must keep exact time whether the window is focused,
hidden behind other windows or minimised. This spec adds the simulation object that every later system lives
in, and the driver that turns real elapsed time into simulation ticks. After it, Zak can start the game,
minimise it for a minute, and see that it kept counting.

## Requirements

- **R1. Fixed ticks.** The simulation advances only in whole ticks, ten per second of game time. One call to
  step it advances exactly one tick. It starts at tick 0.
- **R2. Real time in, ticks out.** Given an amount of elapsed real time, the driver steps the simulation once
  for every full tick's worth, and keeps the remainder for next time. 250 ms of elapsed time is two ticks with
  50 ms kept; a further 50 ms is one more tick.
- **R3. Frame timing does not matter.** The same total elapsed time gives the same tick count however it is
  split into frames: one 10-second frame, 600 even frames and 600 uneven frames all end on the same tick, with
  no drift.
- **R4. A stall is caught up, not lost, and does not freeze the game.** The driver steps at most 50 ticks in
  one frame. Time it could not step is kept as backlog and worked off over the following frames.
- **R5. Very long gaps are handed off, not simulated here.** Backlog is capped at 60 seconds. Time beyond the
  cap is not stepped; the driver reports how much was dropped, so the later offline catch-up spec can account
  for it.
- **R6. Background rendering is throttled; the simulation is not.** When the game window loses focus, rendering
  is limited to 10 frames per second. When it regains focus, the previous limit is restored. The tick rate is
  the same in both states.
- **R7. The clock is visible.** The main scene shows the current tick and the game time in seconds, updating
  as the simulation runs.

## Interfaces

Time is measured in whole microseconds (`int`) throughout, so no rounding error can build up.

```gdscript
# sim/simulation.gd
class_name Simulation
extends RefCounted

const TICKS_PER_SECOND: int = 10
const TICK_USEC: int = 1_000_000 / TICKS_PER_SECOND

## Ticks stepped since the simulation was created. Read-only outside this class.
var tick: int

func _init(seed_value: int) -> void
## Advances the simulation by exactly one tick.
func step() -> void
## Game time elapsed, in seconds.
func seconds() -> float
## A number that is equal for two simulations in the same state. Covers the seed and the tick for now;
## later specs add their state to it.
func state_hash() -> int
```

```gdscript
# game/sim_driver.gd
class_name SimDriver
extends Node

## Emitted after a frame in which at least one tick was stepped.
signal ticked(count: int)
## Emitted when backlog beyond MAX_BACKLOG_USEC was discarded.
signal time_dropped(usec: int)

const MAX_TICKS_PER_FRAME: int = 50
const MAX_BACKLOG_USEC: int = 60_000_000
const BACKGROUND_MAX_FPS: int = 10

## The simulation being driven. Set before the node enters the tree.
var simulation: Simulation

## Adds elapsed real time and steps the simulation for it. Returns the ticks stepped.
## Called once per frame with the measured time; tests call it directly.
func advance(elapsed_usec: int) -> int
## Real time received but not yet stepped.
func backlog_usec() -> int
```

- Each frame the driver measures elapsed time with the engine's monotonic clock (not the frame delta, which the
  engine may clamp) and passes it to `advance`.
- The background limit is applied through `Engine.max_fps`, in response to the window focus notifications.
- The main scene creates one `Simulation` with a fixed seed and one `SimDriver`. Choosing and saving the seed
  belongs to the save-system spec.

## Acceptance

In `tests/acceptance/test_001_sim_clock.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_step_advances_one_tick` | A new simulation is at tick 0; after three steps, tick 3 and 0.3 seconds |
| R2 | `test_r2_elapsed_time_becomes_ticks_with_remainder` | 250 ms gives 2 ticks and 50 ms of backlog; 50 ms more gives 1 tick and none |
| R3 | `test_r3_tick_count_ignores_frame_split` | 10 s as one call, as 600 even calls and as 600 seeded uneven calls each end on tick 100, with equal `state_hash()` |
| R4 | `test_r4_stall_is_capped_per_frame_and_caught_up` | A 20 s stall steps 50 ticks at once; repeated zero-time frames reach tick 200 |
| R5 | `test_r5_backlog_over_cap_is_dropped_and_reported` | A 5-minute gap leaves at most 60 s of backlog and emits `time_dropped` with the other 240 s |
| R6 | `test_r6_focus_loss_throttles_rendering_only` | Focus-out sets `Engine.max_fps` to 10; focus-in restores the earlier value; `advance` gives the same ticks in both |
| R7 | `test_r7_main_scene_shows_the_clock` | The main scene's clock label shows the tick and seconds after the simulation is advanced |

R3 with the call split into one 10 s frame must allow for R4: the test keeps calling with zero elapsed time
until the backlog is empty.

**For Zak's playtest:** run `godot --path .`, note the tick, minimise the window for 60 seconds by a stopwatch,
restore it. The tick should have risen by about 600.

## Out of scope

- Any game content in the simulation: heroes, monsters, the labyrinth, events, commands.
- Saving or loading, and choosing a seed.
- Offline catch-up (time the game was closed or the machine asleep). R5 only reports dropped time.
- Speed controls, pausing, a settings screen.
- Any styling of the clock label beyond being readable; it is a development readout.

## Paths

- `sim/simulation.gd`
- `game/sim_driver.gd`
- `game/main.gd`
- `game/main.tscn`
- `tests/acceptance/test_001_sim_clock.gd`
- `tests/unit/test_simulation.gd`, `tests/unit/test_sim_driver.gd` (optional)

## Open questions

None.
