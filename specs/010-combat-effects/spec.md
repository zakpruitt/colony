# 010 — Combat effects: making every hit felt

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 008, 009
- **Pull request:** —

## Intent

Colony is watched, not played, so watching has to feel good. This spec adds the layer of effects that turns
simulation events into impact: numbers, sparks, shake, a frame of freeze on a crit, monsters bursting, coins
bouncing out and flying to the purse, XP streaming to the heroes. It changes no rules and no sprites; it
listens to `World.sim_event` and draws on the effects layer. Read `docs/design/base-game.md` ("Feel"): that
section is the brief.

## Requirements

All colours come from `Palette`. Effects end by shrinking, blinking or flying away, never by fading opacity.
Effects are pixel-sized squares and small sprites on whole pixels, never smooth circles or blurred shapes.

- **R1. Damage numbers.** Every hit shows its amount as a number in the pixel font that pops up from the
  target's upper body, rises in a short arc and disappears within 0.8 seconds. Numbers on monsters are
  `white`; numbers on heroes are a red; a crit is larger, a gold colour, and has a `!`. Numbers from hits in
  quick succession on one target do not sit on top of each other.
- **R2. Heal numbers.** Every heal that restores at least 1 health shows `+N` in a green rising from the
  healed hero, with a few green sparkles around it. A heal of 0 shows nothing.
- **R3. Hit sparks.** Every hit throws 4 to 8 small sparks from the point of impact, away from the attacker,
  falling under gravity. A crit throws at least twice as many, and brighter.
- **R4. Crits and deaths have weight.** A crit shakes the camera lightly and freezes every character's
  animation for about 0.06 seconds. A hero's death shakes the camera harder. A normal hit does neither. The
  simulation is never slowed.
- **R5. Monsters burst.** When a monster dies it bursts into 10 to 20 particles in the colours of its own
  sprite, thrown outward and falling, plus a small pale puff that shrinks away.
- **R6. Gold is physical.** When gold is gained, coins (one per 5 gold, at least 1 and at most 12) fly out of
  the dead monster in arcs, bounce on the chamber floor, rest briefly, then fly to the gold target on screen.
  As each coin arrives, `coin_collected` is emitted with that coin's share, and the shares of one gain add up
  exactly to its amount.
- **R7. XP is visible.** When XP is gained, one or more small blue motes travel from the dead monster to the
  hero who gained it and vanish on arrival with a tiny flash.
- **R8. Level up is a moment.** A level up shows a rising burst of gold particles around the hero and the text
  `LEVEL UP` above them for about 1.2 seconds.
- **R9. Bolts have trails.** A projectile in flight leaves a short trail of shrinking squares in its own
  colour, and bursts into a small flash where it lands.
- **R10. The loop's beats are marked.** Resting shows a small `z` drifting up from each hero now and then
  until the rest ends. A wipe shows `WIPED` centred on screen for the revive delay. A revival shows a brief
  column of light on each hero. A new last stable depth shows `DEPTH n STABLE` centred for 2 seconds.
- **R11. Nothing piles up.** After a stall (many ticks in one frame) no more than 40 numbers and 300
  particles exist at once, events older than half a second of game time start no effects (their coins are
  credited at once through `coin_collected`), and every effect frees itself: after 5 quiet seconds the
  effects layer has no children left.
- **R12. Effects can be driven by tests.** Effects advance by an `advance(delta)` method, as characters do, so
  tests can step them exactly.

## Interfaces

The lead has already added the stub this spec fills in; `Main` creates it and calls `setup`.

```gdscript
# game/effects/combat_effects.gd
class_name CombatEffects
extends Node2D

## One coin of a gold gain has reached the gold target; amount is that coin's share.
signal coin_collected(amount: int)

## Where coins fly to, in screen pixels. The HUD sets it.
var gold_screen_target: Vector2 = Vector2(600, 12)

func setup(world: World, simulation: Simulation) -> void
func advance(delta: float) -> void
## Counts for tests and for R11.
func live_numbers() -> int
func live_particles() -> int
```

Freezing animation (R4) needs one hook on the world: `World.freeze(seconds)` makes `sync` skip advancing
character animation for that long. This lane adds it.

Sprites for coins, motes and sparks are `.px` sources of category `fx` under `assets/sprites/fx/`. The
monster's burst colours are read from its sheet's pixels.

## Acceptance

In `tests/acceptance/test_010_combat_effects.gd`. Tests build a `World` with a seeded simulation, feed events
through `World.sim_event`, and call `advance`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_damage_numbers` | A HIT creates a number with the amount at the target; colours for monster, hero and crit; crit is larger with `!`; gone by 0.8 s; two quick hits are offset |
| R2 | `test_r2_heal_numbers` | `+N` in green with sparkles; nothing for a heal of 0 |
| R3 | `test_r3_hit_sparks` | 4 to 8 sparks moving away from the attacker and downward over time; at least double on a crit |
| R4 | `test_r4_crit_and_death_weight` | Crit: camera shake and a freeze of about 0.06 s during which character animation does not advance but the simulation does; hero death: stronger shake; normal hit: neither |
| R5 | `test_r5_monster_burst` | 10 to 20 particles whose colours all occur in the monster's sheet, plus the puff |
| R6 | `test_r6_coins` | Coin count per amount (1, 5, 23, 500); coins reach the floor, then the target; `coin_collected` shares sum to the amount |
| R7 | `test_r7_xp_motes` | Motes travel from the monster to the right hero and are freed on arrival |
| R8 | `test_r8_level_up` | Particles and `LEVEL UP` text at the hero for about 1.2 s |
| R9 | `test_r9_bolt_trail_and_flash` | Trail pieces appear behind a moving bolt and shrink; a flash at the landing point |
| R10 | `test_r10_loop_beats` | `z` during rest only; `WIPED`; revival light; `DEPTH n STABLE` |
| R11 | `test_r11_nothing_piles_up` | After 500 injected hits in one frame: caps respected; old events start nothing but credit coins; after 5 s the layer is empty |
| R12 | `test_r12_advance_drives_everything` | With `_process` off, nothing moves until `advance` is called |

**To look at, and for Zak:** run the game long enough to catch fights:
`python tools/dev.py shot --name=fx --seconds=1.5 --count=20`, and more runs as needed. You must find and look
at shots that show: a damage number, a crit, sparks, a monster mid-burst, coins on the floor and coins in
flight, and a heal. Judge them against the "Feel" section honestly: does a hit look like it hurt? If an effect
is too small to notice at 640x360, make it bigger. Describe the shots in your report.

## Out of scope

- The HUD's gold counter and party frames (spec 011 listens to `coin_collected`).
- Torches, light, dust and props (spec 012).
- Sound.
- Changing sprites, the simulation, or what events exist. If an effect needs an event that does not exist,
  report it.

## Paths

- `game/effects/`
- `assets/sprites/fx/`
- `game/world/world.gd` (the `freeze` hook only)
- `tests/acceptance/test_010_combat_effects.gd`, `tests/unit/test_effects*.gd`
- `docs/style-bible.md` (an effects section), `docs/wiki/index.html`

## Open questions

None.
