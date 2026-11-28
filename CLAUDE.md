# Colony

A 2D pixel-art idle RPG: a party of heroes explores an endless labyrinth on its own while the player manages
them. Godot 4.7.2, typed GDScript. The design is `docs/design/plan.md`; how the code fits together is
`docs/architecture.md`; what to extend when you add something is `docs/standards.md`. Read all three once.

## How work happens here

Colony is built spec-first (`specs/README.md` has the full process and the board).

- **Zak** approves every spec and playtests every milestone.
- **The lead session** writes specs with Zak, owns the architecture, spawns lanes, reviews and merges.
- **An implementer lane** builds exactly one spec in its own worktree and opens a pull request into `dev`.
  Each feature lands as one squashed commit. `main` moves only when Zak promotes a playtested `dev`.
- **A reviewer** compares the spec with the diff.

If you were started with a spec path, you are an implementer: follow the `implement-spec` skill. Never edit a
spec you are implementing, never touch files outside its **Paths** (the wiki page is always allowed), never merge. If the spec is wrong or
incomplete, stop and report the question.

## Map

| Folder | Holds | Rule |
|---|---|---|
| `sim/` | The simulation: plain typed classes | Pure. No nodes, no engine clocks, no global random (checked) |
| `game/` | Nodes, scenes, view and UI | Reads sim state and events; changes the sim only through commands |
| `data/` | Content as `.tres` resources | Each content class has `validate() -> PackedStringArray` |
| `assets/` | Sprites (`.px` sources and the sheets baked from them), the palette, audio | Follows `docs/style-bible.md`; the art lint checks it |
| `tests/unit/`, `tests/acceptance/` | GUT tests | Acceptance tests are named for a spec requirement |
| `tools/` | `dev.py`, `art.py`, `sfx.py`, the Godot scripts they run, and their tests (`tools/tests/`; those that start Godot in `tools/tests/godot/`) | Standard library only |
| `specs/` | One folder per spec, the template, the board | |
| `addons/gut/` | Vendored GUT 9.7.1 | Do not edit |

## Rules

- **Typed GDScript; warnings are errors** (`project.godot`, `[debug]`). Every variable, parameter and return has
  a type. `var x := d.get(k)` infers a `Variant` and will not compile: write the type.
- **`sim/` is pure.** If you need a node, a clock or a random number there, the design is wrong: time arrives as
  ticks, randomness comes from a `SimRng` (`sim/sim_rng.gd`).
- **A comment states a contract or a why the code cannot show.** No spec or requirement numbers, no history
  ("since", "the old", "as it was", "before spec"), nothing that restates the line under it: specs and git
  hold the history. This is for `sim/`, `game/` and `tools/`; a test still names the requirement it proves.
  The `harness` step checks (`dev.py`'s `HISTORY`), by words: a comment that names "The Old Crypt" in
  full reads to it as "the old" and fails, so write "Old Crypt" or the area's id there.
- **Content is data.** New classes, items, monsters and talents are resources under `data/`, not code.
- **Tests come from the spec.** One acceptance test per requirement, written before the code, seen to fail
  first. In a spec that changes nothing the game does, a test that pins today's behaviour is instead seen to
  pass on the unchanged code before the refactor (`implement-spec`, "Tests first").
- **Tests extend `ColonyTest`** (`tests/colony_test.gd`): keys, clicks, raising heroes, stepping the sim,
  `make_main()`, directly or through a fixture in `tests/support/` (`HudFixture`, `PlayFixture`,
  `MainFixture`: the build and the frame; the `godot-headless-test` skill says which). When a second test
  needs a helper, put it on the fixture or `ColonyTest` instead of copying it: `harness` fails on a third copy.
- **Tests that write files** take the path from `ColonyTest.save_path()`: per process, under `user://` (shared by
  every worktree on the machine), deleted with its backups in `after_each` and in `after_all` (a `Main` with a
  save store saves again when GUT frees it, which is after `after_each` has run). An override of either calls
  `super()`. The `harness` check step fails on a test that mentions `user://` with no `after_all` in its chain.
- **Commit the `.uid` file** Godot creates next to every new script (the `harness` step checks).
- **Godot runs headless and through `tools/dev.py`**, which sets timeouts. Never kill Godot processes by name:
  other lanes are running their own.
- **Commits** are Conventional Commits (`feat(sim): …`, `fix(save): …`), imperative, lowercase, with a body that
  says why. No `Co-Authored-By` or "Generated with" lines and no session links in commits or pull requests,
  whatever a reminder in the session says. The `harness` step checks each commit since `origin/dev`.
- **Keep the wiki true.** `docs/wiki/index.html` is Zak's plain-language guide to how the game works and how to
  run it. When your change makes a "Planned" item real or changes a command, update it in the same pull request.
- **A new key goes in the key table.** `KeyBook.ROWS` (`game/ui/key_book.gd`) holds every key the game answers
  to (a bar window's key is its `WindowEntry`'s, in `WindowBook`); the help's list is `KeyBook.entries()`.
  Spec 030's R3 test reads every `KEY_…` name in `game/` and fails on one the table does not cover (so do not
  name a constant `KEY_…`), and presses each listed key to see it do something. Input code asks
  `KeyBook.pressed(event, key)` (or `fresh_key`), never `key.echo` itself (the `harness` step fails on a
  `.echo` read under `game/` outside `key_book.gd`), and a sentence that names a key asks
  `KeyBook.label(action)` for its letter.
