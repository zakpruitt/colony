class_name UiIcon
extends Control
## A framed slot showing one picture of a thing a player can gain: an ability, a
## camp upgrade, a paragon stat or a microskill, found by the thing's own id
## ([method picture]). Large, the 16x16 picture is drawn at twice its size (32 UI pixels) in a
## bevelled frame; small, at its own size in a thin one.
##
## Four states, told apart by more than colour: [b]owned[/b] (full colour, a gold frame),
## [b]ready[/b] (full colour, a yellow frame that pulses gently, stepping to white and back),
## [b]locked[/b] (the picture dimmed, a plain frame) and [b]closed[/b] (the picture dark and barely
## there, a small padlock at the corner). The frame is square or has cut corners ([enum Shape]),
## can carry a short count at the bottom right in the UI font's equal-width digits, brightens
## under the mouse and emits [signal clicked] on a left click. Owned and ready never share an edge
## colour, lit or not, at any point of the pulse: owned keeps its gold edge under the mouse and
## brightens its picture and bevel instead.
##
## Its pulse runs in [method advance], which its owner calls every frame (as a talent node's is).

## A left click on the slot.
signal clicked

## How the thing stands for the player.
enum State { OWNED, READY, LOCKED, CLOSED }
## A square frame, or one with its corners cut (for actions and passives).
enum Shape { SQUARE, CUT }

## The sheets of pictures, one 16x16 part per thing, named for its id (assets/sprites/ui/).
const SHEETS: Array[String] = [
	"res://assets/sprites/ui/pictures_knight.png",
	"res://assets/sprites/ui/pictures_rogue.png",
	"res://assets/sprites/ui/pictures_mage.png",
	"res://assets/sprites/ui/pictures_cleric.png",
	"res://assets/sprites/ui/pictures_upgrades.png",
	"res://assets/sprites/ui/pictures_paragon.png",
	"res://assets/sprites/ui/pictures_skills.png",
	"res://assets/sprites/ui/pictures_artifacts.png",
]
## A picture's own size, in pixels.
const PICTURE_SIZE: Vector2 = Vector2(16, 16)
## The frame's width round the picture, large and small: an edge and a bevel, or the edge alone.
const LARGE_FRAME: float = 2.0
const SMALL_FRAME: float = 1.0
## Pixels cut from each corner of a [constant Shape.CUT] frame, large and small.
const LARGE_CUT: float = 4.0
const SMALL_CUT: float = 2.0
## Seconds of one pulse of a ready slot, its bright half then its dim half.
const PULSE_SECONDS: float = 1.2
## How much of the picture's colour shows when locked, and when closed.
const LOCKED_TINT: Color = Color(0.5, 0.5, 0.5)
const CLOSED_TINT: Color = Color(0.16, 0.16, 0.18)
## The picture's colour under the mouse, owned or ready: a little brighter than its own.
const LIT_TINT: Color = Color(1.3, 1.3, 1.3)
## The padlock, in 5x6 cells of one pixel (large: two), drawn at the bottom right of a closed slot:
## [code]#[/code] the steel body and shackle, [code]k[/code] its keyhole.
const LOCK: Array[String] = [".###.", "#...#", "#####", "##k##", "##k##", "#####"]

static var _pictures: Dictionary[StringName, Texture2D] = {}
static var _loaded: bool = false

## The picture, inside the frame.
var picture_rect: TextureRect
## The count at the bottom right ("3", "12/20"), hidden when there is none.
var count_label: Label

var _id: StringName
var _large: bool = true
var _shape: Shape = Shape.SQUARE
var _state: State = State.OWNED
var _time: float = 0.0
var _lit: bool = false
var _over: Control


