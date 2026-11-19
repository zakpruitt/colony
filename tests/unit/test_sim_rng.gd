extends ColonyTest

const DRAWS: int = 64


func _draw(rng: SimRng, count: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in count:
		out.append(rng.next_int(0, 1_000_000))
	return out


func test_same_seed_gives_same_sequence() -> void:
	assert_eq(_draw(SimRng.new(42), DRAWS), _draw(SimRng.new(42), DRAWS))


func test_different_seeds_give_different_sequences() -> void:
	assert_ne(_draw(SimRng.new(42), DRAWS), _draw(SimRng.new(43), DRAWS))


func test_next_int_stays_in_range() -> void:
	var rng := SimRng.new(7)
	for i: int in 1000:
		var roll: int = rng.next_int(3, 5)
		assert_between(roll, 3, 5)


func test_chance_extremes() -> void:
	var rng := SimRng.new(7)
	for i: int in 200:
		assert_false(rng.chance(0.0))
		assert_true(rng.chance(1.0))


func test_fork_ignores_how_many_numbers_were_drawn() -> void:
	var fresh := SimRng.new(42)
	var used := SimRng.new(42)
	_draw(used, DRAWS)
	assert_eq(_draw(fresh.fork("loot"), DRAWS), _draw(used.fork("loot"), DRAWS))


func test_fork_labels_give_different_streams() -> void:
	var rng := SimRng.new(42)
	assert_ne(_draw(rng.fork("loot"), DRAWS), _draw(rng.fork("combat"), DRAWS))


func test_saved_state_resumes_the_sequence() -> void:
	var original := SimRng.new(42)
	_draw(original, DRAWS)
	var saved: Dictionary[String, int] = original.save_state()
	var expected: Array[int] = _draw(original, DRAWS)

	var restored := SimRng.new(0)
	restored.load_state(saved)
	assert_eq(_draw(restored, DRAWS), expected)
