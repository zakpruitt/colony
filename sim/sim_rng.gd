class_name SimRng
extends RefCounted
## A seeded random stream owned by the simulation.
##
## The sim never uses the global random functions: every roll comes from a
## SimRng, so a seed reproduces a run and the stream's position can be saved.

var _seed: int
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value


## A whole number from [param from] to [param to], both included.
func next_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## A number from 0.0 to 1.0, both included.
func next_float() -> float:
	return _rng.randf()


## True with the given probability (0.0 never, 1.0 always).
func chance(probability: float) -> bool:
	return _rng.randf() < probability


## An independent stream derived from this stream's seed and [param label].
## The result depends only on the seed and the label, never on how many
## numbers have been drawn, so systems cannot disturb each other's rolls.
func fork(label: String) -> SimRng:
	var derived: int = ("%d/%s" % [_seed, label]).sha256_buffer().decode_s64(0)
	return SimRng.new(derived)


## The stream's seed and position, for the save file.
func save_state() -> Dictionary[String, int]:
	return {"seed": _seed, "state": _rng.state}


## Puts the stream back where [method save_state] found it.
func load_state(saved: Dictionary[String, int]) -> void:
	_seed = saved["seed"]
	_rng.seed = _seed
	_rng.state = saved["state"]
