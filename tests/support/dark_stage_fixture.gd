class_name DarkStageFixture
extends "res://tests/support/side_path_fixture.gd"
## A test of a winding stage's rooms as the party finds them: a party arrived on a stage, the
## world shown over it with its ambience moved on each frame, and walks hurried from room to
## room.

## The seed most tests play, and the stage (past the first, whose first room holds the campfire).
const SEED: int = 1
const STAGE: int = 2

var _ambience: Ambience


## A winding simulation of [param seed_value] whose party has arrived on [param stage] and is
## heading for [param target], its heroes never learning a microskill (so they pass every gate).
func _arrived(seed_value: int, stage: int, target: int) -> Simulation:
	var sim: Simulation = winding_simulation(seed_value)
	sim.set_auto_push(false)
	_keep_unskilled(sim)
	Arrival.from_save(sim.expedition, sim.tick, stage, stage, target, false)
	return sim


## The world over [param sim] at [param speed], its ambience moved on with each frame played.
func _watch_rooms(sim: Simulation, speed: int = 1) -> void:
	_show(sim, speed)
	_ambience = _world.ambience
	_ambience.set_process(false)
	_frame_parts.append(_ambience.advance)
	_ambience.advance(0.0)


func _shown_level() -> LabyrinthLevel:
	return _sim.labyrinth.level(_world.shown_stage())


## The room of the stage's route the party's anchor is in, or -1.
func _party_room() -> int:
	return _shown_level().course.chamber_at(_sim.expedition.x)


## The lights the darkness was handed last.
func _handed() -> Array[AmbienceLight]:
	return _ambience._darkness.handed


## Ends the fight the party is in and keeps the living whole, so a walk is not held up.
func _hurry() -> void:
	var e: Expedition = _sim.expedition
	if e.state == Expedition.State.FIGHTING and e.battle != null:
		for monster: Combatant in e.battle.monsters:
			if monster.is_alive():
				monster.health = 1
	for hero: Hero in _sim.party.heroes:
		if hero.is_alive():
			hero.health = hero.max_health()


## Plays frames, hurried, until [param done]; fails the test after [param seconds] of them.
func _walk_until(done: Callable, what: String, seconds: float = 240.0) -> void:
	for i: int in roundi(seconds / STEP):
		if done.call():
			return
		_hurry()
		_play_frame()
	fail_test("%s: not within %d s of frames" % [what, roundi(seconds)])


## True once the party's anchor is in route room [param room] and nothing is catching.
func _settled_in(room: int) -> bool:
	return _party_room() == room and _ambience.rooms.flares() == 0


## The sparkle parts [param glinting] shows over a glint's pulse and a half of idle frames.
func _glints_seen(glinting: Callable) -> Dictionary[StringName, bool]:
	var seen: Dictionary[StringName, bool] = {}
	for i: int in ceili(QuestProps.GLINT_PERIOD * 1.5 / STEP):
		_play_frame(false)
		var part: StringName = glinting.call()
		seen[part] = true
	return seen


## The route room with the most torches over [param seeds] seeds' [constant STAGE], neither its
## first nor its last, as Vector3i(seed, room, torches).
func _widest_room(seeds: int) -> Vector3i:
	var best := Vector3i(SEED, 1, 0)
	for seed_value: int in range(1, seeds + 1):
		var level: LabyrinthLevel = winding_labyrinth(seed_value).level(STAGE)
		for room: int in range(1, level.chambers.size() - 1):
			var width: int = level.chambers[room].rect.size.x
			var count: int = maxi(1, roundi(width / AmbienceLevel.TORCH_SPACING))
			if count > best.z:
				best = Vector3i(seed_value, room, count)
	return best


func _shapes(lights: Array[AmbienceLight]) -> Array[Vector4]:
	var shapes: Array[Vector4] = []
	for light: AmbienceLight in lights:
		shapes.append(Vector4(light.position.x, light.position.y, light.radius, light.core))
	return shapes


## True if [param light] is inside route room [param room] of the stage shown.
func _in_room(light: AmbienceLight, room: int) -> bool:
	var rect: Rect2i = _shown_level().chambers[room].rect
	return Rect2(rect.position * int(TILE), rect.size * int(TILE)).has_point(light.position)
