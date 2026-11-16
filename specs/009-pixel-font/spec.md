# 009 — Pixel font and the UI theme

- **Status:** landed (provisional: not yet reviewed by Zak)
- **Milestone:** M0
- **Depends on:** 002
- **Pull request:** [#9](https://github.com/zakpruitt/colony/pull/9)

## Intent

Text is part of the look. Godot's default font is smooth and anti-aliased, which breaks the pixel-art picture
the moment a number or a label appears. This spec adds Colony's own small bitmap font, drawn in the art
pipeline, and makes it the default for every label in the game, so the HUD and the damage numbers that later
specs add are on style without doing anything. Read `docs/style-bible.md`.

## Requirements

- **R1. A bitmap font drawn as text.** The font's glyphs are `.px` sources under `assets/fonts/`, baked and
  lint-clean like any other art, in a single colour (`white`, the palette's `ffffff`) on transparency so text
  can be tinted to any palette colour. It covers space, `A-Z`, `a-z`, `0-9` and
  `. , ! ? : ; ' " + - x / % ( ) < > = * # _`. Lower case may reuse the upper-case shapes if that reads
  better at this size, but every listed character must draw something sensible.
- **R2. Small and readable.** Glyphs are at most 7 pixels tall including descenders, with a 5-pixel cap
  height, and are proportional (an `i` is narrower than an `m`) or monospaced at the lane's choice. A line of
  mixed text such as `Depth 12  Gold 3,450  Lv 7` is comfortably readable in a screenshot at the game's
  640x360 resolution.
- **R3. The art tools accept it.** The lint has a category for font sheets (any size the font needs, not
  outlined, single colour enforced: any opaque pixel that is not `white` fails). Existing categories and
  existing tests are unchanged.
- **R4. Godot uses it as a real font.** The baked sheet is imported as a Godot font resource (the image font
  importer), with nearest filtering and no anti-aliasing, so `Label`, `Button` and `RichTextLabel` can use it.
- **R5. It is the project default.** A project theme at `res://game/ui/theme.tres`, set as the project's
  default theme, makes this font the default for all controls at its native size. A `Label` created with no
  settings draws in the pixel font. The clock label in the main scene now draws in it.
- **R6. Text helpers for code.** `PixelText.width(text)` returns the pixel width of a string in the font;
  `PixelText.label(text, color_name)` returns a `Label` in the font tinted with that palette colour, with a
  1-pixel `ink` shadow or outline so it stays readable over any background.
- **R7. A specimen shows it.** `game/ui/font_specimen.tscn` shows the whole character set, the sample line from
  R2, and the same line in four palette colours over light and dark backgrounds.

## Interfaces

```gdscript
# game/ui/pixel_text.gd
class_name PixelText
extends RefCounted
static func font() -> Font
static func width(text: String) -> int
static func label(text: String, color_name: StringName = &"white") -> Label
```

How the glyph sheet is laid out, and how the `.import` file maps characters to cells, is the lane's choice.
If the image font importer cannot do what is needed in 4.7, building a `FontFile` in code from the baked
sheet is an acceptable alternative, as long as R4 and R5 hold.

## Acceptance

In `tests/acceptance/test_009_pixel_font.gd`, plus Python tests for R3 in `tools/tests/`.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_every_character_has_a_glyph` | Each listed character has a glyph with a positive advance, and all but space draw at least one pixel |
| R2 | `test_r2_metrics` | Font height is at most 7 pixels plus line spacing; `i` is no wider than `m` |
| R3 | `test_r3_font_category_lint` (py) | A font sheet passes; a font sheet with a non-white opaque pixel fails, naming the file; other categories behave as before |
| R4, R5 | `test_r5_default_label_uses_the_pixel_font` | A bare `Label` in the tree reports the pixel font as its font; the project setting points at the theme |
| R5 | `test_r5_clock_label_uses_the_pixel_font` | The main scene's clock label resolves to the pixel font |
| R6 | `test_r6_pixel_text_helpers` | `width("")` is 0, `width("ii") < width("mm")` (or equal if monospaced), `label()` returns a tinted label with the shadow |
| R7 | `test_r7_specimen_runs` | The specimen scene runs 30 frames without errors |

**To look at, and for Zak:** `python tools/dev.py shot --scene=res://game/ui/font_specimen.tscn --name=font`.
Every glyph must be crisp (no blur, no grey edge pixels) and distinguishable from its neighbours (`0` from
`O`, `1` from `l` and `I`, `5` from `S`). Iterate on the glyphs until the sample line reads easily, and
describe the shot in your report.

## Out of scope

- Any HUD, menu, button styling beyond the font, or damage numbers (later specs).
- A second font, bold or large variants, non-Latin characters.
- Fonts from outside the repository.

## Paths

- `assets/fonts/`
- `game/ui/theme.tres`, `game/ui/pixel_text.gd`, `game/ui/font_specimen.gd`, `game/ui/font_specimen.tscn`
- `project.godot` (the default theme setting only)
- `tools/art.py`, `tools/tests/` (the font category only)
- `tests/acceptance/test_009_pixel_font.gd`
- `docs/style-bible.md` (a text section), `.claude/skills/create-sprite/SKILL.md`, `docs/wiki/index.html`

## Open questions

None.
