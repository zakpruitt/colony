extends ColonyTest
## SoundSettings keeps the mute choice in its own file, and reads a missing or damaged file as
## "not muted" without an error. Every test uses a per-process file under user://.

var _path: String = save_path("", "settings")


func test_a_missing_file_is_not_muted() -> void:
	assert_false(SoundSettings.new(_path).muted())


func test_the_choice_round_trips() -> void:
	assert_true(SoundSettings.new(_path).set_muted(true), "written")
	assert_true(SoundSettings.new(_path).muted(), "read back muted")
	SoundSettings.new(_path).set_muted(false)
	assert_false(SoundSettings.new(_path).muted(), "read back unmuted")


func test_a_damaged_file_is_not_muted() -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	assert_false(SoundSettings.new(_path).muted(), "garbage is ignored")
	file = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string('{"sfx_muted": "yes"}')
	file.close()
	assert_false(SoundSettings.new(_path).muted(), "a wrong type is ignored")


func test_the_real_file_is_the_default_and_separate_from_the_save() -> void:
	assert_eq(SoundSettings.new().file_path(), SoundSettings.DEFAULT_PATH)
	assert_ne(SoundSettings.DEFAULT_PATH, SaveStore.DEFAULT_PATH)


func test_help_seen_round_trips_beside_the_mute_choice() -> void:
	var settings := SoundSettings.new(_path)
	assert_false(settings.help_seen(), "a missing file: help not seen")
	assert_true(settings.set_help_seen(true), "written")
	assert_true(SoundSettings.new(_path).help_seen(), "read back seen")
	assert_false(SoundSettings.new(_path).muted(), "the mute choice is untouched")
	settings.set_muted(true)
	assert_true(SoundSettings.new(_path).help_seen(), "muting keeps it")
	assert_true(SoundSettings.new(_path).muted())
	settings.set_help_seen(false)
	assert_false(SoundSettings.new(_path).help_seen(), "and it can be cleared")
	assert_true(SoundSettings.new(_path).muted(), "leaving the mute choice")


func test_a_damaged_help_flag_is_not_seen() -> void:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string('{"help_seen": 1}')
	file.close()
	assert_false(SoundSettings.new(_path).help_seen(), "a wrong type is ignored")
