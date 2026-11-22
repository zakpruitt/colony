# 097 — Rooms dark until entered

- **Status:** in-progress (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 094
- **Pull request:** —

## Intent

A winding stage is lit from end to end the moment the party arrives: every torch burns, every monster on
every floor is plain to see, and nothing is left to find. This spec makes a stage dark until it is walked.
A room the party has not entered on this visit has its torches out; what waits there is a shape in the
gloom and a glint. As the party steps in, the room's torches catch one after another. It changes nothing
the simulation does: it is how the stage is shown.

## Requirements

- **R1. A room not yet entered is dark.** On the stage shown, the torches of a room the party has not
  entered on this visit are drawn unlit (the torch with no flame, no embers) and give no light; the room
  is lit only by the stage's ambient light and by the party's own light where it reaches. Monsters, props
  and the fallen there are drawn as they are, under that darkness. The room the party stands in is always
  lit. This holds for the rooms of the main route and for cache rooms; tunnels and ladders have no torches
  and are as they are.
- **R2. A room lights as the party enters.** When the party's anchor first enters a room, its torches
  light one after another, nearest the party first, about 0.15 seconds apart, each with a short flare (its
  light swells past its rest and settles in about 0.3 seconds). A glint is untouched by this: it goes out in the
  party's own light, as today, whatever the room's torches do.
- **R3. The stage is remembered while the party is on it.** A room entered stays lit until the party
  leaves the stage. Arriving on a stage by any way (a crossing on or back, a revival, a journey, a loaded
  game, a new game) shows it with only the room the party stands in lit, and that room is lit at once,
  with no flare.
- **R4. What matters still reads in the dark.** In an unlit room: a waiting monster can be made out
  against the back wall at the stage's ambient light in every area (the lane checks each area's look and
  says so); a waiting side quest and a full cache keep their glint; a closed gate can be made out; the
  doorway on is drawn as it is. The target arrow, the heroes' frames and everything on the UI layer are
  untouched.
- **R5. Nothing plays for the past.** The lighting follows where the party has been, not events: after a
  stall the rooms lit before it stay lit (a hitch does not darken a stage the party is still on), the room
  the party stands in now is lit at once, the rooms it passed through unseen during the stall stay dark,
  and no flare plays while `World.catching_up()`. A stall that ends on another stage is an arrival (R3).
- **R6. It costs nothing when nothing changes.** A frame in which no room lights and no flare is running
  allocates nothing for this and does not redraw the darkness for it; the lights handed to the darkness
  are those of the lit rooms only.
- **R7. The showcase shows it, and its moments still read.** `Showcase.ROWS` gains one moment, a room
  lighting as the party walks in. Every other moment is seen as it is today: a moment that cuts the party
  into a room shows that room lit.
- **R8. It looks like a place being found.** The lane looks, at 1280x720 and `--ui-room=960x540`, in two
  areas, at: a stage on arrival, a room lighting in sequence (`--count`), a stage half walked, a guardian's
  room before and after the party enters, a cache room entered, and 3x crops of an unlit torch and of a
  monster waiting in the dark; and says what it saw, and whether any area's dark hides too much.

## Interfaces

None that other work relies on. Which rooms are lit is the view's own memory (in `game/ambience/` or
`game/world/`), keyed by stage and room, cleared when the stage shown changes; nothing in `sim/` or the
save knows of it. The unlit torch is a part of the torch's own sheet (a new part in its `.px`, baked).

## Acceptance

In `tests/acceptance/test_097_rooms_dark_until_entered.gd` (extends `ColonyTest`), on the game's winding
world:

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_only_the_partys_room_is_lit_on_arrival` | on 3 stages: every torch of the party's room shows its flame and gives light; every other room's torches show the unlit part and none is among the lights handed to the darkness; a cache room's torch the same |
| R2 | `test_r2_a_room_lights_torch_by_torch` | walking into the next room: its torches light in order of distance from the party, each about 0.15 s after the one before, each light past its rest size and back |
| R3 | `test_r3_the_stage_is_remembered_until_left` | rooms walked stay lit through a fight and a walk back; after a crossing on and back the first stage shows only the party's room lit; the same after a revival, a journey and a load, with no flare |
| R4 | `test_r4_glints_and_gates_show_in_the_dark` | a side quest's and a full cache's glint in an unlit room; a closed gate's sprite shown; the doorway drawn |
| R5 | `test_r5_nothing_lights_for_the_past` | two rooms walked, then a stall in which the party walks three more: after it the first two and the one it stands in are lit, the two between are dark, and no flare is running; a stall that ends on another stage shows only the party's room |
| R6 | `test_r6_an_idle_frame_does_nothing` | over 60 idle frames the darkness is handed the same lights object unchanged and is not redrawn (its own redraw count) |
| R7 | (spec 018's test) | every showcase row plays, the new one among them |

R4's "can be made out" and R8 are the lane's report and Zak's playtest.

## Out of scope

- Anything in `sim/`: no room is hidden from the rules, the party walks as it does.
- Fog that hides the earth or the shape of unvisited rooms, a map of the stage, rooms of new shapes.
- New sounds. Retuning any area's ambient light beyond what R4 needs to make a monster out (say which).

## Paths

- `game/ambience/`, `game/world/world.gd` (only to tell the ambience the room the party is in and the
  stage shown), `game/dev/` (the showcase's row and moment)
- `assets/sprites/ambience/` (the torch's `.px` and its baked sheet)
- `tests/acceptance/test_097_rooms_dark_until_entered.gd` (new), `tests/colony_test.gd`, `tests/support/`
- Existing tests that fail only because a room the party has not entered is now dark, each repaired to
  prove what it proved (by walking the party into the room first, or by asserting of the lit room), none
  removed, one line each in the report
- `docs/architecture.md`, `docs/wiki/index.html`, `docs/style-bible.md` if it speaks of torches

## Open questions

None.
