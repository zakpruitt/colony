# 102 — A camp when they rest, and a revival you can see

- **Status:** landed (approved 2026-11-23)
- **Milestone:** M7
- **Depends on:** 012, 038, 048, 057, 076, 097
- **Pull request:** [#102](https://github.com/zakpruitt/colony/pull/102)

## Intent

When the party rests after a fight, it sets up a small camp where it stands. A fire is lit between the heroes,
a bedroll is laid at each end, and the heroes sit facing the fire until they are healed. Then they pack up and
walk on. A hero who died in a fight the party won no longer vanishes and pops back up standing: it lies where it
fell and gets up at the camp. Every revival (that one, a revive ability in a fight, and the party's revival
after a wipe) shows the same light and sparks, so a hero coming back always reads as a moment.

This is all view. The simulation, its events, its state hashes and saves stay as they are.

## Requirements

- **R1. A camp while resting.** Whenever `Expedition.state` is `RESTING`, the world shows a camp on the floor
  of the room the party rests in. The camp has three parts:
  - a lit campfire at the middle of the party's line, drawn from the `campfire` sheet's `logs` with its four
    `flame_N` frames cycling at `AmbienceLevel.FLAME_RATE`;
  - a bedroll at each end of the line, just past the outermost hero: the `bedroll` sheet's `red` at one end
    and `green` at the other.

  All three stand on the floor the heroes stand on and are drawn under the characters. In any other state there
  is no camp. The camp's nodes are made once and reused for every rest. Each frame the camp only moves and shows
  its pieces: it does not search the tree, measure text or read pixels.
- **R2. The heroes gather round the fire.** While the party rests, the heroes on the fire's left face right
  and those on its right face left. "Left" and "right" go by where the simulation has them; with an odd number
  of heroes, the middle one goes to the side away from the way ahead. Each hero's place moves from where the
  simulation has it just enough that no hero's feet are within `CAMP_CLEARANCE` (10) pixels of the fire's
  middle. No hero moves more than 12 pixels. A hero that has to move walks there. The camp stands on the
  floor of the hero at the front. A hero whose feet are not on that floor (the line bent up a ladder or round
  a turn) stays where the simulation has it, faces the fire, and does not sit. Heroes level in x go to a side
  by rank.
- **R3. They sit.** A hero standing at its camp place sits. The sitting pose is made from the hero's existing
  parts, with no new frames:
  - the body is lower, so the head part sits at least 3 pixels lower than standing;
  - the body is shorter;
  - the head is a little bowed;
  - the weapon is laid down toward the floor.

  The pose eases in over `SIT_TIME` (0.25 s) and out over the same when the hero gets up. A sitting hero still
  breathes, and its z's (spec 010) start above its sitting head. No hero sits in any other state.
- **R4. Set up and packed.**
  - **Setting up.** A `REST_STARTED` that `World.may_animate` allows sets the camp up over `CAMP_SETUP`
    (0.5 s): each bedroll unrolls from nothing to its full width; the fire's logs set down with a small puff of
    dust; then its flames catch.
  - **Already set up.** A rest the world first sees any other way shows the camp whole and the heroes already
    sitting, with no setting-up. That covers a stale event, `World.catching_up()`, and finding the party resting
    after time away (a save keeps no rest: a loaded game is travelling).
  - **Packing.** When the state leaves `RESTING`, the heroes get up and go on as they do today. The fire goes
    out in a puff of smoke, and the bedrolls roll up to nothing over `CAMP_PACK` (0.5 s). One second after the
    rest ends, nothing of the camp is shown.
  - **A short rest.** A rest shorter than `CAMP_SETUP` packs from wherever the setting-up had got to.
  - **Effects.** The puffs are passing effects in `World.fx` under its budget. The camp itself is not in
    `World.effects_layer` (it stays for the whole rest).
- **R5. The fire gives light.** While the camp's fire burns, `Ambience.lights()` holds one more light at the
  fire. It has the start room's campfire's radius, energy and flicker (`AmbienceLevel.CAMPFIRE_*`) and is tinted
  toward orange as that one is. It goes when the fire goes out.
- **R6. A hero who fell in a won fight gets up at the camp.**
  - **Lying.** When a fight the party wins ends with a hero dead, that hero stays lying on its back where it
    fell, shown, instead of finishing its collapse out of sight.
  - **Rising.** When the simulation has that hero alive again during the rest, it rises onto its feet where it
    lay. The rise is the one `FallenParty` plays for the revival, over `FallenParty.STAND_SECONDS`, with the
    revival effect (R7). Then it walks to its camp place and sits.
  - **Never popping in.** At no point is that hero hidden, or shown standing without having risen.
  - **Seen late.** If the world first sees the rest stale (R4), the hero is simply sitting at the camp.
- **R7. One revival effect.** Every revival shows the same effect at the reviving hero's feet:
  - a hero rising at the camp (R6);
  - a revive ability in a fight (`REVIVED`, at its target);
  - the party's revival after a wipe (`PARTY_REVIVED`, at each hero, as today).

  The effect is today's column of revival light (yellow outer column 16 wide, white core 8 wide, both
  `LoopBeats.LIGHT_HEIGHT` tall and lasting `LoopBeats.LIGHT_LIFE`), plus `REVIVAL_SPARKS` (12) sparks in
  green and white that rise from the hero's feet and fade. It starts only for an event `World.may_animate`
  allows, and goes in `World.fx`. The revive ability's own spell visual (spec 056) still plays as well.
