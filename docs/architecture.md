# Architecture

The rules every spec builds on. A spec may refine this document; it changes in the same pull request as the
code that makes it true.

## Two halves

```
 commands                       state + events
game/  ───────────────▶  sim/  ───────────────▶  game/
(input, UI)              (rules, pure)           (sprites, effects, UI)
```

**`sim/` is the game.** It holds every rule: movement, combat, loot, rest, depth. It is plain typed GDScript
(`RefCounted` classes and resources), with no scene tree, no engine clock and no global random state. It can be
created, stepped and inspected from a test with nothing else running.

**`game/` shows it and steers it.** Nodes read the sim's state and the events it reported since the last
frame, and draw them. The player's choices reach the sim as commands. Nothing in `game/` decides a rule, and
nothing in `sim/` knows it is being drawn.

`python tools/dev.py check` enforces the first half (the `boundary` step): a script under `sim/` that names
`Node`, `Engine`, `Time`, `OS`, `Input`, the scene tree, or a global random function fails the check.

## Time

The sim advances only when something calls its step function, one fixed tick at a time. It never asks what
time it is.

The driver in `game/` measures real elapsed time (not rendered frames) and steps the sim as many ticks as have
passed. That one design gives three things the game needs:

- **Background running:** the tick count depends on the clock, so a throttled or hidden window loses no time.
- **Offline catch-up:** time missed while closed or asleep is more ticks to step (or to estimate, past a cap).
- **Fast tests:** a test steps ten minutes of play in a loop, with no waiting.

## Randomness

Every roll comes from a `SimRng` (`sim/sim_rng.gd`), a seeded stream whose position can be saved. Systems take
their own stream with `fork("label")`, so adding a roll to loot never changes what combat rolls. The same seed
and the same commands give the same run; a test asserts it.

## Content

Classes, talents, items and monsters are custom `Resource` classes with typed `@export` fields, stored as text
`.tres` files under `data/`. Adding content means adding a file, not code. Each content class defines
`validate() -> PackedStringArray` (one line per problem); the `data` step of the check loads every resource
and fails on any problem.

## Saving

The save is the party's *progress*, not the exact moment (spec 014). `Simulation.to_save()` returns plain
values: a format version, the seed, the tick, the gold, each hero's class, level and XP, and the expedition's
last stable depth, deepest depth, target depth and auto-push, and the rank of each camp upgrade (spec 016).
Positions, a fight in progress, chamber timers and
random streams are not saved: `Simulation.from_save(data)` makes a new simulation from the seed and stands the
party up the way revival does (`Expedition.arrive_from_save`), alive and full at the arrival point of its last
stable depth, with every chamber freshly populated.

- **Refused, not guessed at.** `Simulation.save_problems(data)` lists every problem, one line naming the field;
  `from_save` returns `null` if there is any. JSON makes whole numbers floats, so a whole float is read as an
  int; a float past 2^53 is refused, so seeds must stay within ±2^53 to survive a save.
- **Versions.** `SAVE_VERSION` is 2. Loading goes through `Simulation.upgrade_save`, which brings older data
  forward one step at a time; a new format adds a step there and raises the version. Version 1 to 2 adds
  `upgrades` (a dictionary of upgrade id to rank) with every rank 0. A rank that is negative, above the
  upgrade's maximum or for an unknown upgrade is refused by name; unknown extra top-level keys are tolerated.
- **Files belong to `game/`.** `SaveStore` (`game/save/save_store.gd`) is given its path (default
  `user://colony.save`). It writes JSON to `<path>.tmp` and renames it into place, keeping the previous save as
  `<path>.bak`; reading falls back to the backup, then to an empty dictionary, if a file is missing or damaged.
- **Time away (spec 019).** `Main` adds a `saved_at` key (real seconds since 1970) beside the simulation's
  fields when it writes; the simulation ignores it. On starting with a stamped save, `Main.time_away` gives
  the real time since, clamped to 0 to 8 hours; from 60 s up, an `AwayReplay` (`game/save/`) steps the loaded
  simulation for that game time in 10 ms slices per frame, draining and counting events into an `AwayReport`,
  while a `CatchUpBar` shows. The driver, world, effects and HUD are made only when it ends (`caught_up`), so
  nothing from the time away is drawn, and an `AwayPanel` reports it. No save is written during a replay, so
  quitting part way loses nothing. Tests set `away_seconds_override`; a run with no `save_store` never replays.
  The world fills the chambers it looks at (`Expedition.monsters_in`), which changes the state hash, so a
  replay is compared with plain stepping at the moment it ends, before the world exists.

## Conventions

- One class per file, `class_name` in PascalCase, file in snake_case, a `##` doc comment on the class and on
  every public method.
- Signals for things that happened, methods for things to do. The sim does not use signals; it returns events.
- Scenes stay small and are composed in code or by instancing; logic lives in scripts, not in the editor.
- Tuning numbers live in data or in named constants with a comment saying what the number does.
