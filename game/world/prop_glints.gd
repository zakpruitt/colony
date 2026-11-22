class_name PropGlints
extends Node2D
## The glints on props waiting out of the party's light: the ambience's sparkle at a prop's top
## corner, drawn over the darkness like the glints on ore, slowly swelling and fading, so a prop
## waiting in the dark reads from across the level. In the party's light a prop has none.
##
## Whoever shows the props ([QuestProps], [SideProps]) makes one as its child and calls
## [method pulse] once a frame with the props that may glint.

## The glint's sheet, and its pulse: seconds for one swell, and the share of it spent small, big,
## small again (the rest dark).
const SHEET: String = "res://assets/sprites/ambience/sparkle.png"
const PERIOD: float = 2.0
const PULSE: Vector3 = Vector3(0.3, 0.6, 0.85)

var _world: World
## The props last pulsed, by their owner's key.
var _props: Dictionary[Vector2i, Sprite2D] = {}
## Seconds of the pulse; and per prop, the part showing now.
var _time: float = 0.0
var _parts: Dictionary[Vector2i, StringName] = {}


## Call once, in the tree, before the first pulse.
func setup(world: World) -> void:
	_world = world
	name = "Glints"
	z_index = AmbienceLevel.GLOW_Z
	z_as_relative = false


## The sparkle part glinting now on the prop pulsed under [param key] ([code]&"small"[/code] or
## [code]&"big"[/code]), or [code]&""[/code] when it has none: in the party's light, between two
## pulses, or no such prop.
func part(key: Vector2i) -> StringName:
	return _parts.get(key, &"")


## True when [param waiting] is out of the party's light, so it carries a glint (which may be
## between two pulses).
func in_the_dark(waiting: Sprite2D) -> bool:
	if waiting == null or _world.ambience == null:
		return false
	var light: Vector2 = _world.ambience.party_light_position
	return _glint_at(waiting).distance_to(light) > Ambience.PARTY_RADIUS


## The glints of those of [param props] out of the party's light, pulsing; moved on by
## [param delta] seconds.
func pulse(delta: float, props: Dictionary[Vector2i, Sprite2D]) -> void:
	_props = props
	_time = fposmod(_time + delta, PERIOD * 64.0)
	var parts: Dictionary[Vector2i, StringName] = {}
	for key: Vector2i in props:
		if not in_the_dark(props[key]):
			continue
		# Each prop's pulse starts at its own point, so two in view do not swell together.
		var phase: float = fposmod(_time / PERIOD + 0.37 * (key.x * 7 + key.y), 1.0)
		if phase < PULSE.x or (phase >= PULSE.y and phase < PULSE.z):
			parts[key] = &"small"
		elif phase < PULSE.y:
			parts[key] = &"big"
	if parts != _parts:
		_parts = parts
		queue_redraw()


## Where a prop's glint shines: on the top corner of its pixels, toward the back of the chamber.
static func _glint_at(waiting: Sprite2D) -> Vector2:
	var box: Rect2i = SpriteBounds.opaque(waiting.texture as AtlasTexture)
	var corner := Vector2(box.end.x - 2, box.position.y + 1)
	return waiting.position + waiting.offset + corner


func _draw() -> void:
	var sparkle: PixelSheet = PixelSheet.load_sheet(SHEET)
	if sparkle == null:
		return
	for key: Vector2i in _parts:
		var waiting: Sprite2D = _props.get(key, null)
		if waiting != null and is_instance_valid(waiting):
			var at: Vector2 = _glint_at(waiting) - (Vector2(sparkle.size) / 2.0).floor()
			draw_texture(sparkle.part(_parts[key]), at)
