# 035 — Party orders: tell the party how to play

- **Status:** provisional
- **Milestone:** M4
- **Depends on:** 005, 014, 020, 027, 030
- **Pull request:** —

## Intent

The player can set a target depth and little else: the party rests when it rests and throws itself at a
guardian the moment it finds one, wipe after wipe. Zak asked for managing the party to be easy and real.
This spec adds **orders**: two standing instructions the party follows by itself, each a plain choice with a
visible effect. They are the first of the knobs a player tunes while the game runs unattended.

## Requirements

- **R1. Pace.** The party has a pace: `Cautious`, `Steady` or `Bold`. It sets the health below which the
  party stops to rest after a fight: 80%, 60% or 40% of the party's total health. `Steady` is today's rule
  and the default.
- **R2. Guardians.** The party has a guardian order: `Challenge` or `Hold`. Under `Challenge` (today's rule
  and the default) the party enters a guardian's chamber when its way down leads through it. Under `Hold`
  the party never enters a chamber whose guardian is alive: it turns back at the chamber's mouth and keeps
  hunting on that level, and a level whose guardian stands still becomes stable as any other does. Changing
  to `Challenge` sends it in on its next pass. A beaten guardian's empty chamber is crossed under either
  order.
- **R3. Orders are commands.** `Simulation.set_pace(pace)` and `Simulation.set_guardian_order(order)` take
  effect at the next step and raise an `ORDER_CHANGED` event (target: 0 for pace, 1 for the guardian order;
  amount: the new value).
- **R4. They are saved.** Both are in the save; the version rises by one, and a save of the previous version
  loads with the defaults through the upgrade step. Bad values are refused by name.
- **R5. Defaults change nothing.** With both orders at their defaults, a simulation's state hash is the
  same, tick for tick, as before this spec, and every existing test passes (apart from assertions about the
  save version or the exact saved dictionary, which may be updated).
- **R6. They do what they say.** Over one hour with `stable_seconds` 120 on three seeds: a `Cautious` party
  rests more often and wipes no more often than a `Bold` one; a party under `Hold` never fights a guardian,
  never passes depth 5, and is not stuck (it keeps fighting and earning on depth 5); and a party switched
  from `Hold` to `Challenge` at level 9 or above beats the first guardian within ten minutes on at least two
  of three seeds.
- **R7. An orders panel.** An `Orders` button in the top band and the `O` key open and close a small panel
  with one row per order: its name, a one-line plain explanation of the current choice (`Bold: rest only
  below 40% health`, `Hold: do not fight guardians until told`), and a button per choice with the current
  one lit. Clicking a choice sends the command. `Esc` closes it. It follows the simulation (a loaded save
  shows the saved orders) and excludes the shop, hero sheet, journal and help as they exclude one another.
- **R8. The status line knows.** While the party is turning back from a guardian under `Hold`, and while it
  hunts on a guardian's level under `Hold` with a deeper target, the status line reads `Holding at the
  <guardian's name>`. The journal gains a line when an order changes.
- **R9. It explains itself.** The Orders button and each choice have a tooltip (spec 030), `O` is in the
  help panel's key list, and "the idea" still fits.
- **R10. It fits.** The panel and the button stay clear of the top band's other controls, the boss bar and
  the party frames, inside the screen.

## Interfaces

```gdscript
# sim/expedition/expedition.gd gains
enum Pace { CAUTIOUS, STEADY, BOLD }
enum GuardianOrder { CHALLENGE, HOLD }
var pace: Pace = Pace.STEADY                       # read-only outside the class
var guardian_order: GuardianOrder = GuardianOrder.CHALLENGE
## True while the party is being kept from a living guardian by the Hold order.
func is_holding() -> bool

# sim/simulation.gd gains
func set_pace(pace: Expedition.Pace) -> void
func set_guardian_order(order: Expedition.GuardianOrder) -> void

# sim/sim_event.gd: Kind.ORDER_CHANGED, placed before ENCOUNTER_STARTED

# game/hud/orders_panel.gd
class_name OrdersPanel
extends Control
func setup(simulation: Simulation, world: World) -> void
func advance(delta: float) -> void
func is_open() -> bool
func open() -> void
func close() -> void
func line(order: int) -> String        # 0 pace, 1 guardians: the explanation shown
func choose(order: int, value: int) -> void

# game/hud/hud.gd gains
var orders: OrdersPanel
var orders_button: HudButton
```

`sim/expedition/expedition.gd` is at about 997 of gdlint's 1000 lines. Move what you add, and if needed
something that is already there, into a small helper class under `sim/expedition/` rather than squeezing
lines; behaviour and the state hash must not change.

## Acceptance

In `tests/acceptance/test_035_party_orders.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_pace` | The party's health at which a rest starts after a fight, for each pace |
| R2 | `test_r2_guardians` | Under Hold: no battle with a living guardian, the turn at the chamber's mouth, the level still becoming stable; in on the next pass after Challenge; a beaten guardian's chamber crossed under Hold |
| R3 | `test_r3_commands` | Effect at the next step and the event's fields |
| R4 | `test_r4_saved` | Round trip; the previous version loads with defaults; bad values refused by name |
| R5 | `test_r5_defaults_change_nothing` | Hashes at sampled ticks over 20 minutes on two seeds equal values recorded before the change |
| R6 | `test_r6_they_do_what_they_say` | The three statements |
| R7 | `test_r7_orders_panel` | The button, `O`, `Esc`; each row's text and lit choice; a click sends the command; a loaded save; the panels excluding one another |
| R8 | `test_r8_status_and_journal` | The holding line and the journal line |
| R9 | `test_r9_explains_itself` | The tooltips and the help panel's key list |
| R10 | `test_r10_it_fits` | Rectangles against the top band's controls, boss bar, frames and screen |

For R5, record the hashes of an untouched simulation before changing any `sim/` code.

**To look at, and for Zak:** shots of the orders panel with each choice lit, and the status line while
holding at the Slime King (a throwaway scene; do not commit it). Crop and enlarge. Is it obvious what each
order does and which is on? Describe the shots.

## Out of scope

- More orders (skipping side quests, per-hero tactics, retreat rules).
- Orders that depend on conditions ("challenge when level 9").
- New sprites or sounds.

## Paths

- `sim/expedition/` , `sim/simulation.gd`, `sim/sim_event.gd`
- `game/hud/orders_panel.gd`, `game/hud/hud.gd`, `game/hud/journal.gd`, `game/hud/help_panel.gd`
- `game/hud/` panels only where they must close when orders opens
- `tests/acceptance/test_035_party_orders.gd`, `tests/unit/test_expedition*.gd`
- Existing tests only where they assert the save version, the exact saved dictionary, the list of event
  kinds, or count HUD children or top-band controls (say which)
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None.
