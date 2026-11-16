# 007 — Character sprites and part-based animation

- **Status:** provisional
- **Milestone:** M2
- **Depends on:** 002, 004
- **Pull request:** —

## Intent

Heroes and monsters need bodies, and those bodies need to feel alive without frame-by-frame art. This spec
draws the four heroes and five monsters as part-based sprites and adds one node, `CharacterSprite`, that
animates any of them in code: breathing, walking, winding up and striking, flinching, dying. It is not yet
wired to the simulation; a demo scene shows every character doing everything, and the world-integration spec
will drive it from sim events. Read `docs/design/base-game.md` ("Feel") and `docs/style-bible.md`.

## Requirements

- **R1. Nine characters.** Baked, lint-clean sprite sheets exist for the heroes `knight`, `rogue`, `mage`,
  `cleric` (category `hero`, under `assets/sprites/heroes/`) and the monsters `slime`, `cave_bat`, `skeleton`,
  `spider` (category `monster_small`) and `ogre` (`monster_large`), under `assets/sprites/monsters/`, each
  named `<id>.px`. Each is recognisable as what it is at 1x, distinct in silhouette and main colour from the
  others, and drawn facing right. Humanoids (the heroes, skeleton, ogre) have the parts `body`, `head`, `arm`,
  `weapon`; other monsters have a `body` and whatever else suits them (for example `wing`, `legs`, `eyes`).
  The knight from spec 002 may be redrawn to match the set.
- **R2. Parts have their own pivots.** A part in a `.px` file may declare the pixel it turns around (for
  example the shoulder for an arm). The baker writes part pivots into the JSON, the lint rejects a pivot
  outside the canvas, and `PixelSheet` returns each part's pivot (the sprite's pivot when none is given).
  Existing files without part pivots still bake to the same PNG.
- **R3. A character is built from its sheet.** `CharacterSprite.create(sheet_path)` returns a node that shows
  all the sheet's parts composed as drawn, standing with the sprite's pivot at the node's position.
  `CharacterSprite.for_hero(id)` and `for_monster(id)` find the sheet by id.
- **R4. Idle is alive.** While idle, the character breathes: a slow, small bob or squash that never stops.
  Two characters created together do not breathe in step (their phase differs).
- **R5. Walking.** While walking, the character bobs faster with a slight lean in its walking direction, and
  swinging parts (arm, weapon, legs, wings) move.
- **R6. Facing.** `set_facing(-1)` mirrors the whole character to face left; `set_facing(1)` faces right. The
  pivot stays in place.
- **R7. Attacks have anticipation and release.** `play_attack(windup_seconds, ranged)` plays a wind-up that
  lasts the given time (drawing back, or raising the weapon for a ranged attack), then a fast strike past the
  rest pose, then settles back to idle. Characters with no arm or weapon lunge with their whole body. The
  signal `struck` fires at the moment of release.
- **R8. Hits are felt.** `play_hit()` flashes the whole character solid white for about 0.08 seconds, knocks
  it back a few pixels away from its facing and returns it, with a brief squash. It can interrupt any other
  animation, and the character recovers to what it was doing.
- **R9. Death.** `play_death()` plays a short collapse (under 0.4 seconds), then the character is hidden and
  the signal `died` fires. Further calls do nothing, until
  `revive()` brings the character back, visible and idle. `cancel_attack()` ends an attack that is still in its
  wind-up without the strike.
- **R10. Animation never drifts.** After any sequence of animations ends, every part is back at its rest
  position, rotation and scale exactly.
- **R11. A demo shows the cast.** `game/entities/character_demo.tscn` shows all nine characters on a mid-dark
  background with their names, heroes facing right and monsters facing left, cycling together through idle,
  walk, melee attack, ranged attack, hit, and death, then reappearing.

## Interfaces

Part pivot syntax in `.px` (optional, after the part name) and in the baked JSON:

```
[arm] pivot=12,14
```

```json
{"parts": ["body", "head", "arm", "weapon"], "part_pivots": {"arm": [12, 14]}}
```

