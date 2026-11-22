---
name: godot-headless-test
description: Write, fix or read Colony's GUT tests (tests/unit, tests/acceptance) and diagnose failures of `python tools/dev.py check` or `test`. Use when adding an acceptance or unit test, when a test fails or prints SCRIPT ERROR, when a test passes with broken code, or when a check step fails in CI but not locally.
---

# Headless tests in Colony

Tests are GUT 9 scripts: functions named `test_*`, in files named `test_*.gd` under `tests/`. The whole suite
runs in one Godot boot.

## Start from `ColonyTest`

Every test script `extends ColonyTest` (`tests/colony_test.gd`), directly or through a per-spec
base; `check`'s `harness` step fails on one under `tests/unit` or `tests/acceptance` that does not. It holds what the tests used to copy:

| Helper | Does |
|---|---|
| `press(keycode, shift = false)` | presses and releases a key, pushed into the viewport |
| `mouse_move(at, held = false)` | moves the mouse, in the world's 640x360 pixels |
| `mouse_button(at, pressed, button = LEFT)` | one press or release |
| `click(at, button = LEFT)` | moves there and clicks; the mouse stays (move it away yourself if a hover would get in the way) |
| `raise(hero, level)` / `raise_party(simulation, level)` | gains a level's experience (levelling up as in play) and full health |
| `set_level_keeping_health(hero, level)` | sets level and experience outright: no levelling up, health untouched |
| `set_party_level(simulation, level)` | the same for the whole party, then full health |
| `step_until(simulation, done, limit)` | steps until `done` is true, checking first; fails the test after `limit` ticks |
| `make_main()` | the main scene, instantiated, not in the tree, no save store or settings |
| `save_path(tag = "", extension = "save")` | a per-process file under `user://`, deleted with its `.bak` and `.tmp` after each test and after the last |
| `before_guardian(simulation, depth, back, reached, held)` | the party just short of `depth`'s guardian, walking in, auto-push off |
| `run_ticks(simulation, ticks)`, `ticks_in(seconds)`, `_of_kind(events, kind)` | ticks with their events; seconds as ticks; the events of a kind |
| `LIMIT_TICKS`, `LIMIT_TICKS_10_MIN`, `_5_MIN`, `_3_MIN`, `_90_S` | ceilings for a loop that waits on the simulation |

## Then a fixture (`tests/support/`)

A test that builds more than the simulation extends a fixture instead, which brings the build and the frame:

| Fixture | Reach for it when the test | Gives |
|---|---|---|
| `HudFixture` | drives a World, its CombatEffects and the Hud (and the UI layer) without `Main` | `_build_hud(with_ui, layered)`, `_make_hud(sim, …)`, `_frame(ticks, delta)` over `_frame_parts`, `_step_until(done)`, `_click_at` / `_click`, `_hear_events()` into `_events` |
| `PlayFixture` (a `HudFixture`) | plays frames as the game does, a tick every `FRAMES_PER_TICK` | `_show(sim, speed, with_effects)`, `_play_frame()`, `_play_until(kind)` |
| `MainFixture` | needs the whole main scene in a UI room (`ROOM_SMALL`, `ROOM_LARGE`) | `_main(room)`, `_frame(main, ticks)` over `_frame_parts`, `_click(main, control)`, `_press`, `_drag` |

Extend one by its path (`extends "res://tests/support/hud_fixture.gd"`): the `harness` step follows
`extends` by path or class name to check every script reaches `ColonyTest`.
Set what a frame moves and how long a wait lasts in `before_each` (`_frame_parts`, `_frame_ticks`,
`_tick_seconds`, `_hud_each_tick`, `_step_limit`, `_mouse_rest`) rather than writing your own `_frame` or
`_step_until`. A shared helper's limit is a claim the test makes ("within ten minutes"): when you move a
script onto a fixture, keep the bounds it had, never the fixture's longer default. `tests/unit/test_fixtures.gd` pins what each one does.

**When a second test needs a helper, put it on the fixture it belongs to, or on `ColonyTest`; do not copy
it.** The `harness` step fails when a function of one name is defined in more than two test scripts; a name
that is really several different helpers is listed in `tools/local_test_helpers.json` with why and the
scripts that define it (another script defining it fails again). A helper
that is one test's alone stays in that file. A copy that does something
slightly different (another step order, a frame of the HUD after) is a local helper built on the shared one,
not a change to the shared one. Do not name a local or a parameter after a `ColonyTest` method (`press`,
`click`): it shadows it, a warning, so an error. A script that overrides `after_each` or `after_all` calls
`super()` in it, or its `save_path` files are left behind. A constant named `MAIN_SCENE` is the base's.

