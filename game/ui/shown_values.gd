class_name ShownValues
extends RefCounted
## The values a view last showed, so it can tell whether new ones differ before it works out any
## text: a view calls [method begin], [method see] for each value its texts and colours are made
## from, in the same order every time, then asks [method changed]. Only on a change does it format
## and set anything. Keeping the values costs nothing once they are kept: no frame allocates.

var _values: Array = []
var _at: int = 0
var _changed: bool = false


## Starts a new look at the values.
func begin() -> void:
	_at = 0
	_changed = false


## Takes in the next value, noting whether it differs from the one in its place last time.
func see(value: Variant) -> void:
	if _at >= _values.size():
		_values.append(value)
		_changed = true
	elif typeof(_values[_at]) != typeof(value) or _values[_at] != value:
		_values[_at] = value
		_changed = true
	_at += 1


## True when any value seen since [method begin] differs from last time (and the first time).
func changed() -> bool:
	if _at != _values.size():
		_values.resize(_at)
		_changed = true
	return _changed
