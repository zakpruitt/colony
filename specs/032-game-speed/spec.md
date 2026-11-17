# 032 — Game speed: watch the loop faster

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M5
- **Depends on:** 001, 008, 010, 011, 021
- **Pull request:** [#33](https://github.com/zakpruitt/colony/pull/33)

## Intent

The loop takes ten minutes to make a depth stable and an hour to show its shape, which is right for an idle
game left running but slow for a player who is watching, tuning a party or trying an upgrade. This spec adds
a speed control: 1x, 2x and 4x. It is a way of watching, not a rule: the simulation plays out exactly as it
would have, only sooner.

## Requirements

- **R1. Three speeds.** The game runs at 1x, 2x or 4x. At 2x the simulation advances twice as many ticks
  per second of real time as at 1x, and at 4x four times (within 5% over 10 seconds). A new session always
  starts at 1x; the speed is not saved.
- **R2. A button and a key.** A small button in the top band shows the speed (`1x`, `2x`, `4x`) and cycles
  it when clicked; the `F` key does the same. At 2x and 4x the button is lit so a faster game is never a
  surprise. It never overlaps the top band's other panels, with the boss bar showing or not.
- **R3. Same game, sooner.** A simulation run for N ticks at 4x has the same state hash and the same events
  as one run for N ticks at 1x.
- **R4. It still looks and sounds right.** At 4x, characters still move smoothly between ticks (no
  teleporting beyond what 1x shows), effects for events still appear and stay within the effects layer's
  caps, the sound player's limits still hold, and no event is treated as old merely because several ticks
  ran in one frame. Animations and effects may play at their normal real-time speed.
- **R5. It keeps up or says so.** If a frame cannot afford the ticks the speed asks for, the game runs as
  many as fit in its time budget and carries on, without freezing or building a backlog that later bursts.
- **R6. Time away is unaffected.** Catching up after time away, saving, and ticking while the window is
  minimised behave as they do at 1x; time away is always counted at 1x.
- **R7. Keys still work.** `F` works with the shop, hero sheet or journal open, and no existing key changes.

## Interfaces

```gdscript
# game/main.gd gains
const SPEEDS: Array[int] = [1, 2, 4]
var speed: int = 1                 # read-only outside the class
func set_speed(value: int) -> void # ignores a value not in SPEEDS
func cycle_speed() -> void
signal speed_changed(value: int)

# game/hud/hud.gd gains
var speed_button: HudButton
```

How the driver is told to run faster is the lane's choice (`SimDriver` is where real time becomes ticks).
The HUD must not reach up into `Main`: give it the speed through a signal or a callable when `Main` builds
it.

## Acceptance

In `tests/acceptance/test_032_game_speed.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_three_speeds` | Ticks per second of driven time at each speed; a new `Main` at 1x; no speed in the save |
| R2 | `test_r2_button_and_key` | The label and lit state at each speed, the click and `F` cycling, the button's rectangle against its neighbours with and without the boss bar |
| R3 | `test_r3_same_game_sooner` | Hash and events equal between a 1x and a 4x run of the same ticks |
| R4 | `test_r4_looks_and_sounds_right` | At 4x over a fight: sprite movement per frame bounded, effects started and under their caps, the sound limits, no recent event dropped as old |
| R5 | `test_r5_keeps_up` | With a tiny time budget, ticks per frame are bounded and no backlog bursts afterwards |
| R6 | `test_r6_time_away_unaffected` | A replay's length and result are the same whatever the speed was |
| R7 | `test_r7_keys` | `F` with each panel open; the other keys unchanged |

**To look at, and for Zak:** shots of the top band at each speed, and a short sequence of a fight at 4x
(`--count`). Crop and enlarge. Does 4x look like the same game played faster, not a broken one? Describe.

## Out of scope

- Pausing, slower-than-1x, or speeds above 4x.
- Saving the speed, or a settings screen.
- Any change under `sim/`.

## Paths

- `game/main.gd`, `game/sim_driver.gd` (or wherever `SimDriver` lives), `game/hud/hud.gd`
- `game/world/world.gd`, `game/effects/`, `game/audio/sound_player.gd` only where R4 needs it
- `tests/acceptance/test_032_game_speed.gd`, `tests/unit/test_sim_driver*.gd`
- Existing tests only where they count HUD children or top-band controls (say which)
- `docs/wiki/index.html`

## Open questions

None.
