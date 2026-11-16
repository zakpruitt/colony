---
name: create-sprite
description: Write, bake, lint and look at a Colony sprite (a hero, monster, boss, item, tile, effect or UI piece) as a `.px` text file in the master palette. Use when a spec asks for new art, when `python tools/art.py lint` or the `art` check step fails, or when a sprite looks wrong in the gallery or the game.
---

# Making a sprite

Colony's art is typed, not painted: a `.px` text file of palette symbols, baked into a PNG sheet. Read
`docs/style-bible.md` first; it holds the rules (palette, sizes, outline, light, parts). The reference sprite
is `assets/sprites/heroes/knight.px`.

## 1. Write the `.px`

- Put it under `assets/sprites/<kind>/<name>.px` (for example `assets/sprites/monsters/rat.px`).
- Header: `category = <hero|monster_small|monster_large|boss|item|tile|fx|ui>`, `size = <w>x<h>` (the size the
  category requires), and `pivot = x,y` only if the default (bottom centre) is wrong.
- Then each part: a `[name]` line (lower case, digits, `_`), optionally with the joint it turns around
  (`[arm] pivot=18,16`), and exactly `<h>` rows of `<w>` symbols. Symbols
  are the first column of `assets/style/palette.txt`; `.` is transparent. Lines starting with `#` are comments.
- Every part is a full canvas at its place in the whole sprite: stacking the parts unmoved gives the
  composed sprite. Draw them so they overlap at joints.
- Outlined categories: every opaque pixel touching transparency or the canvas edge must be `p` (`ink`).
  The easy way is to draw the shape, then put `p` on every transparent pixel next to it (up, down, left,
  right). Leave the outermost row and column free if the shape needs room for its outline.
- Light from the top-left; three tones per material (the style bible lists pairs that work).

Drawing a 32x32 grid by hand is error-prone. It is fine to write a throwaway script in your scratchpad
that builds the rows from shapes and adds the outline, then prints the `.px`; commit only the `.px` and
what baking makes. Write the file with LF line endings (on Windows, `python script.py > file` writes CRLF;
the tools accept it, but git will rewrite it).

## 2. Bake and lint

```
python tools/art.py bake assets/sprites/monsters/rat.px   # or `bake` for every source
python tools/art.py lint
```

Baking writes `rat.png` (parts left to right) and `rat.json` beside the source. Never edit either by hand:
the lint fails a PNG that differs from its source. Commit the `.px`, `.png`, `.json` and the `.png.import`
Godot makes on the next `python tools/dev.py import`. Check that `.import` file has `compress/mode=0`,
`mipmaps/generate=false` and `detect_3d/compress_to=0` (set the last one by hand; Godot's default is 1, which
would recompress the texture if it were ever used in 3D).

Lint messages name the file and the problem. An outline gap lists the `x,y` of each offending pixel,
counted from the top-left of the part's canvas, starting at 0.

## 3. Look at it

```
python tools/dev.py shot --scene=res://game/art/gallery.tscn --name=gallery
```

Open `.shots/gallery.png` with the Read tool. The gallery shows every sheet under `assets/sprites/`: each
part at 4x, the parts composed at 4x and at 1x. Judge it at 1x: the game is 640x360 and the sprite must read
at its real size. The screenshot is small; to inspect pixels, decode the PNG with `art.decode_png` in a
scratch script and write an enlarged copy with `art.encode_png`.

Iterate until it reads clearly, then say in your report what you see. Zak approves new art.

For a character, also run the cast demo and look at it moving, not only standing:
`python tools/dev.py shot --scene=res://game/entities/character_demo.tscn --name=cast --seconds=0.7 --count=10`.
Rotated parts show where a pivot is wrong (a weapon leaving the hand, a gap at the shoulder). For a closer
look at motion, take `--seconds=0.1 --count=70` and put crops of consecutive shots side by side.

Auto-shading helps a throwaway script: give each material a base, highlight and shadow, then make a pixel
the highlight where its top or left neighbour is not the same material and the shadow where its bottom or
right one is not. A small face shaded that way ends up mostly shadow; write its pixels by hand.

## 4. Use it in code

```gdscript
var sheet: PixelSheet = PixelSheet.load_sheet("res://assets/sprites/heroes/knight.png")
var head: AtlasTexture = sheet.part(&"head")   # the part's 32x32 region of the sheet
var ink: Color = Palette.color(&"ink")
var shoulder: Vector2i = sheet.part_pivot(&"arm")   # the declared pivot, or the sprite's pivot

var hero: CharacterSprite = CharacterSprite.for_hero(&"knight")   # composed and animated in code
```
