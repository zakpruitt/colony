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
| `font` | any | no; `white` only (see Text) |

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
- A part may name its own pivot, the joint it turns around: `[arm] pivot=18,16` (the shoulder). A part with
  none turns around the sprite's pivot. A pivot outside the canvas is a lint failure. **(lint)**
- Put the pivot where the part joins the rest: the neck for a head, the shoulder for an arm, the hand's grip
  for a weapon (the weapon is carried by the arm and turns again at the grip), the root of a wing, the hip of
  a leg.
- Characters face right; the game mirrors them to face left.
- Part names say how the game moves them (`game/entities/character_sprite.gd`): `head`, `arm` and `weapon`
  bob and swing; `wing...` beats; `leg...` swings, and a name ending in `back` swings the other way; `eyes`
  blink. A character with a head breathes by moving its head and arm a pixel; with wings it hovers; with
  legs and no head its body bobs; with none of these it squashes. Draw `eyes` over closed lids on the body.

### The cast

Each character has its own main colour, so the party and the monsters read apart at 1x.

| Character | Category | Main colour | Parts |
|---|---|---|---|
| `knight` | `hero` | `steel`, with a `red` cape and plume | body, head, arm, weapon (sword) |
| `rogue` | `hero` | `plum` hood and cloak, `clay` leather | body, head, arm, weapon (dagger) |
| `mage` | `hero` | `navy` and `blue` robe and hat, `cyan` orb | body, head, arm, weapon (staff) |
| `cleric` | `hero` | `silver` hood and robe over `amber` vestments | body, head, arm, weapon (mace) |
| `slime` | `monster_small` | `green` | body, eyes |
| `cave_bat` | `monster_small` | `slate` fur, `plum` wings | wing_back, body, wing |
| `skeleton` | `monster_small` | `sand` bone, rusty `copper` sword | body, head, arm, weapon |
| `spider` | `monster_small` | `red`, on `umber` legs | legs_back, body, legs |
| `ogre` | `monster_large` | `tawny` skin, `umber` club | body, head, arm, weapon (club) |
| `goblin` | `monster_small` | `forest` skin, `clay` leather, `steel` blade | body, head, arm, weapon (blade) |
| `mud_golem` | `monster_large` | `brick` clay with `slate` stones, `yellow` eyes | body, head, arm (fist) |
| `fire_imp` | `monster_small` | `orange` skin, `crimson` wings, `yellow` fireball | wing_back, body, wing, arm, weapon (fireball) |
| `clay_hound` | `monster_small` | `tan` with `umber` stripes, `red` eyes | legs_back, body, legs |
| `ghoul` | `monster_small` | `slate` skin, `navy` rag, `cyan` eyes, `silver` claws | body, head, arm, weapon (claws) |
| `crystal_beetle` | `monster_small` | `cyan` crystals on a `dusk` shell | legs_back, body, legs |
| `wraith` | `monster_small` | `white` and `silver` shroud, `cyan` eyes and orb | body, head, arm, weapon (orb) |
| `deep_horror` | `monster_large` | `deep_teal` and `pine`, `cyan` eyes, `magenta` maw | legs_back, body, eyes, legs, arm (tentacle) |

Monsters take colours from their depth band: the loam's are free, the clay's are warm, the stone's are cold,
and the deep's are teal and strange.

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

## Light and decoration

Underground is dark, and light comes from torches, the campfire, gold and glowing things (spec 012,
`game/ambience/`). Every sprite is still drawn in the palette; the light is applied over it on screen.

- **Light comes in rings, not gradients.** A lamp's pool is three bands (`AmbienceMood.STEPS`): a bright core,
  a middle ring and a faint outer ring. Where pools overlap the stronger light wins (the maximum, never the
  sum), so overlaps add no extra bands. Edges move by whole pixels when they flicker.
- **Two passes.** A multiply pass darkens the world (and the characters) to the stratum's ambient colour and
  lifts it toward unlit in each pool. Multiplying alone can never make the dark back wall look lit, so an
  additive pass puts a little of the stratum's glow colour back near each flame. Keep the added glow small
  (`AmbienceDarkness.GLOW_STRENGTH`) or the pools turn to pale fog.
- **Light fills open space, not earth.** Light is read per tile: a lamp lights open tiles fully, a tile of earth
  touching open space (a wall face, the floor crust) a little, and earth further in not at all, so the lit
  shape is the chamber's shape, never a disc laid over the rock. The earth instead sits a little brighter than
  unlit open space, more so in the stone and the deep, so walls and floor lines always read: dark, not black.
- **The party is always in true colour.** The party's light is white, has a full-strength core covering the
  formation of four and a tile either side, then rings; it lights open space only and adds no glow.
