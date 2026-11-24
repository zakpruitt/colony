# 105 — Chat bubbles

- **Status:** in-progress
- **Milestone:** M0
- **Depends on:** 058, 062, 076, 103 (its Paths touch `world.gd` and the showcase too; it may run beside 104)
- **Pull request:** —

Status is one of `draft`, `approved (YYYY-MM-DD)`, `provisional`, `in-progress`, `landed`.

## Intent

Characters in the world can say a short line in a chat bubble over their head. The bubble is drawn sharp on the UI layer and follows the speaker as they move.

This spec builds the bubble and one call, `World.say`, and nothing in the game uses it yet. Spec 107 gives the quests their lines (a wanderer crying for help, a cleric comforting them). Later work can use the call for anything else a character should say.

## Requirements

- **R1. A bubble shows a line over its speaker.**
  - `World.say(speaker, text, seconds)` shows `text` in a bubble whose tail points at the speaker's head.
  - The speaker is one of two things:
    - a hero or monster id, in which case the bubble sits over that character's sprite at its top;
    - a `Callable` that returns a world point, for a speaker that is not a character, such as a quest's wanderer.
  - The bubble is a rounded panel in the UI theme's colours, with a tail. The text is in `UiText`, at most 160 UI pixels wide, wrapped onto at most 3 lines.
  - `seconds <= 0` picks the hold time from the length of the line: 1.2 s plus 0.06 s a character, capped at 4 s.
- **R2. It follows its speaker.**
  - Every frame the bubble is placed from the speaker's current world point. That point goes through the world's canvas transform (the camera) to the 640x360 screen, then through `UiRoot.world_to_ui`. So a walking speaker, or a camera that pans, takes its bubble along.
  - The bubble is kept inside the UI room. It slides sideways so its panel stays on screen, while its tail still points at the speaker.
  - If the speaker is a character that is gone (freed or removed), its bubble goes.
- **R3. It comes and goes the way the world's words do.**
  - It pops in over 0.12 s, holds, then blinks out, the way `FxText` does, never with a fade.
  - A speaker has at most one bubble: a new `say` for the same speaker replaces the one showing.
  - Different speakers' bubbles may show at once. If two overlap, the later one is nudged up until it clears the earlier one.
- **R4. Windows cover bubbles.**
  - Bubbles are drawn above the world and the frame of the screen's hero frames, but under every window and the button bar. A window dragged over a speaker hides the bubble.
  - Bubbles take no mouse input: the mouse passes through them.
- **R5. Stale or skipped time starts nothing.**
  - `World.say_for(event, speaker, text, seconds)` is the form a listener uses. It shows the bubble only when `World.may_animate(event)` is true.
  - While `World.catching_up()` is true, every bubble showing is cleared.
  - A move to another stage or area also clears every bubble.
- **R6. It is cheap.**
  - Showing a bubble measures and wraps its text once. Each later frame only moves it: no text measuring, no tree searches and no new nodes.
  - Bubble nodes are reused from a pool of at most 8. When a 9th is asked for, the oldest is reused.
  - A bubble calls `queue_redraw` only when its text, size or pop changes, never just because it moved.
- **R7. The showcase shows one.** A showcase row "A CHAT BUBBLE OVER A WALKING HERO": the front hero says a line while the party walks, and the bubble travels with them.

## Interfaces

```gdscript
# game/ui/speech_bubbles.gd (new): a Control on UiRoot.frame, under the windows and the bar
class_name SpeechBubbles
extends Control
## Shows text over the speaker (an int character id, or a Callable returning a world point).
func show_line(speaker: Variant, text: String, seconds: float = 0.0) -> void
## Takes every bubble away at once.
func clear() -> void
## How many bubbles show now, and the text of the one over that speaker ("" when none).
func shown_count() -> int
func line_of(speaker: Variant) -> String

# game/ui/ui_root.gd
var bubbles: SpeechBubbles  # made in setup, under the windows and the bar

# game/world/world.gd
var bubbles: SpeechBubbles  # set by Main; null in a World with no UI layer: say does nothing
func say(speaker: Variant, text: String, seconds: float = 0.0) -> void
func say_for(event: SimEvent, speaker: Variant, text: String, seconds: float = 0.0) -> void
```

`SpeechBubbles` also needs the world's point for a speaker, and a way to turn it into a UI point. The lane decides how it reaches these, for example a `Callable` that `World` hands it in `Main`. This spec fixes only the calls above.

## Acceptance

One test per requirement, in `tests/acceptance/test_105_chat_bubbles.gd`. Each test builds the game with its UI layer, through `HudFixture` or `MainFixture`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_a_bubble_shows_over_its_speaker` | `say(hero, "Hold still, friend.")` shows that line. The tail tip is within 2 UI pixels of the hero's head in UI pixels. A long line wraps and stays within 160 pixels and 3 lines. A `Callable` speaker works too. The hold time with `seconds = 0` follows the length rule |
| R2 | `test_r2_it_follows_its_speaker` | After the hero walks 40 world pixels and the camera moves, the tail still points at the head. A speaker at the screen's edge keeps its panel inside the room. Freeing the speaker removes its bubble |
| R3 | `test_r3_one_bubble_a_speaker` | A second `say` for the same hero replaces the first (`shown_count` stays 1). After its hold, the bubble is gone without passing through a partly transparent state. Two speakers side by side show two bubbles that do not overlap |
| R4 | `test_r4_windows_cover_bubbles` | The bubbles' control comes before every window and the bar in drawing order. Its `mouse_filter` is IGNORE |
| R5 | `test_r5_stale_time_starts_nothing` | `say_for` with an event older than `ANIMATE_TICKS` shows nothing. A catch-up (a stall) clears bubbles that were showing. A move to the next stage clears them |
| R6 | `test_r6_it_is_cheap` | Moving a bubble over 30 frames calls no text measuring (count calls through a seam the lane provides). Ten `say` calls leave at most 8 bubble nodes. A bubble that only moves does not redraw |
| R7 | `test_r7_the_showcase_has_a_bubble_row` | The row exists and its watcher marks it seen once a bubble shows over the front hero |

For Zak's playtest and the lane's shots, at 1280x720 and `--ui-room=960x540`: the bubble reads clearly, sits snugly over the head, does not hide the speaker's face, and looks like part of the same UI as the windows.

## Out of scope

- Any line the game actually says, and any data of lines. Spec 107 adds the quests' lines.
- Icons or emotes in bubbles, a typewriter effect, or sounds.
- Bubbles in the journal or the ticker.
- Changing `FxText`.

## Paths

- `game/ui/speech_bubbles.gd` (new) and its `.uid`, plus a `game/ui/speech_bubble.gd` for one bubble if the lane wants it
- `game/ui/ui_root.gd`
- `game/main.gd` (handing the bubbles to the world)
- `game/world/world.gd` (`bubbles`, `say`, `say_for`, and clearing on a catch-up or a change of stage or area)
- `game/dev/showcase.gd`, `game/dev/showcase_moments.gd`
- `tests/acceptance/test_105_chat_bubbles.gd` and its `.uid`
- `tests/support/hud_fixture.gd` (only if a helper is shared)
- `docs/architecture.md` (the UI layer's children), `docs/standards.md` (a row: a line a character says goes through `World.say`), `docs/wiki/index.html`

## Open questions

None.
