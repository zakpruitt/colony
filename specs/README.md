# Specs

Colony is built from specs. A spec says what a piece of the game must do and how we will know it does; an
implementer lane builds exactly that.

## Board

| # | Spec | Milestone | Status | Depends on |
|---|---|---|---|---|
| — | Harness bootstrap (not a spec: built by the lead), [#1](https://github.com/zakpruitt/colony/pull/1) | M0 | landed | — |
| 059 | [The shop, the area map and the tally as windows](059-shop-map-and-tally-windows/spec.md) | M7 | landed on dev, [#61](https://github.com/zakpruitt/colony/pull/61), provisional | 017, 022, 045, 052, 053, 056, 058 |
| 060 | [Hero sheets as windows, several at once](060-hero-windows/spec.md) | M7 | landed on dev, [#60](https://github.com/zakpruitt/colony/pull/60), provisional | 026, 028, 034, 051, 055, 058 |
| 058 | [A sharp UI layer, a readable font and windows](058-sharp-ui-and-windows/spec.md) | M7 | landed on dev, [#59](https://github.com/zakpruitt/colony/pull/59), provisional | 009, 011, 027, 030, 035 |
| 057 | [Lively moves](057-lively-moves/spec.md) | M6 | landed on dev, [#58](https://github.com/zakpruitt/colony/pull/58), provisional | 007, 008, 010, 048, 050, 051, 056 |
| 056 | [Abilities on screen](056-abilities-on-screen/spec.md) | M6 | landed on dev, [#57](https://github.com/zakpruitt/colony/pull/57), provisional | 010, 027, 045, 050, 051 |
| 052 | [Resources](052-resources/spec.md) | M6 | landed on dev, [#55](https://github.com/zakpruitt/colony/pull/55), provisional | 016, 017, 022, 031, 049, 051, 053 |
| 055 | [The tree on the hero sheet](055-the-tree-on-the-sheet/spec.md) | M6 | landed on dev, [#56](https://github.com/zakpruitt/colony/pull/56), provisional | 034, 037, 041, 042, 051 |
| 051 | [Talent trees and paragon](051-talent-trees-and-paragon/spec.md) | M6 | landed on dev, [#54](https://github.com/zakpruitt/colony/pull/54), provisional | 029, 049, 050 |
| 054 | [Zones on screen](054-zones-on-screen/spec.md) | M6 | landed on dev, [#53](https://github.com/zakpruitt/colony/pull/53), provisional | 006, 008, 012, 018, 048, 049 |
| 053 | [The area map](053-the-area-map/spec.md) | M6 | landed on dev, [#52](https://github.com/zakpruitt/colony/pull/52), provisional | 030, 037, 042, 049 |
| 049 | [Areas](049-areas/spec.md) | M6 | landed on dev, [#51](https://github.com/zakpruitt/colony/pull/51), provisional | 005, 013, 014, 020, 035 |
| 050 | [Abilities in combat](050-abilities-in-combat/spec.md) | M6 | landed on dev, [#50](https://github.com/zakpruitt/colony/pull/50), provisional | 004, 015 |
| 048 | [A wipe told whole](048-a-wipe-told-whole/spec.md) | M5 | landed on dev, [#49](https://github.com/zakpruitt/colony/pull/49), provisional | 038 |
| 047 | [A ladder that points true](047-a-ladder-that-points-true/spec.md) | M5 | landed on dev, [#48](https://github.com/zakpruitt/colony/pull/48), provisional | 043 |
| 046 | [Notes that stay true](046-notes-that-stay-true/spec.md) | M5 | landed on dev, [#47](https://github.com/zakpruitt/colony/pull/47), provisional | 041, 045 |
| 045 | [The party tally](045-the-party-tally/spec.md) | M5 | landed on dev, [#46](https://github.com/zakpruitt/colony/pull/46), provisional | 006, 025, 026, 029, 030, 037 |
| 043 | [A ladder that warns and can be scrolled](043-a-ladder-that-warns/spec.md) | M5 | landed on dev, [#45](https://github.com/zakpruitt/colony/pull/45), provisional | 033, 036, 042 |
| 044 | [Old saves level up](044-old-saves-level-up/spec.md) | M5 | landed on dev, [#44](https://github.com/zakpruitt/colony/pull/44), provisional | 014, 029, 036 |
| 042 | [Goals you can click](042-goals-you-can-click/spec.md) | M5 | landed on dev, [#43](https://github.com/zakpruitt/colony/pull/43), provisional | 034, 035, 037, 039 |
| 041 | [After a defeat](041-after-a-defeat/spec.md) | M5 | landed on dev, [#42](https://github.com/zakpruitt/colony/pull/42), provisional | 020, 027, 029, 035, 037, 038, 039 |
| 040 | [Orders that hold](040-orders-that-hold/spec.md) | M4 | landed on dev, [#41](https://github.com/zakpruitt/colony/pull/41), provisional | 035, 039 |
| 039 | [The countdown tells the truth](039-the-countdown-tells-the-truth/spec.md) | M5 | landed on dev, [#40](https://github.com/zakpruitt/colony/pull/40), provisional | 027, 036, 037 |
| 038 | [Rough edges on screen](038-rough-edges-on-screen/spec.md) | M5 | landed on dev, [#39](https://github.com/zakpruitt/colony/pull/39), provisional | 008, 010, 012, 020, 028 |
| 036 | [A livelier start](036-a-livelier-start/spec.md) | M5 | landed on dev, [#38](https://github.com/zakpruitt/colony/pull/38), provisional | 005, 016, 020, 025, 029 |
| 037 | [Goals](037-goals/spec.md) | M5 | landed on dev, [#37](https://github.com/zakpruitt/colony/pull/37), provisional | 011, 020, 025, 027, 029, 030, 034 |
| 035 | [Party orders](035-party-orders/spec.md) | M4 | landed on dev, [#36](https://github.com/zakpruitt/colony/pull/36), provisional | 005, 014, 020, 027, 030 |
| 033 | [The depth ladder](033-depth-ladder/spec.md) | M5 | landed on dev, [#34](https://github.com/zakpruitt/colony/pull/34), provisional | 011, 020, 027 |
| 034 | [A hero sheet that fits](034-hero-sheet-tabs/spec.md) | M4 | landed on dev, [#35](https://github.com/zakpruitt/colony/pull/35), provisional | 026, 028, 029 |
| 032 | [Game speed](032-game-speed/spec.md) | M5 | landed on dev, [#33](https://github.com/zakpruitt/colony/pull/33), provisional | 001, 008, 010, 011, 021 |
| 030 | [Help, tooltips and live health](030-help-and-hints/spec.md) | M5 | landed on dev, [#32](https://github.com/zakpruitt/colony/pull/32), provisional | 011, 017, 021, 026, 027 |
| 028 | [Seeing side quests and microskills](028-seeing-side-quests/spec.md) | M4 | landed on dev, [#31](https://github.com/zakpruitt/colony/pull/31), provisional | 008, 010, 011, 021, 025, 026, 027 |
| 031 | [The away report tells the whole story](031-away-report-knows-more/spec.md) | M5 | landed on dev, [#30](https://github.com/zakpruitt/colony/pull/30), provisional | 019, 020, 022, 025 |
| 029 | [Hero training](029-hero-training/spec.md) | M4 | landed on dev, [#29](https://github.com/zakpruitt/colony/pull/29), provisional | 014, 016, 022, 026 |
| 027 | [Reading the party](027-reading-the-party/spec.md) | M5 | landed on dev, [#28](https://github.com/zakpruitt/colony/pull/28), provisional | 008, 010, 011, 020 |
| 025 | [Microskills and side quests](025-microskills-and-side-quests/spec.md) | M4 | landed on dev, [#27](https://github.com/zakpruitt/colony/pull/27), provisional | 005, 020, 023 |
| 026 | [The hero sheet](026-hero-sheet/spec.md) | M4 | landed on dev, [#26](https://github.com/zakpruitt/colony/pull/26), provisional | 011, 016, 017 |
| 002 | [Art foundation](002-art-foundation/spec.md) | M0 | landed on dev, [#4](https://github.com/zakpruitt/colony/pull/4), provisional | — |
| 024 | [Guardian fights](024-guardian-fights/spec.md) | M5 | landed on dev, [#24](https://github.com/zakpruitt/colony/pull/24), provisional | 010, 011, 020, 021 |
| 023 | [Steady monster ids](023-steady-monster-ids/spec.md) | M3 | landed on dev, [#25](https://github.com/zakpruitt/colony/pull/25), provisional | 005, 008, 020 |
| 022 | [Auto-buy](022-auto-buy/spec.md) | M3 | landed on dev, [#23](https://github.com/zakpruitt/colony/pull/23), provisional | 016, 017, 019 |
| 021 | [Sound effects](021-sound-effects/spec.md) | M5 | landed on dev, [#22](https://github.com/zakpruitt/colony/pull/22), provisional; not yet heard by anyone | 008, 010 |
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

### In progress (2026-11-18)

Zak asked for more movement in fights (heroes that leap, spin and cast, and spells you can see) and for a
UI overhaul: a sharper UI layer, a font made for reading, and windows that open side by side as in WoW.
New rows go in this table.

| Spec | Status | Depends on |
|---|---|---|
| [061 The frame of the screen on the sharp layer](061-the-frame-of-the-screen/spec.md) | in progress, provisional | 011, 024, 027, 030, 032, 039, 049, 052, 056, 058 |
| [062 Goals, the stage list and the news on the sharp layer](062-goals-stages-and-news/spec.md) | written, waits for 061 to land, provisional | 019, 027, 031, 033, 037, 041, 042, 043, 047, 053, 058 |
