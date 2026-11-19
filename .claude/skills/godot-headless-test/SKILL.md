---
name: godot-headless-test
description: Write, fix or read Colony's GUT tests (tests/unit, tests/acceptance) and diagnose failures of `python tools/dev.py check` or `test`. Use when adding an acceptance or unit test, when a test fails or prints SCRIPT ERROR, when a test passes with broken code, or when a check step fails in CI but not locally.
---

# Headless tests in Colony

Tests are GUT 9 scripts: `extends GutTest`, functions named `test_*`, in files named `test_*.gd` under `tests/`.
The whole suite runs in one Godot boot.

```
python tools/dev.py test                  # all tests
python tools/dev.py test --only=test_003  # scripts whose name contains this
python tools/dev.py check --only=compile,tests
```

## A test must be able to fail

- Write the test before the code and watch it fail because the behaviour is missing. A test that has never
  failed has not been shown to test anything.
- For a change to existing behaviour, put the old value back (copy the file aside; do not `git checkout` over
  uncommitted work), see the test fail, restore.
- Assert the outcome the requirement names. "No error occurred" and "the method was called" are not outcomes.
- A comparison of a count with sums made in the test passes when both are 0. Spec 045's Healing check on the
  last fight passed with healing left out of it, because that fight had no healing; make the test wait for
  data that has something in it (spec 046 found this by breaking the code on purpose).
- When you break code on purpose to see a test fail, keep it compiling: a mutant that leaves a parameter or
  a local unused is a warning, so an error, and then every test that touches the class fails at once for
  the wrong reason (`Invalid call ... in base 'Nil'` by the thousand). Use the parameter
  (`return "" if id != &"zzz" else ...`) and run `check --only=compile` on the mutant first.

## Testing the sim

The sim is plain objects (`docs/architecture.md`), so most tests need no scene, no frames and no waiting.

- Build the state, step it, assert. Ten minutes of game time is a loop, not a wait.
- Fix the seed: `SimRng.new(1234)`. A test whose result depends on an unseeded roll is a flake.
- For "always" and "never" claims, run many seeds in a loop, and print the seed in the assertion message so a
  failure can be replayed.
- Determinism has its own kind of test: run the same seed and commands twice and compare the whole state.
- An "off changes nothing" test compares hashes recorded before the change. If `dev` changes the game after
  you recorded, record again on it with your sim code set aside: commit your work, merge `origin/dev`,
  `git checkout origin/dev -- sim`, run a throwaway recorder test that only uses `Simulation` (one that names
  a `game/` class will not load against the old `sim/`), then `git checkout HEAD -- sim` and delete the
  recorder.
- A change to the default game (tuning, timing) breaks every recorded hash at once, and they are in several
  files with different intervals (016, 022 and 029 every 1500 ticks, 035 every 600). `grep -rn
  RECORDED_HASHES tests/` and re-run each test's own loop; a later merge can bring in a new one.
- When a test file or `sim/expedition/expedition.gd` is near gdlint's 1000 lines, gdformat may split an edited
  line in two and push it over: run `check --only=format` after every edit there. Python's `write_text` on
  Windows writes CRLF; when editing files from a script, read and write bytes.

## Testing nodes (`game/`)

- `add_child_autofree(node)` so GUT frees it; a leaked node is reported as an orphan.
- Do not time things with the wall clock. Headless frames do not take a frame's worth of time. Drive time
  yourself: call the method with a delta, or step the sim directly.
- `await get_tree().process_frame` resumes before that frame's `_process` calls have run. To see what a node's
  `_process` did, await two frames, or use GUT's `await wait_process_frames(2)`.
- The headless window is tiny. Send keys and actions with `Input.parse_input_event`, not mouse positions.
- A mouse event pushed into the viewport (`get_viewport().push_input(event, true)`) does reach a HUD's
  `_gui_input` and its hover, but only if the HUD is on a `CanvasLayer` above GUT's own window (layer 128,
  whose panel otherwise takes every click) and not on the root canvas (where the world's camera moves it away
  from its screen rect). Spec 042's test builds the HUD in a `CanvasLayer` with `layer = 129`; move the mouse
  away in `after_each`, since the viewport remembers where it was. A test that clicks a whole `Main` raises
  its layers the same way (`main.hud_layer.layer = 129`, `main.ui.layer = 130`, spec 058's `_main`).
- A click on the UI layer (spec 058) is pushed at world coordinates: the root viewport thinks in 640x360
  whatever the window's size. Turn a point on a window into one with `main.ui.ui_to_world(point)`, and lay the
  layer out for the room under test with `main.ui.set_room_for_test(Vector2i(960, 540))` first (the headless
  window is too small to give it a real room).
- A window on the UI layer lays out a frame after it opens or its content changes (its containers sort, then
  the window refits): `await get_tree().process_frame` (two, after content shows or hides) before reading a
  control's rect to click it, or the click lands where the control is not yet and silently does nothing.
- A test without `set_room_for_test` (a HUD-only test, or a `Main` in the headless window) gets a room of
  640x360, smaller than any real one, and a tall window's lower controls (the map's foot) fall outside it,
  where no click reaches. Press those by their signal and leave the real click to a test that sets the room.
