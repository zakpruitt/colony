class_name LabyrinthDemo
extends Node2D
## Shows the labyrinth view on its own: a focus point walks the floor of depth 1 to the shaft,
## climbs down it, and goes on through depths 2 and 3 to the shaft at the end, then starts again.
## The camera follows it. Run: python tools/dev.py shot --scene=res://game/world/labyrinth_demo.tscn

## The labyrinth this demo shows.
const SEED: int = 6
## Walking and climbing speeds, in tiles per second.
const WALK_SPEED: float = 10.0
const CLIMB_SPEED: float = 6.0
## How far above the focus the camera looks, in tiles, so more of the chamber shows than the
## earth under it.
const LOOK_ABOVE: float = 2.0
## Depths the route walks through.
const DEPTHS: int = 3

## Where the walk is now, in world tiles: standing on the floor or on the ladder.
var focus: Vector2
## The view this demo drives.
var view: LabyrinthView

var _camera: WorldCamera
var _route: PackedVector2Array = []
var _next: int = 1


func _ready() -> void:
	var labyrinth := Labyrinth.new(SEED)
	view = LabyrinthView.new()
	view.name = "LabyrinthView"
	view.labyrinth = labyrinth
	add_child(view)
	_camera = WorldCamera.new()
	_camera.name = "WorldCamera"
	add_child(_camera)
	_route = _plan(labyrinth)
	_restart()


func _process(delta: float) -> void:
	var goal: Vector2 = _route[_next]
	var speed: float = CLIMB_SPEED if is_equal_approx(goal.x, focus.x) else WALK_SPEED
	focus = focus.move_toward(goal, speed * delta)
	if focus.is_equal_approx(goal):
		_next += 1
		if _next >= _route.size():
			_restart()
			return
	view.set_focus(focus)
	_camera.target = _camera_point()


func _restart() -> void:
	focus = _route[0]
	_next = 1
	view.set_focus(focus)
	_camera.snap_to(_camera_point())


func _camera_point() -> Vector2:
	return LabyrinthView.to_pixels(focus - Vector2(0, LOOK_ABOVE))


## The walk: from the left of the first chamber of depth 1, along each floor to the shaft, down
## it, and on. Points are feet positions: the top edge of the floor's earth.
func _plan(labyrinth: Labyrinth) -> PackedVector2Array:
	var first: LabyrinthLevel = labyrinth.level(1)
	var route: PackedVector2Array = [
		Vector2(first.chambers[0].rect.position.x + 1.5, first.floor_y + 1)
	]
	for depth: int in range(1, DEPTHS + 1):
		var level: LabyrinthLevel = labyrinth.level(depth)
		var shaft_x: float = level.shaft_down.position.x + level.shaft_down.size.x * 0.5
		route.append(Vector2(shaft_x, level.floor_y + 1))
		if depth < DEPTHS:
			route.append(Vector2(shaft_x, labyrinth.level(depth + 1).floor_y + 1))
	return route
