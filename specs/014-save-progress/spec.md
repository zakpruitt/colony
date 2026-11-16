# 014 — Saving progress

- **Status:** provisional
- **Milestone:** M3
- **Depends on:** 005
- **Pull request:** —

## Intent

Closing the game must not throw away the party's levels, gold and depth. This spec saves the party's
*progress*, not the exact moment: on loading, the party stands up fresh at its last stable depth, exactly as
it does after a wipe, with everything it has earned. That keeps the save small, readable and hard to corrupt,
and it avoids freezing a fight in mid-swing. The lead wires saving into the main scene afterwards; this spec
builds the parts and proves them.

## Requirements

- **R1. Progress becomes plain data.** `Simulation.to_save()` returns a dictionary of plain values (numbers,
  strings, arrays, dictionaries; nothing else) holding: a format version, the seed, the tick, the party's gold,
  each hero's class, level and XP, and the expedition's last stable depth, deepest depth, target depth and
  auto-push setting. It round-trips through JSON text unchanged.
- **R2. Progress comes back.** `Simulation.from_save(data)` returns a simulation with the same seed, tick,
  gold, hero classes, levels and XP, last stable depth, deepest depth, target depth and auto-push. Every hero
  is alive at full health. The party stands in the first chamber of its last stable depth, travelling, with
  no fight in progress, and every chamber is freshly populated. No events are pending.
- **R3. It carries on normally.** A loaded simulation steps for an hour of game time without error, and gold,
  XP and levels never go below what was loaded. Two simulations loaded from the same data and stepped the same
  number of ticks have the same state hash.
- **R4. Bad data is refused, not guessed at.** `from_save` returns `null`, and `Simulation.save_problems(data)`
  says why, for: a missing or wrong-typed field, an unknown version, an unknown hero class, a level below 1,
  negative gold or XP, a depth below 1, or a last stable depth greater than the deepest depth. Valid data has
  no problems. Nothing in this path can crash or push an engine error on any dictionary.
- **R5. Old versions can be brought forward.** The version is `1`. Loading goes through one function that
  upgrades older data step by step before reading it, so a later spec adds a step instead of rewriting the
  loader. With only one version this is a pass-through, and it is tested as one.
- **R6. Writing cannot leave half a file.** `SaveStore.write(data)` writes JSON to a temporary file beside the
  save and renames it into place. If a save already exists it is kept as one backup first. It returns whether
  it succeeded.
- **R7. Reading falls back.** `SaveStore.read()` returns the saved dictionary. If the save is missing,
  unreadable, not JSON or not a dictionary, it returns the backup instead; if that also fails, an empty
  dictionary. It never raises an engine error for a missing or damaged file.
- **R8. The store is told where to write.** `SaveStore` takes its file path when created, so tests use their
  own per-process file under `user://` and remove it, the backup and the temporary file afterwards.

## Interfaces

```gdscript
# sim/simulation.gd
const SAVE_VERSION: int = 1
func to_save() -> Dictionary
static func from_save(data: Dictionary) -> Simulation      # null if the data has problems
static func save_problems(data: Dictionary) -> PackedStringArray

# game/save/save_store.gd
class_name SaveStore
extends RefCounted
const DEFAULT_PATH: String = "user://colony.save"
func _init(path: String = DEFAULT_PATH) -> void
func write(data: Dictionary) -> bool
func read() -> Dictionary
func backup_path() -> String
```

`sim/` stays pure: it produces and reads dictionaries and never touches a file. Files belong to `SaveStore` in
`game/`. Placing the party at a depth is what revival already does; reuse that rather than writing a second
way to arrive somewhere. JSON turns whole numbers into floats: the loader accepts a float that is a whole
number where it wants an integer.

## Acceptance

In `tests/acceptance/test_014_save_progress.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_progress_is_plain_data` | After 20 minutes of play, `to_save()` holds every listed field with only plain types, and survives `JSON.stringify` then `JSON.parse_string` |
| R2 | `test_r2_progress_comes_back` | Loading that data (through JSON) gives the same listed values; heroes alive and full; party in the first chamber of the last stable depth, travelling, no battle, no pending events |
| R3 | `test_r3_carries_on` | An hour of steps after loading; gold, XP and levels never below loaded values; two loads stepped alike have equal hashes |
| R4 | `test_r4_bad_data_is_refused` | Each listed fault gives `null` and a problem naming the field; an empty dictionary and a dictionary of wrong types do the same; valid data gives none |
| R5 | `test_r5_upgrade_is_a_pass_through` | Version 1 data is unchanged by the upgrade step; version 2 and version 0 are refused |
| R6 | `test_r6_write_is_atomic_with_a_backup` | After one write the file holds the data and no temporary file remains; after a second, the backup holds the first |
| R7 | `test_r7_read_falls_back` | Missing: empty. Damaged save with a good backup: the backup. Both damaged: empty. No engine errors |
| R8 | `test_r8_store_uses_its_path` | Two stores with different paths do not see each other's data |

## Out of scope

- Wiring into the main scene: when to save, loading at start, a "new game" control. The lead does this.
- Offline progress (what happened while the game was closed).
- Saving the exact moment: positions, a fight in progress, chamber timers, random streams.
- Several save slots, cloud saves, settings.

## Paths

- `sim/simulation.gd`, `sim/party/`, `sim/expedition/expedition.gd`
- `game/save/`
- `tests/acceptance/test_014_save_progress.gd`, `tests/unit/test_save*.gd`
- `docs/architecture.md` (the "Saving" section), `docs/wiki/index.html`

## Open questions

None.
