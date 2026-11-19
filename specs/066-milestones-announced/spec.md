# 066 — The run's milestones, announced

- **Status:** landed (provisional: not yet reviewed by Zak) (direction from Zak 2026-11-19; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 019, 049, 061, 062, 063
- **Pull request:** [#68](https://github.com/zakpruitt/colony/pull/68)

## Intent

Zak wants gains to "feel like bigger accomplishments". Spec 063 made the burst and the banner and specs
064 and 065 use them for talents and upgrades, but the biggest things a run does (beating a guardian,
opening an area, a hero's level, a new safe stage) still pass as a line in the ticker. This spec marks
them on the frame of the screen with the same two sizes of moment.

## Requirements

- **R1. A guardian beaten** gets a banner: the guardian's own sprite as the picture, `<Guardian> is
  beaten` as the headline (the sprite at a whole-number scale, never stretched unevenly) and what that gave under it (`New area: The Claypits` when it opened an area,
  else `<Area> <stage> is behind you`). One banner per guardian slain, not two when an area opens with it.
- **R2. An area opened** without a guardian's banner to carry it (if the simulation ever reports one so)
  gets its own banner with the area's resource icon and `New area: <Area>` over `It gives <resource>`.
- **R3. A level** bursts the hero's frame (spec 063 R4) and its level number steps up in yellow for
  0.6 s. No banner: four heroes level too often.
- **R4. A talent point gained** makes the hero frame's point tag pulse three times, so the player sees
  which hero has something to spend.
- **R5. A new safe stage** bursts the place panel's `Safe N` and the number steps up; a stage made safe
  again after a defeat does nothing.
- **R6. Only for what just happened.** None of these starts for an event that is not recent or while
  the world is catching up, and what is running is cleared when a catch-up starts (spec 063 R6). The
  report after time away still tells what happened meanwhile.
- **R7. Nothing lost.** The ticker, the journal, the sounds and the world's own effects for these
  events are unchanged; the tests of specs 019, 049, 061 and 062 pass unamended. Each of these events
  already has its sound, so its burst or banner is silent: no moment's sound plays for them.
- **R8. Fits both rooms.** With the longest guardian and area names in the data the banner is whole and
  clear of the frame's pieces at 960x540 and 1280x720.
- **R9. Wiki and showcase** are true to it; the showcase's guardian moment shows the banner.

## Interfaces

One new class, `game/ui/frame/milestones.gd` (`Milestones`), hears the world's events and calls
`UiMoment`; the frame's pieces get small functions for the step and the pulse if they need them.
`UiMoment.announce` may gain a way to take a `Texture2D` for the picture (say how). Nothing under
`sim/` changes.

## Acceptance

In `tests/acceptance/test_066_milestones_announced.gd`, one test per requirement named `test_rN_…`,
each written before its code and seen to fail, driven by real events through a `Main`, recent and
stale. A reviewer will break the code under each.

**To look at, and for Zak:** the guardian's banner at both rooms; three frames of a level's burst on a
hero frame; the point tag pulsing; the safe stage's burst. Describe every shot.

## Out of scope

- Talents and upgrades (specs 064, 065). New sounds. Changing what the ticker or journal say.
- Moving the banner out of the way of open windows.

## Paths

- `game/ui/frame/`, `game/ui/ui_moment.gd`, `game/main.gd`, `game/dev/showcase.gd`
- `tests/`
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None.
