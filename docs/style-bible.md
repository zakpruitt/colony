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
| `slime_king` | `boss` | `green` slime, `amber` crown with a `red` gem | body, eyes, head (crown), arm (pseudopod) |
| `clay_colossus` | `boss` | `clay` with `slate` stone plates, `orange` glowing cracks, `yellow` eyes | legs_back, body, head, arm (stone fist) |
| `bone_lord` | `boss` | `sand` bone under `dusk` armour, `plum` cloak, `cyan` eyes, `steel` great blade | body, head, arm, weapon (great blade) |
| `deep_maw` | `boss` | `pine` and `deep_teal`, `crimson` and `magenta` maw with `white` teeth, `cyan` eyes | legs_back, body, eyes, legs, arm (tentacle) |

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
- **Areas, not strata, on screen** (spec 054). The main game shows one stage at a time, and each area wears
  one stratum's look by its place in the list of areas: Mossy Hollow `loam`, The Claypits `clay`, The Old
  Crypt `stone`, Ember Deep `deep` (with that stratum's mood below). Each stage after an area's first keeps
  2% less of its ambient light, never less than 80%, so later stages read a little darker without becoming
  another place. The ladder and the surface are not drawn there; the ways on and back are doorways.
- **The doorway** (`props/doorway.px`, category `fx`, 32x44) is a rounded stone arch two tiles wide, standing
  on the floor where a shaft would have met it: `steel` blocks lit with `silver` and shaded with `slate` and
  `dusk`, outlined in `ink`, a `night` and `ink` dark inside so the party can vanish into it, and a
  threshold on the floor. It is the same in
  every area; the area's light colours it.
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
- **Side-quest props** (`assets/sprites/props/`, spec 028): one plain prop per side quest, placeholder by
  decision: `chest` (locked chest, `item`), `door` (stuck door, `fx` 24x24), `wanderer` (hurt wanderer, `item`),
  `stone` (rune stone, `fx` 24x24, `cyan` runes) and `wire` (tripwire, `item`). Each has a hand-drawn `ink`
  outline, stands on the floor line at the middle of its chamber, and is drawn under the darkness like the
  monsters. Its colours are its burst when the quest is done. Out of the party's light (spec 038) it
  carries a glint (the ambience `sparkle`) at its opaque box's top corner, drawn above the darkness: a
  slow pulse (small, big, small, then nothing, every 2 s), gone in the light and gone for good when the
  quest is done.

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
  Two status looks (below) are the only exceptions, because the spec asks for them by name.
- **Bright on dark.** Effects sit over dark ground (and will sit over darker ground once lighting lands), so
  they use the bright end of the palette: `white`, `yellow`, `amber`, `orange`, `green`, `cyan`, `red`.
- **Tinting.** `spark` is `white` so code can tint it any palette colour (white times a colour is that colour).
  Coins and motes keep their own colours.
- **Numbers.** Damage and heal numbers are the pixel font at 2x (crits at 3x), with an `ink` shadow one font
  pixel down and right: `white` on monsters, `red` on heroes, `amber` with `!` for a crit, `green` `+N` for a
  heal. Banners (`LEVEL UP`, `WIPED`, `DEPTH n STABLE`) use the same font, `yellow` or `red`.
- **Monster bursts** take their colours from the monster's own sheet, without its `ink` outline.
- **Guardians** (spec 024) are the loudest moments. Their announcement is the name at 4x in `white` with
  `GUARDIAN OF DEPTH n` at 2x in `red` under it, in the upper middle of the screen. Their death is a hard
  shake, a 0.2 s freeze, a burst in three waves of the guardian's own colours (each opening with a `white` or
  `yellow` flash and a ring in its first colour), a fountain of coins and `GUARDIAN SLAIN` at 4x in `yellow`.
  Only a guardian's death may go past the particle cap, and only by its own particles.
- **The fallen** (spec 038) are their own sprite turned a quarter turn about the feet, head away from the
  way they faced, and lifted so the back rests on the floor: a quarter turn keeps every pixel whole, so no
  squashed or smeared death pose. They lie until the fight is won or the party revived; after a wipe
  they rise in 0.8 s under the revival light, where the camera has travelled (eased, 0.6 to 3 s) after
  a 1.5 s hold.
