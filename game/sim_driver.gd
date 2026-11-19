class_name SimDriver
extends Node
## Turns real elapsed time into simulation ticks.
##
## Each frame it measures real time with the engine's monotonic clock (not the
## frame delta, which the engine may clamp) and steps the simulation once per
## whole tick of it. Because the tick count follows the clock, a throttled,
## hidden or minimised window loses no time. See docs/architecture.md, "Time".
##
## Above 1x each frame also steps [member speed] - 1 more ticks for every tick of real
## time, but only while the frame's [member step_budget_usec] lasts. Those extra ticks are best
## effort: what a frame cannot afford is let go, never kept, so the real-time ticks above (and
## everything that counts on them) behave exactly as at 1x and nothing bursts later.

## Emitted after a frame in which at least one tick was stepped.
signal ticked(count: int)
## Emitted when backlog beyond MAX_BACKLOG_USEC was discarded.
signal time_dropped(usec: int)

## The most ticks stepped in one frame, so a long stall cannot freeze the game.
const MAX_TICKS_PER_FRAME: int = 50
## The most real time kept waiting to be stepped (60 s). Time past this is left
## to offline catch-up.
const MAX_BACKLOG_USEC: int = 60_000_000
## The rendering frame limit while the window does not have focus.
const BACKGROUND_MAX_FPS: int = 10
## The real time a frame may spend stepping, in microseconds, before it stops taking the extra
## ticks a faster speed asks for (half a 60 fps frame).
const STEP_BUDGET_USEC: int = 8_000

## The simulation being driven. Set before the node enters the tree.
var simulation: Simulation
## How many times real time the simulation runs: 1, 2 or 4. Main sets it.
var speed: int = 1
## See [constant STEP_BUDGET_USEC]; tests change it.
var step_budget_usec: int = STEP_BUDGET_USEC

var _backlog_usec: int = 0
## Game time owed to the ticks a speed above 1x adds, less than a tick once a frame has run.
var _extra_usec: int = 0
## The monotonic clock reading at the last frame, or -1 before the first one.
var _last_clock_usec: int = -1
## The frame limit to restore on focus-in, or -1 while the window has focus.
var _focused_max_fps: int = -1


func _ready() -> void:
	_last_clock_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	advance(now - _last_clock_usec)
	_last_clock_usec = now


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _focused_max_fps < 0:
				_focused_max_fps = Engine.max_fps
				Engine.max_fps = BACKGROUND_MAX_FPS
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_EXIT_TREE:
			if _focused_max_fps >= 0:
				Engine.max_fps = _focused_max_fps
				_focused_max_fps = -1


## Adds elapsed real time and steps the simulation for it. Returns the ticks stepped.
## Called once per frame with the measured time; tests call it directly.
func advance(elapsed_usec: int) -> int:
	var started: int = Time.get_ticks_usec()
	_backlog_usec += maxi(elapsed_usec, 0)
	if _backlog_usec > MAX_BACKLOG_USEC:
		var dropped: int = _backlog_usec - MAX_BACKLOG_USEC
		_backlog_usec = MAX_BACKLOG_USEC
		time_dropped.emit(dropped)

	var count: int = mini(_backlog_usec / Simulation.TICK_USEC, MAX_TICKS_PER_FRAME)
	for i: int in count:
		simulation.step()
	_backlog_usec -= count * Simulation.TICK_USEC
	count += _step_extra(maxi(elapsed_usec, 0), started)
	if count > 0:
		ticked.emit(count)
	return count


## Steps the ticks a speed above 1x adds for [param elapsed_usec] of real time, while the frame
## that began at [param started] (a clock reading) is within its budget. Returns the ticks stepped.
func _step_extra(elapsed_usec: int, started: int) -> int:
	if speed <= 1:
		_extra_usec = 0
		return 0
	_extra_usec += elapsed_usec * (speed - 1)
	var wanted: int = mini(_extra_usec / Simulation.TICK_USEC, MAX_TICKS_PER_FRAME * (speed - 1))
	var stepped: int = 0
	while stepped < wanted and Time.get_ticks_usec() - started < step_budget_usec:
		simulation.step()
		stepped += 1
	_extra_usec -= stepped * Simulation.TICK_USEC
	# What did not fit is let go: only the part of a tick still to come is kept.
	_extra_usec %= Simulation.TICK_USEC
	return stepped


## Real time received but not yet stepped.
func backlog_usec() -> int:
	return _backlog_usec
