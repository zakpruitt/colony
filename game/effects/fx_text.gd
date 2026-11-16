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

var _exact: Vector2
var _drift: Vector2 = Vector2.ZERO


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
	velocity.y += gravity * delta
	_drift += velocity * delta
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


func _place() -> void:
	var swayed := Vector2(sin(age / sway_period * TAU) * sway if sway > 0.0 else 0.0, 0.0)
	position = (_exact + _drift + swayed).round()
	queue_redraw()


func _draw() -> void:
	var font: Font = PixelText.font()
	var font_px: int = font_size()
	var factor: int = font_px / PixelText.SIZE
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var left := Vector2(-floori(width / 2.0), 0)
	var shadow := Vector2(factor, factor)
	var ink: Color = Palette.color(&"ink")
	draw_string(font, left + shadow, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, ink)
	draw_string(font, left, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, color)
