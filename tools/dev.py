#!/usr/bin/env python3
"""Colony's one entry point for checks.

    python tools/dev.py check            every step, in order
    python tools/dev.py check --only=tests,boot
    python tools/dev.py check --skip=tests     every step but these
    python tools/dev.py test [--only=NAME] [--shard=I/N]
                                         the GUT tests; --shard=I/N runs the I-th of N parts
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
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import tokenize
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

# The shared test base, the one test script that may name a user:// path.
SHARED_TEST_BASE = "tests/colony_test.gd"

# Set once a process has imported the project; a dev.py started under it skips its own import.
IMPORTED = "COLONY_PROJECT_IMPORTED"

# The tool tests that start Godot, run by the `tools` step after `compile` instead of by `art`.
GODOT_TOOL_TESTS = "tools/tests/godot"

# Where GUT finds the test scripts, as .gutconfig.json says (its dirs with subfolders, prefix,
# suffix): a shard lists its scripts itself, and must find the ones a whole run finds.
TEST_DIR = "tests"
TEST_PREFIX = "test_"
TEST_SUFFIX = ".gd"

# How long each slow GUT script takes, in seconds, so the shards come out even.
TEST_TIMES = Path(__file__).resolve().parent / "test_times.json"
# What a script missing from TEST_TIMES is reckoned to take.
USUAL_TEST_SECONDS = 4.0

# Comment text that names a spec or a requirement, or tells history.
HISTORY = (
    r"(?i)\bspec \d",
    r"(?i)\bsince spec",
    r"(?i)\bthe old\b",
    r"(?i)\bas it was\b",
    r"(?i)\bas it did before\b",
    r"\bR\d+\b",
)
# game/ is held to more: a comment pointing at "the spec" tells a reader no more than its number.
GAME_HISTORY = (r"(?i)\bspecs?\b",)

# A commit carries none of these: Zak's rule in CLAUDE.md.
ATTRIBUTION = (
    (r"(?im)^\s*co-authored-by:", "a Co-Authored-By line"),
    (r"(?m)^\W*Generated with\b", 'a "Generated with" line'),
    (r"claude\.ai/code/session", "a session link"),
)

# gdlint's limits (its defaults), and how near to them the harness step starts to warn.
MAX_FILE_LINES = 1000
FILE_LINES_WARNING = 15
MAX_PUBLIC_METHODS = 20
PUBLIC_METHODS_WARNING = 1

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
    """Two of the written rules as checks, on the files git tracks under [root].

    A test script names no user:// path of its own (ColonyTest.save_path hands them out and
    deletes them), except in an assertion about a game class's DEFAULT_PATH. A test script that
    mentions user:// cleans up in after_all, itself or in a base it extends (a Main freed by GUT
    saves again after after_each). Every tracked .gd has its .gd.uid.
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
        if not script.startswith("tests/") or script == SHARED_TEST_BASE:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            literals = re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', line)
            if not any("user://" in literal for literal in literals):
                continue
            # The one kind of line allowed: an assertion about the game's own default path.
            if re.match(r"\s*assert_\w+\(", line) and "DEFAULT_PATH" in line:
                continue
            problems.append(
                f"{script}:{number}: a user:// path of its own; take one from"
                " ColonyTest.save_path(), which deletes it"
            )
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


def gd_comment(line: str) -> str:
    """The comment on one GDScript line, from its # to the end, or "" if it has none."""
    quote = ""
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = ""
        elif c in "\"'":
            quote = c
        elif c == "#":
            return line[i:]
        i += 1
    return ""


def py_comments(text: str) -> list[tuple[int, str, bool]]:
    """Each comment in Python source as (line, text, whether it stands on a line of its own).

    Raises tokenize.TokenError or SyntaxError on source that does not tokenize.
    """
    found: list[tuple[int, str, bool]] = []
    for token in tokenize.generate_tokens(io.StringIO(text).readline):
        if token.type == tokenize.COMMENT:
            whole = token.line.strip().startswith("#")
            found.append((token.start[0], token.string, whole))
    return found


