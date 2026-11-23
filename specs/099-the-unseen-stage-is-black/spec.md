# 099 — The unseen stage is black

- **Status:** in-progress (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 097
- **Pull request:** —

## Intent

Spec 097 put out the torches of rooms the party has not entered, but the stage's ambient light still
shows every room's shape, its monsters and its chest: nothing is left to find. Zak asked (2026-11-22) for
a stage that is "enigmatic", with "mystery of where to go". This spec makes everything the party has not
seen black: rooms, the tunnels and ladders beyond them, and the earth round them. Only hints show in the
black: eyes where monsters wait, a glint where a cache or a side quest waits. A room is shown as the party
walks in, and goes black again when its monsters come back behind the party. It changes nothing the
simulation does.

## Requirements

- **R1. What the party has not seen is black.** On the stage shown, a place is *seen* if it is: a room
  that is lit (097: the party has entered it on this visit); a tunnel or ladder that touches a lit room,
  for its whole length; or earth within 3 tiles of any of those. Everything else on screen in the world
  (unlit rooms, the tunnels and ladders that touch none that is lit, the earth beyond, and whatever stands
  there: monsters, props, torches, gates, caches, the doorway on, the fallen) is drawn black, whatever the
  area's ambient light. The black's edge is soft: it fades over the outer 2 of those 3 tiles of earth,
  in the darkness's own steps. The party's own light is not cut by this: it shows what it reaches, as
  today. This is for the game's winding, zoned stages; a flat or un-zoned view is as it is.
- **R2. Eyes in the black.** Each monster waiting in an unseen room shows a pair of eyes over the black at
  its head, which blink (shut for about 0.15 seconds every 2 to 5 seconds, each pair in its own time). A
  guardian's are larger and of another colour of the palette. The eyes go as the room is shown, and are
  not drawn for a monster in a seen place.
- **R3. Glints in the black.** A full cache and a waiting side quest in an unseen room keep the glint
  they have today, over the black. Nothing else there shows: a closed gate, an unlit torch and the doorway
  on are black until their place is seen. The target arrow, the heroes' frames and everything on the UI
  layer are untouched.
- **R4. A room is shown as the party enters.** When the party's anchor first enters a room the black
  leaves it, the tunnels and ladders that touch it and the earth round it over about 0.4 seconds, while
  its torches catch as in 097. Arriving on a stage by any way shows only what R1 gives for the room the
  party stands in, at once.
- **R5. A room that refills goes black again.** A lit room the party is not in, whose monsters come back
  (the simulation refills it), is forgotten: its torches go out one after another about 0.15 seconds
  apart, the black closes over it in about 0.6 seconds, and from then it is as a room never entered (eyes,
  glints, lighting again when the party walks in). A tunnel or ladder stays seen while it touches a room
  that is still lit. The room the party stands in never goes black. Rooms that never hold monsters (where
  the party arrives, a cache room) stay seen once seen.
- **R6. The mouse finds nothing in the black.** The gate's tip does not show for a gate in an unseen
  place, nor does any other tip or tooltip the world gives for a thing there (the lane lists those it
  found and what each does now).
- **R7. Nothing plays for the past.** What is seen follows where the party is and what the rooms hold now,
  not events. After a stall: the room the party stands in is seen at once; rooms lit before the stall stay
  lit unless they have refilled, and those are black at once; nothing fades and no torch flares or gutters
  while `World.catching_up()`.
- **R8. It costs nothing when nothing changes.** In a frame in which nothing becomes seen or unseen and no
  fade is running, nothing is allocated for this and what tells the darkness which places are seen is not
  remade. Blinking eyes do not redraw the darkness.
- **R9. The showcase shows it.** `Showcase.ROWS` gains one moment: a room behind the party refilling and
  going black. The moment 097 added (a room lighting as the party walks in) shows the black leaving.
  Every other moment still reads: a moment that cuts the party into a room shows that room seen.
- **R10. It looks like a place being found.** The lane looks, at 1280x720 and `--ui-room=960x540`, in all
  four areas, at: a stage on arrival, a room being shown (`--count`), a stage half walked, a room going
  black behind the party, a guardian's eyes, a cache's glint in the black, and 3x crops of the black's
  edge and of a pair of eyes; and says what it saw, and whether the party's way on can still be guessed
  from the tunnels and ladders that lead off.

## Interfaces

None that other work relies on. What is seen is the view's own memory, beside 097's (`AmbienceRooms`),
cleared when the stage shown changes; nothing in `sim/` or the save knows of it. `Ambience.light_at` and
`brightness_at` answer for the black (0 in an unseen place), as the shader draws it. The eyes are one new
sheet, `assets/sprites/ambience/eyes.px`.

Spec 100 (rooms shaped like caves) is built at the same time and changes which tiles of a room's rectangle
are open: decide what is seen from the level's rectangles (`LabyrinthChamber.rect`, tunnels, ladders, side
paths), never from which tiles are open.

