class_name Ambience
extends Node2D
## Ambient life over the labyrinth view: darkness with stepped pools of torchlight,
## a light that follows the party, things buried in the earth, props that say what kind each
## chamber is, and small motion everywhere (flames, dust, embers, drips, critters, glints).
## Told where a party is ([method follow_party]), it keeps every room dark until the party has
## stepped into it ([AmbienceRooms]).
## It changes no rules and decides nothing.
##
## Put it in the tree after the [LabyrinthView] and before the characters, at the view's
## position, then call [method setup]. Props draw over the tiles and under the characters; the
## darkness ([AmbienceDarkness], z [constant DARKNESS_Z]) draws over both, so the party and the
## monsters dim with the world; flames and glints draw over the darkness, so they shine.
##
## Each level the view builds gets an [AmbienceLevel], placed only from the labyrinth and tile
## positions, and freed with the level.

## Where the darkness is drawn: over everything at z 0, under each level's glow.
const DARKNESS_Z: int = 100
## The party's light, white so the heroes keep their true colours. Within its core (the
## formation of four, 17 pixels apart, and a tile either side of it, measured from its middle)
## it lifts any stratum's darkness all the way to unlit; past it, rings fade out to its radius.
const PARTY_CORE: float = 58.0
const PARTY_RADIUS: float = 100.0
const PARTY_ENERGY: float = 0.9

## Where the party's light is, in world pixels. Whoever owns the party sets it every frame.
var party_light_position: Vector2

## Which rooms of the stage shown are lit, and the torches catching in one just entered.
var rooms := AmbienceRooms.new()
## The lit lights, listed again only when [member AmbienceRooms.changes] has moved on.
var _lights: Array[AmbienceLight] = []
var _lights_at: int = -1

var _view: LabyrinthView
var _levels: Dictionary[int, AmbienceLevel] = {}
var _darkness: AmbienceDarkness
var _party_light: AmbienceLight
## The built levels' exposure maps in one texture for the darkness; remade when levels change.
var _exposure := ImageTexture.new()
var _exposure_stale: bool = true
## The look the darkness was last given: its band and stage, or (-1, 0) for none, and
## (-2, 0) before the first.
var _zone: Vector2i = Vector2i(-2, 0)


func _process(delta: float) -> void:
	if _view != null:
		advance(delta)


## Call once, before the first advance. Ambience adds itself what it needs around the view.
func setup(view: LabyrinthView) -> void:
	_view = view
	position = view.position
	_darkness = AmbienceDarkness.new()
	_darkness.z_index = DARKNESS_Z
	_darkness.z_as_relative = false
	add_child(_darkness)
	_party_light = AmbienceLight.new(
		&"party", party_light_position, PARTY_RADIUS, PARTY_ENERGY, Palette.color(&"white")
	)
	_party_light.core = PARTY_CORE
	view.level_built.connect(_on_level_built)
	view.level_freed.connect(_on_level_freed)
	for depth: int in view.built_depths():
		_on_level_built(depth)


## Follows the labyrinth view's built levels and advances animation. Called every frame;
## tests call it.
func advance(delta: float) -> void:
	_sync_levels()
	var look: ZoneLook = _view.zone_look()
	var key: Vector2i = Vector2i(look.band, look.stage) if look != null else Vector2i(-1, 0)
	if key != _zone:
		_zone = key
		_darkness.set_zone(look)
	_party_light.position = party_light_position
	rooms.advance(delta)
	for depth: int in _levels:
		_levels[depth].advance(delta)
	if _exposure_stale:
		_update_exposure()
	_darkness.show_lights(_visible_rect(), lights())


## Tells the rooms where [param run]'s party is on [param stage], the stage shown, once a frame:
## a room it steps into lights, and with [param at_once] (an arrival, or a picture catching up)
## only the room it stands in is lit, with no flare. See [method AmbienceRooms.follow].
func follow_party(run: Expedition, stage: int, at_once: bool) -> void:
	rooms.follow(run, stage, at_once)


## How many lights there are, for tests and the budget of lights.
func light_count() -> int:
	return lights().size()


