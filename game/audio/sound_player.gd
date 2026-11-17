class_name SoundPlayer
extends Node
## Plays the sound effects (spec 021): short sounds baked from the recipes in
## [code]assets/audio/sfx/[/code], for the moments [signal World.sim_event] and
## [signal CombatEffects.coin_collected] mark.
##
## It never becomes noise: the same sound does not start twice within [constant REPEAT_SECONDS],
## at most [constant MAX_VOICES] play at once, and each start varies its pitch a little. Sounds play
## on the [constant BUS] bus, quiet by default; the [kbd]M[/kbd] key mutes and unmutes that bus, and
## the choice is kept in [member settings] if there is one. Its clock moves only in
## [code]_process[/code], so a test can step it exactly.

## The audio bus every sound plays on (set up by the project's bus layout).
const BUS: StringName = &"SFX"
## That bus's volume if the layout did not make it, in dB.
const BUS_VOLUME_DB: float = -12.0
## Where the baked sounds are, each [code]<name>.wav[/code].
const DIR: String = "res://assets/audio/sfx/"
## Every sound there is.
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
	&"guardian_appears",
	&"guardian_slain",
]
## The most sounds playing at once.
const MAX_VOICES: int = 8
## The least time, in seconds, between two starts of the same sound.
const REPEAT_SECONDS: float = 0.05
## How far a start's pitch may stray from the sound's own, either way, as a share (under 6%).
const PITCH_SPREAD: float = 0.05
## How much quieter than its own the click of each swing at a side quest is, in dB (spec 028).
const WORK_CLICK_DB: float = -10.0

## Where the mute choice is kept. Null means nowhere: tests, screenshots and headless runs. Set it
## before [method setup] to choose the file.
var settings: SoundSettings

var _world: World
var _simulation: Simulation
## The combatant ids of guardians seen in a fight, whose deaths play the fanfare instead.
var _guardian_ids: Dictionary[int, bool] = {}
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
## When each voice's sound ends, on [member _now].
var _ends: Array[float] = []
## When each sound last started, on [member _now].
var _last_start: Dictionary = {}
var _started: Array[StringName] = []
var _now: float = 0.0
## Old gold gains whose coin_collected is yet to arrive (and must play nothing).
var _stale_coins: int = 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	for sound: StringName in SOUNDS:
		var stream: AudioStream = load(DIR + String(sound) + ".wav") as AudioStream
		if stream != null:
			_streams[sound] = stream
	_ensure_bus()
	for i: int in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		voice.bus = BUS
		add_child(voice)
		_voices.append(voice)
		_ends.append(0.0)


## Listens to [param world]'s events and [param effects]' coins, and takes the mute choice from
## [member settings]. Call it once the world, effects and HUD exist (after any catch-up).
func setup(world: World, effects: CombatEffects, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation
	if not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	# Deferred, so an old gold gain's coin (which the effects pass on at once, before this hears
	# of the gain itself) can be told apart from a coin that flew to the purse.
	if not effects.coin_collected.is_connected(_on_coin_collected):
		effects.coin_collected.connect(_on_coin_collected, CONNECT_DEFERRED)
	# Each swing of a hero working a side quest clicks, softly (spec 028 R9).
	if world.quest_props != null and not world.quest_props.worked.is_connected(_on_worked):
		world.quest_props.worked.connect(_on_worked)
	# A goal finished on the HUD's tracker (spec 037) plays the stable chime.
	var main: Main = get_parent() as Main
	if main != null and main.hud != null and main.hud.goals != null:
		if not main.hud.goals.goal_finished.is_connected(_on_goal_finished):
			main.hud.goals.goal_finished.connect(_on_goal_finished)
	_apply_mute(settings != null and settings.muted())


func _process(delta: float) -> void:
	_now += delta
	_note_guardian()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_M:
		return
	set_muted(not is_muted())
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## Plays a sound by name, subject to the limits of R4, [param volume_db] from its own volume.
## Returns whether it started.
func play(sound: StringName, volume_db: float = 0.0) -> bool:
	if not _streams.has(sound):
		return false
	var last: float = _last_start.get(sound, -INF)
	if _now - last < REPEAT_SECONDS:
		return false
	var free: int = -1
	for i: int in _voices.size():
		if _ends[i] <= _now:
			free = i
			break
	if free < 0:
		return false
	var stream: AudioStream = _streams[sound]
	var voice: AudioStreamPlayer = _voices[free]
	var pitch: float = 1.0 + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.volume_db = volume_db
	if voice.is_inside_tree():
		voice.play()
	_ends[free] = _now + stream.get_length() / pitch
	_last_start[sound] = _now
	_started.append(sound)
	return true


## Mutes or unmutes the [constant BUS] bus, and keeps the choice in [member settings].
func set_muted(muted: bool) -> void:
	_apply_mute(muted)
	if settings != null:
		settings.set_muted(muted)


func is_muted() -> bool:
	var bus: int = AudioServer.get_bus_index(BUS)
	return bus >= 0 and AudioServer.is_bus_mute(bus)


## How many sounds are playing now.
func playing_count() -> int:
	var count: int = 0
	for end: float in _ends:
		if end > _now:
			count += 1
	return count


## The names started since the last call (for tests).
func drain_started() -> Array[StringName]:
	var started: Array[StringName] = _started
	_started = []
	return started


func _apply_mute(muted: bool) -> void:
	var bus: int = AudioServer.get_bus_index(BUS)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, muted)