```gdscript
# game/art/pixel_sheet.gd (addition)
func part_pivot(part_name: StringName) -> Vector2i

# game/entities/character_sprite.gd
class_name CharacterSprite
extends Node2D

signal struck
signal died

static func create(sheet_path: String) -> CharacterSprite
static func for_hero(class_id: StringName) -> CharacterSprite
static func for_monster(monster_id: StringName) -> CharacterSprite

func play_idle() -> void
func play_walk() -> void
func play_attack(windup_seconds: float, ranged: bool) -> void
func play_hit() -> void
func play_death() -> void
## Ends an attack that is still winding up, without emitting struck. Otherwise does nothing.
func cancel_attack() -> void
## After a death: visible, idle and alive again.
func revive() -> void
func set_facing(direction: int) -> void
## True from play_death() on.
func is_dead() -> bool
## Advances animation by this much time. Called from _process; tests call it directly.
func advance(delta: float) -> void
```

Animation is computed in `advance` from elapsed time (no wall clock, no `Tween` that tests cannot step), so
tests can drive it exactly. The white flash is a small canvas-item shader in `game/entities/`.

## Acceptance

In `tests/acceptance/test_007_character_sprites.gd`, plus Python tests for R2 in `tools/tests/`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_nine_sheets_exist_with_parts` | Each id loads through `for_hero`/`for_monster`, with the right category and the humanoid parts where required |
| R2 | `test_r2_part_pivots_bake_and_lint` (py), `test_r2_sheet_returns_part_pivots` | Pivot syntax bakes into JSON; out-of-canvas pivot is a lint failure; old files bake identically; `part_pivot` returns the declared or default pivot |
| R3 | `test_r3_composed_at_pivot` | Every part is present as a child, and the sprite pivot sits at the node's origin |
| R4 | `test_r4_idle_breathes_out_of_step` | Over 3 seconds of `advance`, a part's offset or scale varies and returns; two characters differ at the same instant |
| R5 | `test_r5_walk_is_livelier_than_idle` | Walk bob has a shorter period than idle and a swinging part rotates |
| R6 | `test_r6_facing_mirrors_in_place` | Facing left mirrors horizontally; node position unchanged |
| R7 | `test_r7_attack_has_windup_then_strike` | `struck` fires at `windup_seconds` (within one step), not before; the weapon or body passes the rest pose after it; a part-less monster lunges |
| R8 | `test_r8_hit_flashes_and_recoils` | Flash is on at once and off by 0.12 s; offset is away from facing and returns to zero; a hit mid-walk resumes walking |
| R9 | `test_r9_death_hides_and_signals_once` | `died` fires once within 0.4 s; hidden afterwards; a second call does nothing |
| R10 | `test_r10_parts_return_to_rest` | After attack, hit and walk-then-idle sequences, every part's transform equals its rest transform |
| R11 | `test_r11_demo_runs` | The demo runs 300 frames without errors |

**To look at, and for Zak:** `python tools/dev.py shot --scene=res://game/entities/character_demo.tscn
--name=cast --seconds=0.7 --count=10`. Every character must be recognisable and the set must look like one
game; the attack must show a visible wind-up and strike across frames; the flash must be visible in at least
one frame. Iterate on drawings and motion until that is true, and describe the shots in your report.

## Out of scope

- Reading simulation state or events; placing characters in the labyrinth (the world-integration spec).
- Particles, damage numbers, projectiles, screen shake, loot (the effects spec).
- Health bars and names over heads (the HUD spec).
- Frame-by-frame animation, new palette colours, bosses.

## Paths

- `assets/sprites/heroes/`, `assets/sprites/monsters/`
- `game/entities/`
- `game/art/pixel_sheet.gd`, `tools/art.py`, `tools/tests/` (part pivots only)
- `tests/acceptance/test_007_character_sprites.gd`, `tests/acceptance/test_002_art_foundation.gd` (only if
  the knight's redraw or the JSON addition breaks an assertion), `tests/unit/test_character_sprite*.gd`
- `docs/style-bible.md` (characters and part pivots), `.claude/skills/create-sprite/SKILL.md`,
  `docs/wiki/index.html`

## Open questions

None.
