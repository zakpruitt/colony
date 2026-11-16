# Style bible

The rules every sprite, tile, effect and UI element in Colony follows, so all of it looks like one game.
`python tools/art.py lint` (the `art` step of `python tools/dev.py check`) enforces the rules marked
**(lint)**; the rest are for the artist and for Zak's eye.

**This is a first pass.** The palette and these rules are Zak's to change; a change lands here, in
`assets/style/palette.txt` and in `tools/art.py` together.

## Palette

- Use only the 32 colours of the master palette, `assets/style/palette.txt` (ENDESGA 32). Nothing else, no
  tints, no blends. **(lint)**
- Every pixel is fully opaque or fully transparent. **(lint)**
- In code, use colours by name: `Palette.color(&"ink")`, never a hex literal.

## Categories

The category in a sprite's header fixes its size and whether it is outlined. **(lint)**

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

## Outline

- Outlined sprites have a 1-pixel outline in `ink` (`181425`), inside the canvas: every opaque pixel that
  touches transparency or the canvas edge (up, down, left or right) is `ink`. **(lint)**
- Each part is outlined on its own, so it still reads when it moves away from the others.
- `ink` may also be used inside a shape for slits, seams and deep shadow.

## Light and shading

- Light comes from the top-left: highlights on top and left edges, shadow on the bottom and right.
- At most three tones per material: a base, one shadow, one highlight. For example steel is `steel` with
  `slate` shadow and `silver` highlight; red cloth is `red` with `crimson` and `pink`.
- No dithering, no gradients, no anti-aliasing.

## Characters in parts

- A character is drawn as separate parts on one shared canvas (for a hero: `body`, `head`, `arm`, `weapon`),
  and the game moves the parts in code (bob, swing, recoil). Parts are drawn in file order, later on top.
- Every part keeps its position on the full canvas, so stacking the parts unmoved gives the whole sprite.
- Parts overlap where they meet (a head sits over the top of the body, an arm over the shoulder) so no gap
  opens when one rotates.
- The pivot is the pixel on the ground at the feet's centre, by default the bottom centre of the canvas
  (`16,31` for a hero). The sprite stands and turns around it.
- Characters face right.

## Tiles

The labyrinth (`game/world/labyrinth_view.gd`) is drawn from the sheets in `assets/sprites/tiles/`, all of
category `tile` (16x16, not outlined). Each sheet holds many parts; the view picks a part per tile.

- **Earth strata.** `loam`, `clay`, `stone` and `deep` each cover five levels (1-5, 6-10, 11-15, 16-20, then
  loam again). Each uses three earth tones (base, highlight, shadow), a lighter floor-top colour and a darker
  back wall:

  | Stratum | Earth (base, highlight, shadow) | Floor top | Back wall |
  |---|---|---|---|
  | `loam` | `umber`, `clay`, `dark_brown` | `tan` | `dark_brown` |
  | `clay` | `clay`, `tawny`, `umber` | `tan` | `dark_brown` |
  | `stone` | `dusk`, `slate`, `night` | `steel` | `ink` |
  | `deep` | `deep_teal`, `pine`, `night` | `forest` | `ink` |

- **The back wall is always darker than the earth**, so open space reads at a glance.
- **Buried earth** (`buried_0` to `buried_12`) is mostly the plain `buried_0`; the others carry one small
  feature (a speck, a stone, a clod, a streak) kept a pixel clear of the tile's edge. Features are rare and
  sit in different places, so no pattern lines up into a grid. The view picks a variant from the tile's
  position, so a tile always looks the same. `back_0` to `back_5` do the same for the back wall.
- **Edges are overlays**, drawn over the ground tile and named by a bitmask of the open sides (N=1, E=2, S=4,
  W=8): `edge_<mask>_<variant>` on earth next to open space, `shade_<mask>` on back wall next to earth, and
  `corner_<mask>` (NE=1, SE=2, SW=4, NW=8) where a floor meets a wall.
  - A **floor** is flat, with a lit top: a row of the floor-top colour over a crust of highlight.
  - A **ceiling** and the **walls** are bitten ragged by up to two pixels. The bites take the shade colour of
    the open space; the boundary is `ink` (or the shadow) under a ceiling, highlight on a face turned to the
    left (lit), shadow on a face turned to the right.
  - **Shade** falls on the back wall under a ceiling and beside the walls, never above a floor.
- **The ladder** (`ladder.px`) is two tiles wide, as shafts are: `left` and `right`, with `top_left` and
  `top_right` standing on the floor above the shaft. Wood is `tan` with `clay` and `umber`.
- **The surface** (`surface.px`): `sky` is plain `blue`; `ground` is the grass line in `green`, `forest` and
  `pine`, sitting directly on the first row of earth.

The four stratum sheets share their shapes and differ only in the colours of the table above (they were
written by a throwaway script, as the `create-sprite` skill allows). Keep them that way: a change to a shape
belongs in all four sheets, and a new stratum is the same shapes in a new row of the table.

## Workflow

1. Write the sprite as a `.px` file under `assets/` (the format is below and in
   `specs/002-art-foundation/spec.md`; the `create-sprite` skill is the procedure).
2. Bake it: `python tools/art.py bake <path>` writes the `.png` sheet and `.json` beside it.
3. Lint it: `python tools/art.py lint`.
4. Look at it: `python tools/dev.py shot --scene=res://game/art/gallery.tscn --name=gallery`, at 4x and at 1x.
5. Zak approves new art.

```
# comment
category = hero
size = 32x32
pivot = 16,31

[body]
................................
(32 rows of 32 palette symbols; `.` is transparent)

[head]
...
```

The knight, `assets/sprites/heroes/knight.px`, is the reference sprite.