- Since spec 059 the shop, the area map and the tally are window contents made by the HUD: without a
  `UiRoot` their `open()` does nothing. A HUD-only test that opens one adds `UiRoot.new()` (layer 130 if the
  HUD is on 129) and calls `ui.setup(sim, hud, null)`.
- Since spec 062 everything the HUD shows is on the UI layer, so a HUD-only test that clicks or hovers a
  piece (a goal row, the stage list, the ticker) must raise its `UiRoot` above GUT's window too
  (`ui.layer = 130`), not only the HUD's layer. Left at 20, the pushed events never reach the piece, and the
  failure can show up in a later script instead (spec 060's Tab tests failed only in the full run).
- `python tools/dev.py test` prints only the last 150 lines. For a long failing run, call Godot with GUT
  yourself (`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit -gselect=<part>`) and write
  the whole output to a file to read the failures.
- A `CanvasLayer` that draws into another viewport (`custom_viewport`) must be given it before it enters the
  tree (`Main` does it on `NOTIFICATION_SCENE_INSTANTIATED`). Set in `_ready`, freeing the scene prints
  `Attempt to disconnect a nonexistent connection ... canvas_parent_mark_dirty`, which fails every test that
  frees a `Main` (spec 058).
- Gold set directly (`sim.party.gold = 10_000`) is counted up on the HUD like coins, after
  `Hud.GOLD_CATCH_UP_SECONDS`. A test of "the gold count drops at once" must let the count catch up first
  (`hud.advance(Hud.GOLD_CATCH_UP_SECONDS + 0.1)`), or the count is still below the gold and has nothing to
  drop from.
- A lambda captures a local variable's value when it is made. Recording events with
  `world.sim_event.connect(func(e: SimEvent) -> void: events.append(e))` and then emptying the list with
  `events = []` leaves the lambda filling the old array, and the test sees nothing happen. Empty it with
  `events.clear()`, or keep the list in a member variable.
- A "stall" in a World test (the simulation stepped several ticks, then one long `sync`) is only a stall to
  the world when it is more than `World.STALL_TICKS * speed` ticks since the last sync (half a second of game
  time). Shorter, the frame does not snap and the test of "a stall keeps X" passes whatever the code does.
  Assert the stall's length in the test.
- A test that compares what the world draws with what placed it proves nothing (spec 048 R7). To measure where
  a character's pixels are as drawn, walk its `Sprite2D` parts and map each opaque pixel of the part's
  `AtlasTexture` region through `World.global_transform.affine_inverse() * part.global_transform`
  (`test_038_rough_edges.gd`, `_drawn`).
- A test that calls a Control's `_gui_input` directly must also send what the GUI sends around it: call
  `_notification(Control.NOTIFICATION_MOUSE_ENTER)` before the first motion and `NOTIFICATION_MOUSE_EXIT` when
  the mouse leaves. Since spec 047 the stage list (`StageList`, the depth ladder before spec 062) counts the
  mouse as over it only from those (a press dragged off it keeps sending `_gui_input` from outside), so a test
  that only sends motion has no mouse over it.
- A hover test must let a scrolling panel settle before putting the mouse on a row: a hover follows the row
  under a still mouse as rows move (spec 047), so a mouse placed mid-scroll ends on a different row.
- gdlint caps a script at 20 public methods (`max-public-methods`), and `StageList` is at the cap. A read
  added for a test there has to replace one, or be a public variable, which does not count.
- A hidden button still runs its handler when a test emits `pressed`, so a page's handler must check that the
  page is shown. Check the page (`is_visible_in_tree()` on the page), not the button: a control whose
  visibility a refresh sets lags one HUD frame, and a key pressed right after a level up finds it still hidden
  (spec 055 broke spec 030's `1-3` test this way).
- The showcase's whole pass is held under 90 s by test_018 and runs close to it (89.5 s after spec 055). A new
  moment gets about a second: do its clicks at once and a few tenths apart, and keep its linger short. To
  measure, swap the `PASS_LIMIT` assert for `assert_lt(showcase.elapsed, 1.0)` locally, read the value, and
  restore it.
- Typed GDScript turns shadowing into an error: a local, loop variable or parameter cannot share a name with a
  method of its class (`node`, `state`), and a function cannot be named for a builtin (`wrap`).
- A headless run's window is 640x360, so a `Main` or a `UiRoot` a test does not size has a UI room of 640x360
  at a scale of 1: UI pixels are then world pixels, and anything laid out for the 960x540 it is promised
  overflows the bands. Call `ui.set_room_for_test(...)` where a place matters, compare a UI-layer piece with
  an old-HUD one through `Hud.on_screen(control)` (screen pixels, never a camera's), and click one with
  `Hud.on_screen(control).get_center()` (spec 061).
- A wrapping `Label`'s minimum height is right only once its container has sorted it, a frame later. A box
  sized from `get_combined_minimum_size()` the moment its text changes comes out hundreds of pixels tall:
  size it from the label's own `get_minimum_size()` after setting its width (`UiTip._show`, spec 061), and
  assert a box's height against its line count, since the tall box passed every other check.
- A `Main` built by spec 058's `_main` has a world that has synced once (or not at all), so
  `World.catching_up()` is true until it syncs again: anything gated on it (spec 063's `UiMoment`, spec 057's
  moves) silently starts nothing. Call `main.world.sync(STEP)` twice before testing such a thing with no
  events (spec 063's `_settled`), and assert `catching_up()` is false where it matters.
- `UiMoment` runs its bursts and banners in its own `_process`, and a test's loop runs no frames: in a loop
  that drives the showcase or the world by hand, call `main.ui.moment.advance(dt)` (and `main.hud.advance(dt)`)
  each step, or no banner ever shows (spec 064 R14).
- `SoundPlayer` counts time in its own `_process` too, and has eight voices: in a loop that runs no frames
  its clock stands still, every voice stays busy with the first sounds of a fight, and a later sound never
  starts (`drain_started()` comes back without it). Call `main.sound._process(dt)` each step of a loop
  that then asserts on a sound (spec 066 R7).
- A control past the first view of a `ScrollContainer` (a hero window's paragon medallions, spec 064) cannot
  be clicked until it is scrolled into view, and the container learns how tall its content has grown only a
  frame later. Before a real click there, `await` a frame, then push wheel events over the scroll until its
  rect encloses the control (`talent_tree_test.gd`'s `_into_view`).
- A click that follows a click on something that changes under the mouse can miss: the strip under a talent
  tree shows the node under the mouse, so moving straight from a node to the strip's `Learn` finds the
  button hidden until the HUD's next frame. Move the mouse away and advance a frame first (`_point_away`).

## Files

`user://` is one folder shared by every worktree on the machine. A test that writes there uses a per-process
name and deletes it:

```gdscript
var path: String = "user://test_save_%d.dat" % OS.get_process_id()
```

Code that must not raise engine errors on a missing or damaged file (and a test that checks one with
`assert_engine_error_count(0)`) avoids two calls that print them: `JSON.parse_string` on text that is not JSON
(use `JSON.new().parse(text)` and check the returned `Error`), and `FileAccess.get_file_as_string` on a missing
file (check `FileAccess.file_exists` first). JSON also turns every number into a float, so compare parsed data
by value, not with `assert_eq` against ints.

## Reading a failure

- `[format] FAIL`: run `python tools/dev.py format`. If `gdlint` complains, fix the code, not the rule.
- `[boundary] FAIL`: something under `sim/` named a node, a clock or a global random function. Pass the value
  in instead (ticks for time, a `SimRng` for rolls).
- `[compile] FAIL` with `Warning treated as error`: almost always a missing type. `var x := dict.get(k)` infers
  a `Variant`; write `var x: int = dict.get(k)`. The same goes for elements of an untyped `Array` or
  `Dictionary` passed straight to a typed parameter, `assert_eq` included (`requires the subtype "Variant" but
  the supertype "Variant" was provided`): copy the element into a typed local first.
- `Trying to assign an array of type "Array" to a variable of type "Array[StringName]"` at run time, though
  the script compiled: a ternary of array literals (`var c: Array[StringName] = [&"a"] if x else [&"b"]`)
  makes a plain `Array`; only a literal assigned directly is typed. Put each list in a typed `const` and pick
  between the constants.
- Code that is meant to `push_error` (a rejected input, say) fails the test unless the test claims the error
  with `assert_push_error("part of the message")`.
- `[compile] FAIL` with `is shadowing an already-declared function`: a local or parameter has the name of a
  method of the class (a `chamber()` method and a `var chamber` local). Rename the local.
- gdformat (4.5.0) mangles a lambda of more than one line written as a value in a dictionary literal: it
  copies every comment in the file into the lambda, and the file then fails `--check` for ever. Keep such
  lambdas to one line (`"x": func() -> void: _helper(a),`), and if it has happened, cut the copied comments
  out by hand. Format writes CRLF on Windows; git turns it back to LF (`.gitattributes`).
- `[format] FAIL` with `max-file-lines`: gdlint caps a file at 1000 lines. A long acceptance file stays
  under it with small helpers (one that returns the amounts of every event of a kind, say) rather than
  repeated `if x.size() == 1:` guards. `tests/acceptance/test_005_expedition_loop.gd` sits at exactly 1000:
  an update there must not add lines. The cap counts for `sim/` too: `sim/expedition/expedition.gd` is near
  it, so put a new rule's arithmetic on its def (spec 025's `SideQuestDef.reward_at`), not in the expedition.
  When a spec's tests outgrow one file, move the shared helpers into a script with no tests of its own
  (spec 050's `tests/unit/test_ability_kit.gd`, which `extends GutTest`) and have each test file
  `extends "res://tests/unit/test_ability_kit.gd"`. If GUT then says `Ignoring script ... because it does
  not extend GutTest`, the script (or its parent) failed to parse: `check --only=compile` names the line.
- To prove a test can fail, break the code with a change that still compiles: `if false:` is dead code, a
  warning, so the script stops loading and everything fails (or a `SceneTree` script hangs) for the wrong
  reason. Prefer `if <condition> and <something never true>:`.
- `SCRIPT ERROR ... Could not find type "X"`: a new `class_name` the import cache has not seen. Run
  `python tools/dev.py import` (the full `check` does this for you).
- `test_030 ... test_r3_every_key_is_listed` fails with `KEY_SOMETHING is a key`: the test reads every word
  starting `KEY_` under `game/` as a key the game handles. A constant named `KEY_HINT` counts; name it
  something else (`HIDE_HINT`).
- A HUD test that jumps the simulation from one situation to the next can finish spec 037's goals on the way
  (a deeper depth, a level that learns a microskill); the finished goal holds its row for 3 s. Advance the
  HUD a frame, then past `Goals.CELEBRATE_SECONDS`, before reading `goals.lines()`.
- `[tests] FAIL`: GUT prints the failing assertion with its file and line above the summary.
- A failing `assert_string_contains(wiki, phrase)` prints the whole text it searched, twice, and `dev.py
  test` shows only the last 400 lines of output: one such failure on the wiki pushes every other failure,
  and the test names, out of view. Look for a phrase in a long text with
  `assert_true(text.contains(phrase), "...: %s" % phrase)` (spec 065).
- `[Failed]: Unexpected Errors ... at line -1` with no message: a `SCRIPT ERROR` (often a parse error in a
  script the test loads, or a freed object touched) that `dev.py test` cut from what it shows. Run GUT
  yourself to see it: `godot_console --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit
  -gselect=test_038 -gunit_test_name=<test>` and grep the output for `SCRIPT ERROR`.
- A test that needs a party that *cannot* do a side quest must stay robust to faster levelling (spec 036):
  a level-1 rogue can reach level 2 and learn Lockpicker on one walk. Pick a quest whose microskill comes
  late (a rune stone, Runereader at mage level 4) rather than the locked chest.
- `dev.py test` shows a test's `print` output only when something fails. To read a trace while debugging,
  end the test with a failing assertion, and delete the test (and its `.uid`) afterwards. GUT prints each
  failure twice (as it runs and again in the summary): when you capture a recording this way (an event list
  to compare against later), cut it at the first copy, or you record everything twice.
- A table of cases (`var cases: Array = [[...], ...]`) gives `Variant` elements, and passing `case[1]`
  straight to a typed parameter, or even to `assert_eq`, is an `unsafe_call_argument` error. Copy each into
  a typed local first (`var health: int = case[1]`). A file near gdlint's 1000 lines: write enum values by
  name through a small setter (`_set_all(effect, {"lands": "TARGET"})`) rather than in full.
- `[boot] FAIL`: the main scene printed an error while starting; the line is in the output.
- **Passes locally, fails in CI:** CI is Linux, where paths are case-sensitive (`res://Sim/x.gd` is not
  `res://sim/x.gd`) and nothing untracked exists. `git status` for files you forgot to add, `.uid` files included.
- **One Godot run at a time per machine, from you.** Other lanes run theirs too, and a test that errors
  every frame or recurses without end (a helper that calls itself where it meant to call another object's
  method) prints a stack trace per call: two or three such runs at once exhausted the machine's memory
  (spec 060). Never run tests from several forks or background jobs in one worktree at once. To find
  which file floods, run Godot directly with the output capped on disk:
  `timeout -k 5 300 godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit -gselect=<file> 2>&1 | head -c 2000000 > out.txt`
  and read its tail; stop a stray run by its process id (`Stop-Process -Id`), never by name.
