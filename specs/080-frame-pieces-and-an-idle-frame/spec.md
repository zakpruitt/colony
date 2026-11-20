# 080 — Frame pieces share a base type, and an idle frame does nothing

- **Status:** landed (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 075, 079
- **Pull request:** —

## Intent

A new piece of the screen's frame means four edits in `hud.gd` (make it, give it tips, place it, advance
it), and nothing says what a piece must be. The frame is also laid out afresh every frame, the goals are
rebuilt and re-worded every frame, and so is the status line. This spec gives the frame's pieces one base
type that `Hud` drives in a loop, and finishes spec 075's promise: with nothing changing, a frame of the
UI does no work. Nothing on screen changes.

## Requirements

- **R1. Nothing the player sees or does changes.** Existing tests pass, edited only to follow a moved name
  or a `_process` that became `advance` (list each). Shots of the main scene and showcase at both rooms
  match the baseline.
- **R2. A frame piece is a `FramePiece`.** The frame's seven panels (`PlacePanel`, `Countdown`, `Purse`,
  `BossBarView`, `Ticker`, `GoalsView`, `StageList`) extend `FramePiece`, which gives each `advance(delta)`,
  `catch_up()` (what it does after a stall: today's `snap` / `catch_up`, nothing for most) and
  `add_tips(tips)`. `Hud` holds them in one list and advances, catches up and tips them by walking it.
  `HeroFrameView` is not a panel and stays as it is.
- **R3. A new piece is two edits.** A piece added to the list (a test adds a plain one) is advanced every
  frame, caught up after a stall and asked for its tips, with no other change to `hud.gd` than where it is
  placed.
- **R4. The frame is laid out on a change.** `Hud` places its pieces when the room changes or a piece's
  size or visibility does, not every frame. Over 120 frames with the simulation stopped the layout runs
  no more than once; after the room changes, or the countdown hides, every piece is where it is today.
- **R5. Goals and the status line are worded on a change.** Over 120 frames with the simulation stopped,
  `Goals` builds no goal, emits `refreshed` at most once and asks `KeyBook` for nothing, and `Hud` words
  no status or countdown text. When gold, a level, a stage, the target, the orders or a hero's points
  change, the goals and the status line show it on the next frame as they do today.
- **R6. An open Talents tab is still.** With a hero window open on Talents and nothing changing, a frame
  formats no text and asks `can_take` of no node; after a point is spent or gained, the tree, the strip
  and the top line follow on the next frame.
- **R7. One owner advances.** `CrossingVeil`, `Milestones` and `UiMoment` have no `_process`: whoever makes
  them advances them, in the order they run today.
- **R8. Small leftovers.** `ShownValues.forget` (unused) is deleted; "Click for details" is written once;
  the three `_lower` helpers are one function on `UiFormat`; `Hud`'s key handling asks `KeyBook` for the
  keys it answers to, repeating no key code the table holds.

## Interfaces

```gdscript
# game/ui/frame/frame_piece.gd
class_name FramePiece
extends Panel
## Moves the piece on by delta seconds. Called every frame; does work only when what it shows changed.
func advance(delta: float) -> void
## Shows the present at once, after a stall or a fast-forward.
func catch_up() -> void
## Gives the piece the frame's tooltip for its controls.
func add_tips(tips: UiTip) -> void
```

What each piece needs is still handed to it in its own `setup`; `FramePiece` holds no simulation. Report
the final list of pieces and the seam the tests count through.

## Acceptance

In `tests/acceptance/test_080_frame_pieces.gd` (extends `ColonyTest`), both rooms:

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_every_piece_is_where_it_was` | each piece's rect at both rooms, at rest and with the countdown hidden and a guardian's bar up, equals the rects recorded in the test from unchanged code (written first, seen to pass) |
| R2, R3 | `test_r3_a_new_piece_is_driven_like_the_rest` | a plain `FramePiece` added to the list counts its `advance`, `catch_up` and `add_tips` calls: one a frame, one after a stall, one at setup |
| R4 | `test_r4_an_idle_frame_is_not_laid_out` | the layout count over 120 stopped frames is at most 1; it rises once when the room changes |
| R5 | `test_r5_idle_goals_build_nothing` | over 120 stopped frames: no goal built, `refreshed` at most once, no status text worded |
| R5 | `test_r5_a_change_shows_on_the_next_frame` | gold, a level, the stage, the target, auto on and off, and a talent point each change the goals or the status line one frame later, with the texts written in the test (written first, seen to pass) |
| R6 | `test_r6_an_open_talents_tab_is_still` | the `can_take` and format counts stay still over 120 frames; spending a point moves them once and the tree shows it |
| R7 | `test_r7_one_owner_advances` | reads `game/hud/` and `game/ui/`; the three classes have no `_process`, and a crossing, a milestone and a moment still play through `Main` |
| R8 | `test_r8_small_leftovers` | one `_lower` in `game/`, one "Click for details" literal, no `forget` on `ShownValues` |

**To look at:** main scene at 10 s and 120 s, a guardian fight, a crossing between areas and an open
Talents tab, at both rooms, beside the baseline.

## Out of scope

- Moving the shop, map or tally out of `Hud`; changing how anything looks or is laid out; named colour
  roles. `HeroFrameView`'s base type. `AwayWindow`. Anything under `sim/`, `game/effects/` or `game/world/`.

## Paths

- `game/hud/`, `game/ui/`, `game/main.gd` (advancing what lost its `_process` only)
- `tests/` (R1's edits; `test_080_…` new)
- `docs/standards.md` (a row for a frame piece), `docs/architecture.md` (its small-HUD section)

## Open questions