- **R8. The showcase shows it.** The showcase's "RESTING" moment shows the camp set up, with the heroes
  sitting. A new moment, "A HERO FALLS AND RISES AT CAMP", comes right after it. In that moment a hero dies in a
  fight the party wins, lies there, and gets up at the camp with the revival effect.

Tunable constants, named in the code next to what they tune: `CAMP_CLEARANCE`, `SIT_TIME`, `CAMP_SETUP`,
`CAMP_PACK`, `REVIVAL_SPARKS`.

## Interfaces

```gdscript
class_name CampView
extends Node2D
## The party's camp while it rests: a child of [World], made once in its setup beside QuestProps.

const CAMP_CLEARANCE: float = 10.0
const CAMP_SETUP: float = 0.5
const CAMP_PACK: float = 0.5

func setup(world: World, simulation: Simulation) -> void
## Where hero [param id] stands this frame: its camp place while the party rests, [param goal] otherwise.
## World chains it as it chains QuestProps.goal_for.
func goal_for(id: int, goal: Vector2) -> Vector2
## The way hero [param id] faces while it rests (1 right, -1 left), or [param otherwise].
func facing_of(id: int, otherwise: int) -> int
## True while any part of the camp is shown (set up, burning or being packed).
func is_shown() -> bool
## Where the fire's middle is on the floor, in world pixels. Valid while is_shown().
func fire_feet() -> Vector2
## How far the camp is set up: 0 (nothing) to 1 (whole), rising while it sets up, falling while it packs.
func setup_share() -> float
func animate(delta: float) -> void
```

```gdscript
# World
var camp: CampView

# CharacterSprite
const SIT_TIME: float = 0.25
## True to sit (eased in over SIT_TIME), false to stand (eased out). World sets it.
var sitting: bool = false
## How far into the sitting pose it is, 0 standing to 1 sat.
func shown_sit() -> float

# Ambience
## Lights the camp's fire at [param at] (world pixels), or puts it out with [param lit] false.
func set_camp_light(at: Vector2, lit: bool) -> void

# LoopBeats
const REVIVAL_SPARKS: int = 12
## The revival effect (R7) at hero [param hero_id]'s feet.
func revival_effect(hero_id: int) -> void
```

## Acceptance