- **Mood by stratum:**

  | Stratum | Darkness leans to | Torchlight leans to | Glow | Flames |
  |---|---|---|---|---|
  | `loam` | `tan` (warm) | `amber` | `orange` | orange |
  | `clay` | `orange` (warmer) | `orange` | `orange` | orange |
  | `stone` | `steel` (cold, darker) | `sand` | `amber` | orange |
  | `deep` | `cyan` (eerie teal) | `cyan` | `cyan` | teal (`teal_` frames) |

- **What glows is drawn over the darkness:** flames, embers, glints and glowing mushrooms and crystals. They are
  never dimmed, so keep them small.
- **Sheets** (`assets/sprites/ambience/`): props are `fx` sheets with a hand-drawn `ink` outline where they
  stand apart from the wall (the chest is an `item`); webs, stalactites and the puddle are unoutlined, part of
  the cave. Buried things (`buried.px`, `tile`) are pale against the earth (`sand`, `white`, `steel`) so they
  read in the dark, and sit near the middle of their tile.
- **Torches** hang on the back wall two rows above the floor, one per seven tiles of chamber width, never over
  a shaft. **Props** stand on the floor (a puddle sinks two pixels into the crust) or hang from the ceiling (two
  pixels sunk into its ragged edge), never over a shaft, and never suggest a wall or a ledge.
- **Each chamber kind has a look:** START a campfire between bedrolls; DEN corner webs, a hanging spider,
  bones, a skull and a nest; VAULT a chest among coin piles with a gold gleam; PLAIN one to three of
  stalactites, mushrooms, a broken crate or a puddle, with glowing mushrooms from the stone band down and
  crystals in the deep.

## Text

All text is drawn in Colony's pixel font, `assets/fonts/pixel.px` (category `font`). The project theme
(`game/ui/theme.tres`) makes it every control's default, so a plain `Label` is already on style.

- **One colour.** Glyphs are `white` on transparency, so text can be tinted to any palette colour. Any other
  colour in a font sheet fails. **(lint)**
- **Metrics.** Each glyph is one part on a 5x8 cell, drawn from the cell's left edge: capitals and digits 5
  pixels tall (rows 0-4, the baseline under row 4), lower case 4 tall with ascenders to row 0, descenders on
  rows 5-6, row 7 always empty. Ascent 5, descent 2: a line is 7 pixels plus the label's line spacing.
- **Proportional.** A glyph's advance is its drawn width plus one column of spacing; a space is 3. The advances
  live in `pixel.png.import` (`character_ranges`, one `'c'-'c' <advance - 5> 0 -1` entry per part, in part
  order). Change a glyph's width and you change its entry; `test_009_pixel_font.gd` fails if they disagree.
- **Native size only.** The font's size is 8 (the cell height). It scales only by whole numbers; never set a
  font size other than 8 or a multiple of it.
- **Tell look-alikes apart.** `0` is square, `O` round; `1` has a flag and a foot, `l` is a bare stroke, `I`
  has serifs; `5` is square, `S` round.
- **Colour in code.** `PixelText.label(text, &"yellow")` gives a tinted label with a 1-pixel `ink` drop shadow
  (down and right), which keeps it readable over light ground. `PixelText.width(text)` measures a string.
- Look at it with `python tools/dev.py shot --scene=res://game/ui/font_specimen.tscn --name=font`.

## Effects

Effects (spec 010, `game/effects/`) are drawn in code from palette colours and a few `fx` sprites under
`assets/sprites/fx/` (`coin`, `mote`, `spark`).

- **Squares, not circles.** A particle is a square of whole pixels (a puff or flash has its corners cut);
  nothing is smooth, blurred or anti-aliased. Positions are rounded to whole pixels every frame.
- **Never fade.** An effect ends by shrinking, blinking or flying away, never by lowering its opacity.
- **Bright on dark.** Effects sit over dark ground (and will sit over darker ground once lighting lands), so
  they use the bright end of the palette: `white`, `yellow`, `amber`, `orange`, `green`, `cyan`, `red`.
- **Tinting.** `spark` is `white` so code can tint it any palette colour (white times a colour is that colour).
  Coins and motes keep their own colours.
- **Numbers.** Damage and heal numbers are the pixel font at 2x (crits at 3x), with an `ink` shadow one font
  pixel down and right: `white` on monsters, `red` on heroes, `amber` with `!` for a crit, `green` `+N` for a
  heal. Banners (`LEVEL UP`, `WIPED`, `DEPTH n STABLE`) use the same font, `yellow` or `red`.
- **Monster bursts** take their colours from the monster's own sheet, without its `ink` outline.

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
