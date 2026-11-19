extends ColonyTest
## Acceptance tests for specs/021-sound-effects/spec.md, one per requirement (R1 is in Python:
## tools/tests/test_021_sound_effects.py).
##
## Each test builds a World on a seeded simulation, the CombatEffects that listens to it and a
## SoundPlayer set up on both, with the world's and effects' _process turned off, feeds events
## through World.sim_event and reads what started through drain_started. The player's own clock
## moves only in _process, so a test steps it exactly. Every player here is given a settings file
## on a per-process path under user://, deleted after each test: never the real one.

const SEED: int = 1
const KNIGHT: int = 1
const SOUNDS: Array[StringName] = [
	&"hit",
	&"crit",
	&"hero_hurt",
	&"heal",
	&"monster_die",
	&"hero_die",
	&"coin",
	&"level_up",
	&"bolt",
	&"wipe",
	&"revive",
	&"depth_stable",
	&"ui_click",
	&"ui_buy",
]

var _settings_path: String = save_path("", "settings")
var _save_path: String = save_path()
var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _sound: SoundPlayer


func before_each() -> void:
	_sim = Simulation.new(SEED)
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	_sound = _player()


func after_each() -> void:
	super()
	var bus: int = AudioServer.get_bus_index(SoundPlayer.BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, false)


# --- Helpers -------------------------------------------------------------------


## A player on the test's world and effects, keeping its settings in the test's own file.
func _player() -> SoundPlayer:
	var sound := SoundPlayer.new()
	sound.settings = SoundSettings.new(_settings_path)
	add_child_autofree(sound)
	sound.set_process(false)
	sound.setup(_world, _fx, _sim)
	return sound


## A fresh event of [param kind], as the simulation would report it now.
func _emit(
	kind: SimEvent.Kind, source: int = -1, target: int = -1, amount: int = 0, flag: bool = false
) -> void:
	_world.sim_event.emit(SimEvent.new(kind, _sim.tick, source, target, amount, flag))


## Emits the event a row of test_r3's table describes, at [param tick].
func _emit_case(case: Array, tick: int) -> void:
	var kind: SimEvent.Kind = case[0]
	var source: int = case[1]
	var target: int = case[2]
	var amount: int = case[3]
	var flag: bool = case[4]
	_world.sim_event.emit(SimEvent.new(kind, tick, source, target, amount, flag))


## Lets the player's clock run past the repeat limit, so the next sound may start.
func _later() -> void:
	_sound._process(0.2)


## The id of a monster: any id from the first monster id on.
func _monster() -> int:
	return Expedition.FIRST_MONSTER_ID


## The pitch of every voice the player has, that is playing a sound.
func _pitches() -> Array[float]:
	var found: Array[float] = []
	for child: Node in _sound.get_children():
		var voice: AudioStreamPlayer = child as AudioStreamPlayer
		if voice != null and voice.stream != null:
			found.append(voice.pitch_scale)
	return found


# --- R2 ------------------------------------------------------------------------


func test_r2_every_sound_loads() -> void:
	var seen: Dictionary = {}
	for sound: StringName in SOUNDS:
		var path: String = SoundPlayer.DIR + String(sound) + ".wav"
		var stream: AudioStreamWAV = load(path) as AudioStreamWAV
		assert_not_null(stream, "%s loads as an audio stream" % sound)
		if stream == null:
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		var data_bytes: int = file.get_length() - 44
		file.close()
		var expected: float = data_bytes / 2.0 / 22050.0
		assert_almost_eq(stream.get_length(), expected, 0.002, "%s has its baked length" % sound)
		assert_between(stream.get_length(), 0.02, 1.2, "%s is short" % sound)
		var key: String = Marshalls.raw_to_base64(stream.data)
		assert_false(seen.has(key), "%s is not the same as %s" % [sound, seen.get(key, "")])
		seen[key] = sound
	assert_eq(seen.size(), SOUNDS.size(), "fourteen different sounds")


# --- R3 ------------------------------------------------------------------------


func test_r3_sounds_follow_events() -> void:
	var monster: int = _monster()
	var cases: Array[Array] = [
		[SimEvent.Kind.HIT, KNIGHT, monster, 5, false, &"hit"],
		[SimEvent.Kind.HIT, KNIGHT, monster, 9, true, &"crit"],
		[SimEvent.Kind.HIT, monster, KNIGHT, 4, false, &"hero_hurt"],
		[SimEvent.Kind.HEALED, 4, KNIGHT, 3, false, &"heal"],
		[SimEvent.Kind.DIED, monster, -1, 0, false, &"monster_die"],
		[SimEvent.Kind.DIED, KNIGHT, -1, 0, false, &"hero_die"],
		[SimEvent.Kind.LEVEL_UP, -1, KNIGHT, 2, false, &"level_up"],
		[SimEvent.Kind.PROJECTILE_LAUNCHED, 3, monster, 10, false, &"bolt"],
		[SimEvent.Kind.PARTY_WIPED, -1, -1, 0, false, &"wipe"],
		[SimEvent.Kind.PARTY_REVIVED, -1, -1, 1, false, &"revive"],
		[SimEvent.Kind.STABLE_DEPTH_REACHED, -1, -1, 2, false, &"depth_stable"],
		[SimEvent.Kind.UPGRADE_BOUGHT, 0, -1, 1, false, &"ui_buy"],
	]
	for case: Array in cases:
		_later()
		_sound.drain_started()
		_emit_case(case, _sim.tick)
		var expected: StringName = case[5]
		assert_eq(_sound.drain_started(), [expected] as Array[StringName], "%s plays" % expected)

	_later()
	_emit(SimEvent.Kind.HEALED, 4, KNIGHT, 0, false)
	assert_eq(_sound.drain_started(), [] as Array[StringName], "a heal of 0 plays nothing")

	_later()
	_fx.coin_collected.emit(3)
	await wait_process_frames(2)
	assert_eq(_sound.drain_started(), [&"coin"] as Array[StringName], "a coin collected plays")

	# An old event (after a stall) plays nothing, for any kind.
	var old: int = _sim.tick - World.ANIMATE_TICKS - 1
	for case: Array in cases:
		_later()
		_emit_case(case, old)
	_later()
	# Gold that is old is counted at once, and its coin plays nothing either.
	_world.sim_event.emit(SimEvent.new(SimEvent.Kind.GOLD_GAINED, old, -1, -1, 7, false))
	await wait_process_frames(2)
	assert_eq(_sound.drain_started(), [] as Array[StringName], "old events play nothing")


