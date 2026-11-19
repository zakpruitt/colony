#!/usr/bin/env python3
"""Colony's one entry point for checks.

    python tools/dev.py check            every step, in order; what CI runs
    python tools/dev.py check --only=tests,boot
    python tools/dev.py test [--only=NAME]
    python tools/dev.py format           rewrite scripts with gdformat
    python tools/dev.py import           rebuild Godot's import cache
    python tools/dev.py shot [--name=N] [--seconds=S] [--count=C] [--scene=res://...]
                             [--ui-room=WxH]
                                         run the game in a window, save PNGs to .shots/:
                                         the whole window, 1280x720 (--ui-room=960x540:
                                         as a 1920x1080 window shows it)
    python tools/dev.py sim --seed=N --minutes=M [--target-depth=D] [--stable-seconds=S]
                            [--buy-upgrades] [--timeline] [--spend-talents]
                                         run the simulation headless, print a JSON summary

Standard library only. Godot is found through the GODOT environment
variable, else on PATH. Every Godot run has a timeout.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parent.parent

# Pinned so a formatter release cannot change what "formatted" means.
GDTOOLKIT = "gdtoolkit==4.5.0"

# Folders whose .gd files are ours to format and lint (never addons/).
SOURCE_DIRS = ("sim", "game", "data", "tests", "tools")

# A run that prints more than this is stopped (a test that errors every frame never ends by
# itself), and a stopped run reports only this much of its end.
MAX_OUTPUT_BYTES = 64 * 1024 * 1024
TAIL_BYTES = 20_000

# Lines Godot prints when a script or the engine reports an error.
ERROR_MARKERS = ("SCRIPT ERROR", "Parse Error", "ERROR:")

# Names the simulation may not use: they tie it to the scene tree, to real
# time, or to the global random state, any of which breaks headless,
# repeatable runs. See docs/architecture.md.
SIM_FORBIDDEN_NAMES = (
    "Node",
    "Node2D",
    "Control",
    "SceneTree",
    "Engine",
    "Time",
    "OS",
    "Input",
    "DisplayServer",
    "get_tree",
)
SIM_FORBIDDEN_GLOBAL_CALLS = (
    "randi",
    "randf",
    "randfn",
    "randi_range",
    "randf_range",
    "randomize",
    "rand_from_seed",
)
# Array methods that draw from the global random state.
SIM_FORBIDDEN_METHODS = ("pick_random", "shuffle")


class StepFailed(Exception):
    """A check step did not pass; the message says why."""


# ---------------------------------------------------------------- running


def godot_binary() -> str:
    override = os.environ.get("GODOT")
    if override:
        return override
    # On Windows the console build is the one that writes to stdout.
    for name in ("godot_console", "godot"):
        found = shutil.which(name)
        if found:
            return found
    raise StepFailed("Godot not found: put it on PATH or set GODOT")


def run(command: list[str], timeout: int) -> tuple[int, str]:
    """Run a command from the project root; return its exit code and output."""
    return run_capped(command, timeout, MAX_OUTPUT_BYTES)


def run_capped(command: list[str], timeout: int, max_bytes: int) -> tuple[int, str]:
    """As run(), with the output kept in a file and the run stopped if it grows past max_bytes.

    A test that prints an error every frame once wrote gigabytes into this process's memory and
    starved every other lane on the machine, so the output goes to disk and has a limit.
    """
    with tempfile.TemporaryFile() as sink:
        process = subprocess.Popen(command, cwd=ROOT, stdout=sink, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + timeout
        problem = ""
        while process.poll() is None:
            time.sleep(0.2)
            if os.fstat(sink.fileno()).st_size > max_bytes:
                problem = f"stopped: more than {max_bytes // (1024 * 1024)} MB of output"
            elif time.monotonic() > deadline:
                problem = f"timed out after {timeout}s"
            if problem:
                stop_tree(process)
                break
        size = os.fstat(sink.fileno()).st_size
        sink.seek(max(0, size - TAIL_BYTES) if problem else 0)
        output = sink.read().decode("utf-8", errors="replace").replace("\r\n", "\n")
    if problem:
        raise StepFailed(f"{problem}\n{output}")
    return process.returncode, output


def stop_tree(process: subprocess.Popen) -> None:
    """Stop this one process and the children it started (Godot's console build starts another)."""
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(process.pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    else:
        process.kill()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()


def godot(args: list[str], timeout: int) -> tuple[int, str]:
    return run([godot_binary(), "--headless", "--path", str(ROOT), *args], timeout)


def gdtool(tool: str, args: list[str]) -> tuple[int, str]:
    """Run gdformat or gdlint: from PATH if installed, else through uvx."""
    if shutil.which(tool):
        return run([tool, *args], timeout=120)
    if shutil.which("uvx"):
        return run(["uvx", "--from", GDTOOLKIT, tool, *args], timeout=300)
    raise StepFailed(f"{tool} not found: `pip install {GDTOOLKIT}` or install uv")


def error_lines(output: str, markers: tuple[str, ...] = ERROR_MARKERS) -> list[str]:
    return [line for line in output.splitlines() if any(m in line for m in markers)]


def tail(output: str, limit: int = 150) -> str:
    """The end of a long output, so a failure never floods the terminal."""
    lines = output.splitlines()
    if len(lines) <= limit:
        return output
    return f"... ({len(lines) - limit} earlier lines not shown)\n" + "\n".join(lines[-limit:])


def require_clean(code: int, output: str, what: str) -> None:
    errors = error_lines(output)
    if code != 0 or errors:
        shown = "\n".join(errors[:40]) if errors else tail(output)
        raise StepFailed(f"{what} failed (exit {code})\n{shown}")


def source_files() -> list[str]:
    files: list[str] = []
    for folder in SOURCE_DIRS:
        files += sorted(str(p.relative_to(ROOT)) for p in (ROOT / folder).rglob("*.gd"))
    return files


# ------------------------------------------------------------------ steps


def step_format() -> str:
    files = source_files()
    if not files:
        return "no scripts"
    code, output = gdtool("gdformat", ["--check", *files])
    if code != 0:
        raise StepFailed(f"gdformat: run `python tools/dev.py format`\n{output}")
    code, output = gdtool("gdlint", files)
    if code != 0:
        raise StepFailed(f"gdlint\n{output}")
    return f"{len(files)} scripts"


def strip_comments_and_strings(line: str) -> str:
    """Drop string literals and the trailing comment from one GDScript line."""
    line = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '""', line)
    return line.split("#", 1)[0]


def step_boundary() -> str:
    names = re.compile(r"(?<![\w.])(" + "|".join(SIM_FORBIDDEN_NAMES) + r")\b")
    calls = re.compile(r"(?<![\w.])(" + "|".join(SIM_FORBIDDEN_GLOBAL_CALLS) + r")\s*\(")
    methods = re.compile(r"\.(" + "|".join(SIM_FORBIDDEN_METHODS) + r")\s*\(")
    problems: list[str] = []
    files = sorted((ROOT / "sim").rglob("*.gd"))
    for path in files:
        for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = strip_comments_and_strings(raw)
            for pattern in (names, calls, methods):
                for match in pattern.finditer(line):
                    where = f"{path.relative_to(ROOT).as_posix()}:{number}"
                    problems.append(f"{where}: `{match.group(1)}` is not allowed in sim/")
    if problems:
        raise StepFailed("\n".join(problems))
    return f"{len(files)} sim scripts"


def tracked_files(pattern: str, root: Path = ROOT) -> list[str]:
    """The files git tracks under [root] matching [pattern], as posix paths relative to it."""
    code, output = run(["git", "-C", str(root), "ls-files", "--", pattern], timeout=60)
    if code != 0:
        raise StepFailed(f"git ls-files failed (exit {code})\n{tail(output)}")
    return sorted(line.strip() for line in output.splitlines() if line.strip())


def script_parent(text: str, scripts: dict[str, str]) -> str | None:
    """The script (a res:// relative path) that a GDScript's `extends` names, if it is one of ours."""
    match = re.search(r"^extends\s+(\S+)", text, re.MULTILINE)
    if not match:
        return None
    parent = match.group(1)
    if parent.startswith('"res://'):
        return parent.strip('"')[len("res://") :]
    return scripts.get(parent)


def harness_problems(root: Path = ROOT) -> list[str]:
    """Two of the written rules (spec 071) as checks, on the files git tracks under [root].

    A test script that mentions user:// cleans up in after_all, itself or in a base it extends
    (a Main freed by GUT saves again after after_each). Every tracked .gd has its .gd.uid.
    """
    problems: list[str] = []
    scripts = tracked_files("*.gd", root)
    uids = set(tracked_files("*.gd.uid", root))
    for script in scripts:
        if script + ".uid" not in uids:
            name = Path(script).name
            problems.append(f"{script}: no {name}.uid beside it; commit the one Godot made")
    texts = {
        script: (root / script).read_text(encoding="utf-8")
        for script in scripts
        if (root / script).is_file()
    }
    class_names: dict[str, str] = {}
    for script, text in texts.items():
        match = re.search(r"^class_name\s+(\w+)", text, re.MULTILINE)
        if match:
            class_names[match.group(1)] = script
    for script, text in texts.items():
        if not script.startswith("tests/") or "user://" not in text:
            continue
        current: str | None = script
        seen: set[str] = set()
        cleans = False
        while current is not None and current in texts and current not in seen:
            seen.add(current)
            if re.search(r"^func after_all\(", texts[current], re.MULTILINE):
                cleans = True
                break
            current = script_parent(texts[current], class_names)
        if not cleans:
            problems.append(
                f"{script}: mentions user:// but neither it nor a base it extends defines after_all"
            )
    return problems


def step_harness() -> str:
    problems = harness_problems()
    if problems:
        raise StepFailed("\n".join(problems))
    return "tests clean up, every script has its uid"


def step_art() -> str:
    """The art pipeline's own tests, then the art and sound lints (specs 002, 021)."""
    python = sys.executable or "python"
    code, output = run([python, "-m", "unittest", "discover", "-s", "tools/tests"], timeout=300)
    if code != 0:
        raise StepFailed(f"tools/tests failed (exit {code})\n{tail(output)}")
    tests = re.search(r"^Ran (\d+) tests?", output, re.MULTILINE)
    code, output = run([python, "tools/art.py", "lint"], timeout=300)
    if code != 0:
        raise StepFailed(f"fix these, then `python tools/art.py bake`\n{tail(output)}")
    art = output.strip().splitlines()[-1]
    # The sound lint (spec 021) belongs here too: sounds are baked from recipes like sprites.
    code, output = run([python, "tools/sfx.py", "lint"], timeout=300)
    if code != 0:
        raise StepFailed(f"fix these, then `python tools/sfx.py bake`\n{tail(output)}")
    count = tests.group(1) if tests else "0"
    return f"{count} tool tests, {art}, {output.strip().splitlines()[-1]}"


def import_project() -> None:
    """Build Godot's import cache; raise StepFailed if scripts do not parse.

    Anything that runs Godot from a fresh checkout calls this first.
    """
    code, output = godot(["--import"], timeout=600)
    if code == 0 and error_lines(output):
        # On a fresh checkout Godot loads the project (its theme, for one)
        # before it has imported the assets that depends on, and reports
        # errors that a second pass does not have. Judge the second pass.
        code, output = godot(["--import"], timeout=600)
    if code != 0 or error_lines(output, ("SCRIPT ERROR", "Parse Error")):
        shown = "\n".join(error_lines(output)[:40]) or tail(output)
        raise StepFailed(f"import failed (exit {code})\n{shown}")


def step_compile() -> str:
    import_project()
    code, output = godot(["-s", "res://tools/godot/compile_all.gd"], timeout=300)
    require_clean(code, output, "compile")
    return last_line(output, "[compile]")


def step_tests(only: str | None = None) -> str:
    args = ["-s", "res://addons/gut/gut_cmdln.gd", "-gexit"]
    if only:
        args.append(f"-gselect={only}")
    # The whole suite takes about 12 minutes in CI and has taken 25 on a busy machine.
    code, output = godot(args, timeout=2700)
    if code != 0 or error_lines(output, ("SCRIPT ERROR", "Parse Error")):
        raise StepFailed(f"tests failed (exit {code})\n{tail(output, 400)}")
    passing = re.search(r"^\s*Passing(?: Tests)?\s+(\d+)", output, re.MULTILINE)
    if not passing or int(passing.group(1)) == 0:
        raise StepFailed(f"no passing tests were reported\n{output}")
    return f"{passing.group(1)} passing"


def step_data() -> str:
    code, output = godot(["-s", "res://tools/godot/validate_data.gd"], timeout=300)
    require_clean(code, output, "data validation")
    return last_line(output, "[data]")


def step_boot() -> str:
    code, output = godot(["--quit-after", "120"], timeout=120)
    require_clean(code, output, "boot")
    return "120 frames, no errors"


def last_line(output: str, prefix: str) -> str:
    lines = [line for line in output.splitlines() if line.startswith(prefix)]
    return lines[-1][len(prefix) :].strip() if lines else "ok"


STEPS: dict[str, Callable[[], str]] = {
    "format": step_format,
    "boundary": step_boundary,
    "harness": step_harness,
    "art": step_art,
    "compile": step_compile,
    "tests": step_tests,
    "data": step_data,
    "boot": step_boot,
}


# --------------------------------------------------------------- commands


def run_steps(names: list[str]) -> int:
    for name in names:
        started = time.monotonic()
        try:
            summary = STEPS[name]()
        except StepFailed as failure:
            print(f"[{name}] FAIL\n{failure}")
            print(f"\ncheck: FAIL at `{name}`")
            return 1
        print(f"[{name}] ok ({summary}, {time.monotonic() - started:.1f}s)")
    print("\ncheck: PASS")
    return 0


def command_check(args: argparse.Namespace) -> int:
    names = list(STEPS)
    if args.only:
        names = [name.strip() for name in args.only.split(",")]
        unknown = [name for name in names if name not in STEPS]
        if unknown:
            print(f"unknown step(s): {', '.join(unknown)}; steps are {', '.join(STEPS)}")
            return 2
    return run_steps(names)


def command_test(args: argparse.Namespace) -> int:
    try:
        print(f"[tests] ok ({step_tests(args.only)})")
    except StepFailed as failure:
        print(f"[tests] FAIL\n{failure}")
        return 1
    return 0


def command_format(_args: argparse.Namespace) -> int:
    try:
        code, output = gdtool("gdformat", source_files())
    except StepFailed as failure:
        print(failure)
        return 1
    print(output.strip())
    return code


def command_import(_args: argparse.Namespace) -> int:
    try:
        import_project()
    except StepFailed as failure:
        print(failure)
        return 1
    return 0


# The world's own size, and the least room the UI layer is given (game/ui/ui_root.gd, spec 058).
WORLD_SIZE = (640, 360)
MIN_ROOM = (960, 540)


def ui_room_for(window: tuple[int, int]) -> tuple[int, int]:
    """The UI layer's room in a window of this size, as UiRoot.room_for works it out."""
    world = max(1, min(window[0] // WORLD_SIZE[0], window[1] // WORLD_SIZE[1]))
    shown = (WORLD_SIZE[0] * world, WORLD_SIZE[1] * world)
    ui = max(1, min(shown[0] // MIN_ROOM[0], shown[1] // MIN_ROOM[1]))
    return (shown[0] // ui, shown[1] // ui)


def shot_window(ui_room: str) -> tuple[int, int]:
    """The smallest window whose UI room is `ui_room` ("960x540" is a 1920x1080 window)."""
    match = re.fullmatch(r"(\d+)x(\d+)", ui_room.strip())
    if not match:
        raise StepFailed(f"--ui-room wants WIDTHxHEIGHT, not {ui_room!r}")
    room = (int(match.group(1)), int(match.group(2)))
    for times in range(1, 5):
        window = (room[0] * times, room[1] * times)
        if ui_room_for(window) == room:
            return window
    raise StepFailed(f"no window gives the UI a room of {ui_room}")


def shot_command(args: argparse.Namespace, out: str) -> list[str]:
    """The Godot command a shot runs, saving to `out` (a path without its extension)."""
    command = [
        godot_binary(),
        "--path",
        str(ROOT),
        "-s",
        "res://tools/godot/shot.gd",
        "--",
        f"--out={out}",
        f"--seconds={args.seconds}",
        f"--count={args.count}",
        # Spec 067: the window as the project opens it, never maximized or as the player left it.
        "--window-default",
    ]
    if args.scene:
        command.append(f"--scene={args.scene}")
    window = shot_window(args.ui_room)
    command.append(f"--window={window[0]}x{window[1]}")
    return command


def command_shot(args: argparse.Namespace) -> int:
    """Run the game in a real window (not headless) and save screenshots of the whole window."""
    folder = ROOT / ".shots"
    folder.mkdir(exist_ok=True)
    # Keeps Godot from importing the screenshots as game assets.
    (folder / ".gdignore").touch()
    try:
        command = shot_command(args, (folder / args.name).as_posix())
        code, output = run(command, timeout=int(args.seconds * args.count) + 60)
    except StepFailed as failure:
        print(failure)
        return 1
    saved = [line for line in output.splitlines() if line.startswith("[shot]")]
    print("\n".join(saved) if saved and code == 0 else output)
    return code


def command_sim(args: argparse.Namespace) -> int:
    """Run the simulation headless for some game time and print its JSON summary."""
    options = [f"--seed={args.seed}", f"--minutes={args.minutes}"]
    if args.target_depth is not None:
        options.append(f"--target-depth={args.target_depth}")
    if args.stable_seconds is not None:
        options.append(f"--stable-seconds={args.stable_seconds}")
    if args.buy_upgrades:
        options.append("--buy-upgrades=true")
    if args.timeline:
        options.append("--timeline=true")
    if args.area is not None:
        options.append(f"--area={args.area}")
    if args.spend_talents:
        options.append("--spend-talents=true")
    try:
        # The script needs every class_name registered; a fresh checkout has no cache yet.
        import_project()
        # About a minute of real time per ten hours of game time, plus start-up.
        timeout = 120 + int(args.minutes * 2)
        code, output = godot(["-s", "res://tools/godot/run_sim.gd", "--", *options], timeout)
        require_clean(code, output, "sim")
    except StepFailed as failure:
        print(failure)
        return 1
    summaries = [line for line in output.splitlines() if line.startswith("[sim] ")]
    if not summaries:
        print(f"the run printed no summary\n{tail(output)}")
        return 1
    print(summaries[-1][len("[sim] ") :])
    return 0


def build_parser() -> argparse.ArgumentParser:
    """The command line: a sub-command per thing dev.py does."""
    parser = argparse.ArgumentParser(description="Colony checks and dev commands.")
    commands = parser.add_subparsers(dest="command", required=True)

    check = commands.add_parser("check", help="run every check step (what CI runs)")
    check.add_argument("--only", help=f"comma-separated steps: {', '.join(STEPS)}")
    check.set_defaults(handler=command_check)

    test = commands.add_parser("test", help="run the GUT tests")
    test.add_argument("--only", help="run only test scripts whose name contains this")
    test.set_defaults(handler=command_test)

    commands.add_parser("format", help="format scripts in place").set_defaults(
        handler=command_format
    )
    commands.add_parser("import", help="rebuild Godot's import cache").set_defaults(
        handler=command_import
    )

    shot = commands.add_parser("shot", help="run the game windowed and save screenshots")
    shot.add_argument("--name", default="shot", help="file name without extension")
    shot.add_argument("--seconds", type=float, default=2.0, help="run time before each shot")
    shot.add_argument("--count", type=int, default=1, help="number of shots")
    shot.add_argument("--scene", help="res:// scene to run instead of the main scene")
    shot.add_argument(
        "--ui-room",
        default="1280x720",
        help="the UI layer's room: 1280x720 (a 1280x720 window) or 960x540 (1920x1080)",
    )
    shot.set_defaults(handler=command_shot)

    sim = commands.add_parser("sim", help="run the simulation headless and print a JSON summary")
    sim.add_argument("--seed", type=int, default=1, help="the simulation's seed")
    sim.add_argument("--minutes", type=float, default=10.0, help="game time to run")
    sim.add_argument("--target-depth", type=int, help="set this target depth at the start")
    sim.add_argument("--stable-seconds", type=float, help="seconds for a depth to become stable")
    sim.add_argument(
        "--buy-upgrades",
        action="store_true",
        help="buy the cheapest affordable camp upgrade whenever the party can",
    )
    sim.add_argument(
        "--timeline",
        action="store_true",
        help="add the game time in seconds of each first (level 2, depth 5, first guardian ...)",
    )
    sim.add_argument(
        "--spend-talents",
        action="store_true",
        help="spend talent points (trunk, then the first path) and paragon points (Power)",
    )
    sim.add_argument(
        "--area",
        help="send the party to this area (an id, e.g. claypits) at the start, opening it",
    )
    sim.set_defaults(handler=command_sim)
    return parser


def main() -> int:
    parser = build_parser()

    # Godot's output can hold characters a Windows console cannot encode.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="replace")

    args = parser.parse_args()
    return args.handler(args)


if __name__ == "__main__":
    sys.exit(main())