## A slot for [param picture_id]'s picture: [param large] at twice its size in a bevelled frame,
## or at its own size in a small one, with a square or cut-cornered frame ([param shape]).
func _init(picture_id: StringName, large: bool = true, shape: Shape = Shape.SQUARE) -> void:
	_id = picture_id
	_large = large
	_shape = shape
	name = "Icon_%s" % picture_id
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var border: float = _border()
	var shown: Vector2 = PICTURE_SIZE * (2.0 if large else 1.0)
	size = shown + Vector2.ONE * border * 2.0
	custom_minimum_size = size
	pivot_offset = size / 2.0
	picture_rect = TextureRect.new()
	picture_rect.name = "Picture"
	picture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	picture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture_rect.position = Vector2.ONE * border
	picture_rect.size = shown
	picture_rect.texture = UiIcon.picture(picture_id)
	add_child(picture_rect)
	_over = Control.new()  # the padlock, drawn over the picture
	_over.name = "Over"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.size = size
	_over.draw.connect(_draw_over)
	add_child(_over)
	count_label = UiText.label("", &"white", true)
	count_label.name = "Count"
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_color_override(&"font_shadow_color", Palette.color(&"ink"))
	count_label.add_theme_constant_override(&"shadow_offset_x", 1)
	count_label.add_theme_constant_override(&"shadow_offset_y", 1)
	count_label.visible = false
	add_child(count_label)
	mouse_entered.connect(_set_lit.bind(true))
	mouse_exited.connect(_set_lit.bind(false))
	_apply()


## The picture of the thing with id [param picture_id], or null when there is none.
static func picture(picture_id: StringName) -> Texture2D:
	_load()
	return _pictures.get(picture_id, null)


## True when the thing with id [param picture_id] has a picture.
static func has_picture(picture_id: StringName) -> bool:
	_load()
	return _pictures.has(picture_id)


## Shows the slot in [param shown] state.
func show_state(shown: State) -> void:
	if shown == _state:
		return
	_state = shown
	_time = 0.0
	_apply()


## The state the slot shows.
func state() -> State:
	return _state


## The frame's shape: square for an action, cut for a passive.
func frame_shape() -> Shape:
	return _shape


## Shows [param text] ("3", "12/20") at the bottom right; "" for none.
func set_count(text: String) -> void:
	count_label.visible = not text.is_empty()
	WindowText.set_text(count_label, text)
	count_label.position = (size - count_label.size - Vector2(1, 0)).floor()


## Runs a ready slot's pulse on by [param delta] seconds.
func advance(delta: float) -> void:
	if _state != State.READY:
		return
	var was: StringName = frame_colour()
	_time = fmod(_time + delta, PULSE_SECONDS)
	if was != frame_colour():
		queue_redraw()


## The points of the frame's outer edge, clockwise from the top left: four for a square frame,
## eight for one with cut corners.
func outline() -> PackedVector2Array:
	var w: float = size.x
	var h: float = size.y
	if _shape == Shape.SQUARE:
		return PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
	var c: float = LARGE_CUT if _large else SMALL_CUT
	return PackedVector2Array(
		[
			Vector2(c, 0),
			Vector2(w - c, 0),
			Vector2(w, c),
			Vector2(w, h - c),
			Vector2(w - c, h),
			Vector2(c, h),
			Vector2(0, h - c),
			Vector2(0, c),
		]
	)


## The palette colour of the frame's edge now: amber when owned (under the mouse too: its picture
## and bevel brighten instead), yellow (white on the pulse's second half, and under the mouse) when
## ready, slate when locked, dusk when closed, these two a step brighter under the mouse.
func frame_colour() -> StringName:
	match _state:
		State.OWNED:
			return &"amber"
		State.READY:
			if _lit:
				return &"white"
			return &"yellow" if _time < PULSE_SECONDS / 2.0 else &"white"
		State.LOCKED:
			return &"silver" if _lit else &"slate"
	return &"slate" if _lit else &"dusk"


## True when the padlock shows (the slot is closed).
func has_lock() -> bool:
	return _state == State.CLOSED


## True while the mouse is on the slot.
func is_lit() -> bool:
	return _lit


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


func _draw() -> void:
	var border: float = _border()
	var edge: Color = Palette.color(frame_colour())
	var light: StringName = &"dusk"
	var dark: StringName = &"night"
	match _state:
		State.OWNED:
			light = &"white" if _lit else &"yellow"
			dark = &"copper"
		State.READY:
			light = &"white" if frame_colour() == &"yellow" else &"yellow"
			dark = &"orange"
		State.LOCKED:
			light = &"steel"
			dark = &"dusk"
	_fill(outline(), edge)
	if _large:  # the bevel: light on the top and left, dark on the bottom and right
		_fill(_inset(1.0), Palette.color(dark))
		_fill(_inset(1.0, true), Palette.color(light))
	var fill: StringName = &"ink" if _state == State.CLOSED else &"night"
	_fill(_inset(border), Palette.color(fill))