# --- R4 ------------------------------------------------------------------------


func test_r4_never_noise() -> void:
	# The same sound does not start twice within 0.05 s; another sound may.
	assert_true(_sound.play(&"hit"), "the first hit starts")
	assert_false(_sound.play(&"hit"), "the same sound at once does not")
	_sound._process(0.03)
	assert_false(_sound.play(&"hit"), "nor 0.03 s later")
	assert_true(_sound.play(&"coin"), "a different sound does")
	_sound._process(0.03)
	assert_true(_sound.play(&"hit"), "0.06 s later it does")

	# At most 8 at once.
	_sound._process(2.0)
	assert_eq(_sound.playing_count(), 0, "everything has finished")
	var started: int = 0
	for sound: StringName in SOUNDS:
		if _sound.play(sound):
			started += 1
	assert_eq(started, SoundPlayer.MAX_VOICES, "only 8 of 14 start")
	assert_eq(_sound.playing_count(), 8, "8 play at once")
	_sound._process(2.0)
	assert_eq(_sound.playing_count(), 0, "and they end")

	# Pitch varies, within 6%.
	var pitches: Dictionary = {}
	for i: int in 30:
		_sound._process(0.1)
		assert_true(_sound.play(&"hit"))
		for pitch: float in _pitches():
			assert_between(pitch, 0.94, 1.06, "pitch within 6%")
			pitches[snappedf(pitch, 0.001)] = true
	assert_gt(pitches.size(), 5, "repeated sounds vary in pitch")

	# A burst of 500 hits in one frame plays one hit.
	_later()
	_sound.drain_started()
	var monster: int = _monster()
	for i: int in 500:
		_emit(SimEvent.Kind.HIT, KNIGHT, monster, 3, false)
	assert_eq(_sound.drain_started(), [&"hit"] as Array[StringName], "500 hits, one sound")


# --- R5 ------------------------------------------------------------------------


func test_r5_quiet_and_mutable() -> void:
	var bus: int = AudioServer.get_bus_index(&"SFX")
	assert_gt(bus, 0, "an SFX bus exists, apart from Master")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), -12.0, 0.01, "at -12 dB")
	for child: Node in _sound.get_children():
		var voice: AudioStreamPlayer = child as AudioStreamPlayer
		if voice != null:
			assert_eq(voice.bus, &"SFX", "every voice plays on the SFX bus")
	assert_false(_sound.is_muted(), "not muted to begin with")

	var key_press := InputEventKey.new()
	key_press.keycode = KEY_M
	key_press.pressed = true
	_sound._unhandled_input(key_press)
	assert_true(_sound.is_muted(), "M mutes")
	assert_true(AudioServer.is_bus_mute(bus), "the SFX bus is muted")
	assert_true(FileAccess.file_exists(_settings_path), "the choice is written to the test's file")
	assert_true(SoundSettings.new(_settings_path).muted(), "and says muted")

	AudioServer.set_bus_mute(bus, false)
	var second: SoundPlayer = _player()
	assert_true(second.is_muted(), "a second player given the same file starts muted")

	_sound._unhandled_input(key_press)
	assert_false(_sound.is_muted(), "M again unmutes")
	assert_false(SoundSettings.new(_settings_path).muted(), "and that is kept too")

	var main: Main = make_main()
	add_child_autofree(main)
	assert_not_null(main.sound, "the main scene makes a player")
	assert_null(main.sound.settings, "a test run has no settings file: the real one is untouched")


# --- R6 ------------------------------------------------------------------------


func test_r6_silent_while_catching_up() -> void:
	var sim := Simulation.new(Main.SIMULATION_SEED)
	for i: int in 2000:
		sim.step()
	sim.drain_events()
	var data: Dictionary = sim.to_save()
	data[Main.SAVED_AT_KEY] = Time.get_unix_time_from_system()
	assert_true(SaveStore.new(_save_path).write(data), "the test's save was written")
	var main: Main = make_main()
	main.save_store = SaveStore.new(_save_path)
	main.away_seconds_override = 1200.0
	add_child_autofree(main)
	assert_true(main.is_catching_up(), "a replay runs")
	var frames: int = 0
	while main.is_catching_up() and frames < 3000:
		assert_null(main.sound, "no player exists during the replay")
		await wait_process_frames(1)
		frames += 1
	assert_false(main.is_catching_up(), "the replay ended")
	assert_not_null(main.sound, "the player exists once play starts")

	# Headless, every sound plays without an error.
	for sound: StringName in SOUNDS:
		_later()
		_sound.play(sound)
	await wait_process_frames(3)
	assert_engine_error_count(0, "no audio errors")
	assert_push_error_count(0, "no pushed errors")
