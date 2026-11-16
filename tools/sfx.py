#!/usr/bin/env python3
"""Colony's sound pipeline: bake `.sfx` text recipes into WAV files, and lint the sounds.

    python tools/sfx.py bake            bake every .sfx recipe under assets/audio/
    python tools/sfx.py bake <path>     bake one .sfx recipe
    python tools/sfx.py lint            report every sound that is missing, stale, too long or too loud

A `.sfx` recipe is one or more parts, each a `[name]` header followed by `field = value` lines;
`#` starts a comment. The parts are mixed together. Every field has a default:

    wave     square | triangle | saw | sine | noise      (square)
    start    seconds after the sound starts               (0)
    length   seconds the part lasts                       (0.1)
    pitch    frequency at the start, in Hz                (440)
    slide    frequency at the end, in Hz                  (pitch); the glide is exponential
    duty     share of a square wave's cycle that is high  (0.5)
    volume   peak level, 0 to 1                           (0.5)
    attack   seconds to rise from silence to the peak     (0.005)
    decay    seconds to fall from the peak to `sustain`   (0)
    sustain  level held after the decay, as a share       (1)
    release  seconds to fall to silence at the end        (0.03)
    noise    share of white noise mixed into the wave     (0)
    seed     the noise's seed                             (1)

The `noise` wave is 8-bit style noise: a new random level `pitch` times a second. Every part
starts and ends at silence, so a sound never clicks. The mix goes through a gentle low-pass
filter so nothing is harsh, and is written as 16-bit mono at 22050 Hz beside the recipe.
Baking is deterministic: the same recipe always gives the same bytes. The rules are in
docs/style-bible.md ("Sound"); the format in specs/021-sound-effects.

Standard library only.
"""

from __future__ import annotations

import math
import re
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio"

SAMPLE_RATE = 22050
# The longest a sound may be, in seconds.
MAX_SECONDS = 1.2
# The loudest a sound's peak may be, in dB below full scale.
MAX_PEAK_DB = -3.0
# The low-pass filter's corner, in Hz.
LOWPASS_HZ = 7000.0
# The shortest attack and release, in seconds: anything shorter clicks.
MIN_EDGE = 0.002

WAVES = ("square", "triangle", "saw", "sine", "noise")
PART_HEADER = re.compile(r"^\[([a-z0-9_]+)\]$")
FIELD_LINE = re.compile(r"^([a-z_]+)\s*=\s*(\S+)$")
NUMBER_FIELDS = {
    "start": 0.0,
    "length": 0.1,
    "pitch": 440.0,
    "slide": -1.0,
    "duty": 0.5,
    "volume": 0.5,
    "attack": 0.005,
    "decay": 0.0,
    "sustain": 1.0,
    "release": 0.03,
    "noise": 0.0,
    "seed": 1.0,
}


class SfxError(Exception):
    """A recipe or WAV that cannot be used; the message says why."""


@dataclass
class Part:
    name: str
    wave: str
    values: dict[str, float]

    def __getattr__(self, field: str) -> float:
        try:
            return self.values[field]
        except KeyError:
            raise AttributeError(field) from None


# ---------------------------------------------------------------- recipes


def parse_sfx(text: str) -> list[Part]:
    """The parts of a recipe, in file order. Raises SfxError naming the line at fault."""
    parts: list[Part] = []
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        header = PART_HEADER.match(line)
        if header:
            parts.append(Part(header.group(1), "square", dict(NUMBER_FIELDS)))
            continue
        field = FIELD_LINE.match(line)
        if not field:
            raise SfxError(f"line {number}: expected `[part]` or `field = value`, got `{line}`")
        if not parts:
            raise SfxError(f"line {number}: a field before the first `[part]` header")
        key, value = field.group(1), field.group(2)
        part = parts[-1]
        if key == "wave":
            if value not in WAVES:
                raise SfxError(f"line {number}: wave must be one of {', '.join(WAVES)}")
            part.wave = value
        elif key in NUMBER_FIELDS:
            try:
                part.values[key] = float(value)
            except ValueError:
                raise SfxError(f"line {number}: `{key}` must be a number, got `{value}`") from None
        else:
            raise SfxError(f"line {number}: unknown field `{key}`")
    if not parts:
        raise SfxError("no parts: a recipe needs at least one `[part]`")
    for part in parts:
        if part.length <= 0.0 or part.pitch <= 0.0 or part.start < 0.0:
            raise SfxError(f"part [{part.name}]: length and pitch must be above 0, start not below")
        if part.slide < 0.0:
            part.values["slide"] = part.pitch
    return parts


