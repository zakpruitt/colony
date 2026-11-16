#!/usr/bin/env python3
"""Colony's sprite pipeline: bake `.px` text sprites into PNG sheets, and lint the art.

    python tools/art.py bake            bake every .px file under assets/
    python tools/art.py bake <path>     bake one .px file
    python tools/art.py lint            report every asset that breaks the style rules

A `.px` file is a header (`category`, `size`, optional `pivot`) and one or more named
parts, each a grid of palette symbols with `.` for transparent. A part header may name the
pixel that part turns around: `[arm] pivot=12,14` (spec 007). Baking writes, next to
the source, a PNG sheet (the parts left to right, in file order) and a `.json` file that
describes it. The rules are in docs/style-bible.md; the format in specs/002-art-foundation.

Standard library only: PNGs are written and read with zlib and struct.
"""

from __future__ import annotations

import json
import re
import struct
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
PALETTE_PATH = ASSETS / "style" / "palette.txt"

TRANSPARENT = "."
OUTLINE_NAME = "ink"
# The largest canvas an fx or ui sprite may have, in pixels on each side.
MAX_FREE_SIZE = 64

# Category -> (required (width, height), or None for "any up to MAX_FREE_SIZE"; outlined).
CATEGORIES: dict[str, tuple[tuple[int, int] | None, bool]] = {
    "hero": ((32, 32), True),
    "monster_small": ((24, 24), True),
    "monster_large": ((32, 32), True),
    "boss": ((64, 64), True),
    "item": ((16, 16), True),
    "tile": ((16, 16), False),
    "fx": (None, False),
    "ui": (None, False),
    "font": (None, False),
}
# A font sheet (see docs/style-bible.md, "Text") may be any size, and is drawn in this one colour
# only, so the game can tint text to any palette colour.
FONT_CATEGORY = "font"
FONT_COLOUR_NAME = "white"

REQUIRED_FIELDS = ("category", "size")
KNOWN_FIELDS = ("category", "size", "pivot")
PART_HEADER = re.compile(r"^\[([a-z0-9_]+)\](?:\s+pivot\s*=\s*(\S+))?$")
FIELD_LINE = re.compile(r"^([a-z_]+)\s*=\s*(.*)$")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class ArtError(Exception):
    """A palette, source or PNG that cannot be used; the message says why."""


@dataclass
class Sprite:
    category: str
    width: int
    height: int
    pivot: tuple[int, int]
    parts: list[tuple[str, list[str]]]
    # Part name -> the pixel that part turns around, for the parts that declare one.
    part_pivots: dict[str, tuple[int, int]]


@dataclass
class Colour:
    symbol: str
    rgb: tuple[int, int, int]
    name: str


# ---------------------------------------------------------------- palette


def load_palette(path: Path) -> list[Colour]:
    """The colours of a palette file, in order. Raises ArtError if it is malformed."""
    colours: list[Colour] = []
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        raise ArtError(f"{display(path)}: cannot read the palette ({error})") from None
    for number, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        match = re.fullmatch(r"(\S) ([0-9a-f]{6}) ([a-z][a-z0-9_]*)", line.strip())
        if not match:
            raise ArtError(f"{display(path)}:{number}: expected `<symbol> <hex> <name>`")
        symbol, hex_value, name = match.groups()
        rgb = (int(hex_value[0:2], 16), int(hex_value[2:4], 16), int(hex_value[4:6], 16))
        colours.append(Colour(symbol, rgb, name))
    if len({c.symbol for c in colours}) != len(colours) or TRANSPARENT in {c.symbol for c in colours}:
        raise ArtError(f"{display(path)}: symbols must be unique and not `{TRANSPARENT}`")
    if not any(c.name == OUTLINE_NAME for c in colours):
        raise ArtError(f"{display(path)}: no colour is named `{OUTLINE_NAME}`")
    return colours


# ----------------------------------------------------------------- source


