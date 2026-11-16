# 002 — Art foundation: palette, code-drawn sprites and the art lint

- **Status:** provisional
- **Milestone:** M0
- **Depends on:** none
- **Pull request:** —

## Intent

Every asset in Colony must look like it belongs to the same game, and agents must be able to make assets
without a paint program. This spec fixes the master palette, defines a text format an agent can type a sprite
in, bakes that text into ordinary PNG sprite sheets Godot imports, and adds a blocking lint so off-style art
cannot land. Later lanes draw heroes, monsters, tiles and effects with it. Read `docs/design/base-game.md`.

## Requirements

- **R1. One master palette.** `assets/style/palette.txt` lists exactly 32 colours, one per line as
  `<symbol> <hex> <name>`: ENDESGA 32 in its standard order, symbols `0`-`9` then `a`-`v`, names in snake_case
  (for example `k 181425 ink`). The hex values, in order:
  `be4a2f d77643 ead4aa e4a672 b86f50 733e39 3e2731 a22633 e43b44 f77622 feae34 fee761 63c74d 3e8948 265c42
  193c3e 124e89 0099db 2ce8f5 ffffff c0cbdc 8b9bb4 5a6988 3a4466 262b44 181425 ff0044 68386c b55088 f6757a
  e8b796 c28569`. The colour `181425` is the outline colour and is named `ink`.
- **R2. Sprites are written as text.** A sprite source is a `.px` file under `assets/`. It has a header
  (`category`, `size`, and optional `pivot`) and one or more named parts, each a grid of palette symbols with
  `.` for transparent. All parts in a file share the canvas size. The exact format is in Interfaces.
- **R3. Baking.** `python tools/art.py bake` turns every `.px` file into, next to it, a PNG sheet (parts laid
  left to right in file order) and a `.json` file describing it (category, size, pivot, part names in order).
  Baking is deterministic: the same source gives byte-identical output. `bake <path>` bakes one file.
- **R4. The lint blocks off-style art.** `python tools/art.py lint` fails, naming the file and the problem,
  when any of these is true:
  - a PNG under `assets/` contains a colour not in the palette, or a pixel that is neither fully transparent
    nor fully opaque;
  - a PNG under `assets/` has no `.px` source, or differs from what baking its source would produce;
  - a `.px` file is malformed (unknown symbol, ragged rows, wrong grid size, missing header field, duplicate
    part name, unknown category);
  - a sprite's size is not the size its category requires (R5);
  - in an outlined category (R5), an opaque pixel that touches transparency or the canvas edge (4-neighbour)
    is not `ink`.
- **R5. Categories fix size and outline.**

  | Category | Size | Outlined |
  |---|---|---|
  | `hero` | 32x32 | yes |
  | `monster_small` | 24x24 | yes |
  | `monster_large` | 32x32 | yes |
  | `boss` | 64x64 | yes |
  | `item` | 16x16 | yes |
  | `tile` | 16x16 | no |
  | `fx` | any, up to 64x64 | no |
  | `ui` | any, up to 64x64 | no |

- **R6. The lint is part of the check.** `python tools/dev.py check` has a new step `art`, after `boundary`,
  that runs the lint. It passes when there are no assets.
- **R7. Godot can use a baked sheet by part name.** `PixelSheet.load_sheet(path)` returns the sheet for a baked
  PNG; it gives the texture of each part, the part names, the canvas size and the pivot. Asking for a part
  that does not exist is an error that names the sheet and the part.
- **R8. Code can use palette colours by name.** `Palette.color(&"ink")` returns that palette colour;
  `Palette.all()` returns the 32 colours in order. Both read `assets/style/palette.txt`, so the file is the
  single source of truth. An unknown name is an error that names it.
- **R9. A reference sprite proves the pipeline.** `assets/sprites/heroes/knight.px` is a 32x32 `hero` with the
  parts `body`, `head`, `arm`, `weapon` (in that order), drawn to the style rules in R10, baked and passing the
  lint. A scene `game/art/gallery.tscn` shows every baked sheet under `assets/sprites/` at 4x, each part
  separately and the parts composed, on a mid-dark background, with the sheet's name.
- **R10. The style bible exists.** `docs/style-bible.md` states, briefly and as rules: the palette and that
  nothing else may be used; the category table; outline (1 pixel, `ink`, inside the canvas); light from the
  top-left; shading with at most three tones per material (base, one shadow, one highlight) and no dithering
  or gradients; how a character is split into parts and where pivots go (feet centre for the canvas; parts
  overlap so joints do not gap when rotated); and the workflow (write `.px`, bake, lint, look at the gallery,
  Zak approves). It records that this palette and these rules are first-pass.