## Makes the [constant BUS] bus if the project's bus layout did not.
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var bus: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, BUS)
	AudioServer.set_bus_volume_db(bus, BUS_VOLUME_DB)
	AudioServer.set_bus_send(bus, &"Master")


## Remembers the guardian of the fight on now, if there is one.
func _note_guardian() -> void:
	var guardian: Combatant = CombatEffects.battle_guardian(_simulation)
	if guardian != null:
		_guardian_ids[guardian.id] = true


func _on_sim_event(event: SimEvent) -> void:
	_note_guardian()
	if _world == null or not _world.is_recent(event):
		if event.kind == SimEvent.Kind.GOLD_GAINED:
			_stale_coins += 1
		return
	var on_monster: bool = event.target_id >= Expedition.FIRST_MONSTER_ID
	match event.kind:
		SimEvent.Kind.HIT:
			if not on_monster:
				play(&"hero_hurt")
			else:
				play(&"crit" if event.flag else &"hit")
		SimEvent.Kind.HEALED:
			if event.amount >= 1:
				play(&"heal")
		SimEvent.Kind.ENCOUNTER_STARTED:
			if CombatEffects.battle_guardian(_simulation) != null:
				play(&"guardian_appears")
		SimEvent.Kind.GUARDIAN_SLAIN:
			play(&"guardian_slain")
		SimEvent.Kind.DIED:
			if _guardian_ids.has(event.source_id):
				pass  # GUARDIAN_SLAIN plays the fanfare in its place.
			elif event.source_id >= Expedition.FIRST_MONSTER_ID:
				play(&"monster_die")
			else:
				play(&"hero_die")
		SimEvent.Kind.LEVEL_UP, SimEvent.Kind.MICROSKILL_LEARNED:
			play(&"level_up")
		SimEvent.Kind.SIDE_QUEST_MISSED:
			if event.flag:
				play(&"hero_hurt")  # a trap sprang
		SimEvent.Kind.PROJECTILE_LAUNCHED:
			play(&"bolt")
		SimEvent.Kind.PARTY_WIPED:
			play(&"wipe")
		SimEvent.Kind.PARTY_REVIVED:
			play(&"revive")
		SimEvent.Kind.STABLE_DEPTH_REACHED:
			play(&"depth_stable")
		SimEvent.Kind.UPGRADE_BOUGHT, SimEvent.Kind.HERO_TRAINED:
			play(&"ui_buy")


func _on_goal_finished(_sentence: String) -> void:
	play(&"depth_stable")


func _on_worked(_hero_id: int) -> void:
	play(&"ui_click", WORK_CLICK_DB)


func _on_coin_collected(_amount: int) -> void:
	if _stale_coins > 0:
		_stale_coins -= 1
		return
	play(&"coin")