A spec whose tests share more than that gets a base of its own, named `*_test_base.gd` (GUT loads only
`test_*.gd`, so a base named `test_…` is loaded as an empty test), that extends `ColonyTest` or the fixture
its tests need, and holds only that spec's own helpers.

```
python tools/dev.py test                  # all tests
python tools/dev.py test --only=test_003  # scripts whose name contains this
python tools/dev.py test --shard=2/4      # the second of four parts, as one CI job runs it
python tools/dev.py check --only=compile,tests
```

`test` imports the project before it runs, so a new `class_name` is seen without `dev.py import`. CI runs
the suite as four shards side by side (`--shard=I/4`), split by the script times in
`tools/test_times.json`: if a shard's job is much slower than the others, measure the slow scripts and
update that file. Tool tests (Python, `tools/tests/`) that start Godot go in `tools/tests/godot/`, which
the `tools` step runs; the `art` step runs the rest and must start no Godot.

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
  files with different intervals (016 and 022 every 1500 ticks, 035 every 600, and others since). `grep -rn
  RECORDED_HASHES tests/` and re-run each test's own loop; a later merge can bring in a new one.
- Bound a battle loop by its own step count, not `battle.tick`, and fail the test at the limit:
  `Battle.step()` stops moving the tick once the battle has a result, so a broken `result()` spins forever
  with the tick standing still.
- Tests run through `tools/dev.py`. The one exception is seeing a guard on an endless loop fail: with the
  loop made endless, `dev.py test` runs the whole file and any other unbounded loop in it hangs until the
  timeout, so run only the guarded test, by hand, under `timeout` (`-gunit_test_name=<test>`). If `timeout`
  stops `godot_console`, the `godot.exe` under it keeps running: stop it by its process id (its command line
  names your worktree), never by name.
- When a test file or `sim/expedition/expedition.gd` is near gdlint's 1000 lines, gdformat may split an edited
  line in two and push it over: run `check --only=format` after every edit there. Python's `write_text` on
  Windows writes CRLF; when editing files from a script, read and write bytes.

## Testing nodes (`game/`)

- `add_child_autofree(node)` so GUT frees it; a leaked node is reported as an orphan.
- Do not time things with the wall clock. Headless frames do not take a frame's worth of time. Drive time
  yourself: call the method with a delta, or step the sim directly.
- `await get_tree().process_frame` resumes before that frame's `_process` calls have run. To see what a node's
  `_process` did, await two frames, or use GUT's `await wait_process_frames(2)`.
- The headless window is tiny: place a click from the control's own rect, never from a fixed screen point.
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
- `python tools/dev.py test` prints only the last 400 lines. For a long failing run, call Godot with GUT
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
- The showcase's whole pass is held under `PASS_LIMIT` (150 s) by test_018. A new
  moment gets about a second: do its clicks at once and a few tenths apart, and keep its linger short. To
  measure, swap the `PASS_LIMIT` assert for `assert_lt(showcase.elapsed, 1.0)` locally, read the value, and
  restore it.
- Typed GDScript turns shadowing into an error: a local, loop variable or parameter cannot share a name with a
  method of its class (`node`, `state`), and a function cannot be named for a builtin (`wrap`).
