class_name AmbienceDarkness
extends Node2D
## The darkness over the labyrinth (spec 012, R1): one rectangle covering the view, drawn over
## the world and the characters, that multiplies everything under it by the light at each pixel
## (darkness.gdshader). Its child LampGlow covers the same rectangle just after it and adds a
## share of the lamps' light back (glow.gdshader), so a dark back wall near a torch turns warm.
## It is handed the lights in view each frame.

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

var _view_rect: Rect2
var _darkness := ShaderMaterial.new()
var _glow := ShaderMaterial.new()
var _glow_node := Node2D.new()


func _init() -> void:
	name = "Darkness"
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
	_darkness.set_shader_parameter(&"earth_lift", AmbienceMood.EARTH_LIFT)
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
	_set_both(&"exposure_steps", AmbienceMood.EXPOSURE_STEPS)
	_set_both(&"tile_size", float(LabyrinthView.TILE))


## Tells the shaders how much light reaches each tile: [param map] holds one pixel per tile,
## starting at world tile row [param top_row].
func set_exposure(map: Texture2D, top_row: int) -> void:
	_set_both(&"exposure", map)
	_set_both(&"exposure_origin", Vector2(0, top_row))
	_set_both(&"exposure_size", Vector2(map.get_size()))


## Covers [param view_rect] (world pixels) and lights it with those of [param lights] that reach
## into it.
func show_lights(view_rect: Rect2, lights: Array[AmbienceLight]) -> void:
	_view_rect = view_rect.grow(MARGIN)
	var centre: Vector2 = view_rect.get_center()
	var near: Array[AmbienceLight] = []
	for light: AmbienceLight in lights:
		if _view_rect.grow(light.radius).has_point(light.position):
			near.append(light)
	if near.size() > MAX_LIGHTS:
		near.sort_custom(
			func(a: AmbienceLight, b: AmbienceLight) -> bool:
				return (
					a.position.distance_squared_to(centre) < b.position.distance_squared_to(centre)
				)
		)
		near.resize(MAX_LIGHTS)
	var shapes: Array[Vector4] = []
	var colors: Array[Vector4] = []
	for light: AmbienceLight in near:
		shapes.append(Vector4(light.position.x, light.position.y, light.radius, 0.0))
		var c: Color = light.color * light.energy
		colors.append(Vector4(c.r, c.g, c.b, 1.0))
	shapes.resize(MAX_LIGHTS)
	colors.resize(MAX_LIGHTS)
	_set_both(&"light_shape", shapes)
	_set_both(&"light_color", colors)
	_set_both(&"light_count", near.size())
	queue_redraw()
	_glow_node.queue_redraw()


func _set_both(parameter: StringName, value: Variant) -> void:
	_darkness.set_shader_parameter(parameter, value)
	_glow.set_shader_parameter(parameter, value)


func _draw() -> void:
	draw_rect(_view_rect, Color.WHITE)


func _draw_glow() -> void:
	_glow_node.draw_rect(_view_rect, Color.WHITE)
