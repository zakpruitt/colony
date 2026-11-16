class_name EasedValue
extends RefCounted
## A number shown on the HUD that eases to each new goal over [member seconds], fast at first and
## settling exactly on the goal, so a bar never jumps.

## How long an ease takes.
var seconds: float = 0.3
## The value to show now.
var value: float = 0.0

var _from: float = 0.0
var _goal: float = 0.0
var _time: float = 0.0


func _init(ease_seconds: float = 0.3) -> void:
	seconds = ease_seconds


## Jumps straight to [param to].
func snap(to: float) -> void:
	value = to
	_from = to
	_goal = to
	_time = seconds


## Heads for [param goal] (restarting the ease from the current value when the goal changes)
## and moves [param delta] seconds along.
func advance(goal: float, delta: float) -> void:
	if not is_equal_approx(goal, _goal):
		_from = value
		_goal = goal
		_time = 0.0
	_time = minf(_time + delta, seconds)
	var t: float = _time / seconds if seconds > 0.0 else 1.0
	value = lerpf(_from, _goal, 1.0 - (1.0 - t) * (1.0 - t))
