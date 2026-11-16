# Specs

Colony is built from specs. A spec says what a piece of the game must do and how we will know it does; an
implementer lane builds exactly that.

## Board

| # | Spec | Milestone | Status | Depends on |
|---|---|---|---|---|
| — | Harness bootstrap (not a spec: built by the lead), [#1](https://github.com/zakpruitt/colony/pull/1) | M0 | landed | — |
| 002 | [Art foundation](002-art-foundation/spec.md) | M0 | landed on dev, [#4](https://github.com/zakpruitt/colony/pull/4), provisional | — |
| 020 | [Guardians](020-guardians/spec.md) | M3 | landed on dev, [#21](https://github.com/zakpruitt/colony/pull/21), provisional | 005, 007, 008, 013, 015 |
| 017 | [Upgrade shop](017-upgrade-shop/spec.md) | M4 | landed on dev, [#20](https://github.com/zakpruitt/colony/pull/20), provisional | 011, 016 |
| 018 | [Seeing the loop](018-seeing-the-loop/spec.md) | M5 | landed on dev, [#19](https://github.com/zakpruitt/colony/pull/19), provisional | 008, 010, 011, 012, 015 |
| 016 | [Camp upgrades](016-camp-upgrades/spec.md) | M3 | landed on dev, [#18](https://github.com/zakpruitt/colony/pull/18), provisional | 005, 014 |
| 019 | [Progress while away](019-away-progress/spec.md) | M3 | landed on dev, [#17](https://github.com/zakpruitt/colony/pull/17), provisional | 014 |
| 015 | [Standing room](015-standing-room/spec.md) | M2 | landed on dev, [#16](https://github.com/zakpruitt/colony/pull/16), provisional | 004, 005, 008 |
| 010 | [Combat effects](010-combat-effects/spec.md) | M5 | landed on dev, [#15](https://github.com/zakpruitt/colony/pull/15), provisional | 008, 009 |
| 011 | [HUD](011-hud/spec.md) | M4 | landed on dev, [#14](https://github.com/zakpruitt/colony/pull/14), provisional | 008, 009 |
| 012 | [Ambient life](012-ambient-life/spec.md) | M5 | landed on dev, [#12](https://github.com/zakpruitt/colony/pull/12), provisional | 006 |
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
| H | [021 Sound effects](021-sound-effects/spec.md): 8-bit sounds baked from text recipes, quiet and mutable — provisional, in progress | 008, 010 |
| H | [022 Auto-buy](022-auto-buy/spec.md): the camp can buy its own upgrades, also while away — provisional, in progress | 016, 017, 019 |