All tests go in `tests/acceptance/test_102_a_camp_when_they_rest.gd`, on `PlayFixture` (a real `World` stepping
a real simulation; the party is made to rest by lowering health after a fight, as test_008 does, or by
`Expedition._start_rest()`, as test_091 does).

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_a_camp_while_resting` | Before a rest there is no camp. During a rest, `camp.is_shown()` is true, the fire is between the first and last hero's x and on their floor's y, and both bedrolls are outside the outermost heroes. After the rest plus 1 s, none of it is shown. Across two rests, the camp's child nodes are the same instances. |
| R2 | `test_r2_heroes_face_the_fire` | After 1 s of rest, every hero's facing points toward `fire_feet()`. No hero's feet are within 10 px of it, and none is more than 12 px from `WorldPlaces.feet(hero_position)`. During travel after the rest, facing is the way ahead again. |
| R3 | `test_r3_they_sit` | After 1 s of rest, every hero has `shown_sit()` 1 and its head part's global y is at least 3 px lower than a standing hero's. Travelling or fighting: `shown_sit()` 0. Halfway through `SIT_TIME`, the share is between 0 and 1. |
| R4 | `test_r4_set_up_and_packed` | A fresh rest: `setup_share()` rises from 0 to 1 within `CAMP_SETUP` plus a frame. A rest seen while `catching_up()`, and a `Main` whose away replay ends with the party resting (a stamped save, `away_seconds_override`, the rest started near the replay's end so its `REST_STARTED` goes into the away report): 1 on the first frame, heroes sitting. A rest ended after 0.2 s packs from below 1. `effects_layer` holds nothing of the camp. |
| R5 | `test_r5_the_fire_gives_light` | `ambience.lights()` has one more light during the rest than before it, at the fire's place within a tile. One second after the rest, the count is back. |
| R6 | `test_r6_fallen_rise_at_camp` | A fight is won with one hero dead (its health set to 0 in the fight, the others winning). From the fight's end until the simulation has it alive, its sprite is visible, dead and turned onto its back. Then `fallen_party.is_standing(id)` is true. It is never hidden or upright-and-alive before that. It ends sitting at the camp. A failure case: the same with the rest seen stale shows it sitting at once, with no rise. |
| R7 | `test_r7_one_revival_effect` | For each of the three revivals: two `&"light"` columns and `REVIVAL_SPARKS` rising particles appear at the hero's feet. A `REVIVED` event `may_animate` refuses shows none. |
| R8 | `test_r8_showcase_moments` | `Showcase.ROWS` has the new row right after `&"resting"`. Run with `skip_to`, the moment ends seen: a hero rose with the camp up. |

Test_091's resting check (every hero faces left while resting) becomes R2's rule: every resting hero faces the
fire. That is the only change to that test.

**For Zak's playtest:**
- Does the sitting pose read as sitting for each class, or as squashed?
- Do the fire's light and the camp look cosy in each area's colours?
- Does a hero getting up at camp read as revived?
- Look at the shots at `--seconds` on the resting and new moments, at 1280x720 and `--ui-room=960x540`.

## Out of scope

- No new sprites, sounds, or `.sfx` recipes. The camp reuses `campfire` and `bedroll`. A crackle or a
  revival sound for single heroes is a later spec.
- No change in `sim/`: no new events or states, no different rest length or healing, and no change to state
  hashes or saves.
- Embers from the camp's fire. Cooking, tents, or anything the heroes do at camp beyond sitting.
- The rest that an area journey counts as (`JOURNEYING`, behind the crossing veil) gets no camp.
- A sleeping or lying-down pose.
- Changing the in-fight rise itself (`FallenParty.stand`), beyond adding R7's effect to it.

## Paths

- `game/world/camp_view.gd` (new) and its `.uid`
- `game/world/world.gd`
- `game/world/fallen_party.gd`
- `game/entities/character_sprite.gd`
- `game/effects/loop_beats.gd`
- `game/ambience/ambience.gd`
- `game/dev/showcase.gd`, `game/dev/showcase_moments.gd`
- `tests/acceptance/test_102_a_camp_when_they_rest.gd`
- `tests/acceptance/test_091_the_party_on_a_winding_stage.gd` (the resting facing check only)
- `tests/unit/test_world_fallen.gd` (`test_a_hero_fallen_in_a_won_fight_goes_when_it_ends` becomes R6's
  rule: the hero lies on, shown, while the party rests)
- `tests/support/play_fixture.gd` (a helper two tests share, if one is needed)
- `docs/architecture.md` (the World's children), `docs/wiki/index.html`

## Open questions

None.
