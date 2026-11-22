class_name WindingPreview
extends Main
## A development scene: the game on winding stages (three floors, ladders, a route that doubles
## back), a new game every time, never loaded and never saved. No menu leads here:
## [code]godot --path . res://game/dev/winding.tscn[/code] plays it, and
## [code]python tools/dev.py shot --scene=res://game/dev/winding.tscn[/code] shows it.
##
## It changes nothing of the player's. It has no save store, and its settings are a copy of the
## player's in a file of this process's own, so the sound is as the player left it while the
## welcome, a mute and the windows' places are written to the copy, which goes when the scene
## does.

## Where the copy of the settings is kept, by process id.
const SETTINGS_COPY: String = "user://winding_preview_%d.settings"

## The copy's path, or "" when the preview has no settings.
var _settings_copy: String = ""


func _ready() -> void:
	_copy_settings()
	super()
	# A played Main makes itself a store on the player's file: this game is never written there.
	save_store = null


func _exit_tree() -> void:
	if _settings_copy != "" and FileAccess.file_exists(_settings_copy):
		DirAccess.remove_absolute(_settings_copy)


## A new winding game, whatever a save holds.
func _load_or_new() -> Simulation:
	return Simulation.new(SIMULATION_SEED, Labyrinth.Shape.WINDING)


## Points [member settings] at a copy of the settings file it would use: the one it was given, or
## the player's when a person is playing. With neither there are none, as in any [Main].
func _copy_settings() -> void:
	if settings == null and not _is_played():
		return
	var from: String = settings.file_path() if settings != null else SoundSettings.DEFAULT_PATH
	_settings_copy = SETTINGS_COPY % OS.get_process_id()
	if FileAccess.file_exists(from):
		var file: FileAccess = FileAccess.open(_settings_copy, FileAccess.WRITE)
		if file != null:
			file.store_buffer(FileAccess.get_file_as_bytes(from))
			file.close()
	elif FileAccess.file_exists(_settings_copy):
		DirAccess.remove_absolute(_settings_copy)
	settings = SoundSettings.new(_settings_copy)