def envelope(part: Part, t: float) -> float:
    """The part's level at [t] seconds into it: up, down to the sustain, then out to silence."""
    attack = max(part.attack, MIN_EDGE)
    release = max(part.release, MIN_EDGE)
    if t < attack:
        level = t / attack
    elif t < attack + part.decay:
        level = 1.0 - (1.0 - part.sustain) * (t - attack) / part.decay
    else:
        level = part.sustain
    left = part.length - t
    if left < release:
        level *= max(left, 0.0) / release
    return level


class Lcg:
    """A small deterministic random source (the same on every machine and Python)."""

    def __init__(self, seed: int) -> None:
        self.state = (seed * 2654435761 + 1) & 0xFFFFFFFF

    def next(self) -> float:
        """A number from -1 to 1."""
        self.state = (self.state * 1664525 + 1013904223) & 0xFFFFFFFF
        return (self.state >> 8) / float(1 << 23) - 1.0


def render_part(part: Part) -> list[float]:
    count = int(round(part.length * SAMPLE_RATE))
    out: list[float] = []
    rng = Lcg(int(part.seed))
    phase = 0.0
    held = rng.next()
    ratio = part.slide / part.pitch
    for i in range(count):
        t = i / SAMPLE_RATE
        frequency = part.pitch * ratio ** (i / max(count - 1, 1))
        step = frequency / SAMPLE_RATE
        phase += step
        wrapped = phase - math.floor(phase)
        if part.wave == "square":
            value = 1.0 if wrapped < part.duty else -1.0
        elif part.wave == "triangle":
            value = 4.0 * abs(wrapped - 0.5) - 1.0
        elif part.wave == "saw":
            value = 2.0 * wrapped - 1.0
        elif part.wave == "sine":
            value = math.sin(2.0 * math.pi * wrapped)
        else:
            if phase >= 1.0:
                phase -= math.floor(phase)
                held = rng.next()
            value = held
        if part.noise > 0.0:
            value = value * (1.0 - part.noise) + rng.next() * part.noise
        out.append(value * part.volume * envelope(part, t))
    return out


def render(parts: list[Part]) -> list[float]:
    """The mixed, filtered sound as samples from -1 to 1 (clipped there)."""
    total = max(int(round((p.start + p.length) * SAMPLE_RATE)) for p in parts)
    mix = [0.0] * total
    for part in parts:
        offset = int(round(part.start * SAMPLE_RATE))
        for i, value in enumerate(render_part(part)):
            if offset + i < total:
                mix[offset + i] += value
    # One-pole low-pass: takes the edge off square and saw waves.
    alpha = 1.0 - math.exp(-2.0 * math.pi * LOWPASS_HZ / SAMPLE_RATE)
    level = 0.0
    for i, value in enumerate(mix):
        level += alpha * (value - level)
        mix[i] = max(-1.0, min(1.0, level))
    # The filter's tail may leave the last sample a hair off zero: end on silence.
    if mix:
        mix[-1] = 0.0
    return mix


def encode_wav(samples: list[float]) -> bytes:
    data = b"".join(struct.pack("<h", int(round(s * 32767))) for s in samples)
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + len(data),
        b"WAVE",
        b"fmt ",
        16,
        1,  # PCM
        1,  # mono
        SAMPLE_RATE,
        SAMPLE_RATE * 2,
        2,
        16,
        b"data",
        len(data),
    )
    return header + data


