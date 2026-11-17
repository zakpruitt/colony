# 045 — The party tally: who is doing what

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M5
- **Depends on:** 006, 025, 026, 029, 030, 037
- **Pull request:** [#46](https://github.com/zakpruitt/colony/pull/46)

## Intent

The player trains heroes one at a time (spec 029) with no way to see what each one contributes. Is the
mage out-damaging the rogue? Is the knight taking the hits? Did Toughness on the cleric change anything?
This spec adds a small tally, in the manner of a damage meter: each hero's damage dealt, healing done and
damage taken, as bars side by side, for the last fight and for the whole session. It is what the player
optimises against. It reads the simulation's events and changes no rule.

## Requirements

Everything follows `docs/style-bible.md`; drawn in code, no new sprites.

- **R1. A tally panel.** The `T` key, or a small button beside the party frames, opens and closes a panel
  on the left (where the hero sheet and journal open; opening one closes the others, as they do today).
  `Esc` closes it. It lists the heroes in party order, each with their class colour or portrait as the
  frames show them.
- **R2. Three measures.** The panel shows one measure at a time, chosen by three tabs (and `Q`/`E`, as
  the hero sheet's tabs): `Damage` dealt to monsters, `Healing` done to heroes (not counting healing
  beyond full health, if the simulation's events allow telling; say which), and `Taken`, damage received.
  Each hero's row is a bar scaled to the largest row, the number, and the hero's share as a percentage.
- **R3. Two spans.** A switch chooses `Last fight` (the most recent finished fight, or the current one
  while fighting) or `Session` (since the game was opened or loaded). The panel says which fight: `Last
  fight: 3 ogres, depth 7, 14 s` (the Slime King by name for a guardian).
- **R4. Side quests count too.** Under the bars, one line per hero who has done any: `Rogue: 4 side
  quests` for the session span.
- **R5. It updates as the fight goes.** While open during a fight the bars move as the events arrive, at
  every game speed, and catch-up after time away adds nothing to either span (the away report already
  covers that time).
- **R6. It explains itself.** Each tab and the span switch has a tooltip (spec 030) of one sentence. `T`
  is in the help panel's key list.
- **R7. It fits and changes nothing.** The panel is no larger than the hero sheet (240x150) and covers
  neither the party frames nor the top band; the game runs behind it. No change under `sim/`: the state
  hash is unchanged with the panel open.

## Interfaces

```gdscript
# game/hud/tally.gd  (the counting, a plain class so it can be tested without a HUD)
class_name Tally
extends RefCounted
enum Measure { DAMAGE, HEALING, TAKEN }
enum Span { LAST_FIGHT, SESSION }
func observe(event: SimEvent) -> void
func value(hero_id: int, measure: Measure, span: Span) -> int
func share(hero_id: int, measure: Measure, span: Span) -> float   # 0 to 1
func side_quests(hero_id: int) -> int

# game/hud/tally_panel.gd
class_name TallyPanel
extends Control
func setup(simulation: Simulation, world: World) -> void
func advance(delta: float) -> void
func open() -> void
func close() -> void
func is_open() -> bool
func rows() -> Array[String]            # the lines showing, top first

# game/hud/hud.gd gains
var tally: TallyPanel
```

If the simulation's events do not carry what a measure needs (for example who healed whom), stop and
report the gap rather than changing `sim/`.

## Acceptance

In `tests/acceptance/test_045_the_party_tally.gd`, with the counting in `tests/unit/test_hud_tally.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_tally_panel` | `T`, the button and `Esc`; the heroes in order; exclusion both ways with the sheet, journal, shop, orders and help |
| R2 | `test_r2_three_measures` | Each measure's numbers against a fight's own events summed in the test; the bars' scale; the shares summing to 100% |
| R3 | `test_r3_two_spans` | Last fight against session over two fights; the fight's line for ordinary monsters and for a guardian; the current fight while fighting |
| R4 | `test_r4_side_quests_count` | The line after a hero completes side quests; none for a hero with none |
| R5 | `test_r5_updates_live` | Bars changing during a fight with the panel open, at 1x and 4x; nothing added by catch-up after time away |
| R6 | `test_r6_explains_itself` | The tooltips; `T` in the key list and its case in the 030 test |
| R7 | `test_r7_fits_and_changes_nothing` | Rectangles against the frames and top band; the size bound; the state hash with the panel open and closed |

**To look at, and for Zak:** shots of the panel on each tab after a few fights, and during a guardian
fight (a throwaway scene; do not commit it). Crop and enlarge 3x. Can you tell in a glance who is doing the
work? Describe the shots.

## Out of scope

- Any change under `sim/`; saving the tally; damage per second, per-ability breakdowns, history graphs.
- New sprites or sounds.

## Paths

- `game/hud/tally.gd`, `game/hud/tally_panel.gd`, `game/hud/hud.gd`, `game/hud/hud_tooltip.gd`
- `game/hud/help_panel.gd` (the `T` row in `KEYS`) and `tests/acceptance/test_030_help_and_hints.gd` (its
  case in `_check_entry`)
- Other panels under `game/hud/` only for the line or two that closes them when the tally opens (say
  which)
- `tests/acceptance/test_045_the_party_tally.gd`, `tests/unit/test_hud*.gd`
- Existing HUD tests only where they count HUD children or walk every HUD child's rectangle (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