- **Guardian fights** keep melee heroes at the guardian's opaque edge, 2 pixels off, never overlapping it.

### Abilities and statuses (spec 056)

- **Names.** An ability's name rises 8 px over 1.2 s above the fighter's head, in the pixel font at 1x,
  outlined all round in `ink` (one font pixel) as well as its shadow so it reads against any wall, in the
  fighter's colour (a hero's class bar colour, a monster's most vivid sheet
  colour). At most two stack over one fighter, the newest nearest the head, 8 px apart. Names, words and damage
  numbers are kept inside the band between the HUD's top and bottom panels.
- **Wind-up.** An action's wind-up lights the whole sprite `yellow`, pulsing between a quarter and
  three-fifths at 6 Hz, for exactly the wind-up's length. An ordinary strike's wind-up is never lit.
- **Landings.** A heavy blow (an ability whose damage is at least 1.5x a strike's; a stun
  alone does not make it heavy) adds a 15 px `white`
  flash and ten `amber`/`yellow` shards on top of the usual sparks. Damage to many draws a flat ring of
  single-pixel squares (one every 4 px, a third as tall as wide) from the fighter or the target out to the
  ability's reach in 0.4 s, then blinks out. A push leaves `tan` and `silver` dust at the feet of those it
  landed on while they slide. `Miss` (`silver`) and `Blocked` (`cyan`) are words at 1x; a shield shows at
  most one `Blocked` a second, however many blows it takes.
- **Status marks** (`assets/sprites/ui/status_icons.px`, one 7x7 part per status, named as the status) sit
  in a row 2 px over the head: taunting (a red `!`), marked (a target), mighty (a bright sword), weakened
  (a broken one), hasted (an arrow up), slowed (an arrow down). The same marks are the hero frame's icons.
- **Stunned** is three star marks circling the head, and the sprite stops moving. **Shielded** is a 1 px
  outline 2 px off the body, corners cut, that steps from `cyan` to `blue` to `navy` as the shield is used
  up: it dims by palette steps, not by opacity.
- **Burning, bleeding, chilled** wash the sprite 40% toward `orange`, `red` or `cyan`, with three small motes
  of their colours (bleeding drips down; the others rise), and their damage numbers take the colour.
  **Mending** is green motes rising.
- **Nimble and untouchable** draw the sprite at half opacity: the one exception to "never fade", since the
  spec names it ("the sprite half faded"). It is a state, not an effect ending, and it is whole again the
  frame the status ends.

### Moves and spells (spec 057)

- **Moves** are made in code from the existing parts, never new sheets: a leap (up 12 px in an arc, 8 px
  forward), a spin (a full turn with a small hop), a dash (back 8, through 10), a heavy swing, a throw, a
  brace (a crouch, shield up), a shout (rear back, puff up), a cast (lift 4 px, thrust as it lands), a
  channel (arms up, lift 6, held), a prayer (head bowed, then arms raised) and a flourish (a short hop or
  flick over whatever the hero is doing). Each squashes on landing (shorter and wider) and stretches in the
  air. The blow lands on the simulation's tick; the recovery after is at most 0.4 s.
- **Bounce.** An ordinary strike draws back 3.5 px and steps in 4.5; a ranged shot recoils 2.5. A kill or a
  crit hops 5 px; after a won fight each living hero cheers (a 6 px hop, weapon raised), 0.12 s apart.
- **Spells** are palette squares only, one colour family each: fire `orange`, `amber`, `yellow`, `red`;
  frost `cyan`, `white`, `silver`; holy `yellow`, `sand`, `white`; shadow `orchid`, `plum`, `dusk`; spark
  `white`, `yellow`, `cyan`; thrown steel `silver`, `white`, `steel`. A fireball and an ice shard fly with a
  trail, a meteor falls from above the screen, frost spreads along the floor, flakes fall for a blizzard, a
  spark jumps from enemy to enemy, a column of light stands on whoever is healed, a beam falls for a smite.
  Every spell is gone within a second of landing. A spell that shows on whom it lands shows only on
  the fighters the fight's events say it reached, and a beam starts under the HUD's top band.