def parse_px(text: str, palette: list[Colour]) -> Sprite:
    """Read a .px source. Raises ArtError naming the first problem found."""
    symbols = {c.symbol for c in palette}
    fields: dict[str, str] = {}
    parts: list[tuple[str, list[str]]] = []
    declared_pivots: dict[str, str] = {}
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        header = PART_HEADER.match(line)
        if header:
            name = header.group(1)
            if any(existing == name for existing, _ in parts):
                raise ArtError(f"line {number}: duplicate part name `{name}`")
            parts.append((name, []))
            if header.group(2) is not None:
                declared_pivots[name] = header.group(2)
            continue
        if not parts:
            field = FIELD_LINE.match(line)
            if not field:
                raise ArtError(f"line {number}: expected `key = value` or a `[part]` header")
            key, value = field.group(1), field.group(2).strip()
            if key not in KNOWN_FIELDS:
                raise ArtError(f"line {number}: unknown header field `{key}`")
            if key in fields:
                raise ArtError(f"line {number}: header field `{key}` is given twice")
            fields[key] = value
            continue
        for column, symbol in enumerate(line):
            if symbol != TRANSPARENT and symbol not in symbols:
                raise ArtError(f"line {number}: unknown symbol `{symbol}` at column {column + 1}")
        parts[-1][1].append(line)

    for key in REQUIRED_FIELDS:
        if key not in fields:
            raise ArtError(f"missing header field `{key}`")
    category = fields["category"]
    if category not in CATEGORIES:
        raise ArtError(f"unknown category `{category}` (known: {', '.join(CATEGORIES)})")
    size = re.fullmatch(r"(\d+)x(\d+)", fields["size"])
    if not size or int(size.group(1)) == 0 or int(size.group(2)) == 0:
        raise ArtError(f"size `{fields['size']}` is not `<width>x<height>`")
    width, height = int(size.group(1)), int(size.group(2))
    pivot = (width // 2, height - 1)
    if "pivot" in fields:
        pivot = parse_pivot(fields["pivot"], width, height, "pivot")
    part_pivots = {
        name: parse_pivot(value, width, height, f"part `{name}`: pivot")
        for name, value in declared_pivots.items()
    }
    if not parts:
        raise ArtError("no parts: add a `[name]` header and its grid")
    for name, rows in parts:
        if len({len(row) for row in rows}) > 1:
            raise ArtError(f"part `{name}`: ragged rows (lengths {sorted({len(r) for r in rows})})")
        if len(rows) != height or (rows and len(rows[0]) != width):
            got = f"{len(rows[0]) if rows else 0}x{len(rows)}"
            raise ArtError(f"part `{name}`: grid is {got}, the header says {width}x{height}")
    return Sprite(category, width, height, pivot, parts, part_pivots)


def parse_pivot(value: str, width: int, height: int, what: str) -> tuple[int, int]:
    """An `x,y` pixel inside the canvas. Raises ArtError naming [what] otherwise."""
    given = re.fullmatch(r"(\d+)\s*,\s*(\d+)", value)
    if not given:
        raise ArtError(f"{what} `{value}` is not `<x>,<y>`")
    x, y = int(given.group(1)), int(given.group(2))
    if x >= width or y >= height:
        raise ArtError(f"{what} {x},{y} is outside the {width}x{height} canvas")
    return (x, y)


def style_problems(sprite: Sprite, palette: list[Colour]) -> list[str]:
    """The rules a well-formed sprite can still break: its size and its outline."""
    problems: list[str] = []
    required, outlined = CATEGORIES[sprite.category]
    if sprite.category == FONT_CATEGORY:
        problems += font_problems(sprite, palette)
    elif required is None:
        if sprite.width > MAX_FREE_SIZE or sprite.height > MAX_FREE_SIZE:
            problems.append(
                f"size {sprite.width}x{sprite.height} is over {MAX_FREE_SIZE}x{MAX_FREE_SIZE}, "
                f"the most a `{sprite.category}` may be"
            )
    elif (sprite.width, sprite.height) != required:
        problems.append(
            f"size {sprite.width}x{sprite.height} is wrong: a `{sprite.category}` is "
            f"{required[0]}x{required[1]}"
        )
    if outlined:
        ink = next(c.symbol for c in palette if c.name == OUTLINE_NAME)
        for name, rows in sprite.parts:
            gaps = outline_gaps(rows, ink)
            if gaps:
                shown = " ".join(f"{x},{y}" for x, y in gaps[:8])
                more = f" and {len(gaps) - 8} more" if len(gaps) > 8 else ""
                problems.append(
                    f"part `{name}`: outline gap, these edge pixels are not `{OUTLINE_NAME}`: "
                    f"{shown}{more}"
                )
    return problems


def font_problems(sprite: Sprite, palette: list[Colour]) -> list[str]:
    """A font sheet's glyphs may use only the font colour (and transparency)."""
    white = next(c.symbol for c in palette if c.name == FONT_COLOUR_NAME)
    problems: list[str] = []
    for name, rows in sprite.parts:
        wrong = [
            (x, y)
            for y, row in enumerate(rows)
            for x, symbol in enumerate(row)
            if symbol not in (TRANSPARENT, white)
        ]
        if wrong:
            shown = " ".join(f"{x},{y}" for x, y in wrong[:8])
            more = f" and {len(wrong) - 8} more" if len(wrong) > 8 else ""
            problems.append(
                f"part `{name}`: a font is drawn in `{FONT_COLOUR_NAME}` only, "
                f"these pixels are not: {shown}{more}"
            )
    return problems


def outline_gaps(rows: list[str], ink: str) -> list[tuple[int, int]]:
    """Opaque pixels that touch transparency or the canvas edge (4-neighbour) but are not ink."""
    height, width = len(rows), len(rows[0])

    def clear(x: int, y: int) -> bool:
        return not (0 <= x < width and 0 <= y < height) or rows[y][x] == TRANSPARENT

    gaps: list[tuple[int, int]] = []
    for y, row in enumerate(rows):
        for x, symbol in enumerate(row):
            if symbol in (TRANSPARENT, ink):
                continue
            if clear(x - 1, y) or clear(x + 1, y) or clear(x, y - 1) or clear(x, y + 1):
                gaps.append((x, y))
    return gaps


# ------------------------------------------------------------------ bake


def render(sprite: Sprite, palette: list[Colour]) -> tuple[int, int, bytes]:
    """The sheet's pixels as 8-bit RGBA rows: parts left to right, in file order."""
    lookup = {c.symbol: (*c.rgb, 255) for c in palette}
    lookup[TRANSPARENT] = (0, 0, 0, 0)
    width = sprite.width * len(sprite.parts)
    out = bytearray()
    for y in range(sprite.height):
        for _, rows in sprite.parts:
            for symbol in rows[y]:
                out += bytes(lookup[symbol])
    return width, sprite.height, bytes(out)


def describe(sprite: Sprite) -> str:
    """The baked JSON beside the sheet."""
    described = {
        "category": sprite.category,
        "width": sprite.width,
        "height": sprite.height,
        "pivot": list(sprite.pivot),
        "parts": [name for name, _ in sprite.parts],
    }
    if sprite.part_pivots:
        # Only when declared, so sheets without part pivots bake exactly as before spec 007.
        described["part_pivots"] = {
            name: list(sprite.part_pivots[name]) for name, _ in sprite.parts if name in sprite.part_pivots
        }
    return json.dumps(described) + "\n"


def bake_file(source: Path, palette: list[Colour]) -> None:
    """Write <source>.png and <source>.json next to a .px file. Raises ArtError if malformed."""
    try:
        sprite = parse_px(source.read_text(encoding="utf-8"), palette)
    except ArtError as error:
        raise ArtError(f"{display(source)}: {error}") from None
    width, height, raw = render(sprite, palette)
    source.with_suffix(".png").write_bytes(encode_png(width, height, raw))
    source.with_suffix(".json").write_text(describe(sprite), encoding="utf-8", newline="\n")


def bake_all(assets: Path, palette_path: Path) -> list[Path]:
    """Bake every .px file under a folder; return the sources baked."""
    palette = load_palette(palette_path)
    sources = sorted(assets.rglob("*.px"))
    for source in sources:
        bake_file(source, palette)
    return sources


# ------------------------------------------------------------------- PNG


def encode_png(width: int, height: int, raw: bytes) -> bytes:
    """An 8-bit RGBA, non-interlaced PNG. The same pixels always give the same bytes."""

    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    stride = width * 4
    scanlines = b"".join(b"\x00" + raw[y * stride : (y + 1) * stride] for y in range(height))
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        PNG_SIGNATURE
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(scanlines, 9))
        + chunk(b"IEND", b"")
    )