## Interfaces

`.px` format (lines starting with `#` are comments):

```
category = hero
size = 32x32
pivot = 16,31

[body]
................................
(32 rows of 32 symbols)

[head]
(32 rows of 32 symbols)
```

`pivot` is the pixel that sits on the ground and that the sprite turns around; it defaults to the bottom
centre. Baked JSON:

```json
{"category": "hero", "width": 32, "height": 32, "pivot": [16, 31], "parts": ["body", "head", "arm", "weapon"]}
```

```gdscript
# game/art/palette.gd
class_name Palette
extends RefCounted
static func color(color_name: StringName) -> Color
static func all() -> PackedColorArray

# game/art/pixel_sheet.gd
class_name PixelSheet
extends RefCounted
var category: String
var size: Vector2i
var pivot: Vector2i
var part_names: PackedStringArray
## The sheet baked at res://<...>.png (its .json is beside it). Cached per path.
static func load_sheet(png_path: String) -> PixelSheet
## The texture of one part: a region of the sheet.
func part(part_name: StringName) -> AtlasTexture
func has_part(part_name: StringName) -> bool
```

`tools/art.py` uses the Python standard library only (PNG reading and writing with `zlib` and `struct`; it
only needs to read the 8-bit RGBA PNGs it writes, and reports any other PNG as a lint failure). The `art`
step in `tools/dev.py` calls it. Godot must import PNGs without filtering or compression artefacts: the
project default is already nearest filtering; the lane makes sure the committed `.import` files use lossless
compression and no mipmaps.

## Acceptance

Python behaviour is tested with `python -m unittest discover tools/tests`, which the `art` step also runs.
Godot behaviour is tested in `tests/acceptance/test_002_art_foundation.gd`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_palette_file_is_the_32_colours` (py) | 32 lines, the hex values above in order, unique symbols and names, `ink` is `181425` |
| R2, R3 | `test_r3_bake_writes_sheet_and_json` (py) | A two-part 16x16 source becomes a 32x16 PNG with the right pixels and the JSON above |
| R3 | `test_r3_bake_is_deterministic` (py) | Baking twice gives identical bytes |
| R4 | `test_r4_lint_rejects_*` (py), one per bullet | Off-palette colour; half-transparent pixel; PNG with no source; stale PNG; each malformed-source case; wrong size; outline gap. Each names the file |
| R4 | `test_r4_lint_accepts_a_correct_sprite` (py) | A correct outlined sprite passes |
| R5 | `test_r5_tile_needs_no_outline` (py) | A full 16x16 `tile` with no `ink` passes |
| R6 | `test_r6_check_has_art_step` (py) | `dev.py`'s step list has `art` after `boundary` |
| R7 | `test_r7_sheet_gives_parts_by_name` | The knight sheet has the four parts in order, 32x32 regions at the right offsets; a missing part is an error |
| R8 | `test_r8_palette_colours_by_name` | `Palette.color(&"ink")` is `#181425`; `all()` has 32 entries matching the file |
| R9 | `test_r9_knight_is_baked_and_listed` | The knight PNG and JSON exist and load; the gallery scene instantiates without errors |

**For the lane to look at, and for Zak's review:**
`python tools/dev.py shot --scene=res://game/art/gallery.tscn --name=gallery` and read the PNG. The knight should
read clearly as an armoured figure with a sword, at 1x and at 4x. Iterate on the drawing until it does, and
describe what you see in your report.

## Out of scope

- Any other sprite: the other heroes, monsters, tiles, effects and UI belong to later specs.
- Animation, and any node that draws a character from its parts (a later spec).
- Image generators, importing art from outside, or any tool that costs money.
- A normaliser that fixes art automatically; the lint only reports.
- Wiring the lint into a git hook.

## Paths

- `assets/style/palette.txt`
- `assets/sprites/heroes/knight.px` and its baked `.png`, `.json` and Godot `.import` file
- `tools/art.py`, `tools/tests/`
- `tools/dev.py` (the `art` step only)
- `game/art/palette.gd`, `game/art/pixel_sheet.gd`, `game/art/gallery.gd`, `game/art/gallery.tscn`
- `tests/acceptance/test_002_art_foundation.gd`
- `docs/style-bible.md`
- `docs/wiki/index.html`, `CLAUDE.md` (the art commands and the map)
- `.claude/skills/create-sprite/SKILL.md` (new: the procedure for writing, baking, linting and checking a sprite)

## Open questions

None.
