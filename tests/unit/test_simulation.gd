extends ColonyTest


func test_state_hash_depends_on_tick() -> void:
	var a := Simulation.new(7)
	var b := Simulation.new(7)
	assert_eq(a.state_hash(), b.state_hash())
	a.step()
	assert_ne(a.state_hash(), b.state_hash())
	b.step()
	assert_eq(a.state_hash(), b.state_hash())


func test_state_hash_depends_on_seed() -> void:
	assert_ne(Simulation.new(7).state_hash(), Simulation.new(8).state_hash())
