extends GutTest
## SoundSettings keeps the mute choice in its own file, and reads a missing or damaged file as
## "not muted" without an error. Every test uses a per-process file under user://.

var _path: String = "user://test_sound_settings_%d.settings" % OS.get_process_id()


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


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
