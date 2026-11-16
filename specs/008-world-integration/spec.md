# 008 — World integration: the party in the labyrinth, on screen

- **Status:** provisional
- **Milestone:** M2
- **Depends on:** 005, 006, 007
- **Pull request:** —

## Intent

Every piece exists separately: a simulation that plays the game, a view that draws the labyrinth, sprites
that animate. This spec joins them in the main scene, so that starting the game shows the party walking the
labyrinth, monsters waiting in chambers, and fights playing out, all driven by the simulation. It also gives
later specs (effects, HUD, ambience) one place to hear simulation events and find the sprite for an id.
After it, `godot --path .` is the game, without the juice. Read `docs/design/base-game.md`.

## Requirements

- **R1. The main scene is the world.** The main scene shows the labyrinth of the running simulation with the
  camera on the party. The clock readout stays, small, in a corner, on a UI layer above the world.
- **R2. Heroes are where the simulation says.** Each party hero has one `CharacterSprite`, placed at its
  `hero_position` (tiles x 16). Between ticks the sprite eases toward its simulation position, so walking
  looks smooth at any frame rate: while the party travels, a hero sprite moves a little on every rendered
  frame and is never more than one tile from its simulation position. A jump of more than 4 tiles in one tick
  (revival) is a snap, not a slide.
- **R3. Heroes act out the expedition.** Travelling: walk animation, facing the way the party faces. Climbing:
  walk animation on the shaft. Resting: idle. Fighting: idle between attacks, facing their target. Wiped:
  heroes stay down (hidden after their death animation) until the revival, then reappear idle.
- **R4. Monsters wait in their chambers.** For every level the labyrinth view has built, each populated
  chamber shows its waiting monsters (`monsters_in`) as idle sprites on the floor, facing the party's side.
  They appear when a level is built or a chamber refills, and are removed when the level is freed.
- **R5. Fights are acted out.** From simulation events: an attack starting plays the attacker's attack
  animation with the event's wind-up time (`amount`, in ticks), ranged if the attacker's range is over
  `Battle.MELEE_REACH`; a hit plays
  the target's hit reaction; a death plays the death animation and removes the sprite when it finishes. An attack whose target dies during its wind-up, and any attack or bolt still
  pending when the encounter ends, is cut short: the attacker returns to idle and the bolt is removed.
  During a fight every combatant's sprite follows its battle position with the same easing as R2 and faces
  its target.
- **R6. Projectiles are visible.** A projectile launch shows a small palette-coloured bolt travelling from the
  source to the target over the projectile's flight time, arriving as the hit lands. Heals use a different
  colour from attacks. (The effects spec will dress these up.)
- **R7. One place to listen.** `World` drains the simulation's events once per frame, after the frame's ticks,
  and emits each as `sim_event(event)`, in order. `World.character(id)` returns the sprite for a hero id or
  monster id (or null), and `World.feet_position(id)` its current pixel position. Nothing else calls
  `drain_events`.
- **R8. A stall does not break the picture.** When many ticks are stepped in one frame, the world still ends
  the frame showing the simulation's current state: no sprite remains for a monster that has died, heroes are
  at their current positions, and animations are only started for events from the last half second of game
  time (older events still update state and are still emitted).
- **R9. The camera keeps the party in view.** The camera follows the party, looking slightly ahead in the
  direction it faces, moves smoothly through a shaft descent, and snaps on revival. The labyrinth view's focus
  follows the party, so the levels around it are always built.
- **R10. Layers for later specs.** The scene has named places for what comes next: an effects layer above the
  characters in world space, and a HUD layer (a `CanvasLayer`) above everything, both reachable from `World`
  or `Main` by a typed property.

## Interfaces

