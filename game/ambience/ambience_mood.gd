class_name AmbienceMood
extends RefCounted
## How dark each earth stratum is and what colour light takes there (spec 012, R1 and R7), and
## the stepped light formula. [code]darkness.gdshader[/code] draws the same formula on the GPU;
## [method light_at] computes it here so tests can read it. Change one, change both.
##
## Light is a colour the world is multiplied by: white is unlit, black is pitch dark. Underground
## it starts at the stratum's ambient colour, and the lights add their colour in rings of
## [constant STEPS] bands, so it stays pixel art. Where pools overlap the strongest light wins,
## channel by channel, so overlaps never make extra bands.

## How many rings of brightness a light's pool falls off in.
const STEPS: int = 3
## Each ring's strength is its share of the radius raised to this, so the core is bright and
## the outer ring faint: the pool has no hard rim.
const RING_POWER: float = 1.5
## Per stratum, in [constant LabyrinthTiles.STRATA] order (loam, clay, stone, deep): the palette
## colour the darkness leans toward, and how much of it there is (1 is unlit). Loam is warm,
## clay warmer, stone cold and darker, deep an eerie teal.
const AMBIENT_HUE: Array[StringName] = [&"tan", &"orange", &"steel", &"cyan"]
## The deep is lifted (spec 018 R3) so its dark monsters still read outside the party's light.
const AMBIENT_LEVEL: Array[float] = [0.34, 0.33, 0.36, 0.46]
## How much of the hue goes into the ambient colour, the rest being grey.
const AMBIENT_SATURATION: Array[float] = [0.45, 0.6, 0.5, 0.55]
## Per stratum, the palette colour torchlight leans toward, and how far.
const LIGHT_HUE: Array[StringName] = [&"amber", &"orange", &"sand", &"cyan"]
const LIGHT_SATURATION: Array[float] = [0.7, 0.75, 0.45, 0.55]
## Daylight seeping into the first rows of earth under the surface: how many pixels down each
## band of it reaches, and how much light it adds.
const DAYLIGHT_DEPTHS: Array[float] = [12.0, 28.0, 48.0]
const DAYLIGHT_LEVELS: Array[float] = [0.35, 0.2, 0.1]
## How much of a light reaches each tile: all of it in open space, a little on a tile touching
## open space (a wall's face, the floor's crust), none in the earth beyond. Read per tile, so
## the lit shape is the chamber's shape and no ring is drawn over solid rock.
const EDGE_EXPOSURE: float = 0.35
const EARTH_EXPOSURE: float = 0.0
## Per stratum, how much brighter solid earth is than open space where no lamp reaches, so the
## earth reads as a mass and tunnels as voids, and chamber outlines stay readable in the dark
## strata, whose earth and back wall are nearly black (scaled by how little lamplight reaches).
const EARTH_LIFT: Array[float] = [0.12, 0.12, 0.24, 0.2]
## Per stratum, the palette colour of the warm glow added near lamps (see glow.gdshader).
const GLOW_HUE: Array[StringName] = [&"orange", &"orange", &"amber", &"cyan"]
## The level height in world pixels.
const LEVEL_PIXELS: float = Labyrinth.LEVEL_HEIGHT * LabyrinthView.TILE


## The stratum index (0 loam, 1 clay, 2 stone, 3 deep) of a depth, as the earth is drawn.
static func band(depth: int) -> int:
	return LabyrinthTiles.STRATA.find(LabyrinthTiles.stratum(depth))


## The depth whose band holds the world pixel row [param y] (1 above ground).
static func depth_at(y: float) -> int:
	return maxi(1, floori(y / LEVEL_PIXELS) + 1)


## The light everything at [param depth] has with no lamp near it.
static func ambient_color(depth: int) -> Color:
	var index: int = band(depth)
	var level: float = AMBIENT_LEVEL[index]
	var grey := Color(level, level, level)
	var tone: Color = Palette.color(AMBIENT_HUE[index])
	var hue := Color(tone.r * level, tone.g * level, tone.b * level)
	return grey.lerp(hue, AMBIENT_SATURATION[index])


## The colour of torchlight at [param depth], at full strength.
static func light_tint(depth: int) -> Color:
	var index: int = band(depth)
	return Color.WHITE.lerp(Palette.color(LIGHT_HUE[index]), LIGHT_SATURATION[index])


## How much of a light reaches [param distance] pixels from it: all of it within [param core]
## pixels, then [constant STEPS] rings out to [param radius], none past it.
static func falloff(distance: float, radius: float, core: float = 0.0) -> float:
	if radius <= core or distance >= radius:
		return 0.0
	var out: float = maxf(distance - core, 0.0) / (radius - core)
	return pow(ceilf((1.0 - out) * STEPS) / STEPS, RING_POWER)


## The daylight seeping down to world pixel row [param y]: all of it above ground, a few bands
## in the first rows of earth, none deeper.
static func daylight(y: float) -> float:
	if y < 0.0:
		return 1.0
	for i: int in DAYLIGHT_DEPTHS.size():
		if y < DAYLIGHT_DEPTHS[i]:
			return DAYLIGHT_LEVELS[i]
	return 0.0


## The light at a world pixel from the ambient darkness, daylight and [param lights], of which
## a share of [param exposure] reaches it (see [constant EDGE_EXPOSURE]). Each channel is
## between 0 and 1.
static func light_at(
	world_pixels: Vector2, lights: Array[AmbienceLight], exposure: float = 1.0
) -> Color:
	# Lights are sampled at pixel centres, as the shader does.
	var point := Vector2(floorf(world_pixels.x) + 0.5, floorf(world_pixels.y) + 0.5)
	var sun: float = daylight(point.y)
	if sun >= 1.0:
		return Color.WHITE
	var depth: int = depth_at(point.y)
	var lift: float = sun + EARTH_LIFT[band(depth)] * (1.0 - exposure)
	var total: Color = ambient_color(depth) + Color(lift, lift, lift, 0.0)
	total += lamps_at(point, lights, exposure)
	return Color(minf(total.r, 1.0), minf(total.g, 1.0), minf(total.b, 1.0))


## The lamps' light at a pixel centre whose tile takes [param exposure] of it: the strongest of
## them in each channel, not their sum. A light with a core (the party's) lights open space only.
static func lamps_at(point: Vector2, lights: Array[AmbienceLight], exposure: float = 1.0) -> Color:
	var strongest := Color(0, 0, 0, 0)
	for light: AmbienceLight in lights:
		var taken: float = exposure
		if light.core > 0.0:
			taken = 1.0 if exposure >= 1.0 else 0.0
		var reach: float = falloff(point.distance_to(light.position), light.radius, light.core)
		if reach > 0.0 and taken > 0.0:
			var c: Color = light.color * (light.energy * reach * taken)
			strongest = Color(
				maxf(strongest.r, c.r), maxf(strongest.g, c.g), maxf(strongest.b, c.b), 0.0
			)
	return strongest


## How bright a light colour looks, 0 to 1.
static func brightness(light: Color) -> float:
	return 0.299 * light.r + 0.587 * light.g + 0.114 * light.b
