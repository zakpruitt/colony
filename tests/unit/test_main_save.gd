extends ColonyTest
## The main scene loads and saves progress through its SaveStore.

var _path: String = save_path()


func _main_with_store() -> Main:
	var main: Main = make_main()
	main.save_store = SaveStore.new(_path)
	add_child_autofree(main)
	return main


func test_progress_survives_closing_the_scene() -> void:
	var first: Main = _main_with_store()
	first.simulation.party.gold = 77
	first.simulation.party.heroes[0].level = 4
	first.save_now()
	first.free()
	var second: Main = _main_with_store()
	assert_eq(second.simulation.party.gold, 77, "gold came back")
	assert_eq(second.simulation.party.heroes[0].level, 4, "levels came back")


func test_saves_on_its_own_after_the_interval() -> void:
	var main: Main = _main_with_store()
	main.simulation.party.gold = 5
	main._process(Main.SAVE_SECONDS + 0.1)
	var saved: Dictionary = SaveStore.new(_path).read()
	var gold: float = saved.get("gold", -1.0)
	assert_eq(gold, 5.0, "saved without being asked")


func test_a_damaged_save_starts_a_new_game() -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string('{"version": 1, "gold": "lots"}')
	file.close()
	var main: Main = _main_with_store()
	assert_eq(main.simulation.party.gold, 0, "bad data is refused, a new game starts")
	assert_eq(main.simulation.tick, 0)