- A headless run's window is 640x360, so a `Main` or a `UiRoot` a test does not size has a UI room of 640x360
  at a scale of 1: UI pixels are then world pixels, and anything laid out for the 960x540 it is promised
  overflows the bands. Call `ui.set_room_for_test(...)` where a place matters, compare a UI-layer piece with
  an old-HUD one through `UiFormat.on_screen(control)` (screen pixels, never a camera's), and click one with
  `UiFormat.on_screen(control).get_center()` (spec 061).
- `HudFixture._frames_top()` is for a `Hud` built alone. On a `Main` the hero frames are on the UI layer,
  their rects in UI pixels and below 360, so it answers 360, the bottom of the screen, and an "above the
  frames" check made from it passes whatever the window's height: spec 035's `_check_fits` passes with
  the Orders window 43 pixels over the frames at 960x540 (spec 061's r10 is the check that holds, by
  the windows' default places against the frame's pieces). On a `Main` ask
  `ui.world_to_ui(Vector2(0, ui.frames_top())).y`, the frames' line in UI pixels (486 at 960x540).
- A wrapping `Label`'s minimum height is right only once its container has sorted it, a frame later. A box
  sized from `get_combined_minimum_size()` the moment its text changes comes out hundreds of pixels tall:
  size it from the label's own `get_minimum_size()` after setting its width (`UiTip._show`, spec 061), and
  assert a box's height against its line count, since the tall box passed every other check.
- Every view starts a move, effect, sound or flash only when `World.may_animate(event)` says so: the
  event is recent and the world is not catching up. `catching_up()` is true for a sync after more than
  `World.STALL_TICKS` ticks until the next sync, so a test that steps
  the simulation far between syncs silently starts nothing. Step in small runs with a `sync` between, call
  `main.world.sync(STEP)` once more before testing a start with no events (spec 063's `_settled`), and
  assert `catching_up()` is false where it matters. The world's first sync is not catching up.
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
  rect encloses the control (`talent_tree_test_base.gd`'s `_into_view`).
- A click that follows a click on something that changes under the mouse can miss: the strip under a talent
  tree shows the node under the mouse, so moving straight from a node to the strip's `Learn` finds the
  button hidden until the HUD's next frame. Move the mouse away and advance a frame first (`_point_away`).

- A light that is in `Ambience.lights()` is not yet a light on screen: `AmbienceDarkness` draws the ones it
  chose (`_near`), and it chooses again only when it sees the list or the view change. Spec 097's first
  tests asserted the list handed over and passed while a walking party's newly lit torches had flames and
  no pools (the choice was skipped on every frame the camera moved); only a screenshot showed it. Assert
  what the shaders take (`test_097`'s `_drawn`), and look at a shot with the party moving.

## Files

`user://` is one folder shared by every worktree on the machine. A test that writes there takes its path from
`ColonyTest.save_path`, which names it for the process and deletes it after each test and after the last one
(a `Main` with a save store saves again when GUT frees it, after `after_each`):

```gdscript
var _path: String = save_path()  # in test_032_game_speed.gd: user://test_032_game_speed_<pid>.save
var _b: String = save_path("b", "settings")  # user://test_032_game_speed_b_<pid>.settings
```

A test names no `user://` path of its own: the `harness` step fails on a `user://` string literal in a
test script other than `colony_test.gd`, except in an assertion about a game class's `DEFAULT_PATH`.

```gdscript
assert_eq(SaveStore.DEFAULT_PATH, "user://colony.save")  # allowed: the game's own default
```

The `harness` step also fails on a test script that mentions `user://` with no `after_all` in it or a base
it extends, and on a tracked `.gd` without its tracked `.gd.uid`.

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
- `[14.5500001907349] expected to equal [14.55]`: a `Vector2` holds 32-bit floats, a `float` 64. A
  position read back from one (`Expedition.hero_position(id).x`) is not `==` the `float` it was made from
  (`Combatant.x`) unless that is a whole or half tile: use `assert_almost_eq`, or compare two `Vector2`s.
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
  When a spec's tests outgrow one file, move the helpers they share into a base with no tests of its own
  (spec 050's `tests/unit/ability_kit_test_base.gd`, which `extends ColonyTest`) and have each test file
  `extends "res://tests/unit/ability_kit_test_base.gd"`; a helper another spec could use goes on
  `ColonyTest` instead. If GUT then says `Ignoring script ... because it does not extend GutTest`, the
  script (or its parent) failed to parse: `check --only=compile` names the line.
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
- **A view told by a signal needs a test that starts with the state already there.** A content that
  announces its count during its own setup does so before anything listens (the `Hud` is set up before
  `UiRoot`), and never again while the count stays the same: spec 075 lost the Camp tag on a loaded save this
  way, and its test, which began from no gold, could not see it. Load a save that already has the state.
- **A rule about source text is a `harness` check, never a GUT test.** A GUT test asserts what is shown or
  returned. A standing rule only the source can show (no call to X outside one file, a file under a cap)
  goes in `tools/dev.py`: a check in `rule_problems` that names the file and line and says what to do
  instead, or a row in `CAPS`, with a test in `tools/tests/` that builds a made-up tree with the mistake in
  it (`test_082_text_rules.py`). A test that only proves a refactor happened (a name is gone, a call
  moved) is not written: it fails on a harmless rename and catches nothing new; the reviewer reads the diff.
- **A failing run prints only its last 400 lines.** A test that fails an assert for every seed and stage
  fills them, and the names of the other failing tests are cut off: `Failing Tests 4` with two names in
  sight. Keep the output (`python tools/dev.py test --shard=2/4 > .shots/shard2.log 2>&1`), and when the
  names are still missing run the scripts of that shard one at a time with `--only=`. Do not pipe a shard
  through a `grep` that keeps a few lines round each failure: it loses the same names.
- **`check` runs each lint on the repository once.** A tool test tries the lint on a made-up tree; it does
  not run it on the repository again, and it does not call a real step that runs the tool tests (patch
  `dev.run` and read the commands, as `test_077`'s art step test does).
