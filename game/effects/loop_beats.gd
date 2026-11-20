class_name LoopBeats
extends RefCounted
## The beats of the loop on screen: LEVEL UP over a hero with its rising sparks, z's drifting up
## from resting heroes, the WIPED and stage-stable banners, the columns of light of a revival, and
## a guardian's coming (its name and the depth it guards) and its fall (GUARDIAN SLAIN).
##
## It hears [signal World.sim_event] itself and makes its texts and particles through
## [CombatEffects], which made it and advances it once a frame.

const LEVEL_UP_TIME: float = 1.2
const LEVEL_UP_PARTICLES: int = 22
## LEVEL UP's font multiple, and how far above the hero's feet it sits, in pixels: clear of the
## numbers that leap from the hero's chest.
const LEVEL_UP_SCALE: int = 2
const LEVEL_UP_RAISE: float = 44.0
## Seconds between a resting hero's z's.
const Z_EVERY: float = 1.1
const BANNER_LIFE_STABLE: float = 2.0
## How far above the middle of the screen the depth banner sits, so it never covers WIPED.
const STABLE_RAISE: float = 40.0
const LIGHT_HEIGHT: int = 56
const LIGHT_LIFE: float = 0.9
## A guardian's coming: the name's and the depth line's font multiples, how far above the middle
## of the screen each sits, how long both stay, and the camera's one shake.
const ANNOUNCE_SCALE: int = 4
const ANNOUNCE_LINE_SCALE: int = 2
const ANNOUNCE_RAISE: float = 92.0
const ANNOUNCE_LINE_RAISE: float = 64.0
const ANNOUNCE_LIFE: float = 2.0
const ANNOUNCE_SHAKE: float = 4.0
## GUARDIAN SLAIN: its font multiple, how far above the middle it sits and how long it stays.
const SLAIN_SCALE: int = 4
const SLAIN_RAISE: float = 64.0
const SLAIN_LIFE: float = 2.5

var _fx: CombatEffects
var _world: World
var _simulation: Simulation
## Shared with the combat effects, so what they throw goes on as one sequence.
var _rng: RandomNumberGenerator
var _spark_texture: Texture2D
## Resting, and each hero's seconds to its next z.
var _resting: bool = false
var _z_in: Dictionary[int, float] = {}
## A revival seen this frame, shown once the world has put the heroes back on their feet.
var _revival_due: bool = false


## Call once: texts and particles are made through [param fx], with [param rng] and
## [param spark_texture].
func setup(
	fx: CombatEffects,
	world: World,
	simulation: Simulation,
	rng: RandomNumberGenerator,
	spark_texture: Texture2D
) -> void:
	_fx = fx
	_world = world
	_simulation = simulation
	_rng = rng
	_spark_texture = spark_texture
	if not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)


## Shows a revival seen since the last advance, and the resting heroes' z's.
func advance(delta: float) -> void:
	if _revival_due:
		_revival_due = false
		_revival_lights()
	_rest_z(delta)


func _on_sim_event(event: SimEvent) -> void:
	var recent: bool = _world.may_animate(event)
	match event.kind:
		SimEvent.Kind.LEVEL_UP:
			if recent:
				_level_up(event.target_id)
		SimEvent.Kind.REST_STARTED:
			_resting = true
			_z_in.clear()
		SimEvent.Kind.REST_ENDED:
			_resting = false
		SimEvent.Kind.ENCOUNTER_STARTED:
			_resting = false
			var guardian: Combatant = CombatEffects.battle_guardian(_simulation)
			if recent and guardian != null:
				_announce(guardian)
		SimEvent.Kind.GUARDIAN_SLAIN:
			if recent:
				_slain()
		SimEvent.Kind.PARTY_WIPED:
			_resting = false
			if recent:
				_banner("WIPED", &"red", 3, Expedition.REVIVE_SECONDS, Vector2.ZERO)
		SimEvent.Kind.PARTY_REVIVED:
			if recent:
				_revival_due = true
		SimEvent.Kind.STABLE_DEPTH_REACHED:
			if recent:
				var words: String = (
					"%s STABLE" % PlaceText.here(_simulation, event.amount).to_upper()
				)
				_banner(words, &"yellow", 2, BANNER_LIFE_STABLE, Vector2(0, -STABLE_RAISE))


