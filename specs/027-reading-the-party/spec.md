# 027 — Reading the party: what they are doing, and why

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 008, 010, 011, 020
- **Pull request:** —

## Intent

Zak's first playtest note: it must be easy to understand what the characters are doing. Today the HUD says
one word (`Travelling`, `Fighting`) and the rest is inferred from watching. This spec makes the party's
intent readable at a glance: a status line that says what and why, a visible countdown to the next stable
depth, a short journal of what has happened, and hero frames that show who is down. Everything is drawn in
code or with existing sprites. It changes no rules.

## Requirements

Everything follows `docs/style-bible.md`.

- **R1. The status line says what and why.** In place of the single word, the depth panel shows a short
  sentence chosen from the simulation's state:

  | Situation | Line |
  |---|---|
  | Travelling toward a deeper target | `Heading down to depth N` |
  | Travelling toward a shallower target | `Heading up to depth N` |
  | Travelling at the target depth | `Hunting on depth N` |
  | Fighting ordinary monsters | `Fighting N monsters` (`Fighting 1 monster`) |
  | Fighting a guardian | `Fighting the <guardian's name>` |
  | Resting | `Resting` and the party's health as a percentage |
  | Climbing | `Climbing down` or `Climbing up` |
  | Wiped, reviving | `Chased home! Regrouping` |

  It never overflows its panel; the panel may grow wider but must stay clear of the boss bar and the shop
  button.
- **R2. The road to stable is visible.** While the party is at a depth that is not yet stable, a thin bar
  with the words `Stable in m:ss` shows how long the party must still hold this depth; at a depth already
  stable it reads `Stable` with no bar. With auto-push on, it also shows what happens next (`then depth
  N+1`).
- **R3. A journal.** The game keeps the last 50 notable happenings as plain sentences with the game time
  they happened: reaching a new deepest depth, a depth becoming stable, a hero's level up, a wipe and where
  the party fell back to, a guardian slain, an upgrade bought (and whether auto-buy bought it, if that can
  be known from the events; otherwise just that it was bought). The newest line shows for 4 seconds in a
  one-line ticker just above the party frames, then fades. `J` opens and closes a journal panel listing the
  last 12 lines, newest at the top. Events that are not recent (`World.is_recent`) are written to the
  journal but do not show in the ticker.
- **R4. Frames show who is down.** A dead hero's frame is dimmed and reads `Down` where the level was;
  during a revival all four read `Recovering`.
- **R5. A marker shows where the party is going.** When the party's target is a deeper or shallower depth,
  a small arrow (drawn in code) bobs above the party pointing down or up. It hides during fights and when
  the party is at its target depth.
- **R6. It fits and stays out of the way.** The ticker, the stable bar and the journal never cover the
  party frames, the top band's other panels, the shop or the boss bar, and the journal closes when the shop
  opens. The game does not pause while the journal is open.
- **R7. Keys still work.** With the journal open, `-`, `=`, `A`, `Z`, `M` and `U` do what they do without
  it; `Esc` closes it.

## Interfaces

```gdscript
# sim/expedition/expedition.gd gains (read-only; reading must not change the state hash)
## Seconds the party must still hold this depth before it becomes stable; 0.0 when it already is.
func seconds_to_stable() -> float

# game/hud/journal.gd
class_name Journal
extends Control
func setup(simulation: Simulation, world: World) -> void
func advance(delta: float) -> void
func lines() -> Array[String]        # newest first, at most 50
func ticker_text() -> String         # "" when nothing is showing
func is_open() -> bool
func open() -> void
func close() -> void

# game/hud/hud.gd gains
var journal: Journal
func status_text() -> String
func stable_text() -> String
```

## Acceptance

In `tests/acceptance/test_027_reading_the_party.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_status_line` | Each row of the table from a simulation put in that situation; the panel's rectangle clear of its neighbours with the longest line |
| R2 | `test_r2_road_to_stable` | `seconds_to_stable` against the simulation's own timing; the text counting down; `Stable` at a stable depth; the auto-push addition; reading it leaves the state hash unchanged |
| R3 | `test_r3_journal` | A line for each listed happening with its numbers and names; the cap of 50; the ticker's 4 seconds; `J`; old events in the journal but not the ticker |
| R4 | `test_r4_frames_show_who_is_down` | `Down` and the dimming for a dead hero; `Recovering` during a revival; back to the level afterwards |
| R5 | `test_r5_marker` | The arrow's direction for a deeper and a shallower target; hidden in a fight and at the target depth |
| R6 | `test_r6_it_fits` | Rectangles of the ticker, bar and journal against the frames, top band, shop and boss bar; the journal closing when the shop opens; the tick advancing |
| R7 | `test_r7_keys` | Each key with the journal open |

**To look at, and for Zak:** take shots of the main scene travelling, fighting, resting and just after a
wipe, and one with the journal open after a few minutes of play (a throwaway scene may speed things up; do
not commit it). Crop and enlarge. Could someone who has never seen the game say what the party is doing and
what happens next? Describe the shots.

## Out of scope

- Any rule change; the only `sim/` change is the one read-only accessor.
- Speech bubbles, per-hero activity text (spec 026's sheet has it), tutorials.
- New sprites or sounds.

## Paths

- `sim/expedition/expedition.gd` (`seconds_to_stable` only)
- `game/hud/journal.gd`, `game/hud/hud.gd`, `game/hud/hero_frame.gd` (the `Down` and `Recovering` text only)
- `game/effects/` or `game/world/` (the arrow marker only)
- `tests/acceptance/test_027_reading_the_party.gd`, `tests/unit/test_hud*.gd`
- Existing HUD tests only where they assert the one-word status or count HUD children (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