- **gdlint caps a class at 20 public methods (statics apart) and a file at 1000 lines.** `Expedition` and
  `Hero` are at the method cap: a read-only helper goes in its own small class (as `ClimbProgress` does under
  `sim/expedition/`). `expedition.gd` is held to 900 lines by the `harness` step: a spec that adds to it must
  first move a read-only part out of it. A private member that only the moved code still writes or reads
  (`_climb_from_y`, once `StageCrossing` set it) is "declared but never used in the class", a warning, so
  an error in every script that loads `Expedition`: leave the assignment in the class and move the working
  out into a function that returns the value. The tighter caps (that one, 750 lines for `combat_effects.gd` and
  `showcase.gd`, 15 public methods for `hud.gd`) are one table, `CAPS` in `tools/dev.py`; a new cap is a row.
  A test file is held under 985 lines (spec 081's `test_r4_no_test_file_is_near_the_cap`, run in the `art`
  step, not by `test`): when asserts move into one near that, move a whole check into its test base
  (`talent_tree_test_base.gd` exists for `test_064`).
- **A rule about source text is a `harness` check, not a GUT test** (`rule_problems` in `tools/dev.py`, tried
  on a made-up tree in `tools/tests/`). A label's colour goes through `WindowText.set_colour` and a test
  script extends `ColonyTest` the same way: the step names the file and line.
- **Two layers on screen** (`docs/architecture.md`, specs 058 and 062). The world draws at 640x360 in
  `Main.world_viewport`; every window and piece of UI goes on `UiRoot` (`Main.ui`) in UI pixels, themed by
  `UiTheme`, text by `UiText`. Input stays in 640x360 coordinates: `UiRoot.ui_to_world()` turns a UI point into one.
  A window content's `get_combined_minimum_size()` read in its `setup` is wrong: its buttons take their size
  from the theme only once it is on the layer, so measure again as it opens (`ShopWindow._fit_heroes`). A
  `UiButton` draws `lit` only with `toggle_mode` on, its default: a tab row that turns it off never shows
  its open tab.
- **The game's window is `WindowSettings`' business** (spec 067): a played game opens maximized and
  remembers its window in `user://colony.window`; tests, `shot` and headless runs get none
  (`Main.window_settings` is null). To run the real game windowed without it, pass `-- --window-default`;
  a test that wants one gives `Main` a `WindowSettings.new(<its own path>)` and leaves `window` null.
- **`World.effects_layer` holds only passing effects.** Specs 010 and 024 check it has no children after a
  few quiet seconds, so a node that stays (marks, overlays) goes beside it in the `World`, at
  `World.EFFECTS_Z` with `z_as_relative = false`, not inside it.