## How many motes there are, for tests and the budget of motes.
func particle_count() -> int:
	var count: int = 0
	for depth: int in _levels:
		count += _levels[depth].motes.size()
	return count


## The decoration placed in a chamber, as prop names, for tests.
func props_in(depth: int, chamber_index: int) -> PackedStringArray:
	var names: PackedStringArray = []
	if _levels.has(depth):
		for prop: AmbienceProp in _levels[depth].props:
			if prop.chamber == chamber_index:
				names.append(prop.name)
	return names


## The decoration of a built level, or null. For tests.
func level(depth: int) -> AmbienceLevel:
	if _levels.has(depth):
		return _levels[depth]
	return null


## Depths decorated now, ascending. For tests.
func built_depths() -> Array[int]:
	var depths: Array[int] = []
	for depth: int in _levels:
		depths.append(depth)
	depths.sort()
	return depths


## Every light that is lit now: the party's, then each level's in its lit rooms. The ambience's
## own list, the same one every time: read it, never change it.
func lights() -> Array[AmbienceLight]:
	if _lights_at != rooms.changes:
		_lights_at = rooms.changes
		_lights.clear()
		if _party_light != null:
			_lights.append(_party_light)
		for depth: int in _levels:
			rooms.lit_lights(depth, _lights)
	return _lights


## The light at a world pixel, as the darkness draws it (1 in each channel is unlit).
func light_at(world_pixels: Vector2) -> Color:
	var look: ZoneLook = _view.zone_look() if _view != null else null
	return AmbienceMood.light_at(world_pixels, lights(), _exposure_at(world_pixels), look)


## How bright the world is drawn at a world pixel, 0 (black) to 1 (unlit).
func brightness_at(world_pixels: Vector2) -> float:
	return AmbienceMood.brightness(light_at(world_pixels))


func _on_level_built(depth: int) -> void:
	if _levels.has(depth):
		return
	var decoration := AmbienceLevel.new()
	decoration.build(_view, depth)
	add_child(decoration)
	_levels[depth] = decoration
	rooms.dress(decoration, _view.labyrinth.level(depth))
	_exposure_stale = true


func _on_level_freed(depth: int) -> void:
	if _levels.has(depth):
		rooms.strip(depth)
		_levels[depth].free()
		_levels.erase(depth)
		_exposure_stale = true


## The share of lamplight that reaches a world pixel: its tile's, as the shaders read it.
func _exposure_at(world_pixels: Vector2) -> float:
	return _tile_exposure(Vector2i((world_pixels / LabyrinthView.TILE).floor()))


func _tile_exposure(tile: Vector2i) -> float:
	var decorated: AmbienceLevel = level(maxi(1, floori(float(tile.y) / _rows()) + 1))
	if decorated == null:
		return AmbienceMood.EARTH_EXPOSURE
	return decorated.exposure_at(tile)


func _update_exposure() -> void:
	_exposure_stale = false
	var depths: Array[int] = built_depths()
	if depths.is_empty():
		return
	var first: int = depths[0]
	var rows: int = (depths[-1] - first + 1) * _rows()
	var map: Image = Image.create_empty(Labyrinth.LEVEL_WIDTH, rows, false, Image.FORMAT_R8)
	map.fill(Color(AmbienceMood.EARTH_EXPOSURE, 0.0, 0.0))
	for depth: int in depths:
		var band: Image = _levels[depth].exposure
		map.blit_rect(
			band, Rect2i(Vector2i.ZERO, band.get_size()), Vector2i(0, (depth - first) * _rows())
		)
	_exposure.set_image(map)
	_darkness.set_exposure(_exposure, (first - 1) * _rows())


## Rows of world each of the view's stages takes.
func _rows() -> int:
	return _view.labyrinth.band_height()


## Catches up with the view if a level was built or freed while not listening.
func _sync_levels() -> void:
	var built: Array[int] = _view.built_depths()
	for depth: int in _levels.keys():
		if not built.has(depth):
			_on_level_freed(depth)
	for depth: int in built:
		_on_level_built(depth)


## The world pixels the camera shows.
func _visible_rect() -> Rect2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Rect2()
	var screen := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	return get_global_transform_with_canvas().affine_inverse() * screen
