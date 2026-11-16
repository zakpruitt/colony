# Colony

A 2D pixel-art idle RPG: a party of heroes explores an endless labyrinth on its own while the player manages
them. Godot 4.7.2, typed GDScript. The design is `docs/design/plan.md`; how the code fits together is
`docs/architecture.md`. Read both once.

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
| `tools/` | `dev.py`, `art.py`, the Godot scripts they run, and their tests (`tools/tests/`) | Standard library only |
| `specs/` | One folder per spec, the template, the board | |
| `addons/gut/` | Vendored GUT 9.7.1 | Do not edit |

## Rules

- **Typed GDScript; warnings are errors** (`project.godot`, `[debug]`). Every variable, parameter and return has
  a type. `var x := d.get(k)` infers a `Variant` and will not compile: write the type.
- **`sim/` is pure.** If you need a node, a clock or a random number there, the design is wrong: time arrives as
  ticks, randomness comes from a `SimRng` (`sim/sim_rng.gd`).
- **Content is data.** New classes, items, monsters and talents are resources under `data/`, not code.
- **Tests come from the spec.** One acceptance test per requirement, written before the code, seen to fail first.
- **Tests that write files** use a per-process name under `user://` and delete it: `user://` is shared by every
  worktree on the machine.
- **Commit the `.uid` file** Godot creates next to every new script.
- **Godot runs headless and through `tools/dev.py`**, which sets timeouts. Never kill Godot processes by name:
  other lanes are running their own.
- **Commits** are Conventional Commits (`feat(sim): …`, `fix(save): …`), imperative, lowercase, with a body that
  says why. No `Co-Authored-By` or "Generated with" lines in commits or pull requests.
- **Keep the wiki true.** `docs/wiki/index.html` is Zak's plain-language guide to how the game works and how to
  run it. When your change makes a "Planned" item real or changes a command, update it in the same pull request.
- **Lessons go back into the harness.** If you hit a trap a future lane would hit too, add it to the relevant
  skill or to this file, as its own commit.

## Commands

| What | Command |
|---|---|
| Everything CI runs | `python tools/dev.py check` |
| Some steps | `python tools/dev.py check --only=compile,tests` (steps: `format`, `boundary`, `art`, `compile`, `tests`, `data`, `boot`) |
| Tests only | `python tools/dev.py test [--only=<part of a script name>]` |
| Format in place | `python tools/dev.py format` |
| Rebuild the import cache (new worktree, new asset, new `class_name`) | `python tools/dev.py import` |
| Play | `godot --path .` |
| Bake sprites (`.px` to `.png` and `.json`) | `python tools/art.py bake [<path>]` |
| Lint the art | `python tools/art.py lint` |
| Look at every sprite (the gallery) | `python tools/dev.py shot --scene=res://game/art/gallery.tscn --name=gallery` |
| Run the simulation headless, print a JSON summary | `python tools/dev.py sim --seed=N --minutes=M [--target-depth=D] [--stable-seconds=S]` |
| Screenshot the running game | `python tools/dev.py shot [--name=<n>] [--seconds=2] [--count=1] [--scene=res://…]` → `.shots/<n>.png` |

## Looking at the game

Tests cannot tell you whether something looks right. If your change affects what is on screen, run
`python tools/dev.py shot --name=<what> --seconds=<enough to see it>` and open the PNG with the Read tool. It
runs the main scene in a real window for a few seconds (headless Godot draws nothing) and saves the game's own
640x360 picture. Use `--count`
for a sequence when motion matters, and `--scene=res://…` to run a scene other than the main one. Look before you call visual work done, and say what you saw in your report.
A plain grey shot means the scene's script did not load (a typing warning is an error, and `shot` does not
print it): run `python tools/dev.py check --only=compile` on it. A throwaway scene for a shot must not be
committed.
Screenshots stay in `.shots/` (ignored by git).

## Skills (`.claude/skills/`)

`write-spec` (drafting a spec with Zak), `implement-spec` (a lane's procedure from spec to pull request),
`land-lane` (review, merge and the board, for the lead), `godot-headless-test` (writing GUT tests that mean
something), `create-sprite` (writing, baking, linting and looking at a sprite).