- **Particle caps.** Each kind of effect keeps its own: spec 010's combat effects 300
  (`CombatEffects.MAX_PARTICLES`), spec 056's ability effects 150 (`AbilityEffects.MAX_PARTICLES`)
  and spells 120 (`SpellEffects.MAX_PARTICLES`), so at most 570 at once; past its cap an effect
  makes fewer particles, never more.

## UI

The HUD (`game/hud/`, spec 011) sets the pattern for every screen element.

- **Edges only.** The HUD keeps to the top 28 and bottom 40 pixels of the 640x360 screen; the middle belongs to
  the world.
- **Always on a dark panel.** Every text and bar sits on a `HudPanel`: a 1-pixel `ink` border around a `night`
  fill, with a `dusk` bevel along the top and left inside the border (light from the top-left). Square
  corners, whole pixels, no gradients. Panels are opaque, so text reads the same over sky and deep rock.
- **Buttons** (`HudButton`) are 11 pixels tall: `ink` border, `dusk` fill with a `slate` bevel, `silver`
  text; `slate` with `yellow` text under the mouse; `night` and one pixel lower when pressed. A toggle that is
  on is `forest` with a `green` bevel and `white` text, and says so in words (`Auto on`). No Godot default
  styles, no focus rings.
- **Disabled buttons** sink to a `night` fill with no bevel and do nothing. A button may colour its text
  (`text_colour`): the shop's prices are `yellow` when affordable and `brick` (dim red) when not.
- **Overlays** such as the upgrade shop (spec 017) are the one exception to "edges only": a `HudPanel` that
  drops from under the top band at the right, never covering the top band or the party frames, opened and
  closed by the player. Rows inside it are separated by space, not lines; a row that just changed flashes
  `forest` with a `green` edge, then `dusk`, for half a second.
- **The hero sheet** (spec 026) is the shop's twin on the left: a `HudPanel` dropping from under the top
  band below the depth panel, ending well above the party frames (a 12-pixel strip stays clear above them).
  The portrait is the frame's icon at 2x in an `ink` box with a `dusk` edge, the class name is the font at
  2x in `white`, sections are split by 1-pixel `dusk` lines, stat names are `steel` captions with `white`
  values and an upgrade's bonus in `green` after them. The hero's activity is one word or phrase in the colour
  of the HUD's state word (`orange` fighting, `green` healing or resting, `red` down). The frame whose sheet
  is open has a `yellow` edge with an `amber` bevel. Since spec 034 the sheet is at most 240x150: the header
  (portrait, class, role, level, activity, health and XP with their bars) is always shown, then a row of tab
  buttons (`Stats`, `Talents`, `Skills`) standing on a `dusk` line, the open one lit as a toggle is, with the
  keys in `slate` at the row's right (`Q E tabs   Tab next hero`). Only the open tab's page is shown; the
  panel keeps one size on every tab so it never jumps, except Talents (below). A tab's marker sits beside it,
  against its right edge, not over its name.
