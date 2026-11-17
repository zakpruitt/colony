# 026 — The hero sheet: one place to look at each hero

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M4
- **Depends on:** 011, 016, 017
- **Pull request:** [#26](https://github.com/zakpruitt/colony/pull/26)

## Intent

A hero is a portrait and two bars. The player cannot see what a hero is good at, how strong they are, how
far they are from the next level, or what they are doing right now. This spec adds a sheet for each hero:
click a hero's frame and a panel opens with everything about them in plain words. It is the place later
specs will hang per-hero upgrades, microskills and management on, so it must be clear and roomy. It changes
no rules.

## Requirements

Everything follows `docs/style-bible.md` and matches the shop panel's look (`game/hud/shop_panel.gd`).

- **R1. Opening and closing.** Clicking a hero's frame opens that hero's sheet; clicking the same frame
  again, pressing `Esc`, or clicking the sheet's close button closes it. Clicking another frame switches to
  that hero. `Tab` opens the sheet on the first hero, then moves to the next hero, wrapping. The open
  hero's frame is visibly marked. The shop and the sheet are never open together: opening one closes the
  other. The game does not pause.
- **R2. Who they are.** The sheet shows the hero's portrait at twice the frame's size, class name, role in
  one word (Tank, Striker, Caster, Healer; from the class's role), and level.
- **R3. Where they stand.** Health as numbers and a bar (`34 / 80`), and XP as numbers and a bar with the
  amount still needed (`120 / 200 XP, 80 to level 6`).
- **R4. What they can do.** A stat block with plain labels and the real current values, camp upgrades
  included: Health, Damage, Armor, Attack speed (attacks per second, one decimal), Crit chance (percent),
  Range (`Melee` or tiles) and, only for a class that heals, Healing. A stat raised by a camp upgrade shows
  its bonus beside it in green (`Damage 14 (+15%)`).
- **R5. What they are doing now.** One line, updated every frame, in words: `Walking`, `Fighting <monster
  name>` (their current target, or `Fighting` when they have none), `Healing <hero name>` for a healer
  whose target is an ally, `Resting`, `Climbing`, `Down` (in red, when dead), `Recovering` (during a
  revival).
- **R6. It follows the simulation.** Every value is read from the simulation each frame; nothing is cached
  across a level up, an upgrade purchase or a loaded save. A HUD built from a loaded save opens sheets that
  show the saved heroes.
- **R7. It fits.** The sheet sits above the party frames and below the top band, never covers the top
  band or the frames, stays inside the screen for all four heroes, and all text is legible at 640x360.
- **R8. Keys still work.** With the sheet open, `-`, `=`, `A`, `Z`, `M` and `U` do what they do without it
  (`U` opens the shop, which closes the sheet).

## Interfaces

```gdscript
# game/hud/hero_sheet.gd
class_name HeroSheet
extends Control
func setup(simulation: Simulation, world: World) -> void
func advance(delta: float) -> void
func open(hero_id: int) -> void
func close() -> void
func is_open() -> bool
func shown_hero_id() -> int          # -1 when closed
## The text of a line of the sheet, for tests: &"class", &"role", &"level", &"health", &"xp",
## &"activity", and one per stat: &"stat_health", &"stat_damage", &"stat_armor", &"stat_attack_speed",
## &"stat_crit", &"stat_range", &"stat_healing" ("" when the class does not heal).
func line(key: StringName) -> String

# game/hud/hud.gd gains
var hero_sheet: HeroSheet
```

A hero's current fight target comes from the battle's combatants (`Expedition.battle`); if the battle does
not expose a combatant's target, show `Fighting` and say so in your report rather than changing `sim/`.

## Acceptance

In `tests/acceptance/test_026_hero_sheet.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_opening_and_closing` | Click, click again, `Esc`, the close button, switching, `Tab` and its wrap, the marked frame, the shop and sheet excluding each other, the tick advancing while open |
| R2 | `test_r2_who_they_are` | Class, role word and level for each of the four |
| R3 | `test_r3_where_they_stand` | The health and XP lines against the hero's real numbers, before and after damage and XP |
| R4 | `test_r4_what_they_can_do` | Each stat line against the simulation; the green bonus after buying an upgrade; no healing line for a class that does not heal |
| R5 | `test_r5_what_they_are_doing` | Each activity line in its state, including `Down` in red |
| R6 | `test_r6_follows_the_simulation` | Values change with a level up and an upgrade without reopening; a loaded save |
| R7 | `test_r7_it_fits` | The sheet's rectangle for each hero against the top band, the frames and the screen |
| R8 | `test_r8_keys` | Each key with the sheet open |

**To look at, and for Zak:** in a throwaway scene you do not commit, open the sheet for a hero mid-fight
with an upgrade bought, and take a shot for each of the four heroes. Crop and enlarge. Is every line
readable, and can you tell at a glance what this hero is and what they are doing? Describe the shots.

## Out of scope

- Any change under `sim/`.
- Per-hero upgrades, microskills, equipment, renaming or choosing heroes (later specs add sections).
- New sprites.

## Paths

- `game/hud/hero_sheet.gd`, `game/hud/hud.gd`, `game/hud/hero_frame.gd` (clicks and the marked state)
- `game/hud/shop_panel.gd` (only closing the sheet when the shop opens)
- `tests/acceptance/test_026_hero_sheet.gd`, `tests/unit/test_hud*.gd`
- Existing HUD or shop tests only where they count HUD children (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