def comments(path: Path) -> list[tuple[int, str]]:
    """The comments in a script as (first line, text): a run of whole-line comments joined into
    one text, so a reference wrapped over two lines is read whole, and a comment after code alone.
    """
    text = path.read_text(encoding="utf-8")
    if path.suffix == ".py":
        each = py_comments(text)
    else:
        each = []
        for number, line in enumerate(text.splitlines(), 1):
            comment = gd_comment(line)
            if comment:
                each.append((number, comment, line.strip().startswith("#")))
    found: list[tuple[int, str]] = []
    run_start = 0
    run: list[str] = []
    last = 0
    for number, comment, whole in each:
        words = comment.lstrip("#").strip()
        if whole and run and number == last + 1:
            run.append(words)
        else:
            if run:
                found.append((run_start, " ".join(run)))
                run = []
            if whole:
                run_start, run = number, [words]
            else:
                found.append((number, words))
        last = number
    if run:
        found.append((run_start, " ".join(run)))
    return found


def comment_scripts(root: Path) -> list[Path]:
    """The scripts held to the comment rule: sim/, game/, tools/ but its tests, the test base."""
    found: list[Path] = []
    for folder in ("sim", "game", "tools"):
        for path in sorted((root / folder).rglob("*")):
            relative = path.relative_to(root).as_posix()
            if path.suffix in (".gd", ".py") and not relative.startswith("tools/tests/"):
                found.append(path)
    if (root / SHARED_TEST_BASE).is_file():
        found.append(root / SHARED_TEST_BASE)
    return found


def comment_problems(root: Path = ROOT) -> list[str]:
    """Every comment that names a spec or requirement or tells history (CLAUDE.md's rule)."""
    history = [re.compile(pattern) for pattern in HISTORY]
    game = history + [re.compile(pattern) for pattern in GAME_HISTORY]
    problems: list[str] = []
    for path in comment_scripts(root):
        relative = path.relative_to(root).as_posix()
        patterns = game if relative.startswith("game/") else history
        try:
            found = comments(path)
        except (tokenize.TokenError, SyntaxError) as failure:
            problems.append(f"{relative}: its comments cannot be read, as it does not tokenize: {failure}")
            continue
        for number, text in found:
            if any(pattern.search(text) for pattern in patterns):
                problems.append(
                    f"{relative}:{number}: a comment that names a spec or tells history: {text}"
                )
    return problems


def git_in(root: Path, args: list[str]) -> tuple[int, str]:
    return run(["git", "-C", str(root), *args], timeout=60)


def commit_range(root: Path = ROOT) -> list[str]:
    """The commits on this branch as `git log` arguments: origin/dev..HEAD, or HEAD alone with no
    origin/dev to compare with (a shallow checkout), or none in a repository with no commit.
    """
    code, _ = git_in(root, ["rev-parse", "--verify", "-q", "HEAD"])
    if code != 0:
        return []
    code, _ = git_in(root, ["rev-parse", "--verify", "-q", "origin/dev"])
    return ["origin/dev..HEAD"] if code == 0 else ["-1", "HEAD"]


def attribution_problems(root: Path = ROOT) -> list[str]:
    """Each commit in commit_range whose message carries an attribution line or a session link."""
    commits = commit_range(root)
    if not commits:
        return []
    code, output = git_in(root, ["log", "--format=%h %s%x00%B%x1e", *commits])
    if code != 0:
        raise StepFailed(f"git log failed (exit {code})\n{tail(output)}")
    problems: list[str] = []
    for entry in output.split("\x1e"):
        if "\x00" not in entry:
            continue
        name, message = entry.strip("\n").split("\x00", 1)
        for pattern, what in ATTRIBUTION:
            if re.search(pattern, message):
                problems.append(f"commit {name}: {what}; reword it out (CLAUDE.md, Commits)")
    return problems


def cap_warnings(root: Path = ROOT) -> list[str]:
    """Each script near gdlint's limit on lines or on a class's public methods."""
    warnings: list[str] = []
    for folder in SOURCE_DIRS:
        for path in sorted((root / folder).rglob("*.gd")):
            text = path.read_text(encoding="utf-8")
            relative = path.relative_to(root).as_posix()
            lines = len(text.splitlines())
            if lines >= MAX_FILE_LINES - FILE_LINES_WARNING:
                warnings.append(f"{relative}: {lines} lines; gdlint stops at {MAX_FILE_LINES}")
            # gdlint counts a class's functions without a leading _, not its static ones.
            public = len(re.findall(r"^func\s+[A-Za-z]", text, re.MULTILINE))
            if public >= MAX_PUBLIC_METHODS - PUBLIC_METHODS_WARNING:
                warnings.append(
                    f"{relative}: {public} public methods; gdlint stops at {MAX_PUBLIC_METHODS}"
                )
    return warnings


