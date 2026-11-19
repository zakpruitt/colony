class_name SoundSettings
extends RefCounted
## Keeps the player's choices that are not progress in a small JSON file under [code]user://[/code],
## separate from the save: whether sounds are muted, and whether the help panel has opened by
## itself once. Like [SaveStore] it takes its path when created, so tests
## can give it a file of their own and never touch the real one.

## Where the game's settings live unless told otherwise.
const DEFAULT_PATH: String = "user://colony.settings"
## The key of the muted choice in the file.
const MUTED_KEY: String = "sfx_muted"
## The key of "the help panel has welcomed the player" in the file.
const HELP_SEEN_KEY: String = "help_seen"

var _path: String


## Settings kept in the file at [param path].
func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


## Whether sounds were left muted: false if the file is missing, unreadable or says nothing.
func muted() -> bool:
	return _flag(MUTED_KEY)


## Records whether sounds are muted. Returns true if the file was written.
func set_muted(value: bool) -> bool:
	return _write(MUTED_KEY, value)


## Whether the help panel has already opened by itself: false if the file is missing, unreadable
## or says nothing.
func help_seen() -> bool:
	return _flag(HELP_SEEN_KEY)


## Records whether the help panel has opened by itself. Returns true if the file was written.
func set_help_seen(value: bool) -> bool:
	return _write(HELP_SEEN_KEY, value)


## The file this keeps.
func file_path() -> String:
	return _path


## The true-or-false choice under [param key]; false unless the file says true.
func _flag(key: String) -> bool:
	var value: Variant = _read().get(key, false)
	return value is bool and value


## Writes [param value] under [param key], keeping every other choice in the file.
func _write(key: String, value: bool) -> bool:
	var data: Dictionary = _read()
	data[key] = value
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_string(JSON.stringify(data))
	file.close()
	return stored


## The dictionary in the file, or an empty one. Raises no engine error.
func _read() -> Dictionary:
	if not FileAccess.file_exists(_path):
		return {}
	var file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return json.data