```gdscript
# game/world/world.gd
class_name World
extends Node2D

## Every simulation event, once, in order, in the frame it happened.
signal sim_event(event: SimEvent)

## Set before entering the tree.
var simulation: Simulation

var labyrinth_view: LabyrinthView
var camera: WorldCamera
## World-space parent for effects, drawn above characters.
var effects_layer: Node2D

## The sprite of a hero (ids 1-4) or monster (ids from 100), or null.
func character(id: int) -> CharacterSprite
## Pixel position of that character's feet, or Vector2.ZERO if there is none.
func feet_position(id: int) -> Vector2
## Brings the picture up to date with the simulation. Called every frame after the driver; tests call it.
func sync(delta: float) -> void
```

```gdscript
# game/main.gd (additions)
var world: World
## Screen-space layer for the HUD, above the world.
var hud_layer: CanvasLayer
```

The driver steps the simulation; `World` only reads it. `World` must work when tests step the simulation
directly and then call `sync`.

## Acceptance

In `tests/acceptance/test_008_world_integration.gd`. Tests build `Main` or a `World` with a seeded simulation,
step the simulation directly, and call `sync`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_main_scene_shows_the_world` | Main has a World with a labyrinth view built around the party and a camera near it; the clock label is on the HUD layer |
| R2 | `test_r2_hero_sprites_follow_smoothly` | Four hero sprites exist; over 3 s of travel with 60 `sync` calls per second, each moves on every call and stays within one tile of its simulation position; a forced teleport snaps |
| R3 | `test_r3_heroes_act_out_the_state` | The animation and facing for travelling, climbing, resting and fighting; hidden after a wipe, back after revival |
| R4 | `test_r4_waiting_monsters_are_shown` | Populated chambers of built levels have one idle sprite per waiting monster, at its position; none for unbuilt levels; removed when freed |
| R5 | `test_r5_events_drive_fight_animation` | Injected ATTACK_STARTED, HIT and DIED events cause the attack (with the right wind-up and ranged flag), the hit reaction, and removal after death |
| R6 | `test_r6_projectiles_fly_and_arrive` | A launch creates a bolt that reaches the target's position at the flight time and is then freed; heal and attack colours differ |
| R7 | `test_r7_events_emitted_once_in_order` | Over a real fight, `sim_event` emits every event exactly once in simulation order; `character` and `feet_position` answer for heroes and monsters |
| R8 | `test_r8_stall_leaves_a_true_picture` | After stepping 20 s of ticks then one `sync`: no sprite for any dead monster, heroes within a tile of their positions, and no attack animation started for old events |
| R9 | `test_r9_camera_and_focus_follow_the_party` | Camera target leads the party in its facing direction; after a descent the focus depth is the party's depth; revival snaps |
| R10 | `test_r10_layers_exist` | `effects_layer` and `hud_layer` exist, typed, in the right draw order |

**To look at, and for Zak:** `python tools/dev.py shot --name=world --seconds=4 --count=8` (the main scene).
The shots must show the party walking in formation through a chamber or tunnel, monsters waiting ahead, and
at least one shot of a fight in progress with a hero mid-attack. If the first 32 seconds do not include a
fight, lengthen the run. Judge it honestly: is it readable what is happening? Describe the shots in your
report, including anything that looks wrong and is outside this spec to fix.

## Out of scope

- Damage numbers, particles, screen shake, hit pause, coins, death bursts (the effects spec).
- Health bars, party frames, counters, any controls (the HUD spec).
- Torches, lighting, props, dust (the ambience spec).
- Changing simulation rules, the labyrinth view's drawing, or the sprites' art or animation. If one of them
  makes a requirement impossible, report it.

## Paths

- `game/main.gd`, `game/main.tscn`
- `game/world/world.gd`, `game/world/world.tscn` (optional), `game/world/bolt.gd`
- `tests/acceptance/test_008_world_integration.gd`, `tests/unit/test_world*.gd`
- `tests/acceptance/test_001_sim_clock.gd` (only where the clock label's new place breaks an assertion)
- `docs/wiki/index.html`

## Open questions

None.
