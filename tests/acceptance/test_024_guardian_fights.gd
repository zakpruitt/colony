extends "res://tests/support/play_fixture.gd"
## Acceptance tests for specs/024-guardian-fights/spec.md, one per requirement.
##
## Each test builds a World on a seeded simulation, with the CombatEffects, the Hud (and its
## BossBarView) and a SoundPlayer on it, every _process turned off. It puts a party beside the Slime
## King's chamber on depth 5 (as the 020 tests do) and plays frames by hand: the simulation steps
## once every FRAMES_PER_TICK frames of STEP seconds, and the world, effects, HUD and sound player
## each move on by STEP. Events are recorded as the world passes them on.

const SEED: int = 1
const GUARDIAN_DEPTH: int = 5
const STRONG_LEVEL: int = 40
const SLIME_KING_SHEET: String = "res://assets/sprites/monsters/slime_king.png"

var _settings_path: String = save_path("", "settings")
var _sound: SoundPlayer


func before_each() -> void:
	_frames_played = 0
	_sim = Simulation.new(SEED)
	_build_hud(false)
	_sound = SoundPlayer.new()
	_sound.settings = SoundSettings.new(_settings_path)
	add_child_autofree(_sound)
	_sound.set_process(false)
	_sound.setup(_world, _fx, _sim, null)
	_frame_parts = [_fx.advance, _hud.advance, _sound._process]
	_hear_events()


# --- Helpers -------------------------------------------------------------------


func _play_seconds(seconds: float, stepping: bool = true) -> void:
	for i: int in roundi(seconds / STEP):
		_play_frame(stepping)


func _words(kind: StringName) -> Array[String]:
	var found: Array[String] = []
	for text: FxText in _texts(kind):
		found.append(text.text)
	return found