def decode_png(data: bytes) -> tuple[int, int, bytes]:
    """Width, height and RGBA rows of an 8-bit RGBA, non-interlaced PNG. Raises ArtError otherwise."""
    if not data.startswith(PNG_SIGNATURE):
        raise ArtError("not a PNG file")
    position = len(PNG_SIGNATURE)
    header = b""
    compressed = bytearray()
    try:
        while position < len(data):
            (length,) = struct.unpack(">I", data[position : position + 4])
            kind = data[position + 4 : position + 8]
            body = data[position + 8 : position + 8 + length]
            position += 12 + length
            if kind == b"IHDR":
                header = body
            elif kind == b"IDAT":
                compressed += body
            elif kind == b"IEND":
                break
        width, height, depth, colour_type, _, _, interlace = struct.unpack(">IIBBBBB", header)
    except struct.error:
        raise ArtError("the PNG is truncated or corrupt") from None
    if depth != 8 or colour_type != 6 or interlace != 0:
        raise ArtError("the PNG is not 8-bit RGBA without interlacing (bake it from its .px source)")
    try:
        scanlines = zlib.decompress(bytes(compressed))
    except zlib.error:
        raise ArtError("the PNG's image data is corrupt") from None
    stride = width * 4
    if len(scanlines) != height * (stride + 1):
        raise ArtError("the PNG's image data has the wrong length")
    return width, height, unfilter(scanlines, height, stride)