## Acceptance

In `tests/acceptance/test_099_the_unseen_stage_is_black.gd` (extends `ColonyTest`), on the game's winding
world:

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_only_what_is_seen_is_not_black` | on 3 stages on arrival: `brightness_at` is 0 at the middle of every unlit room, of every tunnel and ladder touching no lit room, and of earth 6 tiles from anything seen; above 0 in the party's room, along a tunnel leaving it and in earth 1 tile from it |
| R2 | `test_r2_waiting_monsters_show_eyes` | a pair of eyes at each waiting monster of an unseen room, a guardian's of the larger part; none for the party's room; a pair shuts and opens within 6 seconds |
| R3 | `test_r3_glints_show_and_nothing_else` | a full cache's and a side quest's glint drawn in an unseen room; `brightness_at` 0 at a closed gate and at the doorway on in unseen places |
| R4 | `test_r4_a_room_is_shown_as_the_party_enters` | walking into the next room: its middle, the tunnel beyond it and the earth 1 tile round it go from 0 to their rest within 0.5 s |
| R5 | `test_r5_a_refilled_room_goes_black` | a room cleared and left, then its refill tick passed: its torches go out in turn, its middle is 0 within 0.8 s, it shows eyes, and walking back in lights it again with a flare; the party's own room refilling under it does not go black; a cache room stays seen |
| R6 | `test_r6_no_tip_for_an_unseen_gate` | `GateTip` shown for a gate in a seen place, not for one in an unseen place |
| R7 | `test_r7_nothing_fades_for_the_past` | a stall in which a lit room refills and the party walks on: after it that room is black, the party's room seen, no fade or flare running |
| R8 | `test_r8_an_idle_frame_does_nothing` | over 60 idle frames with eyes blinking, the darkness is not redrawn and what it is told of seen places is the same object unchanged |
| R9 | (spec 018's test) | every showcase row plays, the new one among them |

R10 is the lane's report and Zak's playtest.

## Out of scope

- Anything in `sim/`: no room is hidden from the rules, the party walks and chooses as it does.
- Hiding anything on the UI layer (the stage list, goals that name a gate, the area map), a map of the
  stage, sounds.
- The shape of rooms and new decoration: specs 100 and 101.
- Retuning any area's ambient light or the torches' light in seen places.

## Paths

- `game/ambience/ambience.gd`, `ambience_rooms.gd`, `ambience_darkness.gd`, `ambience_mood.gd`,
  `ambience_light.gd`, the shaders in `game/ambience/`, and new scripts there
- `game/world/world.gd` (only what telling the ambience needs, and the eyes' layer), `game/world/gate_tip.gd`,
  `game/world/side_props.gd`, `game/world/quest_props.gd`, `game/world/prop_glints.gd`, new scripts in
  `game/world/`
- `game/dev/` (the showcase's row and moment)
- `assets/sprites/ambience/eyes.*` (new)
- `tests/acceptance/test_099_the_unseen_stage_is_black.gd` (new), `tests/colony_test.gd`, `tests/support/`
- `tests/acceptance/test_097_rooms_dark_until_entered.gd` (its R1 and R4 say a monster and the doorway are
  drawn in an unlit room: they follow this spec), and existing tests that fail only because an unseen
  place is now black, each repaired to prove what it proved, none removed, one line each in the report
- `docs/architecture.md`, `docs/wiki/index.html`, `CLAUDE.md` (the showcase's `--count`)

## Open questions

None.
