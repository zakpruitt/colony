# 074 — One list of windows, one list of keys

- **Status:** in-progress (approved 2026-11-19)
- **Milestone:** M8 (cleanup)
- **Depends on:** 070, 071
- **Pull request:** —

## Intent

A new window today means edits in `UiRoot` (twice), `UiButtonBar.ABOUT`, `HelpPanel.KEYS`, the icon
sheet and often `Hud`; a new key means a hand-written guard in one of eight files plus the help list
and every sentence that names the key. This spec makes a window one entry and a key one entry, with
the button, the tooltip, the help line and the key handling all read from them. Nothing on screen
changes.

## Requirements

- **R1. Nothing the player sees or does changes.** Every window, button, tooltip, key and help line is
  as it is today, in the same order and the same places at both rooms. Existing tests pass, edited only
  to follow a name this spec moves (list each); no `assert_…` line changes meaning.
- **R2. A window is one entry.** One list holds, for each of the six bar windows: its id, title, short
  name, key, the sentence its button's tooltip says, its icon part, how its default place is worked
  out, and how its content is made. `UiRoot` builds the windows from the list; `UiButtonBar` takes each
  button's name, key and tooltip from it; the help's "Open or close …" lines come from it.
  `UiButtonBar.ABOUT` and the per-window lines of `UiRoot.setup`, `_management_windows` and
  `place_defaults` are gone.
- **R3. Adding an entry is all it takes.** A window entry added to the list (a test adds one with a
  plain label as content and a free key) gets a button on the bar with its name and key, a tooltip, a
  line in help, opens and closes with its key, and is remembered like the others, with no other code
  changed.
- **R4. Every window's content is a `WindowContent`.** `OrdersPanel`, `JournalView` and `HelpPanel`
  join `ShopWindow`, `AreaMapWindow` and `TallyWindow`: one base, each made by its entry, each advanced
  through `advance` by whoever owns the windows, and none runs its own `_process` (`OrdersPanel` and
  `JournalView` do today). What each needs in its own `setup` may differ. The six live under
  `game/ui/windows/`.
- **R5. A key is one entry.** One table holds every key the game answers to: its label, what it does
  (the help's text), and when it applies ("Camp in front", "Talents tab", always). One helper answers
  "is this event a fresh press of that key"; the eight hand-written guards use it. The help list is
  built from the table and shows the same lines in the same order as today.
- **R6. Text names a key by asking.** The "(O)", "(U)", "(W)" and "press F" written into tooltips,
  goals, notes and news are read from the table, so the words on screen are unchanged and a key's
  letter is written in one place.
- **R7. The harness is true to it.** `CLAUDE.md`'s rule about `HelpPanel.KEYS` names the new table,
  the spec 030 test that reads every `KEY_…` name still guards it, and `docs/architecture.md` says how
  to add a window and a key.

## Interfaces

```gdscript
# game/ui/windows/window_entry.gd
class_name WindowEntry
extends RefCounted
var id: StringName
var title: String
var short_name: String
var key: Key
var about: String
var make_content: Callable   # () -> WindowContent

# game/ui/key_book.gd
class_name KeyBook
static func entries() -> Array[Array]                  # [label, what it does], in help order
static func pressed(event: InputEvent, key: Key) -> bool
static func label(action: StringName) -> String         # "O", "U", "F", …
```

`HelpPanel.KEYS` is a constant that eleven test files loop over (`for entry: Array in HelpPanel.KEYS`),
with `HelpPanel.keycodes`. Once the list is built from the table it cannot be a constant: those tests
change to the new name (`KeyBook.entries()`, `KeyBook.keycodes`), a rename and nothing more. Exact
names are the lane's to settle; report them.

## Acceptance

In `tests/acceptance/test_074_one_list_of_windows_and_keys.gd` (extends `ColonyTest`), both rooms:

| Requirement | Test | What it shows |
|---|---|---|
| R2 | `test_r2_bar_tips_and_help_come_from_the_list` | each of the six windows' button name, key cap, tooltip sentence and help line equals its entry; the texts equal those written in the test (today's) |
| R3 | `test_r3_a_new_entry_gets_a_button_a_key_and_a_help_line` | as R3 says; and without the entry none of them exists |
| R4 | `test_r4_every_window_content_is_a_window_content` | the six contents extend `WindowContent` and none has `_process` |
| R5 | `test_r5_help_lists_the_keys_in_the_same_order` | the help's lines equal today's 22, written in the test |
| R5 | `test_r5_keys_are_guarded_one_way` | reads `game/`; `key.echo` appears only in `KeyBook` |
| R6 | `test_r6_no_sentence_spells_a_key_itself` | reads `game/`; no string literal holds `(O)`, `(U)`, `(W)` or `press F` |

**To look at:** the bar, the help window and one tooltip at both rooms, beside the baseline shots.

## Out of scope

- Rebinding keys, new windows, new keys. Hero windows and the away window (they are not on the bar).
- Splitting `Hud` further than moving the window contents and their keys out of it (spec 075).
  Per-frame refresh work (075). Effects and event listeners (076).

## Paths

- `game/ui/`, `game/hud/`, `game/main.gd`, `game/audio/` and `game/world/world.gd` (their key guards only)
- `tests/` (R1's renames; `test_074_…` new)
- `CLAUDE.md`, `docs/architecture.md`, `docs/wiki/index.html`, `.claude/skills/write-spec/SKILL.md`
  (its note on adding a key)

## Open questions