- **The talent tree** (spec 055) is the sheet's Talents tab, and the one tab that makes the sheet taller
  (240x278, still clear of the ticker's strip): the whole tree fits with nothing to scroll. The unspent points
  in `yellow` (or when the next comes, in `steel`) over the tree, with `Reset <price>` at the right and, when it
  is greyed, why in `slate` beside it. The trunk's three nodes in a row, then the two paths side by side under
  their names, four nodes each in a column, joined by 1-pixel lines (`silver` between taken nodes, `slate`
  otherwise, `dusk` into a closed path). A node is a 14x14 box holding a 12x12 picture of its kind, its
  ability's name beside it: taken is a `pine` box with a `green` edge, a small `green` tick and the name in
  `white`; one that can be taken now has a `yellow` edge stepping to `amber` once a second and its name in
  `yellow`; a plain one has a `dusk` edge and a `steel` name; a closed one is an `ink` box with no picture and
  a `slate` name, its path's name `slate` with a `silver` line through it, and the chosen path's name `white`.
  Under the tree, past a `dusk` line, one fixed place tells the node under the mouse (or last clicked): its
  name in `white` with its kind at the right in `steel` (`Action, every 8 s`, `Passive`), the description in
  `silver` over two or three lines, and the reason in `red` (`green` `Taken`, `yellow` `Click to take it`);
  a question replaces it in `yellow`, with its two buttons under it. The paragon points come last, past
  another `dusk` line: a `+1` button, the stat's name in `white` and its bonus in `green` for each.
- **Markers** that ask for attention are a small `amber` tag with an `ink` number, pulsing to `orange` and
  lifting a pixel on the beat, pinned to the top-right corner of the button they belong to.
- **The boss bar** (spec 024) is a top-band panel of its own between the depth panel and the shop tab,
  centred, at most 240 pixels wide: the guardian's name in capitals over a 7-pixel `red`/`crimson` bar with a
  `pink` top row, an `amber` trail of lost health draining behind it, and a `white` flash on each hit.
- **Reading the party** (spec 027). The depth panel's state is a short sentence in the state's colour
  (`Heading down to depth 5`, `Fighting the Slime King`), and the panel grows to hold it, never into the boss
  bar or the shop tab. The road to stable is the panel's third column, after its own `dusk` divider:
  `Stable in m:ss` in `silver` over a 40x5 bar filling in `yellow`/`amber` on `ink`, and what auto-push does
  next (`then depth N`) in `steel`; a stable depth reads `Stable` in `green`, with no bar. A fallen hero's
  frame reads `Down` in `red` where the level was, and all four read `Recovering` in `pink` during a revival.
- **The journal ticker and panel** are overlays like the shop. The ticker is a one-line `HudPanel` centred
  just above the party frames, its sentence in `white`; after 4 s the text steps down `silver`, `steel`,
  `slate` (0.2 s each) and the panel goes. Text never fades by opacity. The journal panel (`J`) drops from
  under the top band at the left: `Journal` in `yellow`, the game time in `steel`, the newest line in `white`
  and the rest in `silver`.
- **Help and tooltips** (spec 030). The help panel is an overlay centred under the top band, ending above the
  journal ticker's strip: `How Colony works` in `yellow` with an `x` button, `steel` section captions
  (`The idea`, `Keys`), the idea in `white`, each key in `yellow` with what it does in `silver`, and a `steel`
  footer under a `dusk` line. Its `?` button sits in the shop tab, left of `Shop`, lit while help is open. A
  tooltip is one line of `white` text on a 13-pixel `night` panel with a `slate` border: under the top band
  for a top element, just above a bottom one, never over what it explains.
- **The depth ladder** (spec 033) is the one HUD panel that stays up below the top band: 52 pixels wide on the
  right edge, from under the top band to well above the ticker's strip, hidden while the shop (which drops
  into the same place) is open. `Depths` in `steel` over a `dusk` line, then 12 rows of 20 pixels, all drawn
  in code: two `slate` rails with a 3-pixel rung between them per depth, `silver`/`steel` solid when held,
  `green`/`forest` for the safe depth, a `steel` outline when visited, a 1-pixel `dusk` line when never
  reached. The depth number sits left of the rails in the colour of how that depth looks for the party
  (spec 043): `cyan` safe, `orange` within reach, `red` dangerous, never the `white`, `yellow` or `green` of
  the party's, the target's or the safe depth's marks. The party is a 7x7 `white` diamond with an `ink` edge and a `cyan`
  glint, bobbing a pixel; the target is a 4x7 `yellow` arrow left of its number; a guardian is a 5x5 `white`
  skull right of the rails, `slate` and crossed in `red` while beaten. A rung under the mouse gets a `slate`
  outline, and after the tooltips' delay its line shows left of the ladder in the tooltip's box, with
  `Click to send the party here` in `yellow`, and under it, in the risk's colour, `Within reach` or
  `Dangerous: heroes are level L`. It scrolls smoothly, never a whole rung in one frame. Scrolled away by the
  wheel, it shows a 15x8 `night` box with an `ink` edge, holding a 7x4 `white` triangle pointing toward the
  party: in the caption's row just right of `Depths` when the party is above, on the panel's bottom edge over
  the rails when below, never over the party's diamond, which is drawn above everything else on the rungs.
  Since spec 047 the target's number sits in a 21x14 `yellow` frame whose left edge the target's arrow
  touches, and the party's in a 19x12 `white` frame one pixel inside where the two share a rung, so neither
  depends on the number's risk colour.