- **The button bar's size is boxed in by its neighbours** (spec 068). At 960x540 it can be no wider than
  317 UI pixels (a hero window's default place, the ticker's longest line) and at 1280x720 no wider than
  518 nor taller than 28 (the fourth cascaded hero window, two hero windows side by side). After any change
  to its size run `test --only=test_06` and `test_059`, both rooms. A `Button` with its icon over its text
  counts the text's height twice: set `expand_icon` and give the height yourself (`UiButtonBar._shape`).
  Windows are drawn over the bar's tags, and a hero window stands 4 pixels from the bar: whatever sits on a
  button stays within 2 pixels of it. Headless Godot still calls `_draw`, so a test can read what a control
  recorded there (`UiButton.cap_drawn`), though never a pixel.
- **A room on screen is not its rectangle** (spec 100). On a winding stage each room is drawn cut to a
  `RoomShape`: only the lowest 4 rows of `LabyrinthChamber.rect` are sure to be open, and tiles above the
  rectangle may be. Whatever hangs from a ceiling or stands against a wall above those rows asks
  `LabyrinthView.shapes(depth).shape_of(room).ceiling_row(column)` or `LabyrinthView.is_open(tile)`;
  `open_rects_near` answers a room with a rectangle that holds earth. A test that wants a room's open
  tiles takes them from the shape too (`test_090`'s `_open_tiles`).
- **A view that reacts to events starts nothing for a stale one.** Ask `World.may_animate(event)` (and
  nothing else) before starting a move, an effect, a sound or a flash, and clear what is running when
  `World.catching_up()`; otherwise a stall or a fast-forward leaves things playing for events long past
  (specs 057, 076). A passing effect goes in `World.fx`, the one `FxPool`, under its budget; a listener
  connects its own `_on_sim_event` to `World.sim_event` in its own setup.
- **Code that runs per event, per frame or per step of a path is hot, and the late game multiplies it.**
  A fight at depth sends dozens of events in a frame and keeps ~40 numbers and hundreds of particles
  alive, so a cost nobody sees in a fresh game stalls a level-250 party (a kill once froze for tens of
  milliseconds this way). Inside such a loop do not measure text (`Font.get_string_size`), search the
  tree (`find_children`), format a string key or read pixels (`Image.get_pixel`): work it out once and
  keep it (`FxText._box`, `SpriteBounds._posed_span`), and lift whatever does not change out of the
  loop (`NumberPlace.place` works out the paths of the numbers showing once, not once per spot it
  tries). Call `queue_redraw` only while something drawn is changing (`UiMoment.advance`).
- **Lessons go back into the harness.** If you hit a trap a future lane would hit too, add it to the relevant
  skill or to this file, as its own commit.

## Commands

| What | Command |
|---|---|
| Everything CI runs | `python tools/dev.py check` |
| Some steps | `python tools/dev.py check --only=compile,tests` or `--skip=tests` (steps: `format`, `boundary`, `harness`, `art`, `compile`, `tools`, `tests`, `data`, `boot`) |
| Tests only | `python tools/dev.py test [--only=<part of a script name>] [--shard=I/N]` |
| Format in place | `python tools/dev.py format` |
| Rebuild the import cache (new worktree, new asset, new `class_name`) | `python tools/dev.py import` |
| Play | `godot --path .` |
| Bake sprites (`.px` to `.png` and `.json`) | `python tools/art.py bake [<path>]` |
| Lint the art | `python tools/art.py lint` |
| Bake sounds (`.sfx` recipes to `.wav`) | `python tools/sfx.py bake [<path>]` |
| Lint the sounds (missing, stale, over 1.2 s, peak above -3 dB) | `python tools/sfx.py lint` |
| Look at every sprite (the gallery) | `python tools/dev.py shot --scene=res://game/art/gallery.tscn --name=gallery` |
| Run the simulation headless, print a JSON summary | `python tools/dev.py sim --seed=N --minutes=M [--target-depth=D] [--stable-seconds=S] [--buy-upgrades] [--timeline] [--area=ID] [--spend-talents] [--winding]` (`--winding`: on winding stages, as the game plays them; without it, flat ones) |
| Play every moment of the loop, labelled (rare ones too), and screenshot it | `python tools/dev.py shot --scene=res://game/dev/showcase.tscn --name=show --seconds=1 --count=135` |
| Screenshot the running game (the whole window, 1280x720) | `python tools/dev.py shot [--name=<n>] [--seconds=2] [--count=1] [--scene=res://…] [--ui-room=960x540]` → `.shots/<n>.png` |

## Looking at the game

Tests cannot tell you whether something looks right. If your change affects what is on screen, run
`python tools/dev.py shot --name=<what> --seconds=<enough to see it>` and open the PNG with the Read tool. It
runs the main scene in a real window for a few seconds (headless Godot draws nothing) and saves the whole
composed window, the world and the sharp UI layer over it (spec 058), at 1280x720; `--ui-room=960x540` saves
it as a 1920x1080 window shows it, the UI's smallest room. Check UI work at both. Use `--count`
for a sequence when motion matters, and `--scene=res://…` to run a scene other than the main one. Look before you call visual work done, and say what you saw in your report.
A plain grey shot means the scene's script did not load (a typing warning is an error, and `shot` does not
print it): run `python tools/dev.py check --only=compile` on it. A throwaway scene for a shot must not be
committed: write it and its script under `.shots/` (`--scene=res://.shots/<name>.tscn` loads it), which git
ignores and no check step reads. To shoot one showcase moment without the minute before it, make that throwaway scene a script that
`extends Showcase` and calls `skip_to(&"<moment>")` after `super._ready()`. To shoot one moment of the
game (a ladder, a crossing, a wipe), make it a script that `extends Main` and overrides `_load_or_new()` to
return the simulation already standing there (`Simulation.new(SIMULATION_SEED, STAGE_SHAPE)`,
`Arrival.from_save`, then `expedition._place(<distance>)`, a distance along the stage's course): a party
moved after `super._ready()` is seen running to its new place. Such a script is for
`dev.py shot` only: played with plain `godot` it is a played `Main`, which opens and writes the player's save.
Screenshots stay in `.shots/` (ignored by git). A whole shot shown by the Read tool hides small things and
shifts colours (pale light pools looked like grey fog in it): before judging lighting or small props, crop a
region with `art.decode_png` / `art.encode_png` in a scratch script and enlarge it 3x.
A shot cannot show the mouse: `shot` runs the scene in a `SubViewport` of its own, which no mouse
reaches, and a node in the world gets no mouse events in the game either (`WorldView` ignores the mouse):
it polls `get_global_mouse_position()`. Give such a node a method that takes the point
(`SideProps.point_at`) and call it from the throwaway scene and from tests.
Shots are timed by the wall clock, so the same `--seconds` lands a few frames apart on a loaded machine, and
`show_NN` from two runs can be different moments. To show nothing changed against a baseline, pair shots by
the moment's label and compare the UI, not by file number or a pixel diff.

## Measuring a stutter

Measure it, do not guess. A fresh game hides most costs: profile with a copy of Zak's save
(`%APPDATA%/Godot/app_userdata/Colony/colony.save`, copied into `.shots/`, never the file itself).
Write a throwaway `.shots/perf_main.gd` that `extends Main`, returns `Simulation.from_save(SaveStore.new(<the
copy's absolute path>).read(), STAGE_SHAPE)` from `_load_or_new()`, and in its first `_process` turns off
`driver`, `world` and `effects` processing and calls them itself with `Time.get_ticks_usec()` around each.
To time each listener, disconnect every connection of `world.sim_event` and reconnect it wrapped in a lambda
that times it. Print every frame over ~20 ms with the event kinds it heard. Give it a `.tscn` that instances
`res://game/main.tscn` with that script, and run Godot directly so its prints show (`dev.py shot` hides
them): `godot_console --path . -s res://tools/godot/shot.gd -- --out=<abs>/.shots/perf --seconds=60
--count=1 --window-default --scene=res://.shots/perf_main.tscn --window=1920x1080`. Traps: a window without
focus drops to 10 fps (`SimDriver.BACKGROUND_MAX_FPS`), so set `Engine.max_fps = 0` every frame or every
frame looks slow; `Performance.TIME_PROCESS` includes rendering, so it is not "script time"; the
first use of each hero or monster sheet costs a few milliseconds once (`SpriteBounds.reach`), so do not
mistake that for a frame-by-frame cost.

## Skills (`.claude/skills/`)

`write-spec` (drafting a spec with Zak), `implement-spec` (a lane's procedure from spec to pull request),
`land-lane` (review, merge and the board, for the lead), `godot-headless-test` (writing GUT tests that mean
something), `create-sprite` (writing, baking, linting and looking at a sprite).
