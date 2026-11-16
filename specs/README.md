# Specs

Colony is built from specs. A spec says what a piece of the game must do and how we will know it does; an
implementer lane builds exactly that.

## Board

| # | Spec | Milestone | Status | Depends on |
|---|---|---|---|---|
| — | Harness bootstrap (not a spec: built by the lead), [#1](https://github.com/zakpruitt/colony/pull/1) | M0 | landed | — |
| 002 | [Art foundation](002-art-foundation/spec.md) | M0 | landed on dev, [#4](https://github.com/zakpruitt/colony/pull/4), provisional | — |
| 014 | [Saving progress](014-save-progress/spec.md) | M3 | landed on dev, [#13](https://github.com/zakpruitt/colony/pull/13), provisional | 005 |
| 008 | [World integration](008-world-integration/spec.md) | M2 | landed on dev, [#10](https://github.com/zakpruitt/colony/pull/10), provisional | 005, 006, 007 |
| 013 | [Deeper monsters](013-deeper-monsters/spec.md) | M2 | landed on dev, [#11](https://github.com/zakpruitt/colony/pull/11), provisional | 004, 005, 007 |
| 009 | [Pixel font](009-pixel-font/spec.md) | M0 | landed on dev, [#9](https://github.com/zakpruitt/colony/pull/9), provisional | 002 |
| 007 | [Character sprites](007-character-sprites/spec.md) | M2 | landed on dev, [#7](https://github.com/zakpruitt/colony/pull/7), provisional | 002 |
| 006 | [Labyrinth view](006-labyrinth-view/spec.md) | M1 | landed on dev, [#6](https://github.com/zakpruitt/colony/pull/6), provisional | 002, 003 |
| 005 | [Expedition loop](005-expedition-loop/spec.md) | M3 | landed on dev, [#8](https://github.com/zakpruitt/colony/pull/8), provisional | 001, 003, 004 |
| 004 | [Combat core](004-combat-core/spec.md) | M2 | landed on dev, [#5](https://github.com/zakpruitt/colony/pull/5), provisional | 001 |
| 003 | [Labyrinth generation](003-labyrinth-generation/spec.md) | M1 | landed on dev, [#3](https://github.com/zakpruitt/colony/pull/3), provisional | — |
| 001 | [Simulation clock and background ticking](001-sim-clock/spec.md) | M0 | landed, [#2](https://github.com/zakpruitt/colony/pull/2) | — |

### Planned for the 2026-11-16 overnight run

Written and spawned by the lead as each wave's dependencies land; numbers and scope may shift.

| Wave | Spec | Depends on |
|---|---|---|
| D | [010 Combat effects](010-combat-effects/spec.md): numbers, sparks, shake, freeze, bursts, coins, XP motes — provisional, not started | 008, 009 |
| D | [011 HUD](011-hud/spec.md): party frames, gold, depth, target-depth control — provisional, not started | 008, 009 |
| D | [012 Ambient life](012-ambient-life/spec.md): light, torches, buried detail, props, motion — provisional, in progress | 006 |
| D | [015 Standing room](015-standing-room/spec.md): fighters stop standing on one spot, climbers stand on the ladder — provisional, not started | 004, 005, 008 |
| E | Lead pre-wires stubs for 010-012 in `Main` after 008 lands (CombatEffects, Hud, Ambience), then spawns them | 008 |
| F | Polish passes from looking at the running game; saves if time allows | all |
