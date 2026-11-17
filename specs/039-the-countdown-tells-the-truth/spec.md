# 039 — The countdown tells the truth

- **Status:** provisional
- **Milestone:** M5
- **Depends on:** 027, 036, 037
- **Pull request:** —

## Intent

A new game shows `Stable, then depth 2` and a goal `Reach depth 2` with a full bar reading `stable`, and
then the party stays on depth 1. The HUD is reporting that depth 1 is already safe, which is true, but the
thing the player wants to know is when the party will move on, and that runs on a second timer the HUD does
not show: with auto-push on, the party goes deeper once it has held its target depth for the stable time,
whether or not that depth was already safe. This spec makes the countdown and the goal show the timer that
decides what happens next.

## Requirements

- **R1. The simulation can say when it will push.** `Expedition.seconds_to_push()` returns the seconds
  until auto-push raises the target depth: 0.0 when auto-push is off or the party is not at its target
  depth, otherwise the time still to hold. It reaches 0 on the tick the target rises. Reading it leaves the
  state hash unchanged.
- **R2. The stable note says what happens next.** In the depth panel:

  | Situation | Note |
  |---|---|
  | Not yet stable here | `Stable in m:ss`, with the bar, and `then depth N+1` when auto-push is on (as today) |
  | Stable here, auto-push on, at the target | `Deeper in m:ss`, with the bar filling toward the push, and `then depth N+1` |
  | Stable here, auto-push off, at the target | `Stable`, and `staying on depth N` |
  | Heading to another depth | `Stable` or `Stable in m:ss` for the depth the party is on, with no `then` line |
  | Holding at a guardian (spec 035) | `Holding`, and `Orders (O) to go in` |

- **R3. The goal agrees.** The `Reach depth N` goal's bar and count follow the same timer: when the party
  is at its deepest depth and auto-push will take it down, the bar fills toward the push and reads the time
  left; when auto-push is off it reads `Auto is off` and its tooltip says how to go deeper (turn Auto on,
  or raise the target); when the party is holding at a guardian the goal is the guardian's, not the depth's.
- **R4. A new game reads right.** In a new game with default settings, within the first second the note
  reads `Deeper in` with a time no longer than the stable time for depth 1, the goal's bar is not full, and
  both reach their end on the tick the target becomes 2.
- **R5. Nothing else changes.** No rule changes: a simulation's state hash is the same, tick for tick, as
  before this spec.

## Interfaces

```gdscript
# sim/expedition/expedition.gd gains (read-only)
func seconds_to_push() -> float
```

`sim/expedition/expedition.gd` is at about 999 of gdlint's 1000 lines: put the arithmetic in the helper
beside it that already holds depth timing (`sim/expedition/depth_timing.gd`) or in `party_orders.gd`, and
keep the accessor to a line or two.

## Acceptance

In `tests/acceptance/test_039_the_countdown.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_seconds_to_push` | The value against the tick the target actually rises, on three seeds and at two depths; 0.0 with auto-push off and away from the target; the hash unchanged by reading |
| R2 | `test_r2_stable_note` | Each row of the table from a simulation put in that situation |
| R3 | `test_r3_goal_agrees` | The goal's bar and count in each of the three cases |
| R4 | `test_r4_new_game` | The note and goal in a new default game, and both ending on the tick the target becomes 2 |
| R5 | `test_r5_nothing_else_changes` | Hashes at sampled ticks over 10 minutes on two seeds equal values recorded before the change |

**To look at, and for Zak:** shots of the top-left of a new game at 5 seconds and just before the first
push, and with Auto off. Crop and enlarge. Would a new player know when the party will go deeper?

## Out of scope

- Any rule change, including how auto-push decides.
- New sprites or sounds.

## Paths

- `sim/expedition/` (the accessor and its arithmetic only)
- `game/hud/hud.gd`, `game/hud/goals.gd`, `game/hud/hud_tooltip.gd`
- `tests/acceptance/test_039_the_countdown.gd`
- `tests/acceptance/test_027_reading_the_party.gd` and `test_037_goals.gd` only where they assert the note
  or the goal's text in a situation this spec changes (say which)
- `docs/wiki/index.html`

## Open questions

None.
