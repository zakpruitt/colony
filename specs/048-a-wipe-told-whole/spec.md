# 048 — A wipe told whole: fixes from the review of the rough edges

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 038
- **Pull request:** —

## Intent

A reviewer read the wipe and guardian drawing change (spec 038, pull request 39) against its spec after it
had landed. The wipe's story (the fallen party, the camera's hold and travel, the heroes standing up) is
only told when the wipe is seen within half a second of happening. Return to the game while the party is
down, or have a hitch at the wrong moment, and the camera cuts and the heroes pop up standing. This spec
makes the sequence start from wherever the wipe has got to, closes the smaller gaps the review found, and
gives the view a public place to read where the party revives. It changes no rule.

## Requirements

- **R1. The sequence starts from where the wipe has got to.** Whenever the world finds the party down
  and waiting to revive, however it learned of the wipe (a live event, an old event after a stall, the
  first frame after time away), the heroes lie where they fell, the camera is on them or travelling as
  the time since the wipe says, and at the revival the heroes stand up. A hard cut happens only when the
  distance is more than three screens (spec 038 R2).
- **R2. A stall does not pull the camera back.** A frame that snaps the world's sprites during the wipe
  sequence leaves the camera where the sequence has it (on the fallen, travelling, or at the revival
  place), and the sequence's clock includes that frame's time.
- **R3. The camera arrives first at every speed.** At 1x, 2x and 4x, and when the wipe is first seen up
  to 2 game seconds late, the camera is at the revival place before the heroes appear there.
- **R4. A second wipe starts clean.** A wipe that arrives while the heroes are standing up leaves them
  lying on the floor, not floating above it.
- **R5. The revival place is the simulation's to tell.** `Expedition` says publicly where the party will
  arrive when it revives; the view reads that and no longer copies the rule. Reading it changes nothing
  (the state hash is unchanged) and the recorded-hash tests pass unchanged.
- **R6. A far cut waits for the moment.** When the revival is more than three screens away, the camera
  stays on the fallen party and cuts shortly before the heroes stand, instead of cutting early to an
  empty place.
- **R7. Tests that can fail.** The guardian-spacing test measures overlap from the sprites' pixels
  through the fight's poses (including the guardian's lunge), not from the helper that placed the
  heroes, and covers a guardian on each side of the party.

## Interfaces

```gdscript
# sim/expedition/expedition.gd gains (read-only; the rule already exists there as private code)
func revival_place() -> Vector2i        # depth and column the party arrives at when it revives
```

(Amended by the lead: as built this is `revival_place() -> Vector3`, column, depth and facing, since the
column can be a half tile, plus a read-only `revive_tick`, which R1 needs to know how long the party has
been down; the arrival rule lives in `sim/expedition/arrival.gd`. R7 also changed the spacing itself:
measured from drawn pixels the old spacing overlapped during lunges and swings, so melee heroes now stand
about a sword's reach from a guardian. That is for Zak to judge.)

The exact shape is the lane's choice if the existing private code suggests a better one. The file is near
gdlint's 1000 lines (998): make the existing private function public or move it to a helper beside it
rather than adding lines.

## Acceptance

In `tests/acceptance/test_048_a_wipe_told_whole.gd`, plus the amended 038 tests.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_starts_from_where_it_is` | A world made while the party is down (as after time away) and a wipe heard as an old event: heroes lying, the camera's place for that age, the travel without a cut, the stand-up |
| R2 | `test_r2_a_stall_keeps_the_camera` | A snapping frame during the hold, the travel and after arrival: the camera where the sequence has it |
| R3 | `test_r3_camera_arrives_first` | 1x, 2x and 4x, with the wipe first seen on time and 2 game seconds late |
| R4 | `test_r4_second_wipe_starts_clean` | A forced wipe during the stand-up: each hero's feet on the floor |
| R5 | `test_r5_revival_place` | The public value against where the simulation then revives the party, at several depths and seeds; the hash unchanged by reading |
| R6 | `test_r6_far_cut_waits` | A revival more than three screens away: the camera on the fallen until shortly before the stand-up |
| R7 | (`test_038`, `test_r3_heroes_at_the_guardian`) | Pixel overlap through the poses; a guardian on the left and on the right |

**To look at, and for Zak:** a sequence (`--count`) of a wipe the world first sees two seconds late, and
of a far cut. Crop and enlarge. Does it still read as a defeat and a return? Describe the shots.

## Out of scope

- Whether a hero who dies in an ordinary fight lies on the field until it ends (left as built; a
  question for Zak, recorded in spec 038).
- Any rule change; new sprites or sounds.

## Paths

- `game/world/`, `game/dev/showcase.gd` (only if a moment needs it)
- `sim/expedition/` (the public read for R5 only)
- `tests/acceptance/test_048_a_wipe_told_whole.gd`, `tests/acceptance/test_038_rough_edges.gd`,
  `tests/unit/test_world*.gd`
- `docs/architecture.md`, `docs/wiki/index.html` only if a sentence there becomes untrue

## Open questions

None.
