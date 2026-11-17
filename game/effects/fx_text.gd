class_name FxText
extends Node2D
## A word or number of an effect (spec 010) in the pixel font, at a whole multiple of its size,
## with a 1-pixel-per-multiple ink shadow. It pops one size larger as it appears, moves in an arc
## (or drifts), and blinks out at the end of its life: it never fades. Its position is the centre
## of its baseline. [CombatEffects] creates and advances it.

## Seconds a new text shows one size larger.
const POP_TIME: float = 0.07
## The last seconds of its life it blinks, and how long each blink is.
const BLINK_TIME: float = 0.2
const BLINK_STEP: float = 0.05

## What it is: &"damage" and &"heal" are numbers (spec 010 R1, R2); &"banner" and &"z" are words.
var kind: StringName = &""
var text: String = ""
var color: Color = Color.WHITE
## The font's size as a multiple of its native size (1, 2, 3).
var scale_factor: int = 1
## Pops one size larger when it appears.
var pops: bool = true
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 0.0
## Pixels a drifting text sways side to side, and seconds per sway.
var sway: float = 0.0
var sway_period: float = 1.0
var life: float = 0.7
var age: float = 0.0
## A hero or monster it stays over, or -1. The world position is then relative to its feet.
var follow_id: int = -1
## Kept in the middle of the screen, offset by [member screen_offset] (CombatEffects places it).
var on_screen: bool = false
var screen_offset: Vector2 = Vector2.ZERO
## Drawn with an ink outline all round as well as its shadow (spec 056's ability names), so it
## reads over any wall.
var outline: bool = false

var _exact: Vector2


## Places the text at [param at] before its first advance.
func start(at: Vector2) -> void:
	_exact = at
	_place()


## Where it would be with no motion of its own: the anchor it moves from.
func set_anchor(at: Vector2) -> void:
	_exact = at
	_place()


## Moves it on by [param delta] seconds. False once its life is over.
func advance(delta: float) -> bool:
	age += delta
	if age >= life:
		return false
	_place()
	var left: float = life - age
	visible = left > BLINK_TIME or int(left / BLINK_STEP) % 2 == 0
	return true


## The font size it is drawn at now.
func font_size() -> int:
	var factor: int = scale_factor
	if pops and age < POP_TIME:
		factor += 1
	return PixelText.SIZE * factor


## Where it is drawn at [param at_age] seconds old, if its anchor stays where it is. Its motion is
## worked out from its age (an arc from [member velocity] under [member gravity]), so where it will
## be is known when it appears: [CombatEffects] places numbers so their paths do not cross.
func position_at(at_age: float) -> Vector2:
	var moved: Vector2 = velocity * at_age + Vector2(0, 0.5 * gravity * at_age * at_age)
	var swayed := Vector2(sin(at_age / sway_period * TAU) * sway if sway > 0.0 else 0.0, 0.0)
	return (_exact + moved + swayed).round()


## The box it covers at [param at_age] seconds old, glyphs and shadow, in its parent's pixels.
func rect_at(at_age: float) -> Rect2:
	var shape: Rect2 = box(text, _size_at(at_age))
	return Rect2(shape.position + position_at(at_age), shape.size)


## The box it covers now, where it is drawn (its outline too).
func rect() -> Rect2:
	var shape: Rect2 = box(text, font_size())
	if outline:
		var factor: float = float(font_size()) / PixelText.SIZE
		shape = shape.grow(factor)
	return Rect2(shape.position + position, shape.size)


## The box [param words] cover at font size [param font_px], around the centre of its baseline.
static func box(words: String, font_px: int) -> Rect2:
	var font: Font = PixelText.font()
	var factor: int = font_px / PixelText.SIZE
	var width: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var top: float = font.get_ascent(font_px)
	var bottom: float = font.get_descent(font_px)
	return Rect2(-floori(width / 2.0), -top, width + factor, top + bottom + factor)


func _size_at(at_age: float) -> int:
	return PixelText.SIZE * (scale_factor + (1 if pops and at_age < POP_TIME else 0))


func _place() -> void:
	position = position_at(age)
	queue_redraw()


func _draw() -> void:
	var font: Font = PixelText.font()
	var font_px: int = font_size()
	var factor: int = font_px / PixelText.SIZE
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var left := Vector2(-floori(width / 2.0), 0)
	var shadow := Vector2(factor, factor)
	var ink: Color = Palette.color(&"ink")
	if outline:
		for x: int in [-1, 0, 1]:
			for y: int in [-1, 0, 1]:
				var at: Vector2 = left + Vector2(x, y) * factor
				draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, ink)
	draw_string(font, left + shadow, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, ink)
	draw_string(font, left, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, color)