- **The goals tracker** (spec 037) drops from under the top band at the left, below the depth panel, in the
  place the hero sheet and journal use (it hides while either, or the tally, is open): `Goals` in `steel` and `G hide` in
  `slate` over up to three rows. A row is a small `steel` square (a 7x5 `green` tick drawn in code once
  done), the sentence in `white`, and under it a 4-pixel bar (`cyan`/`blue` for levels and XP,
  `yellow`/`amber` for depth) ending at one column for every row, with its count in `steel` to its right; a
  gold goal has no bar and its price in `yellow` at the sentence's right. A finished row flashes `forest`
  with a `green` edge (text `white`), then its sentence and bar turn `green` for 3 s. Since spec 042 each row
  is a button: under the mouse it is lit as a `HudButton` is (`slate` fill, `steel` bevel, `ink` edge), a
  finished row is not, and a gold goal ends in a 3x5 `>` in `yellow` with an `ink` shadow, drawn in code
  after its price. The depth goal's click flashes its rung on the ladder for 1 s: a `yellow` outline round
  the row with an `amber` one inside it, blinking on and off every quarter second.
- **The defeat note** (spec 041) is an overlay of its own after a wipe: a `HudPanel` centred across the
  screen, its bottom 6 pixels above `WIPED` (popped size) and so below the goals tracker. What beat the party
  in `white`, the reason under it in `silver`, both centred, then a centred row of up to three `HudButton`s 4
  pixels apart; `Holding` is lit as a toggle is, only while the order is Hold. 8 s after the heroes stand (not while
  the mouse is on it or a panel hides it) its text steps down `silver`, `steel`,
  `slate` (0.2 s each), buttons too, and it goes; never by opacity. It hides while any panel is open.
- **The party tally** (spec 045) is a damage meter in the hero sheet's place and at its size (240x150),
  never sharing the screen with the other panels. `Party tally` in `yellow`; the span switch (`Last fight`,
  `Session`) as two buttons left of the `x`, the chosen one lit as a toggle is; three tab buttons (`Damage`,
  `Healing`, `Taken`) on a `dusk` line with `Q E tabs   T close` in `slate`; the fight's line in `silver`
  (`Last fight: 3 ogres, depth 7, 14 s`); then a row per hero in party order: the frame's portrait in a
  20x20 `ink` box with a `dusk` edge, the class in `white`, the number in `white` and the share in `steel` at
  the right, over an 8-pixel bar on `ink` in the class's colour (knight `red`/`crimson`, rogue
  `orchid`/`plum`, mage `blue`/`navy`, cleric `amber`/`copper`), the largest row full and the bars easing as
  every bar does. On the Session span each hero's side quests are a `green` line under the bars. Its button
  sits left of the party frames, as tall as one: three small bars in `red`, `blue` and `amber` on `ink`
  edges over a `T`, lit while the tally is open.
- **The area map** (spec 053) is an overlay like the help panel: centred under the top band, left of the
  depth ladder, ending above the ticker's strip, at most 34 pixels a row so six areas fit. `Areas` in
  `yellow`, `W close` in `slate` and an `x` button over a `dusk` line; then a row per area on its own
  `night` panel: the name in `white` with `Here` in `green` or `On the way, 7 s` in `tan` after it, the level
  of the first stage in `silver` and the safe and furthest stage in `steel` under it, and at the right the
  area's monsters standing at rest (at 1x up to 32 pixels tall; a guardian's 64-pixel sprite at half size),
  then, after a `dusk` line, its guardian with the goals' 7x5 `green` tick once beaten. A closed area has no
  panel of its own: its name is `slate`, its line says which guardian opens it, and its sprites are darkened,
  never faded. A row under the mouse is lit as a `HudButton` is; the chosen row has a `yellow` outline with
  an `amber` one inside. Under a `dusk` line the footer shows the chosen area, `-`, the stage in the ladder's
  risk colour (`cyan`, `orange`, `red`), `+`, `Go`, and the risk in words in the same colour. The area's name
  in the depth panel is the map's button: outlined `yellow` under the mouse and `green` while the map is
  open, with the usual amber marker at its top-right while an area has opened since the map was last seen.
