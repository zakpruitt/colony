# 038 — Rough edges on screen

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M5
- **Depends on:** 008, 010, 012, 020, 028
- **Pull request:** [#39](https://github.com/zakpruitt/colony/pull/39)

## Intent

Three things on screen have been reported as wrong by lane after lane and never fixed, because each was
outside the spec that noticed it. A wipe shows an empty chamber. Melee heroes stand inside a guardian's body.
Side quests waiting in the dark cannot be seen. None changes a rule; each breaks the picture at a moment the
player is watching closely. This spec fixes the three, in the world's drawing only.

## Requirements

Everything follows `docs/style-bible.md`; no new sprites.

- **R1. A wipe leaves the party where it fell.** When the party is wiped, each hero's sprite stays where
  it died, in its death pose, until the revival. Then the sprites appear at the place the simulation
  revives them, under the revival light, and stand up (the death pose played back, or the idle pose
  rising, the lane's choice). At no moment during a wipe is the screen without the party unless the camera
  has moved to where it will revive.
- **R2. The camera tells the story of a wipe.** After the wipe the camera holds on the fallen party for
  about 1.5 seconds, then travels to the place of revival in time to see the heroes stand, without a
  hard cut unless the distance is more than three screens.
- **R3. Melee heroes stand at a guardian, not in it.** In a fight with a guardian, no hero's sprite
  overlaps the guardian's body: melee heroes are drawn at its near edge, however the simulation's
  positions (measured to its middle) place them. Hits, damage numbers and effects still appear on the
  guardian. Fights with ordinary monsters look as they do today.
- **R4. Side quests can be seen in the dark.** A side quest's prop that is outside the party's light
  carries a small glint that pulses slowly, drawn above the darkness, so it reads as "something is there"
  from a distance. Within the party's light the glint is gone and the prop is lit as everything else is.
  A prop the party has passed and could not do keeps its glint.
- **R5. Nothing else moves.** The simulation, its events and its state hash are untouched; monsters'
  sprites, ordinary fights and the showcase's existing moments look as before.
- **R6. The showcase shows it.** The showcase's wipe moment shows the fallen party and the revival, and
  its guardian moment shows the heroes at the guardian's edge.

## Interfaces

No new public classes are required. If `World` gains a helper node for the glints or for the fallen party,
it is a child of `World` in its own file (`game/world/world.gd` and `game/effects/combat_effects.gd` are
both large; keep additions there to a few lines).

## Acceptance

In `tests/acceptance/test_038_rough_edges.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_wipe_leaves_the_party` | Hero sprites visible in the death pose at their places through the wipe; at the revival place and standing after it; at least one hero sprite or the camera's move on every frame |
| R2 | `test_r2_camera_tells_the_story` | The hold, the travel and its speed bound, the arrival before the heroes stand |
| R3 | `test_r3_heroes_at_the_guardian` | No overlap between each hero's sprite rectangle and the guardian's body rectangle through a guardian fight; effects positioned on the guardian; an ordinary fight's positions unchanged |
| R4 | `test_r4_side_quests_in_the_dark` | A glint on a prop outside the light, pulsing; none inside it; kept after a miss; gone when the quest is done |
| R5 | `test_r5_nothing_else_moves` | The state hash after ten minutes with and without a world watching; monster sprite positions in an ordinary fight equal to a recorded reference |
| R6 | `test_r6_showcase` | The two moments run without errors and show what R1 and R3 describe |

**To look at, and for Zak:** sequences (`--count`) of a wipe through to the revival, a guardian fight, and
a side quest waiting two chambers away in the dark. Crop and enlarge. Does the wipe read as a defeat and a
return, and can you see the quest from across the level? Describe the shots.

## As built (noted by the lead after review)

A hero who dies in an ordinary fight now lies on the field until the fight ends, where before it
collapsed and vanished. R1 asked this only for a wipe and R5 said ordinary fights look as before, so this
goes beyond the spec. It is left in place for Zak to judge.

## Out of scope

- Any change under `sim/`; hero or monster art; new sounds.
- Lighting changes beyond the glint.

## Paths

- `game/world/`, `game/effects/`, `game/ambience/` (only where the glint must draw above the darkness),
  `game/dev/showcase.gd`
- `tests/acceptance/test_038_rough_edges.gd`, `tests/unit/test_world*.gd`
- Existing world or showcase tests only where they assert that hero sprites are hidden during a wipe or
  count the world's children (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
