# Specs

Colony is built from specs. A spec says what a piece of the game must do and how we will know it does; an
implementer lane builds exactly that.

## Board

| # | Spec | Milestone | Status | Depends on |
|---|---|---|---|---|
| — | Harness bootstrap (not a spec: built by the lead), [#1](https://github.com/zakpruitt/colony/pull/1) | M0 | landed | — |
| 071 | [A shared test base](071-shared-test-base/spec.md) | M8 | landed on dev, [#71](https://github.com/zakpruitt/colony/pull/71) | — |
| 069 | [Sim tidy](069-sim-tidy/spec.md) | M8 | landed on dev, [#72](https://github.com/zakpruitt/colony/pull/72) | — |
| 070 | [Game tidy](070-game-tidy/spec.md) | M8 | landed on dev, [#70](https://github.com/zakpruitt/colony/pull/70) | — |
| 068 | [A button bar that says what it opens](068-a-button-bar-that-says-what-it-opens/spec.md) | M7 | landed on dev, [#69](https://github.com/zakpruitt/colony/pull/69), provisional | 058, 059, 062 |
| 066 | [The run's milestones, announced](066-milestones-announced/spec.md) | M7 | landed on dev, [#68](https://github.com/zakpruitt/colony/pull/68), provisional | 019, 049, 061, 062, 063 |
| 067 | [Opens at a size you can read](067-opens-at-a-size-you-can-read/spec.md) | M7 | landed on dev, [#67](https://github.com/zakpruitt/colony/pull/67), provisional | 030, 058 |
| 064 | [The talent tree as a tree, with paragon and skills](064-the-talent-tree-as-a-tree/spec.md) | M7 | landed on dev, [#66](https://github.com/zakpruitt/colony/pull/66), provisional | 028, 051, 055, 060, 063 |
| 065 | [Camp upgrades you can see](065-camp-upgrades-you-can-see/spec.md) | M7 | landed on dev, [#65](https://github.com/zakpruitt/colony/pull/65), provisional | 017, 045, 052, 059, 063 |
| 063 | [A picture for everything you gain, and the moment you gain it](063-pictures-and-the-moment/spec.md) | M7 | landed on dev, [#64](https://github.com/zakpruitt/colony/pull/64), provisional | 017, 028, 051, 055, 058, 059, 060, 062 |
| 062 | [Goals, the stage list and the news on the sharp layer](062-goals-stages-and-news/spec.md) | M7 | landed on dev, [#63](https://github.com/zakpruitt/colony/pull/63), provisional | 019, 027, 031, 033, 037, 041, 042, 043, 047, 053, 058 |
| 061 | [The frame of the screen on the sharp layer](061-the-frame-of-the-screen/spec.md) | M7 | landed on dev, [#62](https://github.com/zakpruitt/colony/pull/62), provisional | 011, 024, 027, 030, 032, 039, 049, 052, 056, 058 |
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

### The cleanup (2026-11-19 on)

Zak asked for a cleanup: a codebase that is clean, idiomatic and easy to extend. It runs in rounds of
"no behaviour change" specs: tidy (069 to 071), then structure (072, 074 to 076), then a fresh survey.
State hashes and old saves stay as they are throughout. New rows go in this table.
On 2026-11-20 Zak asked for standards to extend from (`docs/standards.md`) and left the choice of work to
the lead: 077 on are provisional, land on `dev` only, and wait for his playtest like the rest.

| Spec | Status | Depends on |
|---|---|---|
| 072 | [One content table, and less work per tick](072-content-registry-and-sim-hot-paths/spec.md): landed on dev, [#74](https://github.com/zakpruitt/colony/pull/74) | 069 |
| 074 | [One list of windows, one list of keys](074-one-list-of-windows-and-keys/spec.md): landed on dev, [#73](https://github.com/zakpruitt/colony/pull/73) | 070, 071 |
| 076 | [One pool for effects, one gate for old events](076-one-pool-for-effects/spec.md): landed on dev, [#75](https://github.com/zakpruitt/colony/pull/75) | 070, 071 |
| 075 | [A smaller Hud that works only when something changed](075-a-smaller-hud/spec.md): landed on dev, [#76](https://github.com/zakpruitt/colony/pull/76) | 074, 076 |
| 077 | [A faster check that holds the standards](077-a-faster-check/spec.md): landed on dev, [#77](https://github.com/zakpruitt/colony/pull/77), provisional | 071 |
| 078 | [A base type for content, a cheaper fight tick, and room in Expedition](078-sim-base-types-and-headroom/spec.md): landed on dev, [#79](https://github.com/zakpruitt/colony/pull/79), provisional | 072 |
| 079 | [One base type for effect nodes, and room in the two biggest game files](079-effect-nodes-and-room-in-big-files/spec.md): landed on dev, [#78](https://github.com/zakpruitt/colony/pull/78), provisional | 076 |
| 080 | [Frame pieces share a base type, and an idle frame does nothing](080-frame-pieces-and-an-idle-frame/spec.md): landed on dev, [#80](https://github.com/zakpruitt/colony/pull/80), provisional | 075, 079 |
| 081 | [Shared test fixtures, and a check that keeps helpers shared](081-shared-test-fixtures/spec.md): landed on dev, [#81](https://github.com/zakpruitt/colony/pull/81), provisional | 071, 077, 080 |
| 082 | [Text rules live in the harness; proofs that a refactor happened go](082-text-rules-in-the-harness/spec.md): landed on dev, [#82](https://github.com/zakpruitt/colony/pull/82), provisional | 081 |
| 083 | [Simulation tests that each prove something](083-sim-tests-that-prove-something/spec.md): landed on dev, [#84](https://github.com/zakpruitt/colony/pull/84), provisional | 081 |
| 084 | [The hero window and the talent tree, tested once](084-hero-window-tests-once/spec.md): landed on dev, [#83](https://github.com/zakpruitt/colony/pull/83), provisional | 081 |
| 085 | [The shop, the map, the tally and the bar, tested once](085-window-tests-once/spec.md): landed on dev, [#85](https://github.com/zakpruitt/colony/pull/85), provisional | 081 |
| 086 | [The frame of the screen, tested once and on the screen the game shows](086-frame-tests-once/spec.md): landed on dev, [#86](https://github.com/zakpruitt/colony/pull/86), provisional | 081 |
| 087 | [World, effects and time-away tests that hold](087-world-tests-that-hold/spec.md): landed on dev, [#87](https://github.com/zakpruitt/colony/pull/87), provisional | 081 |

On 2026-11-20 Zak asked for the tests to be cleaned up ("clear and purposeful, very intentional"; he
suspected broken and unneeded tests). Every test was read and given a verdict; 082 to 087 remove what the
audit could show is a duplicate, stale, unable to fail or a proof that a refactor happened, and fix the
tests that hide a failure. They cut no test whose worth is a judgement (balance runs, recorded baselines,
the un-zoned labyrinth view): those wait for Zak.

### The dungeon overhaul (2026-11-21 on)

Zak asked for stages that are more interesting to look at, about twice as long and mysterious to explore,
with chances for the party to leave the main way: side paths a microskill opens, leading to a cache. He
chose: winding caves (a stage two or three floors tall, ladders, a route that doubles back, side paths off
it; fights stay on a flat room floor); the party takes every side path it can open, with an order to press
on instead; a cache pays what exists already (the area's resource, gold, XP); the safe timers stay. The
lead's decisions: the work lands in steps that each leave `dev` playable, the new shape first behind a
switch the game does not use, then on screen, then switched on with the flat generator and the un-zoned
view removed. All are provisional, land on `dev` only, and wait for his playtest.

| Spec | Status | Depends on |
|---|---|---|
| 088 | [The party walks a course](088-the-party-walks-a-course/spec.md): landed on dev, [#88](https://github.com/zakpruitt/colony/pull/88), provisional | 078 |
| 089 | [Winding stages in the simulation](089-winding-stages-in-the-simulation/spec.md) (a second shape of level, used by nothing yet): landed on dev, [#89](https://github.com/zakpruitt/colony/pull/89), provisional | 088 |
| 090 | [A winding stage, drawn](090-a-winding-stage-drawn/spec.md) (rooms on their floors, ladders, doorways, light, the camera's limits, a preview scene): landed on dev, [#90](https://github.com/zakpruitt/colony/pull/90), provisional | 089 |
| 091 | [The party on a winding stage](091-the-party-on-a-winding-stage/spec.md) (monsters, props, the fallen and the crossing in their room; the camera follows up and down): landed on dev, [#91](https://github.com/zakpruitt/colony/pull/91), provisional | 090 |
| 092 | [The game plays winding stages](092-the-game-plays-winding-stages/spec.md) (new games, loaded saves and the showcase; tests that make their own flat simulation stay as they are): landed on dev, [#92](https://github.com/zakpruitt/colony/pull/92), provisional | 091 |
| 093 | [Side paths and caches](093-side-paths-and-caches/spec.md) (gates a microskill opens, caches that pay what exists): landed on dev, [#93](https://github.com/zakpruitt/colony/pull/93), provisional | 092 |
| 094 | [Gates and caches in the world](094-gates-and-caches-in-the-world/spec.md) (each gate closed and open, the opener at work, the cache's burst, a sealed gate's tip): landed on dev, [#95](https://github.com/zakpruitt/colony/pull/95), provisional | 093 |
| 095 | [Gates and caches in words](095-gates-and-caches-in-words/spec.md) (the journal, the tally, the away report, the goal a sealed gate gives): landed on dev, [#94](https://github.com/zakpruitt/colony/pull/94), provisional | 093 |
| 096 | [The order to press on](096-the-order-to-press-on/spec.md) (Explore or Press on, in the Orders window and the save): landed on dev, [#96](https://github.com/zakpruitt/colony/pull/96), provisional | 094, 095 |
| 097 | [Rooms dark until entered](097-rooms-dark-until-entered/spec.md) (torches out until the party walks in; rooms of more shapes are left for after the playtest): landed on dev, [#97](https://github.com/zakpruitt/colony/pull/97), provisional | 094 |
| 098 | The gate's tip on the UI layer (so a window over a gate hides it properly): to write | 096 |
| 099 | [The unseen stage is black](099-the-unseen-stage-is-black/spec.md) (unvisited rooms, their tunnels and the earth round them black; eyes and glints in it; a refilled room goes black again): landed on dev, [#99](https://github.com/zakpruitt/colony/pull/99), provisional | 097 |
| 100 | [Rooms shaped like caves](100-rooms-shaped-like-caves/spec.md) (uneven ceilings, leaning walls, each area cut its own way; drawing only, flat floors): landed on dev, [#98](https://github.com/zakpruitt/colony/pull/98), provisional | 094 |
| 101 | [What stands in a cave](101-what-stands-in-a-cave/spec.md) (stalagmites, columns, stalactites in groups, each area's own decoration from one table): landed on dev, [#100](https://github.com/zakpruitt/colony/pull/100), provisional | 100 |
| later | The old tests move to winding stages, and the flat generator and the un-zoned view go, in batches: to write | 096 |

A trial on 2026-11-22 with winding as the default everywhere failed 47 of 112 test scripts, so the switch
is made for the game alone first (092) and the tests follow as their own work.

### Feel (2026-11-23 on)

| Spec | Status | Depends on |
|---|---|---|
| 102 | [A camp when they rest, and a revival you can see](102-a-camp-when-they-rest/spec.md) (a fire and bedrolls, heroes sit facing the fire; a hero fallen in a won fight rises at camp; one light-and-sparks effect for every revival): landed on dev, [#102](https://github.com/zakpruitt/colony/pull/102), provisional | 012, 038, 048, 057, 076, 097 |
| 103 | [Quests](103-quests/spec.md) ("side quests" become quests in words, code and data; quests and gates are kinds of one `JobDef`; nothing the game does changes): approved | 025, 093 |
| 104 | [The skilled party works, and it takes time](104-the-skilled-party-works/spec.md) (quests take 10 to 15 s; every hero with the microskill works, each helper shortening it): approved | 103 |
| 105 | [Chat bubbles](105-chat-bubbles/spec.md) (a line over a character's head, sharp on the UI layer, following them; `World.say`): approved | 103 |
| 106 | [The quest's stage](106-the-quest-stage/spec.md) (the prop on the far side, every worker at it, the rest sit; props that open, light and walk off; three looks, a tint and dressing so each room differs): approved | 104, 105 |
| 107 | [The quest's story](107-the-quest-story/spec.md) (a pose for each job, lines as data said at each beat, the wanderer healed): approved | 104, 105, 106 |
