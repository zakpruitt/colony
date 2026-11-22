# Standards

Colony grows by extension: for each kind of thing the game has, there is one base type or one table, and a
new one is made by extending it or adding a row. This page is the index. If what you are adding has a row
here, do it that way; if it does not and you are about to add the second of its kind, the spec that adds
it also adds the row. `docs/architecture.md` explains how the pieces fit; this page only says where to
plug in.

## Extension points

| To add a… | Do this | Where | What holds you to it |
|---|---|---|---|
| Hero class, monster, upgrade, ability, area, resource, side quest, microskill, gate, talent tree | A `.tres` under `data/<kind>/`, named for its id | `data/` | `check`'s `data` step runs every definition's `validate()` |
| Kind of content | A row in `Content.KINDS`, a `Content.Kind` name, its two getters, a def class extending `ContentDef` (`key()`, `validate()`) | `sim/defs/content.gd` | spec 072's tests compare every getter with its folder; spec 078's, every definition with its key |
| Check on a definition | A function on `DefChecks` that returns problems | `sim/defs/def_checks.gd` | |
| Check on a save field | `SaveChecks.check_whole` / `check_counts` | `sim/save_checks.gd` | spec 072's tests pin every problem's wording |
| Question about place on a stage (where a distance is, which chamber, which way, where a party arrives or leaves) | Ask the stage's `StageCourse` (`LabyrinthLevel.course`); a level of a new shape builds its own with `begin` and `line_to` | `sim/labyrinth/stage_course.gd` | spec 088's tests walk a course that bends; nothing under `sim/expedition/` names a level's floor row, tunnels or shafts |
| Read-only question about the expedition | A small class under `sim/expedition/` | as `ClimbProgress`, `ChamberRules`, `PartyPlaces` | gdlint: `Expedition` is at 20 public methods; `check`'s `harness` step: `expedition.gd` at most 900 lines |
| Window on the button bar | A `WindowEntry` in `WindowBook`, whose content extends `WindowContent` | `game/ui/windows/` | spec 074's tests: button, key, tooltip, help line |
| Key | A row in `KeyBook.ROWS`; input asks `KeyBook.pressed`, text asks `KeyBook.label` | `game/ui/key_book.gd` | spec 030's tests (every key listed and pressed); `check`'s `harness` step (only `KeyBook` reads `.echo`) |
| Panel of the screen's frame | A class that extends `FramePiece` (`advance`, `catch_up`, `add_tips`), added with `Hud.add_piece` and placed in `Hud._lay_out_frame` | `game/ui/frame/` | spec 080's new-piece and idle-frame tests |
| Passing effect (particle, text, flash) | A class that extends `FxNode` and overrides `advance(delta) -> bool`, added with `World.fx.add(node, budget)` | `game/effects/` | spec 076's budget and empty-layer tests; `FxPool.add` takes nothing but an `FxNode` |
| View that reacts to events | Its own `_on_sim_event`, connected in its own setup, asking `World.may_animate(event)` | | spec 076's old-event tests |
| Label's text or colour | `WindowText.set_text` / `set_colour`, which set only on a change | `game/ui/windows/window_text.gd` | spec 075's idle-screen test; `check`'s `harness` step (a font colour set by hand in the UI's code) |
| Number or time shown to the player | `UiFormat` | `game/ui/ui_format.gd` | spec 075 |
| Tag on a bar button | `WindowContent._show_badge(count)` | | spec 075's badge test |
| Showcase moment | A row in `Showcase.ROWS`; how it begins and is seen in `ShowcaseMoments` | `game/dev/` | spec 018's test plays every row |
| Test | `extends ColonyTest`, or the fixture that builds what it drives: `HudFixture` (World, effects, Hud, UI layer), `PlayFixture` (frames as played), `MainFixture` (the main scene in a UI room); a helper two tests need goes on the fixture or `ColonyTest` | `tests/colony_test.gd`, `tests/support/` | `check`'s `harness` step (a script under `tests/unit` or `tests/acceptance` that does not reach `ColonyTest` fails, and so does a third copy of a helper; `tools/local_test_helpers.json` lists the names that are different helpers); `tests/unit/test_fixtures.gd` |
| Rule about what source text may say | A check in `rule_problems`, with a test that builds a made-up tree; never a GUT test that reads scripts | `tools/dev.py`, `tools/tests/` | `check`'s `harness` step |
| Cap on one file's lines or public methods | A row in `CAPS` | `tools/dev.py` | `check`'s `harness` step |
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
  every comment in `sim/`, `game/`, `tools/`, `tests/colony_test.gd` and `tests/support/`, holds the files in `CAPS` to their own caps, and warns of a
  file or class near gdlint's.
- **Nothing changes a state hash or an old save by accident.** A spec that means to says so.

## When the standard does not fit

Say so in the spec's open questions before building around it. A second way of doing a thing that has a
row above is a defect, however well it works.
