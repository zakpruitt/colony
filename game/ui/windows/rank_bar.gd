class_name RankBar
extends UiBar
## The bar under a path's banner: how far the hero's XP in the path has come from its rank's
## threshold toward the next, filled in the path's colour ([PathColours]). [method show_share] sets
## where it stands; [method sweep] plays a rank passed, the bar filling to the end and starting
## again from empty up to where it stands, only ever started for what just happened
## ([HeroWindows] asks). Its owner runs the sweep in [method advance].

## Seconds the sweep takes to fill to the end, and then to fill again from empty.
const FILL_SECONDS: float = 0.3
const REFILL_SECONDS: float = 0.3
## The bar's height, in UI pixels: inside its 1-pixel edge, four of fill and its shade under.
const HEIGHT: int = 7

## Where the bar stands when no sweep plays.
var _target: float = 0.0
## Seconds into the sweep, or below 0 for none; and the share it started from.
var _sweep_time: float = -1.0
var _sweep_from: float = 0.0


func _init(fill_colour: StringName = PathColours.PLAIN) -> void:
	super(fill_colour, PathColours.shade(fill_colour), HEIGHT)
	name = "RankBar"
	mouse_filter = Control.MOUSE_FILTER_PASS  # for its tooltip; the wheel goes on to the scroll


## How much of the bar is filled now, from 0 to 1.
func share() -> float:
	return fraction


## Sets where the bar stands, [param target] from 0 to 1; a sweep under way goes on to it.
func show_share(target: float) -> void:
	_target = clampf(target, 0.0, 1.0)
	if not is_sweeping():
		fraction = _target


## Plays a rank passed: from where the bar is, it fills to the end, then from empty to where it
## stands. One under way goes on as it is.
func sweep() -> void:
	if is_sweeping():
		return
	_sweep_from = fraction
	_sweep_time = 0.0


## True while a sweep plays.
func is_sweeping() -> bool:
	return _sweep_time >= 0.0


## Runs the sweep on by [param delta] seconds.
func advance(delta: float) -> void:
	if not is_sweeping():
		return
	_sweep_time += delta
	if _sweep_time < FILL_SECONDS:
		fraction = lerpf(_sweep_from, 1.0, _sweep_time / FILL_SECONDS)
	elif _sweep_time < FILL_SECONDS + REFILL_SECONDS:
		var refill: float = (_sweep_time - FILL_SECONDS) / REFILL_SECONDS
		fraction = 1.0 if is_equal_approx(refill, 0.0) else lerpf(0.0, _target, refill)
	else:
		stop()


## Ends a sweep at once: the bar stands where it should.
func stop() -> void:
	_sweep_time = -1.0
	fraction = _target
