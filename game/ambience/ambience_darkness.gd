class_name AmbienceDarkness
extends Node2D
## The darkness over the labyrinth: one rectangle covering the view, drawn over
## the world and the characters, that multiplies everything under it by the light at each pixel
## (darkness.gdshader). Its child LampGlow covers the same rectangle just after it and adds a
## share of the lamps' light back (glow.gdshader), so a dark back wall near a torch turns warm.
## It is handed the lights in view each frame; it chooses and sorts them again, and redraws, only
## when the view or the lights' places change, and otherwise only passes on their flicker.

const DARKNESS: Shader = preload("res://game/ambience/darkness.gdshader")
const GLOW: Shader = preload("res://game/ambience/glow.gdshader")
## The most lights the shaders take at once (MAX_LIGHTS in light.gdshaderinc); the nearest to the
## middle of the view win.
const MAX_LIGHTS: int = 32
## How much of the lamps' light the glow adds back.
const GLOW_STRENGTH: float = 0.2
## How far past the view's edges the rectangle reaches, in pixels, so a camera shake shows none
## of its edge.
const MARGIN: float = 32.0

## The lights handed over last (the caller's own list), and how many times a redraw was asked
## for, for tests.
var handed: Array[AmbienceLight] = []
var redraws: int = 0

var _view_rect: Rect2
## The lights handed over last, and each one's place, reach and core then (x, y, radius, core).
var _given: Array[AmbienceLight] = []
var _places: PackedVector4Array = []
## The lights the shaders take now, and their shapes and colours as the shaders read them.
var _near: Array[AmbienceLight] = []
var _shapes: Array[Vector4] = []
var _colors: Array[Vector4] = []
var _darkness := ShaderMaterial.new()
var _glow := ShaderMaterial.new()
var _glow_node := Node2D.new()


func _init() -> void:
	name = "Darkness"
	_shapes.resize(MAX_LIGHTS)
	_colors.resize(MAX_LIGHTS)
	_darkness.shader = DARKNESS
	material = _darkness
	_glow.shader = GLOW
	_glow_node.name = "LampGlow"
	_glow_node.material = _glow
	_glow_node.draw.connect(_draw_glow)
	add_child(_glow_node)
	var ambient: Array[Vector4] = []
	for stratum: int in LabyrinthTiles.STRATA.size():
		var color: Color = AmbienceMood.ambient_color(
			stratum * LabyrinthTiles.LEVELS_PER_STRATUM + 1
		)
		ambient.append(Vector4(color.r, color.g, color.b, 1.0))
	_darkness.set_shader_parameter(&"ambient", ambient)
	_set_both(&"level_pixels", AmbienceMood.LEVEL_PIXELS)
	_set_both(&"levels_per_stratum", float(LabyrinthTiles.LEVELS_PER_STRATUM))
	var lifts := PackedFloat32Array(AmbienceMood.EARTH_LIFT)
	_darkness.set_shader_parameter(&"earth_lift", lifts)
	_darkness.set_shader_parameter(&"ring_power", AmbienceMood.RING_POWER)
	var tints: Array[Vector4] = []
	for hue: StringName in AmbienceMood.GLOW_HUE:
		var tint: Color = Palette.color(hue)
		tints.append(Vector4(tint.r, tint.g, tint.b, 1.0))
	_glow.set_shader_parameter(&"glow_tint", tints)
	var depths: Array[float] = AmbienceMood.DAYLIGHT_DEPTHS
	var levels: Array[float] = AmbienceMood.DAYLIGHT_LEVELS
	_darkness.set_shader_parameter(&"daylight_depths", Vector3(depths[0], depths[1], depths[2]))
	_darkness.set_shader_parameter(&"daylight_levels", Vector3(levels[0], levels[1], levels[2]))
	_glow.set_shader_parameter(&"strength", GLOW_STRENGTH)
	_set_both(&"steps", float(AmbienceMood.STEPS))
	_set_both(&"earth_exposure", AmbienceMood.EARTH_EXPOSURE)
	_set_both(&"tile_size", float(LabyrinthView.TILE))


