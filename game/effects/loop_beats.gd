class_name LoopBeats
extends RefCounted
## The beats of the loop on screen: LEVEL UP over a hero with its rising sparks, z's drifting up
## from resting heroes, the WIPED and stage-stable banners, the light and sparks of every revival
## (the party's, a revive in a fight, a hero getting up at the camp), and
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
## The sparks of a revival, rising from the hero's feet beside its column of light.
const REVIVAL_SPARKS: int = 12
## The longest a revival's spark lives, in seconds, and how far either side of the feet one
## starts, in pixels: within the hero's own width.
const SPARK_LIFE: float = 1.0
const SPARK_SPREAD: float = 5.0
## How high above a standing hero's feet its z's start, in pixels: over its head. A sitting
## hero's start as much lower as its head is.
const Z_HEIGHT: float = 28.0
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
	if not world.fallen_party.rose_at_camp.is_connected(revival_effect):
		world.fallen_party.rose_at_camp.connect(revival_effect)


## Shows a revival seen since the last frame. [CombatEffects] calls it before the guardian's waves
## and the bolts' trails, and [method advance] after them, so effects join the pool in one order.
func light_revival() -> void:
	if _revival_due:
		_revival_due = false
		_revival_lights()


## The revival effect at hero [param hero_id]'s feet: its column of light, a yellow outer one and
## a white core, and green and white sparks rising from the floor and fading. The same for every
## revival: one at the camp, a revive in a fight, and the party's after a wipe.
func revival_effect(hero_id: int) -> void:
	if _world.character(hero_id) == null:
		return
	var feet: Vector2 = _world.feet_position(hero_id)  # on the floor, under a hero still lying
	if not _light_column(feet, &"yellow", 16) or not _light_column(feet, &"white", 8):
		return
	for i: int in REVIVAL_SPARKS:
		var spark: FxParticle = _fx.new_particle(&"revival_spark")
		if spark == null:
			return
		spark.color = Palette.color(&"white" if i % 3 == 0 else &"green")
		spark.texture = _spark_texture if i % 4 == 0 else null
		spark.size = 1 + i % 2
		spark.velocity = Vector2(_rng.randf_range(-6.0, 6.0), -_rng.randf_range(30.0, 60.0))
		spark.gravity = -10.0
		spark.life = _rng.randf_range(0.5, SPARK_LIFE)
		var side: float = _rng.randf_range(-SPARK_SPREAD, SPARK_SPREAD)
		spark.start(feet + Vector2(side, -_rng.randf_range(0.0, 3.0)).round())


## A column of revival light [param width] pixels wide standing on [param feet]; false when the
## budget has no room for it.
func _light_column(feet: Vector2, colour: StringName, width: int) -> bool:
	var light: FxParticle = _fx.new_particle(&"light")
	if light == null:
		return false
	light.shape = FxParticle.Shape.COLUMN
	light.color = Palette.color(colour)
	light.size = width
	light.height = LIGHT_HEIGHT
	light.life = LIGHT_LIFE
	light.start(feet)
	return true


## Moves the resting heroes' z's on by [param delta] seconds.
func advance(delta: float) -> void:
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
		SimEvent.Kind.REVIVED:
			if recent:
				revival_effect(event.target_id)
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
		revival_effect(hero.id)


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
		var sat: float = sprite.shown_sit()
		var height: float = (
			Z_HEIGHT * lerpf(1.0, CharacterSprite.SIT_HEIGHT, sat) - CharacterSprite.SIT_DROP * sat
		)
		z.start(sprite.position + Vector2(5, -roundf(height)))
		_fx.show_text(z)
