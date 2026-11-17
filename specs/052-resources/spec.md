# 052 — Resources: a reason to choose an area

- **Status:** landed (provisional: not yet reviewed by Zak) (direction agreed with Zak 2026-11-17; text not yet read by him)
- **Milestone:** M6
- **Depends on:** 016, 017, 022, 031, 049, 051, 053
- **Pull request:** [#55](https://github.com/zakpruitt/colony/pull/55)

## Intent

Zak wants the party to go to different areas "to get different resources, farm different mobs". Each
area gives its own resource, and camp upgrades cost gold and a resource, so what the player wants to
build decides where the party goes. This is the first use of resources; gear and professions are later.

## Requirements

- **R1. Each area has a resource.** An area names one resource: Mossy Hollow gives **glowcaps**, the
  Claypits **clay**, the Old Crypt **old bones**, Ember Deep **embers**. A resource is content (a name,
  a plural, an icon) under `data/resources`.
- **R2. The party gathers it by fighting there.** A monster killed in an area may drop that area's
  resource: small monsters sometimes, large ones usually, a guardian always and several. The amount
  grows with the stage, so farming further in pays more. A side quest finished in an area pays some too.
  Drops come from their own random stream, so adding them changes no fight.
- **R3. The party keeps a count** of each resource, shown beside the gold when it has any, with a
  tooltip naming the resource and the area it comes from.
- **R4. Upgrades cost resources.** Each camp upgrade names one resource. Its first three ranks cost gold
  alone, as today, so the opening is unchanged; each later rank costs gold and that resource. Which
  upgrade takes which:

  | Upgrade | Resource |
  |---|---|
  | Field Medicine, Quick March | glowcaps |
  | Stout Armor | clay |
  | Sharp Blades | old bones |
  | Fat Purse | embers |

- **R5. The shop says what is missing.** A shop row shows both prices, greys the one the party cannot
  pay, and its tooltip says where the resource comes from (`Clay comes from the Claypits`). A row whose
  resource comes from an area that is not open says how that area is opened.
- **R6. Auto-buy pays both prices** and never buys what it cannot pay in full.
- **R7. The map shows it.** Each area on the map shows its resource and how many the party holds; a
  closed area shows the resource so the player knows what opening it gives.
- **R8. Told like gold.** A drop shows on screen as gold does (a small icon rising from the monster, the
  count ticking up); the journal notes the first of each resource; the away report lists resources
  gathered; the tally of a fight is unchanged.
- **R9. Saves carry it** (the next save version): the count of each resource. Older saves load with
  none; upgrade ranks they already hold stay.
- **R12. Beaten guardians are remembered.** The simulation keeps, and the save holds, which areas'
  guardians have been beaten at least once (`Simulation.is_guardian_beaten(area_id)`), and the map reads
  that instead of working it out. Today the last area's guardian shows as not beaten after a reload.
  Older saves count a guardian beaten when the area it opens is open or the furthest stage is past it.
- **R10. Worth the trip.** In the headless run with auto-buy, a party that only ever stays in Mossy
  Hollow stops being able to buy Stout Armor, Sharp Blades and Fat Purse at rank 3, and a party sent to
  the Claypits once it is open holds clay within five minutes of arriving. The numbers are the lane's
  to tune; report them.
- **R11. Still deterministic**; the recorded-hash tests are re-recorded only where the hash now includes
  resources, and the pull request says so.

## Interfaces

```gdscript
# sim/defs/resource_def.gd, one .tres per resource under res://data/resources
class_name ResourceDef extends Resource
@export var id: StringName
@export var display_name: String        # "Glowcap"
@export var plural: String              # "glowcaps"
func validate() -> PackedStringArray

# sim/defs/area_def.gd
@export var resource: StringName

# sim/defs/upgrade_def.gd
@export var resource: StringName
@export var resource_from_rank: int     # 3: the first rank (counting from 0) that also costs the resource
@export var resource_base: int
func resource_cost_at(rank: int) -> int

# sim/party/party.gd
func resource(id: StringName) -> int

# sim/sim_event.gd, before ENCOUNTER_STARTED
RESOURCE_GAINED
```

## Acceptance

In `tests/acceptance/test_052_resources.gd`, one test per requirement named `test_rN_…`, each showing
what its requirement says with exact numbers where the requirement has them. R8 and R3 are tested at the
view with events delivered many ticks to a frame as well as one. R10 is a headless comparison on seeds
1 to 3.

**To look at, and for Zak:** the shop with a row the party can pay, one missing its resource and one
whose area is closed; the HUD with two resources held; the map. Cropped and enlarged. Describe them.

## Out of scope

- Crafting, gear, professions, trading one resource for another.
- New upgrades (a later spec may add ones that only a far area's resource buys).
- New monsters; resource sprites beyond a plain 8x8 icon each.

## Paths

- `sim/`, `data/resources/`, `data/areas/`, `data/upgrades/`
- `game/hud/`, `game/effects/`, `game/save/`, `game/dev/showcase.gd`
- `assets/` (four icons)
- `tools/dev.py`, `tools/godot/`, `tools/tests/`
- `tests/`
- `docs/architecture.md`, `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