## Tells the shaders how much light reaches each tile: [param map] holds one pixel per tile,
## starting at world tile row [param top_row].
func set_exposure(map: Texture2D, top_row: int) -> void:
	_set_both(&"exposure", map)
	_set_both(&"exposure_origin", Vector2(0, top_row))
	_set_both(&"exposure_size", Vector2(map.get_size()))


## Lights the world as stage [param look]: its stratum everywhere, its ambient light,
## and no sky or daylight; or, with null, by depth under a sky.
func set_zone(look: ZoneLook) -> void:
	_set_both(&"zone_band", look.band if look != null else -1)
	_set_both(&"sky_line", -1.0e9 if look != null else 0.0)
	_darkness.set_shader_parameter(&"ambient_scale", look.dim() if look != null else 1.0)
	var levels: Array[float] = AmbienceMood.DAYLIGHT_LEVELS
	var sun: Vector3 = Vector3(levels[0], levels[1], levels[2]) if look == null else Vector3.ZERO
	_darkness.set_shader_parameter(&"daylight_levels", sun)


## Covers [param view_rect] (world pixels) and lights it with those of [param lights] that reach
## into it.
func show_lights(view_rect: Rect2, lights: Array[AmbienceLight]) -> void:
	var cover: Rect2 = view_rect.grow(MARGIN)
	handed = lights
	if cover != _view_rect or _moved(lights):
		_view_rect = cover
		redraws += 1
		_choose(view_rect.get_center())
		queue_redraw()
		_glow_node.queue_redraw()
	for i: int in _near.size():
		var light: AmbienceLight = _near[i]
		var c: Color = light.color * light.energy
		_colors[i] = Vector4(c.r, c.g, c.b, 1.0)
	_set_both(&"light_color", _colors)


## True when [param lights] are not those handed over last, or one has moved or changed its
## reach or core; it then remembers them.
func _moved(lights: Array[AmbienceLight]) -> bool:
	var moved: bool = lights.size() != _given.size()
	if moved:
		_given.assign(lights)
		_places.resize(lights.size())
	for i: int in lights.size():
		var light: AmbienceLight = lights[i]
		var place := Vector4(light.position.x, light.position.y, light.radius, light.core)
		if moved or _given[i] != light or _places[i] != place:
			moved = true
			_given[i] = light
			_places[i] = place
	return moved


## Chooses the lights that reach into the view, the nearest to [param centre] if there are too
## many, and hands the shaders their shapes.
func _choose(centre: Vector2) -> void:
	_near.clear()
	for light: AmbienceLight in _given:
		if _view_rect.grow(light.radius).has_point(light.position):
			_near.append(light)
	if _near.size() > MAX_LIGHTS:
		_near.sort_custom(
			func(a: AmbienceLight, b: AmbienceLight) -> bool:
				return (
					a.position.distance_squared_to(centre) < b.position.distance_squared_to(centre)
				)
		)
		_near.resize(MAX_LIGHTS)
	for i: int in MAX_LIGHTS:
		var shape := Vector4.ZERO
		_colors[i] = Vector4.ZERO
		if i < _near.size():
			var light: AmbienceLight = _near[i]
			shape = Vector4(light.position.x, light.position.y, light.radius, light.core)
		_shapes[i] = shape
	_set_both(&"light_shape", _shapes)
	_set_both(&"light_count", _near.size())


func _set_both(parameter: StringName, value: Variant) -> void:
	_darkness.set_shader_parameter(parameter, value)
	_glow.set_shader_parameter(parameter, value)


func _draw() -> void:
	draw_rect(_view_rect, Color.WHITE)


func _draw_glow() -> void:
	_glow_node.draw_rect(_view_rect, Color.WHITE)
