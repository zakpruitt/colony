# 043 — A ladder that warns and can be scrolled

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M5
- **Depends on:** 033, 036, 042
- **Pull request:** [#45](https://github.com/zakpruitt/colony/pull/45)

## Intent

The depth ladder lets the player send the party anywhere with one click, including far below what it can
survive, and says nothing about the risk. It also shows only twelve rungs around the party, so a depth the
player wants to look at or a rung a goal has just flashed (spec 042) can be off its edge. This spec makes
the ladder say how dangerous a depth looks before the click, and lets the player scroll it. It changes no
rule: any depth can still be chosen.

## Requirements

Everything follows `docs/style-bible.md`; drawn in code, no new sprites.

- **R1. Each rung shows how it looks for this party.** A rung's number is drawn in one of three colours,
  from the party's lowest hero level `L` and the rung's depth `d`:
  - **safe:** `d` is at or above the safe depth;
  - **reachable:** below the safe depth and `d <= L + 1`;
  - **dangerous:** `d > L + 1`.
  The rule is one function with a doc comment saying it is a rough guide, not a promise. (It follows the
  guardians' balance, a party of level `depth + 4` beating the guardian of that depth, loosely: ordinary
  levels are easier than their guardians.) The colours are from the palette and distinct from the marks
  for the party, the target and the safe depth.
- **R2. The hover says it in words.** Hovering a rung adds a line to its hint: nothing for a safe rung,
  `Within reach` for a reachable one, `Dangerous: heroes are level L` for a dangerous one. A rung with a
  living guardian on it or above it on the way says so as today.
- **R3. A dangerous click still works, and says so once.** Clicking a dangerous rung sets the target as
  today, and the journal's ticker gains a line: `Target set to depth N: dangerous for level L heroes`.
- **R4. The ladder scrolls.** The mouse wheel over the ladder scrolls it by one rung per notch, from depth
  1 down to 6 rungs below the deepest depth ever reached. While scrolled away, a small arrow at the
  ladder's top or bottom edge points toward the party's rung; clicking it, or 5 seconds without the mouse
  over the ladder, returns the ladder to following the party.
- **R5. A flash is always seen.** `flash(depth)` (spec 042) scrolls the ladder so the flashed rung is on
  show before it blinks.
- **R6. Nothing else changes.** Marks, clicks, the `L` key and the ladder's size and place are as before;
  no change under `sim/`; no new key.

## Interfaces

```gdscript
# game/hud/depth_ladder.gd gains
enum Risk { SAFE, REACHABLE, DANGEROUS }
func risk(level_depth: int) -> Risk
func scroll_by(rungs: int) -> void
func is_following() -> bool
```

## Acceptance

In `tests/acceptance/test_043_a_ladder_that_warns.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_rungs_show_risk` | `risk` and the number's colour at the three boundaries, for two party levels and safe depths |
| R2 | `test_r2_hover_says_it` | The hint's line for each kind of rung |
| R3 | `test_r3_dangerous_click` | The target set, the ticker's line once; no line for a safe or reachable click |
| R4 | `test_r4_scrolls` | A wheel notch moving one rung; the two limits; the arrow and its click; the return after 5 seconds |
| R5 | `test_r5_flash_is_seen` | A flash of a rung outside the twelve on show: on show while it blinks |
| R6 | `test_r6_nothing_else_changes` | The 033 and 042 ladder tests pass unchanged; the ladder's rectangle; the state hash unchanged by scrolling and hovering |

**To look at, and for Zak:** shots of the ladder for a level-3 party with the three colours on show, the
hover on a dangerous rung, and the ladder scrolled away with its arrow (a throwaway scene; do not commit
it). Crop and enlarge 3x. Can you tell at a glance where it is safe to send the party? Describe the shots.

## Out of scope

- Refusing or capping a target depth; any change under `sim/`.
- New sprites, sounds or keys.

## Paths

- `game/hud/depth_ladder.gd`, `game/hud/hud.gd` (only if the ticker line needs wiring), `game/hud/journal.gd`
  (only a way to write that one ticker line, if none exists)
- `tests/acceptance/test_043_a_ladder_that_warns.gd`, `tests/unit/test_hud*.gd`
- `tests/acceptance/test_033_depth_ladder.gd` only where it asserts a rung number's colour or the hint's
  exact text (say which)
- `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