## Draws the padlock over a closed slot's picture.
func _draw_over() -> void:
	if _state != State.CLOSED:
		return
	var cell: float = 2.0 if _large else 1.0
	var at: Vector2 = size - Vector2(5, 6) * cell - Vector2.ONE * (cell + 1.0)
	_over.draw_rect(
		Rect2(at - Vector2.ONE, Vector2(5, 6) * cell + Vector2(2, 2)), Palette.color(&"ink")
	)
	for y: int in LOCK.size():
		for x: int in LOCK[y].length():
			var symbol: String = LOCK[y][x]
			if symbol == ".":
				continue
			var colour: StringName = &"ink" if symbol == "k" else (&"silver" if y < 2 else &"steel")
			_over.draw_rect(
				Rect2(at + Vector2(x, y) * cell, Vector2.ONE * cell), Palette.color(colour)
			)


## The frame's outline moved [param by] pixels in. With [param light_half], only the top-left half
## of that ring's area: the outline cut along the diagonal, for the bevel's light.
func _inset(by: float, light_half: bool = false) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var cut: float = (LARGE_CUT if _large else SMALL_CUT) if _shape == Shape.CUT else 0.0
	var c: float = maxf(cut - by * 0.4, 0.0) if cut > 0.0 else 0.0
	var lo: float = by
	var hi_x: float = size.x - by
	var hi_y: float = size.y - by
	if light_half:
		# The top-left of the ring: along the top and down the left, one pixel thick.
		if c > 0.0:
			(
				points
				. append_array(
					[
						Vector2(lo, lo + c),
						Vector2(lo + c, lo),
						Vector2(hi_x - c, lo),
						Vector2(hi_x - c, lo + 1.0),
						Vector2(lo + c, lo + 1.0),
						Vector2(lo + 1.0, lo + c),
						Vector2(lo + 1.0, hi_y - c),
						Vector2(lo, hi_y - c),
					]
				)
			)
		else:
			(
				points
				. append_array(
					[
						Vector2(lo, lo),
						Vector2(hi_x, lo),
						Vector2(hi_x, lo + 1.0),
						Vector2(lo + 1.0, lo + 1.0),
						Vector2(lo + 1.0, hi_y),
						Vector2(lo, hi_y),
					]
				)
			)
		return points
	if c <= 0.0:
		return PackedVector2Array(
			[Vector2(lo, lo), Vector2(hi_x, lo), Vector2(hi_x, hi_y), Vector2(lo, hi_y)]
		)
	return PackedVector2Array(
		[
			Vector2(lo + c, lo),
			Vector2(hi_x - c, lo),
			Vector2(hi_x, lo + c),
			Vector2(hi_x, hi_y - c),
			Vector2(hi_x - c, hi_y),
			Vector2(lo + c, hi_y),
			Vector2(lo, hi_y - c),
			Vector2(lo, lo + c),
		]
	)


func _fill(points: PackedVector2Array, colour: Color) -> void:
	draw_colored_polygon(points, colour)


## The frame's width round the picture.
func _border() -> float:
	return LARGE_FRAME if _large else SMALL_FRAME


func _set_lit(lit: bool) -> void:
	if lit == _lit:
		return
	_lit = lit
	_apply()


## Shows the state: the picture's colour, the padlock and the frame.
func _apply() -> void:
	match _state:
		State.LOCKED:
			picture_rect.modulate = LOCKED_TINT
		State.CLOSED:
			picture_rect.modulate = CLOSED_TINT
		_:
			picture_rect.modulate = LIT_TINT if _lit else Color.WHITE
	queue_redraw()
	_over.queue_redraw()


## Reads every sheet once: each part is the picture of the thing it is named for.
static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for path: String in SHEETS:
		var sheet: PixelSheet = PixelSheet.load_sheet(path)
		if sheet == null:
			push_error("UiIcon: no sheet at %s" % path)
			continue
		for part: String in sheet.part_names:
			_pictures[StringName(part)] = sheet.part(StringName(part))
