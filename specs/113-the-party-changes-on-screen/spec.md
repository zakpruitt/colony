# 113 — The party changes on screen

- **Status:** landed (approved 2026-11-27)
- **Milestone:** M9
- **Depends on:** 102, 105, 112 (and 111, whose Paths hold `hero_windows.gd`, `hero_window.gd` and
  `journal.gd`)
- **Pull request:** [#115](https://github.com/zakpruitt/colony/pull/115)

## Intent

After spec 112 the four going down can change, but every view was built once for the party a game
started with: the hero frames, the hero windows, the tally's rows. This spec makes everything on
screen follow a change of party, and shows the change as a small moment in the world: the hero who
leaves fades away, the one who comes in fades in at its place and says a line. It also lets a benched
hero's window be opened, and draws a class that has no pictures of its own with the class it looks
like. Spec 114 adds the window where the player recruits and chooses; until then a swap comes only
from a command, as the tests make it.

## Requirements

- **R1. The world follows a swap.** For a recent `HERO_FIELDED` heard while not catching up
  (`World.may_animate`):
  - the leaving hero's sprite fades out over 0.4 s with a puff (`FxParticle.Shape.PUFF`, in
    `World.fx`) and is then removed;
  - the incoming hero's sprite appears at its place in the line, fades in over 0.4 s with a puff,
    and says one line over its head (`World.say`), picked from four in a table:
    `Reporting in!`, `My turn.`, `Point me at them.`, `Fresh boots, ready.`;
  - if the party is resting, the incoming hero sits at the fire with the others (spec 102), and the
    leaving one's place by the fire is not left empty.
  - For a stale one, or one heard while catching up, the sprites change at once, with no fade, puff
    or line. Either way, no sprite is left for a hero who is not going down.
- **R2. The hero frames follow.** Within the frame a swap is heard in, the four frames show the four
  going down in formation order: picture, class, level, health, statuses and tooltip. A click on a
  frame opens the window of the hero now in it.
- **R3. The hero windows follow.**
  - Each window `hero_<place>` shows the hero now at that place. A window open at the swap stays
    open, where it was, showing the incoming hero on the tab it had open.
  - `Tab` cycles through the four going down only.
  - A benched hero has one window, `hero_bench`, opened with `HeroWindows.open_hero(hero_id)`. It
    shows the benched hero asked for last, and is a hero window in every way (it moves, layers,
    closes on `Esc` and is remembered). Its header says `At Camp` where a hero going down says what
    it is doing, and its health is full.
  - Its Talents tab works: a click on a node that can be taken takes it, and the paragon keys spend
    its points, through the commands spec 112 R5 allows.
  - `open_hero` for a hero going down opens its place's window.
  - If the benched hero shown goes down, the bench window closes and its place's window shows it.
- **R4. The tally follows.** The tally's rows are the four going down. Counts stay by hero for the
  session: a hero who leaves keeps its session counts and shows them again if it comes back. An
  incoming hero starts the current fight at 0.
- **R5. The journal says it.**
  - `ARTIFACT_FOUND`: `Found a Ranger's Whistle: a Ranger waits at Camp` (the class's
    `artifact_name` and name).
  - `HERO_RECRUITED`: `The Ranger joins the colony`.
  - `HERO_FIELDED`: `The Ranger goes down in the Knight's place`.
  - All three are in the ticker as other lines are.
- **R6. A class drawn as the class it looks like.** A hero whose class has a `looks_like`
  (`HeroClassDef.look()`) is drawn with that class's sheet in the world, and its picture in the
  frame, the hero window and the tally. Its name is always its own class's name.
- **R7. True in a crowded frame.** After a frame of 300 ticks holding a swap, a level-up and a won
  fight, the frames, every open hero window and the tally show the end state, and no sprite or
  frame is left for the hero who left.

## Interfaces

```gdscript
# game/ui/windows/hero_windows.gd
const BENCH_ID: StringName = &"hero_bench"
## Opens hero [param hero_id]'s window and brings it to the front: its place's window when it is
## going down, else the bench window showing it. Does nothing for an id not in the colony.
func open_hero(hero_id: int) -> void
```

`Hud` is at its cap of 15 public methods (`CAPS` in `tools/dev.py`) and gains none: the frames
follow through what it does privately when it hears `HERO_FIELDED`. `world.gd` is 882 lines: the
fades and the line go in a new listener, `game/world/roster_arrivals.gd`, which connects its own
`_on_sim_event` to `World.sim_event`, as `CLAUDE.md` asks of a view.

## Acceptance

In `tests/acceptance/test_113_the_party_changes_on_screen.gd`, one test per requirement named
`test_rN_…`, each written before its code and seen to fail. The swaps are made with
`ColonyTest.add_recruit_class()` (spec 112) and `simulation.roster`, through `make_main()` and the
real frame.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_the_world_follows_a_swap` | A recent swap fades one out and one in, with two puffs and a line from the table; at rest, the incoming hero is at the fire; a stale one changes the sprites at once with nothing else. No sprite for the benched hero |
| R2 | `test_r2_the_frames_follow` | The frames' classes and levels in formation order after a swap; a click on the changed frame opens the incoming hero's window |
| R3 | `test_r3_the_windows_follow` | An open window keeps its place and tab and shows the new hero; Tab skips the bench; `open_hero` on a benched hero opens `hero_bench` with `At Camp`; a click takes a node for it and the simulation has it; the bench window closes when its hero goes down |
| R4 | `test_r4_the_tally_follows` | Rows after a swap, session counts kept and shown again on return, the fight starting at 0 |
| R5 | `test_r5_the_journal_says_it` | The three lines, with the artifact's and the class's names |
| R6 | `test_r6_drawn_as_it_looks` | The added class (it looks like the Knight) has the Knight's sheet and picture everywhere, under its own name |
| R7 | `test_r7_true_in_a_crowded_frame` | The 300-tick frame |

**To look at, and for Zak:** three frames of a swap made at camp, at 1280x720
and `--ui-room=960x540` (a throwaway scene under `.shots/` that adds a class, recruits and swaps);
the bench window beside a hero window. Describe each shot.

## Out of scope

- The window to recruit and choose (spec 114). New keys.
- A walk in from off screen, a new effect or sound for the swap, a portrait for a class without one
  beyond R6.
- Hero names. A banner for a find (spec 114).

## Paths

- `game/world/roster_arrivals.gd` (new, with its `.uid`), `game/world/world.gd` (dropping the sprite
  of a hero not going down, the sheet by `look()`, and making the listener), `game/world/camp_view.gd`
  (only if the fire does not follow by itself)
- `game/hud/hud.gd`, `game/ui/frame/hero_frame_view.gd`
- `game/ui/windows/hero_windows.gd`, `game/ui/windows/hero_window.gd`
- `game/hud/tally.gd`, `game/ui/windows/tally_window.gd`
- `game/hud/journal.gd`
- `tests/acceptance/test_113_the_party_changes_on_screen.gd` and its `.uid`; a test fixture under
  `tests/support/` if a second test needs a helper
- `docs/architecture.md` (views that follow the party), `docs/wiki/index.html` (only lines this makes
  false)

## Open questions

None.