def unfilter(scanlines: bytes, height: int, stride: int) -> bytes:
    """Undo PNG row filters (4 bytes per pixel)."""
    out = bytearray()
    previous = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind = scanlines[start]
        row = bytearray(scanlines[start + 1 : start + 1 + stride])
        for i in range(stride):
            left = row[i - 4] if i >= 4 else 0
            up = previous[i]
            corner = previous[i - 4] if i >= 4 else 0
            if kind == 1:
                row[i] = (row[i] + left) & 0xFF
            elif kind == 2:
                row[i] = (row[i] + up) & 0xFF
            elif kind == 3:
                row[i] = (row[i] + (left + up) // 2) & 0xFF
            elif kind == 4:
                guess = left + up - corner
                pa, pb, pc = abs(guess - left), abs(guess - up), abs(guess - corner)
                nearest = left if pa <= pb and pa <= pc else (up if pb <= pc else corner)
                row[i] = (row[i] + nearest) & 0xFF
            elif kind != 0:
                raise ArtError(f"the PNG uses unknown row filter {kind}")
        out += row
        previous = row
    return bytes(out)


# ------------------------------------------------------------------ lint


def lint(assets: Path, palette_path: Path) -> list[str]:
    """Every problem with the art under a folder, one line each, naming the file."""
    try:
        palette = load_palette(palette_path)
    except ArtError as error:
        return [str(error)]
    problems: list[str] = []
    sprites: dict[Path, Sprite] = {}

    for source in sorted(assets.rglob("*.px")):
        try:
            sprite = parse_px(source.read_text(encoding="utf-8"), palette)
        except ArtError as error:
            problems.append(f"{display(source)}: malformed: {error}")
            continue
        sprites[source] = sprite
        problems += [f"{display(source)}: {p}" for p in style_problems(sprite, palette)]
        if not source.with_suffix(".png").exists():
            problems.append(f"{display(source)}: not baked: run `python tools/art.py bake`")
        description = source.with_suffix(".json")
        if not description.exists() or description.read_text(encoding="utf-8") != describe(sprite):
            problems.append(
                f"{display(description)}: missing or differs from its .px source: "
                "run `python tools/art.py bake`"
            )

    allowed = {c.rgb for c in palette}
    for image in sorted(assets.rglob("*.png")):
        problems += [f"{display(image)}: {p}" for p in png_problems(image, sprites, allowed, palette)]
    return problems


def png_problems(
    image: Path, sprites: dict[Path, Sprite], allowed: set[tuple[int, int, int]], palette: list[Colour]
) -> list[str]:
    try:
        width, height, raw = decode_png(image.read_bytes())
    except ArtError as error:
        return [f"unreadable PNG: {error}"]
    problems: list[str] = []
    off_palette: set[tuple[int, int, int]] = set()
    partial = 0
    for i in range(0, len(raw), 4):
        alpha = raw[i + 3]
        if alpha == 255:
            rgb = (raw[i], raw[i + 1], raw[i + 2])
            if rgb not in allowed:
                off_palette.add(rgb)
        elif alpha != 0:
            partial += 1
    if off_palette:
        shown = " ".join(f"#{r:02x}{g:02x}{b:02x}" for r, g, b in sorted(off_palette)[:8])
        problems.append(f"{len(off_palette)} colour(s) not in the palette: {shown}")
    if partial:
        problems.append(f"{partial} pixel(s) are half transparent (alpha must be 0 or 255)")

    source = image.with_suffix(".px")
    if not source.exists():
        problems.append("no .px source beside it: every PNG under assets/ is baked from one")
    elif source in sprites:
        expected = render(sprites[source], palette)
        if (width, height, normalised(raw)) != expected:
            problems.append("differs from what baking its .px source gives: run `python tools/art.py bake`")
    return problems


def normalised(raw: bytes) -> bytes:
    """RGBA rows with every fully transparent pixel as 0,0,0,0 (its colour is invisible)."""
    out = bytearray(raw)
    for i in range(0, len(out), 4):
        if out[i + 3] == 0:
            out[i : i + 4] = b"\x00\x00\x00\x00"
    return bytes(out)


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
        problems = lint(ASSETS, PALETTE_PATH)
        for problem in problems:
            print(problem)
        print(f"art lint: {len(problems)} problem(s)" if problems else "art lint: ok")
        return 1 if problems else 0
    try:
        if len(argv) > 1:
            palette = load_palette(PALETTE_PATH)
            sources = [Path(arg).resolve() for arg in argv[1:]]
            for source in sources:
                if source.suffix != ".px" or not source.exists():
                    raise ArtError(f"{display(source)}: not a .px file")
                bake_file(source, palette)
        else:
            sources = bake_all(ASSETS, PALETTE_PATH)
    except ArtError as error:
        print(f"bake failed: {error}")
        return 1
    for source in sources:
        print(f"baked {display(source)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