def step_harness(root: Path = ROOT) -> str:
    commits = commit_range(root)
    shown = " ".join(commits).replace("-1 HEAD", "HEAD alone (no origin/dev)") or "none"
    print(f"[harness] commits read for attribution lines: {shown}")
    problems = harness_problems(root) + comment_problems(root) + attribution_problems(root)
    if problems:
        raise StepFailed("\n".join(problems))
    warnings = cap_warnings(root)
    for warning in warnings:
        print(f"[harness] near a cap: {warning}")
    return (
        "tests clean up, every script has its uid, comments and commits are clean,"
        f" {len(warnings)} near a lint cap"
    )


def tool_tests(folder: str, timeout: int) -> str:
    """Run the Python tests in one folder (not the folders under it); return how many ran."""
    python = sys.executable or "python"
    command = [python, "-m", "unittest", "discover", "-s", folder, "-t", folder]
    code, output = run(command, timeout=timeout)
    if code != 0:
        raise StepFailed(f"{folder} failed (exit {code})\n{tail(output)}")
    tests = re.search(r"^Ran (\d+) tests?", output, re.MULTILINE)
    return tests.group(1) if tests else "0"


def step_art() -> str:
    """The tool tests that need no Godot, then the art and sound lints."""
    python = sys.executable or "python"
    count = tool_tests("tools/tests", timeout=300)
    code, output = run([python, "tools/art.py", "lint"], timeout=300)
    if code != 0:
        raise StepFailed(f"fix these, then `python tools/art.py bake`\n{tail(output)}")
    art = output.strip().splitlines()[-1]
    # The sound lint belongs here too: sounds are baked from recipes like sprites.
    code, output = run([python, "tools/sfx.py", "lint"], timeout=300)
    if code != 0:
        raise StepFailed(f"fix these, then `python tools/sfx.py bake`\n{tail(output)}")
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


def ensure_imported() -> None:
    """Import the project unless this process, or the dev.py that started it, already has.

    Every step that runs Godot calls this, so a check imports once and a step run alone still
    imports for itself.
    """
    if os.environ.get(IMPORTED) == "1":
        return
    import_project()
    os.environ[IMPORTED] = "1"


def step_compile() -> str:
    ensure_imported()
    code, output = godot(["-s", "res://tools/godot/compile_all.gd"], timeout=300)
    require_clean(code, output, "compile")
    return last_line(output, "[compile]")


def step_tools() -> str:
    """The tool tests that start Godot: the headless sim runs and the real shots."""
    ensure_imported()
    return f"{tool_tests(GODOT_TOOL_TESTS, timeout=1800)} tool tests that run Godot"


def test_scripts(root: Path = ROOT) -> list[str]:
    """Every GUT test script, as a path relative to [root], found as .gutconfig.json finds them."""
    found = (root / TEST_DIR).rglob(f"{TEST_PREFIX}*{TEST_SUFFIX}")
    return sorted(path.relative_to(root).as_posix() for path in found)


def parse_shard(text: str) -> tuple[int, int]:
    """`I/N` as (I, N), refusing anything but 1 <= I <= N."""
    match = re.fullmatch(r"(\d+)/(\d+)", text.strip())
    if not match or not 1 <= int(match.group(1)) <= int(match.group(2)):
        raise argparse.ArgumentTypeError(f"a shard is I/N with 1 <= I <= N, not {text!r}")
    return int(match.group(1)), int(match.group(2))


def shard_scripts(scripts: list[str], index: int, count: int) -> list[str]:
    """The [index]-th of [count] parts of [scripts], the same whatever order they come in.

    The slowest go first, each to the part with the least time so far (the lower part on a tie),
    by the times in TEST_TIMES; a script it does not list counts as USUAL_TEST_SECONDS.
    """
    times: dict[str, float] = json.loads(TEST_TIMES.read_text(encoding="utf-8"))
    parts: list[list[str]] = [[] for _ in range(count)]
    loads = [0.0] * count
    for script in sorted(scripts, key=lambda s: (-times.get(s, USUAL_TEST_SECONDS), s)):
        lightest = loads.index(min(loads))
        parts[lightest].append(script)
        loads[lightest] += times.get(script, USUAL_TEST_SECONDS)
    return sorted(parts[index - 1])


