# 013 — Monsters of the deeper bands

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M2
- **Depends on:** 004, 005, 007
- **Pull request:** [#11](https://github.com/zakpruitt/colony/pull/11)

## Intent

The labyrinth changes look every five levels, but the same five monsters live all the way down, so going
deeper only makes numbers bigger. This spec gives each depth band its own inhabitants: eight new monsters,
as data and as sprites, so that reaching a new band means meeting something new. It adds no rules: every
monster uses the fighting rules that exist. Read `docs/design/base-game.md` and `docs/style-bible.md`, and
look at the existing cast (`python tools/dev.py shot --scene=res://game/entities/character_demo.tscn`).

## Requirements

- **R1. Eight new monsters exist as data,** each a valid `MonsterDef` under `data/monsters/`:

  | Id | From depth | Band | Size | Character |
  |---|---|---|---|---|
  | `goblin` | 4 | loam | small | Quick melee skirmisher with a crude blade; a step up from the skeleton |
  | `mud_golem` | 6 | clay | large | Slow wall of health and armour; hits rarely but hard |
  | `fire_imp` | 7 | clay | small | Ranged: throws fire from a distance; fragile and fast |
  | `clay_hound` | 8 | clay | small | Very fast melee biter with some crit |
  | `ghoul` | 11 | stone | small | Tough melee brawler |
  | `crystal_beetle` | 12 | stone | small | Heavily armoured, low damage: takes a long time to crack |
  | `wraith` | 13 | stone | small | Ranged, hard-hitting, low health |
  | `deep_horror` | 16 | deep | large | The first thing of the deep: huge health, heavy hits, some crit |

  XP and gold grow with the depth a monster first appears at, so deeper kills are worth clearly more.
- **R2. Each has a sprite in the family.** A baked, lint-clean sheet per monster under
  `assets/sprites/monsters/`, in the right size category, facing right, with parts that suit it (humanoids:
  `body`, `head`, `arm`, `weapon`; others as fits) and part pivots where parts turn. Each is recognisable at
  1x, distinct in silhouette and main colour from the other twelve monsters and from the heroes, and its
  colours suit its band (clay monsters warm, stone monsters cold, the deep horror teal and strange).
- **R3. They animate.** `CharacterSprite.for_monster(id)` builds each one, and it idles, walks, attacks (with
  the ranged pose for the two ranged monsters, `fire_imp` and `wraith`), flinches and dies without errors, ending at rest.
- **R4. They appear where they should.** In encounters at a monster's first depth and below, it turns up;
  above that depth, never. Because encounters favour deeper-dwelling monsters, each band is dominated by its
  own inhabitants: over many encounters at depths 8, 13 and 18, most monsters met are from that band or the
  one before it.
- **R5. The game still plays as designed.** Every existing test still passes without changing its numbers,
  including the expedition's one-hour statements. If the new monsters make one of those statements false,
  adjust the new monsters' numbers, not the test and not the old data. One existing test may change, in one
  way: `test_r5_encounter_composition` in the 005 tests compares every pair of monsters by how often they are
  met at depth 5, which cannot hold for a monster that does not live there yet. It may be narrowed to compare
  only monsters whose first depth is 5 or shallower. Its numbers stay as they are. Likewise an existing assertion that counts the whole cast (there are
  exactly five monsters, the demo shows nine characters) may be changed to allow the larger cast, as long as
  the test still checks the original five by name.
- **R6. The deep is survivable but hard.** A party of four level-12 heroes beats a typical stone-band
  encounter (three monsters at depth 12) more often than not but not always (between 50% and 95% over 200
  seeds), and a level-6 party loses the same fight at least 80% of the time.
- **R7. The cast demo shows them.** The character demo shows the new monsters alongside the old, still
  readable, with names.

## Interfaces

No new classes or fields. Data files follow the existing `.tres` monsters; sprites follow the existing `.px`
sheets and the `create-sprite` skill.

## Acceptance

In `tests/acceptance/test_013_deeper_monsters.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_eight_new_monsters_are_valid` | Each id loads, validates clean, with the depth and size above; XP and gold do not decrease as first depth increases across all thirteen monsters |
| R2, R3 | `test_r3_each_new_monster_builds_and_animates` | Each builds through `for_monster` in the right category and runs idle, walk, attack, hit, death without pushed errors, parts back at rest |
| R4 | `test_r4_bands_have_their_own_inhabitants` | Never above first depth; over many encounters at depths 8, 13 and 18, at least half the monsters are from that band or the one before |
| R5 | (the existing suite) | `python tools/dev.py check` passes with no existing test changed, apart from the changes R5 allows |
| R6 | `test_r6_stone_band_is_hard_but_fair` | The two win-rate statements |
| R7 | `test_r7_demo_shows_all_thirteen` | The demo lists all thirteen monsters and runs without errors |

**To look at, and for Zak:** `python tools/dev.py shot --scene=res://game/entities/character_demo.tscn
--name=cast --seconds=0.7 --count=10`. Judge the eight honestly next to the existing five: same family, each
distinct, each readable at real size. Iterate on the drawings until that is true and describe them in your
report.

## Out of scope

- New rules: abilities, status effects, bosses, flying, anything `Battle` or `Expedition` would need to change.
- Changing the existing heroes or the first five monsters, in data or art.
- Loot, drops other than the existing XP and gold numbers.

## Paths

- `data/monsters/` (new files only)
- `assets/sprites/monsters/` (new files only)
- `game/entities/character_demo.gd`, `game/entities/character_demo.tscn` (showing the larger cast)
- `tests/acceptance/test_013_deeper_monsters.gd`
- `tests/acceptance/test_005_expedition_loop.gd` (the one narrowing R5 allows, nothing else)
- `tests/acceptance/test_004_combat_core.gd` (a count of the whole cast only)
- `tests/acceptance/test_007_character_sprites.gd` (only if an assertion counts the demo's characters)
- `docs/style-bible.md` (the cast colour table), `docs/wiki/index.html`

## Open questions

None.