func _guardian_events(kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for event: SimEvent in _events:
		if event.kind == kind:
			found.append(event)
	return found


## Starts the fight with the Slime King with a strong party; true once it has begun.
func _start_guardian_fight(level: int = STRONG_LEVEL) -> bool:
	raise_party(_sim, level)
	before_guardian(_sim, GUARDIAN_DEPTH)
	return _play_until(SimEvent.Kind.ENCOUNTER_STARTED)


## The guardian's death event among the events just passed on, or null.
func _guardian_death() -> SimEvent:
	for event: SimEvent in _events:
		if event.kind == SimEvent.Kind.DIED and _fx.is_guardian(event.source_id):
			return event
	return null


# --- R1 ------------------------------------------------------------------------


func test_r1_guardian_is_announced() -> void:
	assert_true(_start_guardian_fight(), "the guardian's fight starts")
	var words: Array[String] = _words(&"announce")
	assert_has(words, "SLIME KING", "its name is announced")
	assert_has(words, "GUARDIAN OF MOSSY HOLLOW 5", "with the place it guards (spec 049)")
	for text: FxText in _texts(&"announce"):
		assert_true(text.on_screen, "%s is pinned to the screen" % text.text)
		assert_lt(text.screen_offset.y, 0.0, "%s sits in the upper screen" % text.text)
		assert_almost_eq(text.life, 2.0, 0.3, "%s stays about 2 s" % text.text)
	var title: FxText = _texts(&"announce")[0]
	var line: FxText = _texts(&"announce")[1]
	assert_gt(title.scale_factor, line.scale_factor, "the name is larger than the depth line")
	assert_gt(_world.camera._shake, 0.0, "the camera shakes")
	assert_has(_sound.drain_started(), &"guardian_appears", "the guardian_appears sound starts")
	_play_seconds(1.5)
	assert_eq(_texts(&"announce").size(), 2, "still showing after 1.5 s")
	_play_seconds(0.7)
	assert_eq(_texts(&"announce").size(), 0, "gone after about 2 s")

	# After the guardian, the party goes on down: its next, ordinary fight is not announced.
	assert_true(_play_until(SimEvent.Kind.ENCOUNTER_ENDED), "the guardian's fight ends")
	_sound.drain_started()
	assert_true(_play_until(SimEvent.Kind.ENCOUNTER_STARTED), "an ordinary fight starts")
	assert_null(CombatEffects.battle_guardian(_sim), "it has no guardian")
	assert_eq(_texts(&"announce").size(), 0, "an ordinary encounter is not announced")
	assert_does_not_have(_sound.drain_started(), &"guardian_appears", "nor sounds like one")


# --- R2 ------------------------------------------------------------------------


func test_r2_boss_bar() -> void:
	var bar: BossBarView = _hud.boss_bar
	assert_not_null(bar, "the HUD has a boss bar")
	assert_false(bar.is_showing(), "no bar before any fight")
	assert_true(_start_guardian_fight(), "the guardian's fight starts")
	assert_true(bar.is_showing(), "the bar shows as the fight starts")
	assert_eq(bar.shown_name(), "SLIME KING", "with the guardian's name")
	assert_almost_eq(bar.shown_fraction(), 1.0, 0.01, "full at the start")

	# Inside the top band, between the panels, clear of the shop too.
	var rect: Rect2 = bar.get_global_rect()
	assert_gte(rect.position.y, 0.0, "inside the top band")
	assert_lte(rect.end.y, HudFrame.TOP_BAND, "inside the top band")
	assert_gte(
		rect.position.x, _hud.place_panel.get_global_rect().end.x, "right of the depth panel"
	)
	assert_lte(rect.end.x, _hud.purse.get_global_rect().position.x, "left of the gold")
	assert_gt(rect.size.x, 150.0, "wide")
	_hud.shop.open()
	_hud.advance(0.0)
	assert_false(rect.intersects(_hud.shop.get_global_rect()), "clear of the open shop")
	_hud.shop.close()

	# It follows the guardian's health, eased.
	var guardian: Combatant = CombatEffects.battle_guardian(_sim)
	var hit_guardian: bool = false
	for i: int in 600 * FRAMES_PER_TICK:
		_events = []
		_play_frame()
		for event: SimEvent in _guardian_events(SimEvent.Kind.HIT):
			if event.target_id == guardian.id:
				hit_guardian = true
		if hit_guardian:
			break
	assert_true(hit_guardian, "a hit lands on the guardian")
	var actual: float = float(guardian.health) / guardian.max_health
	assert_lt(actual, 1.0, "the guardian is hurt")
	assert_true(bar.is_flashing(), "the bar flashes on the hit")
	assert_gt(bar.shown_fraction(), actual + 0.0001, "the bar eases down rather than jumping")
	for i: int in 60:
		bar.advance(STEP)
	assert_almost_eq(bar.shown_fraction(), actual, 0.001, "and arrives at the guardian's health")
	assert_false(bar.is_flashing(), "the flash is brief")

	# Gone after the win.
	assert_true(_play_until(SimEvent.Kind.ENCOUNTER_ENDED), "the fight ends")
	assert_true(_guardian_events(SimEvent.Kind.ENCOUNTER_ENDED)[0].flag, "the heroes won")
	assert_false(bar.is_showing(), "the bar is gone after a win")
	assert_true(_play_until(SimEvent.Kind.ENCOUNTER_STARTED), "an ordinary fight starts")
	_play_seconds(0.5)
	assert_false(bar.is_showing(), "no bar in an ordinary fight")


# --- R3 ------------------------------------------------------------------------


func test_r3_guardian_death() -> void:
	assert_true(_start_guardian_fight(), "the guardian's fight starts")
	_sound.drain_started()
	var guardian_id: int = CombatEffects.battle_guardian(_sim).id
	var sprite: CharacterSprite = _world.character(guardian_id)
	assert_not_null(sprite, "the guardian has a sprite")
	var palette: PackedColorArray = CombatEffects.sheet_colors(load(SLIME_KING_SHEET) as Texture2D)
	var died: bool = false
	var started: Array[StringName] = []
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		_events = []
		_play_frame()
		started.append_array(_sound.drain_started())
		if _guardian_death() != null:
			died = true
			break
	assert_true(died, "the guardian dies")
	if not died:
		return
	assert_gt(_world.camera._shake, CombatEffects.HERO_DEATH_SHAKE, "the camera shakes hard")
	assert_almost_eq(_world._frozen, 0.2, 0.03, "animation freezes for about 0.2 s")
	assert_does_not_have(started, &"monster_die", "no ordinary death sound")
	var gold: SimEvent = _guardian_events(SimEvent.Kind.GOLD_GAINED)[0]
	assert_eq(gold.source_id, guardian_id, "the gold is the guardian's")

	var coins: Array[FxCoin] = []
	for child: Node in _world.effects_layer.get_children():
		if child is FxCoin:
			coins.append(child as FxCoin)
	assert_gte(coins.size(), 20, "at least 20 coins pour out")
	var shares: int = 0
	for coin: FxCoin in coins:
		shares += coin.share
	assert_eq(shares, gold.amount, "their shares add up to the gold paid")
	assert_eq(_words(&"slain"), ["GUARDIAN SLAIN"] as Array[String], "GUARDIAN SLAIN shows")
	var slain: FxText = _texts(&"slain")[0]
	assert_eq(slain.color, Palette.color(&"yellow"), "in gold")
	assert_almost_eq(slain.life, 2.5, 0.2, "for about 2.5 s")

	# The burst, watched over the next second and a half.
	var seen: Dictionary[int, float] = {}
	var all_in_colours: bool = true
	var bursts: int = 0
	var t: float = 0.0
	for i: int in 90:
		for particle: FxParticle in _fx.particles():
			if particle.kind == &"burst":
				bursts += 1
			if particle.kind != &"guardian" or seen.has(particle.get_instance_id()):
				continue
			seen[particle.get_instance_id()] = t
			if not palette.has(particle.color):
				all_in_colours = false
		_events = []
		_play_frame()
		started.append_array(_sound.drain_started())
		t += STEP
	assert_gte(seen.size(), 60, "at least 60 particles")
	assert_true(all_in_colours, "every one in a colour of the guardian's sheet")
	var times: Array[float] = seen.values()
	times.sort()
	assert_eq(bursts, 0, "no ordinary burst")
	assert_between(times[-1] - times[0], 0.4, 1.1, "in waves over about a second")
	var waves: int = 1
	for i: int in range(1, times.size()):
		if times[i] - times[i - 1] > 0.1:
			waves += 1
	assert_between(waves, 2, 3, "two or three waves")
	assert_has(started, &"guardian_slain", "the fanfare plays")
	assert_does_not_have(started, &"monster_die", "no ordinary death sound")
	assert_true(sprite == null or not is_instance_valid(sprite) or sprite.is_dead(), "it is down")


# --- R4 ------------------------------------------------------------------------


func test_r4_losing_is_marked() -> void:
	assert_true(_start_guardian_fight(1), "a level-1 party meets the guardian")
	assert_true(_hud.boss_bar.is_showing(), "the bar shows")
	assert_true(_play_until(SimEvent.Kind.PARTY_WIPED), "the party is wiped")
	_play_frame()
	assert_false(_hud.boss_bar.is_showing(), "the bar is gone")
	var banners: Array[String] = _words(&"banner")
	assert_has(banners, "WIPED", "WIPED shows")
	assert_eq(_texts(&"slain").size(), 0, "no GUARDIAN SLAIN")
	assert_eq(_guardian_events(SimEvent.Kind.GUARDIAN_SLAIN).size(), 0, "nothing claims a win")
	assert_does_not_have(_sound.drain_started(), &"guardian_slain", "no fanfare")


# --- R5 ------------------------------------------------------------------------


func test_r5_within_budget() -> void:
	assert_true(_start_guardian_fight(), "the guardian's fight starts")
	# The particle cap already full when it dies: its death still shows, within its allowance.
	while _fx.live_particles() < CombatEffects.MAX_PARTICLES:
		var filler: FxParticle = _fx.new_particle(&"filler")
		filler.life = 30.0
	var most_particles: int = 0
	var most_numbers: int = 0
	var died: bool = false
	for i: int in LIMIT_TICKS_5_MIN * FRAMES_PER_TICK:
		_events = []
		_play_frame()
		most_particles = maxi(most_particles, _fx.live_particles())
		most_numbers = maxi(most_numbers, _fx.live_numbers())
		if _guardian_death() != null:
			died = true
			break
	assert_true(died, "the guardian dies")
	for filler: FxParticle in _fx.particles().duplicate():
		if filler.kind == &"filler":
			filler.age = filler.life
	for i: int in 120:
		_play_frame(false)
		most_particles = maxi(most_particles, _fx.live_particles())
		most_numbers = maxi(most_numbers, _fx.live_numbers())
	assert_lte(
		most_particles,
		CombatEffects.MAX_PARTICLES + CombatEffects.GUARDIAN_ALLOWANCE,
		"particles stay within the raised cap"
	)
	assert_gt(most_particles, CombatEffects.MAX_PARTICLES, "the death used its allowance")
	assert_lte(most_numbers, CombatEffects.MAX_NUMBERS, "numbers stay under their cap")
	_play_seconds(5.0, false)
	await get_tree().process_frame  # queue_free takes effect at the end of a frame
	assert_eq(_world.effects_layer.get_child_count(), 0, "the layer is empty after 5 quiet s")
	assert_false(_hud.boss_bar.is_showing(), "and the bar is gone")

	# An old GUARDIAN_SLAIN and its gold start nothing, but the coins are still credited.
	_sound.drain_started()
	var collected: Array[int] = []
	_fx.coin_collected.connect(func(amount: int) -> void: collected.append(amount))
	var old: int = _sim.tick - World.ANIMATE_TICKS - 5
	assert_gt(old, 0, "there is an old tick to use")
	_world.sim_event.emit(SimEvent.new(SimEvent.Kind.GOLD_GAINED, old, 100, -1, 290, false))
	_world.sim_event.emit(SimEvent.new(SimEvent.Kind.GUARDIAN_SLAIN, old, 100, -1, 5, false))
	_play_frame(false)
	await get_tree().process_frame
	assert_eq(_texts(&"slain").size(), 0, "no GUARDIAN SLAIN for an old event")
	assert_eq(_world.effects_layer.get_child_count(), 0, "no effect for an old event")
	assert_eq(collected, [290] as Array[int], "but its gold is credited at once")
	assert_does_not_have(_sound.drain_started(), &"guardian_slain", "and no fanfare")


# --- R6 ------------------------------------------------------------------------


func test_r6_sounds_exist() -> void:
	for sound: StringName in [&"guardian_appears", &"guardian_slain"]:
		assert_has(SoundPlayer.SOUNDS, sound, "%s is one of the player's sounds" % sound)
		var stream: AudioStreamWAV = (
			load(SoundPlayer.DIR + String(sound) + ".wav") as AudioStreamWAV
		)
		assert_not_null(stream, "%s loads" % sound)
		if stream != null:
			assert_between(stream.get_length(), 0.3, 1.2, "%s is short" % sound)
	_sound.drain_started()
	assert_true(_sound.play(&"guardian_slain"), "the fanfare plays")
	assert_false(_sound.play(&"guardian_slain"), "but not twice at once (the repeat limit)")
	var refused: int = 0
	for sound: StringName in SoundPlayer.SOUNDS:
		if sound != &"guardian_slain" and not _sound.play(sound):
			refused += 1
	assert_eq(_sound.playing_count(), SoundPlayer.MAX_VOICES, "no more than the voice limit")
	assert_gt(refused, 0, "the rest are refused while every voice is busy")
	var output: Array = []
	var tool: String = ProjectSettings.globalize_path("res://tools/sfx.py")
	var code: int = OS.execute("python", [tool, "lint"], output, true)
	assert_eq(code, 0, "python tools/sfx.py lint passes: %s" % [output])