func _level_up(hero_id: int) -> void:
	var hero: CharacterSprite = _world.character(hero_id)
	if hero == null:
		return
	var feet: Vector2 = hero.position
	var colors: Array[StringName] = [&"yellow", &"amber", &"white", &"orange"]
	for i: int in LEVEL_UP_PARTICLES:
		var bit: FxParticle = _fx.new_particle(&"rise")
		if bit == null:
			break
		bit.color = Palette.color(colors[i % colors.size()])
		bit.texture = _spark_texture if i % 4 == 0 else null
		bit.size = 1 + i % 2
		bit.velocity = Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-75.0, -30.0))
		bit.gravity = -25.0
		bit.life = _rng.randf_range(0.6, LEVEL_UP_TIME)
		bit.start(
			feet + Vector2(_rng.randf_range(-11.0, 11.0), -_rng.randf_range(0.0, 8.0)).round()
		)
	var words: FxText = _fx.new_text(&"banner")
	words.text = "LEVEL UP"
	words.color = Palette.color(&"yellow")
	words.scale_factor = LEVEL_UP_SCALE
	# Over every number, so a fight's numbers never hide it.
	words.z_index = 2
	words.life = LEVEL_UP_TIME
	words.velocity = Vector2(0, -6)
	words.follow_id = hero_id
	words.screen_offset = Vector2(0, -LEVEL_UP_RAISE)
	words.start(feet + words.screen_offset)
	_fx.show_text(words)


func _banner(
	words: String, color_name: StringName, factor: int, life: float, offset: Vector2
) -> void:
	var banner: FxText = _fx.new_text(&"banner")
	banner.text = words
	banner.color = Palette.color(color_name)
	banner.scale_factor = factor
	banner.life = life
	banner.on_screen = true
	banner.screen_offset = offset
	banner.start(_fx.screen_middle(offset))
	_fx.show_text(banner)


## Its name, large, in the upper middle of the screen, the depth it guards under it, and a shake.
func _announce(guardian: Combatant) -> void:
	var name: String = Content.monster(guardian.def_id).display_name.to_upper()
	var depth: String = PlaceText.here(_simulation, _simulation.expedition.depth).to_upper()
	_guardian_words(&"announce", name, &"white", ANNOUNCE_SCALE, ANNOUNCE_RAISE, ANNOUNCE_LIFE)
	_guardian_words(
		&"announce",
		"GUARDIAN OF %s" % depth,
		&"red",
		ANNOUNCE_LINE_SCALE,
		ANNOUNCE_LINE_RAISE,
		ANNOUNCE_LIFE
	)
	_world.camera.shake(ANNOUNCE_SHAKE)


## GUARDIAN SLAIN, in gold, above the middle of the screen.
func _slain() -> void:
	_guardian_words(&"slain", "GUARDIAN SLAIN", &"yellow", SLAIN_SCALE, SLAIN_RAISE, SLAIN_LIFE)


## Words of [param kind] for a guardian, [param raise] pixels above the middle of the screen for
## [param life] seconds, over everything.
func _guardian_words(
	kind: StringName, words: String, color_name: StringName, factor: int, raise: float, life: float
) -> void:
	var shown: FxText = _fx.new_text(kind)
	shown.text = words
	shown.color = Palette.color(color_name)
	shown.scale_factor = factor
	shown.z_index = 3
	shown.life = life
	shown.on_screen = true
	shown.screen_offset = Vector2(0, -raise)
	shown.start(_fx.screen_middle(shown.screen_offset))
	_fx.show_text(shown)


func _revival_lights() -> void:
	for hero: Hero in _simulation.party.heroes:
		var sprite: CharacterSprite = _world.character(hero.id)
		if sprite == null:
			continue
		var outer: FxParticle = _fx.new_particle(&"light")
		if outer == null:
			return
		outer.shape = FxParticle.Shape.COLUMN
		outer.color = Palette.color(&"yellow")
		outer.size = 16
		outer.height = LIGHT_HEIGHT
		outer.life = LIGHT_LIFE
		outer.start(_world.feet_position(hero.id))  # on the floor, under a hero still lying
		var core: FxParticle = _fx.new_particle(&"light")
		if core == null:
			return
		core.shape = FxParticle.Shape.COLUMN
		core.color = Palette.color(&"white")
		core.size = 8
		core.height = LIGHT_HEIGHT
		core.life = LIGHT_LIFE
		core.start(_world.feet_position(hero.id))


## While the party rests, a z drifts up from each living hero now and then.
func _rest_z(delta: float) -> void:
	if not _resting:
		return
	var index: int = 0
	for hero: Hero in _simulation.party.heroes:
		index += 1
		var sprite: CharacterSprite = _world.character(hero.id)
		if sprite == null or sprite.is_dead():
			continue
		var due: float = _z_in.get(hero.id, 0.15 + 0.27 * index) - delta
		if due > 0.0:
			_z_in[hero.id] = due
			continue
		_z_in[hero.id] = Z_EVERY
		var z: FxText = _fx.new_text(&"z")
		z.text = "z"
		z.color = Palette.color(&"white")
		z.scale_factor = 2
		z.life = 1.3
		z.velocity = Vector2(5, -16)
		z.sway = 2.0
		z.sway_period = 0.9
		z.start(sprite.position + Vector2(5, -28))
		_fx.show_text(z)
