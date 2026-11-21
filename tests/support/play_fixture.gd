class_name PlayFixture
extends "res://tests/support/hud_fixture.gd"
## A test that watches the world play over a simulation of its own at 60 frames a second, a tick
## every [constant FRAMES_PER_TICK] frames: [method _show] makes the world (and, when asked, the
## CombatEffects), [method _play_frame] plays a frame and returns the events told in it.

## A tile's size in world pixels.
const TILE: float = 16.0
## Frames a tick lasts at 60 frames a second and 10 ticks a second.
const FRAMES_PER_TICK: int = 6

## Frames [method _play_frame] has played since [method _show].
var _frames_played: int = 0


## A World over [param simulation] at [param speed], not processing by itself (and the
## CombatEffects on it, moved on with each frame, if [param with_effects]); every event it tells of
## goes into [member _events]. The count of frames played starts again.
func _show(simulation: Simulation, speed: int = 1, with_effects: bool = false) -> void:
	_sim = simulation
	_world = World.new()
	_world.simulation = simulation
	_world.speed = speed
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = null
	_hud = null
	_ui = null
	_frame_parts = []
	_frames_played = 0
	if with_effects:
		_fx = CombatEffects.new()
		add_child_autofree(_fx)
		_fx.set_process(false)
		_fx.setup(_world, simulation)
		_frame_parts = [_fx.advance]
	_hear_events()


## One frame of play: every [constant FRAMES_PER_TICK] frames the simulation steps (the world's
## speed times, unless not [param stepping]); then the world syncs and [member _frame_parts] move
## on by [member _frame_seconds]. Returns the events told in it.
func _play_frame(stepping: bool = true) -> Array[SimEvent]:
	var before: int = _events.size()
	if stepping and _frames_played % FRAMES_PER_TICK == 0:
		for i: int in maxi(_world.speed, 1):
			_sim.step()
	_frames_played += 1
	_world.sync(_frame_seconds)
	for part: Callable in _frame_parts:
		part.call(_frame_seconds)
	return _events.slice(before)


## Plays frames until an event of [param kind] is told: true, or false after [param ticks] ticks
## of them. [member _events] holds only what is told from here on.
func _play_until(kind: SimEvent.Kind, ticks: int = LIMIT_TICKS_5_MIN) -> bool:
	_events.clear()
	for i: int in ticks * FRAMES_PER_TICK:
		if _has(_play_frame(), kind):
			return true
	return false


## Whether [param events] hold one of [param kind].
static func _has(events: Array[SimEvent], kind: SimEvent.Kind) -> bool:
	for event: SimEvent in events:
		if event.kind == kind:
			return true
	return false


## Where hero [param hero_id]'s feet are in world pixels.
func _feet(hero_id: int) -> Vector2:
	var tiles: Vector2 = _sim.expedition.hero_position(hero_id)
	return Vector2(tiles.x * TILE, (tiles.y + 1.0) * TILE)


## Where the camera rests when it is sent to [param target]: kept inside the band.
func _rest(target: Vector2) -> Vector2:
	var half: float = _world.get_viewport_rect().size.x * 0.5 / _world.camera.zoom.x
	return Vector2(clampf(target.x, ceilf(half), floorf(WorldCamera.BAND_WIDTH - half)), target.y)