- **Frame markers** (spec 037) sit inside a hero frame's top-right corner, not above it (the ticker's strip
  stays clear); the level moves left of the marker.
- **The target arrow** over the party is the one HUD-like mark in the world: a 9x10 arrow drawn in code,
  `yellow` (the target's colour) with an `ink` outline, bobbing two pixels, above the effects' darkness.
- **Bars** have an `ink` border and fill from the left in whole pixels, with a darker bottom row: health is
  `green`/`forest` above half, `yellow`/`amber` down to a quarter, `red`/`crimson` below, on `dark_brown`;
  XP is `cyan`/`blue` on `ink`. Bars ease to a new value over about 0.3 s, never jump.
- **Text.** Captions in `steel`, values in `white` or `silver`, levels and the target in `yellow`. Big
  numbers (the depth, the gold) are the font at 2x with a 2-pixel shadow. Dim things are `slate`.
- **Icons** are 16x16 parts of `assets/sprites/ui/hud_icons.px` (category `ui`): a portrait per hero class,
  cropped from the hero's own head and body, a `skull` for a fallen hero and a `coin`. A new class needs a
  portrait part named for its id.
- **Resource icons** (spec 052) are 8x8 parts of `assets/sprites/ui/resource_icons.px` (category `ui`), one
  named for each resource's id: a `cyan` glowing mushroom on a `silver` stalk (glowcaps), a `sand`-to-`umber`
  lump (clay), two crossed `white`/`silver` bones (old bones) and a coal burning `yellow` to `crimson`
  (embers), each drawn with an `ink` edge so it reads on any panel. They stand beside the gold with their count
  in `white`, on the shop's rows (the price `white`, `slate` while the party has too little) and the area map,
  and rise from a monster that drops one. A new resource needs a part named for its id.
- **Talent pictures** (spec 055) are 12x12 parts of `assets/sprites/ui/talent_icons.px`, one per kind of
  ability, not one per ability: `strike` (a sword), `guard` (a shield), `heal` (a green cross), `fire` (a
  flame), `frost` (an ice crystal), `shadow` (a crescent), `light` (a four-pointed spark) and `rally` (a red
  banner), each with an `ink` edge. `TalentNode.KINDS` gives each ability its kind; a new ability needs a
  line there (it shows `strike` until it has one). Placeholder art.

## Sound

Sound effects (spec 021) are made like the sprites: each is a small text recipe, `assets/audio/sfx/<name>.sfx`,
baked by `python tools/sfx.py bake` into a 16-bit mono 22050 Hz `.wav` beside it. The recipe format is in
the docstring of `tools/sfx.py`: one or more `[part]`s, each a wave (`square`, `triangle`, `saw`, `sine` or
8-bit `noise`), a start, a length, a pitch with an optional slide, a volume envelope and optional noise.
`python tools/sfx.py lint` (in the check's `art` step) fails on a missing or stale `.wav`, a sound over
1.2 seconds or a peak above -3 dB.

- **Chunky and 8-bit.** Square, triangle and noise waves, short slides and arpeggios; no samples from outside
  the repository.
- **Short.** Most sounds are under 0.3 s; only the beats of the loop (a wipe, a revival, a stable depth, a
  level up, a guardian appearing or slain) run longer, and none past 1.2 s.
- **Never harsh.** Peaks well under -3 dB (most are -5 to -14 dB), a gentle low-pass on every mix, and no
  click: every part rises from silence and falls back to it.
- **Shape matches the moment.** A coin is bright and short, a level up and a revival rise, a wipe and a hero's
  death fall, hits are thumps with a crack of noise (a crit heavier, with a ring), a hero's hurt is duller.
- **Quiet in the game.** Everything plays on the `SFX` bus at -12 dB; `M` mutes it. The player
  (`game/audio/sound_player.gd`) never starts the same sound twice within 0.05 s, plays at most 8 at once and
  varies each start's pitch a little.

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
