class_name WorldCamera
extends Camera2D
## The camera over the labyrinth. It eases toward [member target], keeps the view inside the
## band's columns, sits on whole pixels, and can be shaken.
##
## [member position] is the followed point (clamped and rounded); a shake only moves
## [member offset], so it never disturbs where the camera is going. A [method travel]
## carries the view to a far place at a pace of its own, eased in and out.

## How fast the camera closes on its target: each second it covers all but e^-rate of the
## remaining distance. 6 settles in about half a second.
const FOLLOW_RATE: float = 6.0
## How fast a shake dies away, per second, the same way.
const SHAKE_DECAY: float = 8.0
## A shake weaker than this many pixels stops.
const SHAKE_STOP: float = 0.5
## Closer than this many pixels to the target, the camera settles on it.
const SETTLE: float = 0.5
## Width of the labyrinth in pixels; the view never shows past either side.
const BAND_WIDTH: float = Labyrinth.LEVEL_WIDTH * LabyrinthView.TILE
## The view size assumed outside the tree (the game's 640x360 viewport).
const FALLBACK_VIEW: Vector2 = Vector2(640, 360)
## Seconds a change of zoom level takes to ease from one level to the other.
const ZOOM_TIME: float = 0.25

## World pixel position to follow.
var target: Vector2

var _followed: Vector2
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()
## The whole zoom level asked for (1 or 2), the zoom it eases from, and seconds into the change.
var _zoom_level: int = 1
var _zoom_from: float = 1.0
var _zoom_age: float = ZOOM_TIME
## A travel in progress: where it started and ends, its length and seconds into it (-1 for none).
var _travel_from: Vector2
var _travel_to: Vector2
var _travel_time: float = 0.0
var _travel_age: float = -1.0


func _process(delta: float) -> void:
	_ease_zoom(delta)
	if _travel_age >= 0.0:
		_travel_age = minf(_travel_age + delta, _travel_time)
		var share: float = smoothstep(0.0, 1.0, _travel_age / _travel_time)
		_followed = _travel_from.lerp(_travel_to, share)
		if _travel_age >= _travel_time:
			_travel_age = -1.0
			_followed = _travel_to
	else:
		_followed = _followed.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
		if _followed.distance_to(target) < SETTLE:
			_followed = target
	_shake *= exp(-SHAKE_DECAY * delta)
	if _shake < SHAKE_STOP:
		_shake = 0.0
	_apply()


## Jumps to a world pixel position and follows it from there, with no easing.
func snap_to(world_pixels: Vector2) -> void:
	_travel_age = -1.0
	target = world_pixels
	_followed = world_pixels
	_apply()


## Carries the view from where it is (or from [param from]) to [param world_pixels] over
## [param seconds], eased in and out, whatever [member target] says meanwhile; then it follows
## [member target] again. [param into] seconds of the travel are already over, so the next
## [method _process] goes on from there: a travel can be taken up part way. The end is kept inside
## the band, so the travel ends where the view will rest.
func travel(
	world_pixels: Vector2, seconds: float, into: float = 0.0, from: Vector2 = Vector2.INF
) -> void:
	if seconds <= 0.0:
		snap_to(world_pixels)
		return
	var half: float = _view_size().x * 0.5 / zoom.x
	_travel_from = _followed if from == Vector2.INF else from
	_travel_to = Vector2(_clamp_to_band(world_pixels.x, half), world_pixels.y)
	_travel_time = seconds
	_travel_age = clampf(into, 0.0, seconds)
	target = world_pixels


## True while a [method travel] is under way.
func is_travelling() -> bool:
	return _travel_age >= 0.0


## Asks for zoom [param level] (1 the normal view, 2 the close one); the view eases to it over
## [constant ZOOM_TIME] seconds and ends exactly on it.
func set_zoom_level(level: int) -> void:
	level = clampi(level, 1, 2)
	if level == _zoom_level:
		return
	_zoom_level = level
	_zoom_from = zoom.x
	_zoom_age = 0.0


## The zoom level asked for last: 1 or 2.
func zoom_level() -> int:
	return _zoom_level


## Shakes the view by up to [param strength] pixels, dying away over a fraction of a second.
## A stronger shake replaces a weaker one; a weaker one does not cut a stronger one short.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## Moves the zoom on by [param delta] seconds toward the level asked for, eased in and out.
func _ease_zoom(delta: float) -> void:
	if _zoom_age >= ZOOM_TIME:
		zoom = Vector2.ONE * _zoom_level
		return
	_zoom_age = minf(_zoom_age + delta, ZOOM_TIME)
	var share: float = smoothstep(0.0, 1.0, _zoom_age / ZOOM_TIME)
	var now: float = lerpf(_zoom_from, float(_zoom_level), share)
	if _zoom_age >= ZOOM_TIME:
		now = float(_zoom_level)
	zoom = Vector2(now, now)


func _apply() -> void:
	var half: float = _view_size().x * 0.5 / zoom.x
	_followed.x = _clamp_to_band(_followed.x, half)
	position = _followed.round()
	if _shake <= 0.0:
		offset = Vector2.ZERO
		return
	var jolt := Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake))
	jolt.x = _clamp_to_band(position.x + jolt.x, half) - position.x
	offset = jolt.round()


## [param x] moved so a view [param half] wide either side of it stays inside the band.
func _clamp_to_band(x: float, half: float) -> float:
	var low: float = ceilf(half)
	var high: float = floorf(BAND_WIDTH - half)
	if low > high:
		return BAND_WIDTH * 0.5
	return clampf(x, low, high)


func _view_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else FALLBACK_VIEW
