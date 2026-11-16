# 012 — Ambient life: light, detail and a world that is never still

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 008
- **Pull request:** —

## Intent

The labyrinth is drawn but empty: flat earth, bare chambers, even brightness everywhere. This spec makes it a
place. Chambers are lit by torches and fall into darkness between them, the earth is full of buried things,
chambers have furniture that says what kind they are, and something is always moving: flames, dust, drips,
small creatures. It changes no rules and decides nothing; everything is placed deterministically from the
labyrinth, so the same seed always looks the same. Read `docs/design/base-game.md` ("The picture", "Feel").

## Requirements

All colours come from the palette. Decoration never suggests something is walkable or blocked that is not.
Everything is placed from the labyrinth's seed and the tile position, so rebuilding a level gives the same
decoration in the same places.

- **R1. Darkness and light.** Underground is dark by default: chambers and tunnels are visibly dimmer away
  from light, and the party and monsters dim with them. Light comes in steps (bands of brightness), not a
  smooth gradient, so it stays pixel art. The surface above depth 1 is in daylight.
- **R2. Torches.** Every chamber has wall torches on its back wall, about one per 6 to 8 tiles of width and
  at least one, at a consistent height above the floor. Each torch has an animated flame (at least 3 frames
  or equivalent code-driven motion), casts a warm pool of light that flickers slightly, and gives off an
  occasional rising ember. Tunnels have none, so they are darker than chambers.
- **R3. The party carries light.** A small light follows the party, so heroes are never lost in the dark of a
  tunnel or shaft.
- **R4. Buried things.** The solid earth holds occasional detail visible in cross-section: stones, roots near
  the surface, bones and fossils, ore glints that suit the depth band. Roughly one detail per 30 to 60 buried
  tiles: enough that no screen of earth is empty, not so many that it is busy.
- **R5. Chambers show their kind.** A START chamber has a campfire and bedrolls. A DEN has bones, webs or nests
  and feels infested. A VAULT has a chest, coin piles and a visible gleam. PLAIN chambers have one to three
  modest props (stalactites, mushrooms, a broken crate, a puddle). Props stand on the floor or hang from the
  ceiling, never float, and never overlap the shaft or its ladder.
- **R6. Motion.** At any moment something in view is moving besides the characters: flames, dust motes
  drifting in torchlight, an occasional water drip from a ceiling with a small splash, and now and then a
  tiny critter (a beetle or a moth) crossing a floor or circling a torch. Critters are decoration: they are
  not monsters and nothing interacts with them.
- **R7. Depth has mood.** The ambient darkness and the tint of light shift with the depth bands of the
  labyrinth view: loam is warm, clay warmer, stone cold and darker, deep an eerie teal. Mushrooms or crystals
  that glow on their own appear from the stone band downward.
- **R8. It follows the view.** Decoration and lights exist only for levels the labyrinth view has built, and
  are freed with them. Walking the focus down 30 levels leaves no more decoration than five levels' worth and
  no orphan nodes.
- **R9. It is cheap.** With three levels built, the scene has at most 60 lights and 600 ambient particles, and
  the frame rate in the windowed game stays at 60 on this machine.
- **R10. A demo shows it.** `game/ambience/ambience_demo.tscn` travels the labyrinth like the labyrinth demo,
  with ambience on, visiting at least one chamber of each kind and one level from each depth band.

## Interfaces

The lead has already added the stub this spec fills in; `Main` creates it and calls `setup`.

```gdscript
# game/ambience/ambience.gd
class_name Ambience
extends Node2D

func setup(world: World) -> void
## Follows the labyrinth view's built levels and advances animation. Called every frame; tests call it.
func advance(delta: float) -> void
## Counts for tests and for R9.
func light_count() -> int
func particle_count() -> int
## The decoration placed in a chamber, as prop names, for tests.
func props_in(depth: int, chamber_index: int) -> PackedStringArray
```

How light is done is the lane's choice, within R1 and R9: Godot 2D lights with a `CanvasModulate`, a
light-map drawn at low resolution and quantised by a shader, or stepped overlay sprites are all acceptable.
Props, flames and critters are `.px` sources of category `fx`, `item` or `tile` under
`assets/sprites/ambience/`. To attach to levels as they are built and freed, the lane may add signals
`level_built(depth)` and `level_freed(depth)` to `LabyrinthView`.

## Acceptance

In `tests/acceptance/test_012_ambient_life.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_dark_with_stepped_light` | A point far from any light is darker than a point at a torch; brightness between takes a small number of distinct values; the surface is at full brightness |
| R2 | `test_r2_torches` | Torch count per chamber width, on the back wall at the set height, none in tunnels; flame animates; light strength varies over time; an ember appears within 10 s |
| R3 | `test_r3_party_light_follows` | A light sits at the party's position after it moves |
| R4 | `test_r4_buried_detail_density` | Detail count per buried tile within the stated range over 3 levels; all on buried tiles, none on edges or open space |
| R5 | `test_r5_chambers_show_their_kind` | `props_in` contains the required props per kind; props are on the floor or ceiling, inside the chamber, clear of the shaft |
| R6 | `test_r6_something_always_moves` | Over 20 s, dust exists near torches, at least one drip and one critter appear, and critters stay in open space |
| R7 | `test_r7_depth_mood` | Ambient darkness and light tint differ between the four bands; glowing props appear only from the stone band down |
| R8 | `test_r8_follows_the_view` | Same decoration after free and rebuild; after a 30-level walk, bounded node count and no orphans |
| R9 | `test_r9_budget` | Light and particle counts within budget with three levels built |
| R10 | `test_r10_demo_runs` | The demo runs 300 frames without errors |

**To look at, and for Zak:** `python tools/dev.py shot --scene=res://game/ambience/ambience_demo.tscn
--name=amb --seconds=3 --count=10`, and the main scene the same way. The test is whether a single screenshot
looks like a place you would want to watch: pools of torchlight, darkness between, things to notice in the
earth, each chamber kind recognisable. Compare against a shot of the labyrinth demo without ambience; the
difference must be large. If it looks flat, sparse or muddy, iterate. Check the party stays clearly visible in
a tunnel. Describe the shots in your report, and report the frame rate you measured.

## Out of scope

- Combat effects, coins, numbers (spec 010); the HUD (spec 011).
- Sound.
- Anything the simulation knows about: loot in the vault chest, resting at the campfire, critters as monsters.
- Changing the labyrinth view's tiles or the generator. If a tile needs changing to make lighting work,
  report it.

## Paths

- `game/ambience/`
- `assets/sprites/ambience/`
- `game/world/labyrinth_view.gd` (the two signals only)
- `tests/acceptance/test_012_ambient_life.gd`, `tests/unit/test_ambience*.gd`
- `docs/style-bible.md` (a light and decoration section), `docs/wiki/index.html`

## Open questions

None.
