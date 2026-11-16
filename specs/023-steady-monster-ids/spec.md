# 023 — Watching must not change the game

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M3
- **Depends on:** 005, 008, 020
- **Pull request:** [#25](https://github.com/zakpruitt/colony/pull/25)

## Intent

Four lanes have reported the same flaw: asking the expedition which monsters wait in a chamber
(`monsters_in`) rolls them on the spot and hands out ids from a running counter. The view asks for every
chamber it draws, so a game that is watched and the same game run headless give monsters different ids and
different state hashes. Nothing visible is wrong yet, but the architecture promises that the view only
reads, and saves, replays and any future multiplayer or bug report depend on it. This spec makes reading
free of side effects.

## Requirements

- **R1. Reading changes nothing.** Calling `is_populated`, `monsters_in`, `hero_position`, `chamber`,
  `guardian_of` or `hash_parts` any number of times, for any depth and chamber, in any order, never changes
  `Simulation.state_hash()`.
- **R2. A watched game equals an unwatched one.** Two simulations of one seed, stepped alike, where one has
  `monsters_in` called for every chamber of the party's level and its neighbours on every tick (as the world
  does) and the other never has, are hash-equal at every sampled tick over 30 minutes, and their event lists
  are identical (kind, tick, ids, amounts).
- **R3. Monster ids come from where the monster is.** A monster's id is fixed by its depth, chamber, visit
  count and place in the encounter, not by the order anything was asked for. Ids are unique among all
  monsters that exist at one time, never collide with hero ids, and stay at or above
  `Expedition.FIRST_MONSTER_ID`. How the number is built is the lane's choice; state it in a doc comment.
- **R4. The same game otherwise.** Which monsters appear where, their stats and positions, and every existing
  balance statement are unchanged. Existing tests pass; one that asserts a particular id value (rather than
  uniqueness or range) may be updated.
- **R5. The world still follows.** The main scene runs a 10-minute game with refills, a climb and a wipe
  with no sprite left behind or missing: the 008 tests pass, and ids reused by a refilled chamber (if the
  scheme reuses them) never show a dead monster's sprite as alive or leave a live one hidden.

## Interfaces

No signatures change. `Expedition._next_monster_id` may go away.

## Acceptance

In `tests/acceptance/test_023_steady_monster_ids.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_reading_changes_nothing` | The hash before and after a storm of read calls at several points in a 10-minute run |
| R2 | `test_r2_watched_equals_unwatched` | The hash and event-list equality over 30 minutes on three seeds |
| R3 | `test_r3_ids_come_from_place` | The same chamber and visit give the same ids whenever asked; ids unique among all populated chambers of three neighbouring levels and all fighters; all at or above `FIRST_MONSTER_ID` |
| R4 | (the existing suite) | `python tools/dev.py check` passes |
| R5 | `test_r5_world_follows_reused_ids` | In a `World`, through a chamber cleared and refilled, sprites match the living monsters after each sync |

## Out of scope

- Saving the exact moment, or anything else about saves.
- The battle's private random stream and projectiles being absent from the hash (a separate question).

## Paths

- `sim/expedition/expedition.gd`, `sim/expedition/chamber_state.gd`
- `game/world/world.gd` (only if R5 needs it: how gone or reused ids are tracked)
- `tests/acceptance/test_023_steady_monster_ids.gd`, `tests/unit/test_expedition*.gd`
- An existing test only where it asserts a particular monster id value (say which)
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None.