def decode_wav(data: bytes) -> tuple[int, list[int]]:
    """The sample rate and 16-bit samples of a mono PCM WAV. Raises SfxError otherwise."""
    if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise SfxError("not a WAV file")
    rate = 0
    position = 12
    while position + 8 <= len(data):
        kind, size = struct.unpack("<4sI", data[position : position + 8])
        body = data[position + 8 : position + 8 + size]
        if kind == b"fmt ":
            fmt, channels, rate, _, _, bits = struct.unpack("<HHIIHH", body[:16])
            if fmt != 1 or channels != 1 or bits != 16:
                raise SfxError("not 16-bit mono PCM")
        elif kind == b"data":
            if rate == 0:
                raise SfxError("data before the format")
            count = len(body) // 2
            return rate, list(struct.unpack(f"<{count}h", body[: count * 2]))
        position += 8 + size + (size & 1)
    raise SfxError("no data chunk")


def bake_bytes(source: Path) -> bytes:
    return encode_wav(render(parse_sfx(source.read_text(encoding="utf-8"))))


def bake_file(source: Path) -> Path:
    target = source.with_suffix(".wav")
    target.write_bytes(bake_bytes(source))
    return target


def bake_all(folder: Path) -> list[Path]:
    sources = sorted(folder.rglob("*.sfx"))
    for source in sources:
        bake_file(source)
    return sources


# ------------------------------------------------------------------- lint


def lint(folder: Path) -> list[str]:
    """Every problem with the sounds under a folder, one line each, naming the file."""
    problems: list[str] = []
    for source in sorted(folder.rglob("*.sfx")):
        try:
            expected = bake_bytes(source)
        except SfxError as error:
            problems.append(f"{display(source)}: malformed: {error}")
            continue
        target = source.with_suffix(".wav")
        if not target.exists():
            problems.append(f"{display(target)}: missing: run `python tools/sfx.py bake`")
        elif target.read_bytes() != expected:
            problems.append(
                f"{display(target)}: stale, differs from its .sfx recipe: run `python tools/sfx.py bake`"
            )
    for target in sorted(folder.rglob("*.wav")):
        problems += [f"{display(target)}: {p}" for p in wav_problems(target)]
    return problems


def wav_problems(target: Path) -> list[str]:
    try:
        rate, samples = decode_wav(target.read_bytes())
    except SfxError as error:
        return [f"unreadable WAV: {error}"]
    problems: list[str] = []
    if not target.with_suffix(".sfx").exists():
        problems.append("no .sfx recipe beside it: every sound under assets/audio/ is baked from one")
    seconds = len(samples) / rate
    if seconds > MAX_SECONDS:
        problems.append(f"too long: {seconds:.2f} s (at most {MAX_SECONDS} s)")
    peak = max((abs(s) for s in samples), default=0)
    if peak > 0:
        peak_db = 20.0 * math.log10(peak / 32767.0)
        if peak_db > MAX_PEAK_DB:
            problems.append(f"too loud: peak {peak_db:.1f} dB (at most {MAX_PEAK_DB} dB)")
    return problems


def display(path: Path) -> str:
    """A path relative to the project when it is inside it, with forward slashes."""
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


# --------------------------------------------------------------- commands


def main(argv: list[str]) -> int:
    if not argv or argv[0] not in ("bake", "lint") or (argv[0] == "lint" and len(argv) > 1):
        print(__doc__.strip())
        return 2
    if argv[0] == "lint":
        problems = lint(AUDIO)
        for problem in problems:
            print(problem)
        print(f"sfx lint: {len(problems)} problem(s)" if problems else "sfx lint: ok")
        return 1 if problems else 0
    try:
        if len(argv) > 1:
            sources = [Path(arg).resolve() for arg in argv[1:]]
            for source in sources:
                if source.suffix != ".sfx" or not source.exists():
                    raise SfxError(f"{display(source)}: not a .sfx file")
                bake_file(source)
        else:
            sources = bake_all(AUDIO)
    except SfxError as error:
        print(f"bake failed: {error}")
        return 1
    for source in sources:
        print(f"baked {display(source)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
