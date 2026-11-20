# Standards

Colony grows by extension: for each kind of thing the game has, there is one base type or one table, and a
new one is made by extending it or adding a row. This page is the index. If what you are adding has a row
here, do it that way; if it does not and you are about to add the second of its kind, the spec that adds
it also adds the row. `docs/architecture.md` explains how the pieces fit; this page only says where to
plug in.

## Extension points

| To add a… | Do this | Where | What holds you to it |
|---|---|---|---|
| Hero class, monster, upgrade, ability, area, resource, side quest, microskill, talent tree | A `.tres` under `data/<kind>/`, named for its id | `data/` | `check`'s `data` step runs every definition's `validate()` |
| Kind of content | A row in `Content.KINDS`, a `Content.Kind` name, its two getters, a def class with `validate()` | `sim/defs/content.gd` | spec 072's tests compare every getter with its folder |
| Check on a definition | A function on `DefChecks` that returns problems | `sim/defs/def_checks.gd` | |
| Check on a save field | `SaveChecks.check_whole` / `check_counts` | `sim/save_checks.gd` | spec 072's tests pin every problem's wording |
| Read-only question about the expedition | A small class under `sim/expedition/` | as `ClimbProgress` | gdlint: `Expedition` is at 20 public methods |
| Window on the button bar | A `WindowEntry` in `WindowBook`, whose content extends `WindowContent` | `game/ui/windows/` | spec 074's tests: button, key, tooltip, help line |
| Key | A row in `KeyBook.ROWS`; input asks `KeyBook.pressed`, text asks `KeyBook.label` | `game/ui/key_book.gd` | specs 030 and 074 |
| Passing effect (particle, text, flash) | A node with `advance(delta) -> bool`, added with `World.fx.add(node, budget)` | `game/effects/` | spec 076's budget and empty-layer tests |
| View that reacts to events | Its own `_on_sim_event`, connected in its own setup, asking `World.may_animate(event)` | | spec 076's old-event tests |
| Label's text or colour | `WindowText.set_text` / `set_colour`, which set only on a change | `game/ui/windows/window_text.gd` | spec 075's idle-screen test |
| Number or time shown to the player | `UiFormat` | `game/ui/ui_format.gd` | spec 075 |
| Tag on a bar button | `WindowContent._show_badge(count)` | | spec 075's badge test |
| Showcase moment | A row in `Showcase.ROWS` | `game/dev/showcase.gd` | spec 076 |
| Test | `extends ColonyTest`; a helper two tests need goes on it | `tests/colony_test.gd` | `check`'s `harness` step |
| Tool test | A `test_*.py` in `tools/tests/`, or in `tools/tests/godot/` if it starts Godot | | `check`'s `art` step; its `tools` step |
| Sprite | A `.px` file, baked | `create-sprite` skill | `check`'s `art` step |
| Sound | A `.sfx` recipe, baked | `tools/sfx.py` | the sound lint |

## Rules every extension keeps

- **`sim/` decides, `game/` shows.** A rule lives in `sim/` once; `game/` asks, and never works the answer
  out again for itself.
- **Work on a change, not on a frame.** A view words text, sets a colour or redraws when its value changes.
  A per-frame or per-tick path builds no array, dictionary or string it throws away.
- **A thing is handed what it needs.** In `setup`, by whoever makes it: no finding a parent by type, no
  node looked up by name, no signal emitted for another object.
- **Public means used elsewhere.** A constant or function nothing outside its file uses is private.
- **A comment states a contract or a why.** No spec numbers, no history. `check`'s `harness` step reads
  every comment in `sim/`, `game/`, `tools/` and `tests/colony_test.gd`, and warns of a file or class near gdlint's caps.
- **Nothing changes a state hash or an old save by accident.** A spec that means to says so.

## When the standard does not fit

Say so in the spec's open questions before building around it. A second way of doing a thing that has a
row above is a defect, however well it works.
