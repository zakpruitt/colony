# Specs

Colony is built from specs. A spec says what a piece of the game must do and how we will know it does; an
implementer lane builds exactly that.

## Board

| # | Spec | Milestone | Status | Depends on |
|---|---|---|---|---|
| — | Harness bootstrap (not a spec: built by the lead), [#1](https://github.com/zakpruitt/colony/pull/1) | M0 | landed | — |
| 002 | [Art foundation](002-art-foundation/spec.md) | M0 | landed on dev, [#4](https://github.com/zakpruitt/colony/pull/4), provisional | — |
| 004 | [Combat core](004-combat-core/spec.md) | M2 | landed on dev, [#5](https://github.com/zakpruitt/colony/pull/5), provisional | 001 |
| 003 | [Labyrinth generation](003-labyrinth-generation/spec.md) | M1 | landed on dev, [#3](https://github.com/zakpruitt/colony/pull/3), provisional | — |
| 001 | [Simulation clock and background ticking](001-sim-clock/spec.md) | M0 | landed, [#2](https://github.com/zakpruitt/colony/pull/2) | — |

### Planned for the 2026-11-16 overnight run

Written and spawned by the lead as each wave's dependencies land; numbers and scope may shift.

| Wave | Spec | Depends on |
|---|---|---|
| B | [005 Expedition loop](005-expedition-loop/spec.md): travel, encounters, XP, gold, rest, wipe and fallback (sim) — provisional, in progress | 001, 003, 004 |
| B | [006 Labyrinth view](006-labyrinth-view/spec.md): tiles, depth bands, camera — provisional, in progress | 002, 003 |
| B | [007 Character sprites](007-character-sprites/spec.md): nine characters, part-based animation — provisional, in progress | 002, 004 |
| C | [008 World integration](008-world-integration/spec.md): the party, monsters and fights on screen from sim state and events — provisional, not started | 005, 006, 007 |
| D | 009 Combat effects: hit sparks, damage numbers, projectiles, shake, death bursts, coins | 008 |
| D | 010 HUD: party frames, XP, gold, depth, target-depth control | 008 |
| D | 011 Ambient life: torches and light, dust, props, background detail | 008 |
| E | Balance and polish passes, then saves if the night allows | all |