def step_tests(only: str | None = None, shard: tuple[int, int] | None = None) -> str:
    args = ["-s", "res://addons/gut/gut_cmdln.gd", "-gexit"]
    which = ""
    if shard:
        index, count = shard
        every = test_scripts()
        scripts = shard_scripts(every, index, count)
        if not scripts:
            raise StepFailed(f"shard {index}/{count} holds no script: there are {len(every)}")
        if only:
            if not any(only in Path(script).name for script in every):
                raise StepFailed(f"--only={only} matches no test script")
            scripts = [script for script in scripts if only in Path(script).name]
            if not scripts:
                return f"no script in shard {index}/{count} matches {only!r}; other shards hold them"
        which = f", shard {index}/{count}: {len(scripts)} script{'' if len(scripts) == 1 else 's'}"
        # Without the config file, whose folder would add every script back.
        listed = ",".join(f"res://{script}" for script in scripts)
        args += ["-gconfig=", "-glog=1", f"-gtest={listed}"]
    elif only:
        args.append(f"-gselect={only}")
    # The whole suite takes about 17 minutes in one CI job and has taken 25 on a busy machine.
    ensure_imported()
    code, output = godot(args, timeout=2700)
    if code != 0 or error_lines(output, ("SCRIPT ERROR", "Parse Error")):
        raise StepFailed(f"tests failed (exit {code})\n{tail(output, 400)}")
    passing = re.search(r"^\s*Passing(?: Tests)?\s+(\d+)", output, re.MULTILINE)
    if not passing or int(passing.group(1)) == 0:
        raise StepFailed(f"no passing tests were reported\n{output}")
    return f"{passing.group(1)} passing{which}"


def step_data() -> str:
    ensure_imported()
    code, output = godot(["-s", "res://tools/godot/validate_data.gd"], timeout=300)
    require_clean(code, output, "data validation")
    return last_line(output, "[data]")


def step_boot() -> str:
    ensure_imported()
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
    "tools": step_tools,
    "tests": step_tests,
    "data": step_data,
    "boot": step_boot,
}


# --------------------------------------------------------------- commands


def tree_state() -> str:
    """The commit checked and whether the tree differs from it, for the first line of a run."""
    code, head = run(["git", "rev-parse", "--short", "HEAD"], timeout=60)
    if code != 0:
        return "not in a git repository"
    code, status = run(["git", "status", "--porcelain"], timeout=60)
    changed = "with uncommitted changes" if code != 0 or status.strip() else "clean"
    return f"on {head.strip()}, {changed}"


def run_steps(names: list[str]) -> int:
    print(f"[tree] {tree_state()}")
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


def step_names(listed: str | None) -> list[str]:
    """The steps named in a comma-separated list; raise ValueError naming any unknown one."""
    names = [name.strip() for name in (listed or "").split(",") if name.strip()]
    unknown = [name for name in names if name not in STEPS]
    if unknown:
        raise ValueError(f"unknown step(s): {', '.join(unknown)}; steps are {', '.join(STEPS)}")
    return names


def command_check(args: argparse.Namespace) -> int:
    try:
        only = step_names(args.only)
        skip = step_names(getattr(args, "skip", None))
    except ValueError as failure:
        print(failure)
        return 2
    names = [name for name in (only or list(STEPS)) if name not in skip]
    return run_steps(names)


def command_test(args: argparse.Namespace) -> int:
    print(f"[tree] {tree_state()}")
    try:
        print(f"[tests] ok ({step_tests(args.only, args.shard)})")
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


# The world's own size, and the least room the UI layer is given (game/ui/ui_root.gd).
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
        # The window as the project opens it, never maximized or as the player left it.
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
        ensure_imported()
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
    check.add_argument("--skip", help="comma-separated steps to leave out of the rest")
    check.set_defaults(handler=command_check)

    test = commands.add_parser("test", help="run the GUT tests")
    test.add_argument("--only", help="run only test scripts whose name contains this")
    test.add_argument(
        "--shard",
        type=parse_shard,
        metavar="I/N",
        help="run only the I-th of N parts of the test scripts (with --only: of those it names)",
    )
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
