class_name AbilityEffects
extends Node
## Abilities on screen: what a fighter's action or passive is and does, told plainly.
##
## - An ability's name rises over its fighter in the hero's (a summon's summoner's, or a
##   monster's) colour, at most [constant MAX_NAMES] stacked over one fighter. An action is
##   named as its wind-up begins, a passive as it fires.
## - An action's wind-up lights its fighter (a pulsing glow for its length) and performs its
##   move; a heavy blow throws a larger spark, damage to many a ring on the floor, a push
##   kicks dust at the feet of those the events say it landed on (its target, and whoever its
##   ability's other effects reached in that tick) as they slide. A heal shows the heal effect
##   [CombatEffects] already draws for every HEALED, and a revive stands the fallen hero up
##   ([method FallenParty.stand]), even one revived in the frame it fell.
## - The statuses are [StatusMarks], drawn from [member AbilityCredit.statuses]; a status's
##   damage number takes its colour ([method number_color]).
## - A strike that misses shows [code]Miss[/code], damage a shield absorbs [code]Blocked[/code]
##   (once a second for one shield, however many blows it takes).
##
## It listens to [signal World.sim_event] before [CombatEffects] does (that one asks it the colour
## of a number), and makes its names, words, rings and particles through the world's [FxPool].
## Everything moves from elapsed time, so a test can step it exactly. Names, words and
## [CombatEffects]' numbers keep inside the band between the HUD's top and bottom, so they never
## cover a health bar.

# Names.
## Seconds a name shows, and how fast it drifts up, in pixels a second.
const NAME_LIFE: float = 1.2
const NAME_DRIFT: float = 8.0
## Pixels between the top of a fighter's head and its first name, room for the status marks
## between; and between two names stacked over one fighter.
const NAME_RAISE: float = 12.0
const NAME_STEP: float = 8.0
## The most names over one fighter at once.
const MAX_NAMES: int = 2
## Pixels a name or word keeps clear of the HUD's bands and the screen's sides.
const BAND_MARGIN: float = 2.0

# Wind-ups.
## The glow's colour, its least and most, and how many times a second it pulses.
const GLOW_COLOR: StringName = &"yellow"
const GLOW_LOW: float = 0.25
const GLOW_HIGH: float = 0.6
const GLOW_RATE: float = 6.0

# Landings.
## A damage effect at least this many times the fighter's damage is a heavy blow.
const HEAVY: float = 1.5
## The heavy blow's flash, in pixels, and how many large shards it throws.
const HEAVY_FLASH: int = 15
const HEAVY_SHARDS: int = 10
## A ring's seconds, and its reach in tiles when its effect reaches everyone.
const RING_LIFE: float = 0.4
const RING_EVERYONE: float = 4.0
## Seconds a pushed fighter's dust kicks.
const DUST_SECONDS: float = 0.35
## The most particles these effects make at once.
const MAX_PARTICLES: int = FxPool.ABILITY

# Misses.
const MISS_LIFE: float = 0.6
const MISS_LEAP: float = 45.0
const MISS_GRAVITY: float = 90.0

## The colour of a status's damage numbers and of its tint and motes.
const STATUS_COLORS: Dictionary[int, StringName] = {
	AbilityEffect.Status.BURNING: &"orange",
	AbilityEffect.Status.BLEEDING: &"red",
	AbilityEffect.Status.CHILLED: &"cyan",
}

## What each blow and heal was, and the statuses on every fighter.
var credit: AbilityCredit = AbilityCredit.new()
## The marks of the statuses, beside the effects layer.
var marks: StatusMarks

var _world: World
var _simulation: Simulation
var _rng := RandomNumberGenerator.new()
var _spark_texture: Texture2D
## Per fighter winding up an action: real seconds of wind-up left, and whom it is aimed at.
var _glows: Dictionary[int, float] = {}
var _aims: Dictionary[int, int] = {}
var _glow_time: float = 0.0
## Per fighter: the action named as its wind-up began, so its landing is not named again.
var _announced: Dictionary[int, StringName] = {}
## Per pushed fighter: seconds of dust left.
var _dust: Dictionary[int, float] = {}
## The push being told: its fighter, its ability and its tick (a push lands on its target and on
## whoever that ability's other effects reach in the same tick).
var _pushing: Dictionary[int, StringName] = {}
var _push_tick: int = -1
## Per fighter: the tick a Blocked last showed over it.
var _blocked: Dictionary[int, int] = {}
## The last HIT heard, for [method number_color].
var _last_hit: SimEvent
## A monster's name colour, by its sheet's path.
var _sheet_colors: Dictionary[String, Color] = {}


## Call once, before the first advance, and before [CombatEffects] listens to [param world].
func setup(world: World, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation
	_rng.seed = 56
	var sheet: PixelSheet = PixelSheet.load_sheet(CombatEffects.SPARK_SHEET)
	_spark_texture = sheet.part(&"spark") if sheet != null else null
	if not _world.sim_event.is_connected(_on_sim_event):
		_world.sim_event.connect(_on_sim_event)
	if marks == null:
		marks = StatusMarks.new()
		marks.name = "StatusMarks"
		# Beside the effects layer, not in it (the layer holds only passing effects, and empties
		# when nothing happens): at its height over the darkness, just before it so under every
		# number, name and spark.
		marks.z_index = World.EFFECTS_Z
		marks.z_as_relative = false
		_world.add_child(marks)
		_world.move_child(marks, _world.effects_layer.get_index())
	marks.setup(world, credit.statuses)
	credit.statuses.power = _power


## Advances the glows, the dust and the marks by [param delta] real seconds; the pool moves the
## rest. [CombatEffects] calls it each frame.
func advance(delta: float) -> void:
	if _world == null or _world.fx == null:
		return
	_glow_time += delta
	_advance_glows(delta)
	_advance_dust(delta)
	marks.advance(delta)


## Keeps [param text] (a word on the effects layer, one of [CombatEffects]' numbers) inside the
## band between the HUD's top and bottom, so it never covers a health bar. Call after it moves.
func keep_text_in_band(text: FxText) -> bool:
	text.position += _band_shift(text.rect())
	return true


## Keeps [param icon] (a resource drop) inside that band while it rises and hangs where the
## fighter fell; one flying to its place beside the gold crosses the screen to get there, as a coin
## does, and is left alone.
func keep_drop_in_band(icon: FxResource) -> void:
	if icon.phase == FxResource.Phase.RISE:
		var box := Rect2(icon.position - ResourceIcon.SIZE / 2.0, ResourceIcon.SIZE)
		icon.position += _band_shift(box)


## The colour a damage or heal number of [param event] is drawn in: a status's own colour for
## damage a burning, bleeding or chilled status did, [param fallback] for a critical hit, a
## summon's summoner's class colour for what else it dealt or healed, [param fallback] otherwise.
func number_color(event: SimEvent, fallback: StringName) -> StringName:
	if event == _last_hit and STATUS_COLORS.has(credit.status):
		return STATUS_COLORS[credit.status]
	if event.kind == SimEvent.Kind.HIT and event.flag:
		return fallback  # a critical hit reads as one, whoever struck it
	var summoner: StringName = (
		_world.summons.colour_of(event.source_id) if _summoned(event) else &""
	)
	return summoner if summoner != &"" else fallback


## The names showing over fighter [param id], lowest first.
func names_over(id: int) -> Array[String]:
	var found: Array[String] = []
	var names: Array[FxText] = _names()
	for slot: int in MAX_NAMES:
		for text: FxText in names:
			if text.follow_id == id and text.slot == slot:
				found.append(text.text)
	return found


## Every name and word showing.
func texts() -> Array[FxText]:
	var found: Array[FxText] = _names()
	for word: Node2D in _world.fx.nodes(&"ability_word"):
		found.append(word as FxText)
	return found


## How many particles of [param kind] these effects have now.
func particles(kind: StringName) -> int:
	var count: int = 0
	for particle: Node2D in _world.fx.nodes(&"ability"):
		if (particle as FxParticle).kind == kind:
			count += 1
	return count


## Every particle these effects have now.
func all_particles() -> Array[FxParticle]:
	var found: Array[FxParticle] = []
	found.assign(_world.fx.nodes(&"ability"))
	return found


## The rings showing.
func rings() -> Array[FxRing]:
	var found: Array[FxRing] = []
	found.assign(_world.fx.nodes(&"ring"))
	return found


## True while fighter [param id] is lit for an action's wind-up.
func is_glowing(id: int) -> bool:
	return _glows.has(id)


# --- Events --------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	credit.observe(event)
	var recent: bool = _world.may_animate(event)
	if event.tick != _push_tick:
		_pushing.clear()
	if _pushing.get(event.source_id, &"") != &"" and recent:
		_pushed_by(event)
	match event.kind:
		SimEvent.Kind.ABILITY_STARTED:
			_started(event, recent)
		SimEvent.Kind.ABILITY_USED:
			_used(event, recent)
		SimEvent.Kind.HIT:
			_last_hit = event
			if recent:
				_heavy(event)
		SimEvent.Kind.MISSED:
			if recent:
				_miss(event)
		SimEvent.Kind.DIED, SimEvent.Kind.SUMMON_ENDED:
			_died(event.source_id)
		SimEvent.Kind.STATUS_BEGAN:
			if event.status == AbilityEffect.Status.STUNNED:
				# A stunned fighter loses its wind-up: it never swings at nothing after.
				_stop_glow(event.target_id, true)
				var stunned: CharacterSprite = _world.character(event.target_id)
				if stunned != null:
					stunned.cancel_attack()
		SimEvent.Kind.ENCOUNTER_ENDED, SimEvent.Kind.PARTY_WIPED, SimEvent.Kind.AREA_CHANGED:
			_forget_fight()
		SimEvent.Kind.DEPTH_CHANGED:
			_forget_fight()


func _forget_fight() -> void:
	for id: int in _glows.keys():
		_stop_glow(id, true)
	_announced.clear()
	_dust.clear()
	_pushing.clear()
	_blocked.clear()


## An action's wind-up begins: its fighter glows for its length, and it is named.
func _started(event: SimEvent, recent: bool) -> void:
	var ability: AbilityDef = Content.ability(event.ability_id)
	var sprite: CharacterSprite = _world.character(event.source_id)
	if ability == null or sprite == null:
		return
	var speed: int = maxi(_world.speed, 1)
	var age: float = float(_simulation.tick - event.tick) / Simulation.TICKS_PER_SECOND
	var left: float = maxf(float(event.amount) / Simulation.TICKS_PER_SECOND - age, 0.0) / speed
	_glows[event.source_id] = left
	_aims[event.source_id] = event.target_id
	_light(event.source_id)
	if not recent:
		return
	_announce(event.source_id, ability)  # its fighter's move is the World's to play
	_announced[event.source_id] = ability.id


## An action lands or a passive fires: it is named (an action only if its wind-up was not), and
## what it does there is shown.
func _used(event: SimEvent, recent: bool) -> void:
	var ability: AbilityDef = Content.ability(event.ability_id)
	if ability == null:
		return
	if ability.is_action():
		_stop_glow(event.source_id, false)
	var named: bool = ability.is_action() and _announced.get(event.source_id, &"") == ability.id
	_announced.erase(event.source_id)
	if not recent:
		return
	if not named:
		_announce(event.source_id, ability)
	for effect: AbilityEffect in ability.effects:
		if effect.does == AbilityEffect.Does.DAMAGE and _many(effect):
			_ring(event, effect)
			break
	for effect: AbilityEffect in ability.effects:
		if effect.does == AbilityEffect.Does.PUSH:
			_pushing[event.source_id] = ability.id
			_push_tick = event.tick
			if effect.lands in [AbilityEffect.Lands.TARGET, AbilityEffect.Lands.AROUND_TARGET]:
				_dust[event.target_id] = DUST_SECONDS
			break


## True if [param effect] lands on more than its target.
static func _many(effect: AbilityEffect) -> bool:
	match effect.lands:
		AbilityEffect.Lands.AROUND_TARGET:
			return effect.radius > 0.0
		AbilityEffect.Lands.ENEMIES, AbilityEffect.Lands.ALLIES:
			return true
	return false


## True if [param ability] deals a heavy blow: a damage effect of at least HEAVY times the
## fighter's damage.
static func is_heavy(ability: AbilityDef) -> bool:
	if ability == null:
		return false
	for effect: AbilityEffect in ability.effects:
		if effect.does == AbilityEffect.Does.DAMAGE and effect.multiplier >= HEAVY:
			return true
	return false


func _heavy(event: SimEvent) -> void:
	if credit.ability_id == &"" or not is_heavy(Content.ability(credit.ability_id)):
		return
	var target: CharacterSprite = _world.character(event.target_id)
	if target == null:
		return
	var feet: Vector2 = target.position
	var impact: Vector2 = feet + Vector2(0, -roundf(_height(target) * CombatEffects.IMPACT_HEIGHT))
	var flash: FxParticle = _particle(&"heavy")
	if flash != null:
		flash.shape = FxParticle.Shape.PUFF
		flash.color = Palette.color(&"white")
		flash.size = HEAVY_FLASH
		flash.life = 0.16
		flash.start(impact)
	var colors: Array[StringName] = [&"white", &"yellow", &"amber"]
	for i: int in HEAVY_SHARDS:
		var shard: FxParticle = _particle(&"heavy")
		if shard == null:
			break
		shard.color = Palette.color(colors[i % colors.size()])
		shard.texture = _spark_texture if i % 2 == 0 else null
		shard.size = 4 if i % 3 == 0 else 3
		var angle: float = TAU * (i + _rng.randf()) / HEAVY_SHARDS
		shard.velocity = Vector2.from_angle(angle) * _rng.randf_range(110.0, 190.0)
		shard.gravity = CombatEffects.SPARK_GRAVITY
		shard.floor_y = feet.y
		shard.life = _rng.randf_range(0.3, 0.5)
		shard.start(impact)


## A ring on the floor from the target (an effect round it) or the fighter (one on every enemy).
func _ring(event: SimEvent, effect: AbilityEffect) -> void:
	var at_target: bool = effect.lands == AbilityEffect.Lands.AROUND_TARGET
	var from: CharacterSprite = _world.character(event.target_id if at_target else event.source_id)
	if from == null:
		return
	var ring := FxRing.new()
	ring.name = "Ring"
	ring.color = _fighter_color(event.source_id)
	ring.reach = (effect.radius if effect.radius > 0.0 else RING_EVERYONE) * World.TILE
	ring.life = RING_LIFE
	ring.position = from.position + Vector2(0, -1)
	_world.fx.add(ring, &"ring")


## [param event] follows a push by its fighter in the same tick: if it is that ability's (a status
## it put on, a blow it dealt), its receiver was pushed too, and kicks dust.
func _pushed_by(event: SimEvent) -> void:
	var ability: StringName = _pushing[event.source_id]
	var landed: bool = false
	match event.kind:
		SimEvent.Kind.STATUS_BEGAN:
			landed = event.ability_id == ability
		SimEvent.Kind.HIT, SimEvent.Kind.MISSED:
			landed = credit.ability_id == ability
	if landed and event.target_id >= 0:
		_dust[event.target_id] = DUST_SECONDS


func _miss(event: SimEvent) -> void:
	var target: CharacterSprite = _world.character(event.target_id)
	if target == null:
		return
	if event.flag:
		# One Blocked a second over a shield, however many blows it takes.
		var last: int = _blocked.get(event.target_id, -Simulation.TICKS_PER_SECOND)
		if event.tick - last < Simulation.TICKS_PER_SECOND:
			return
		_blocked[event.target_id] = event.tick
	var word := FxText.new()
	word.name = "Word"
	word.kind = &"miss"
	word.text = "Blocked" if event.flag else "Miss"
	word.color = Palette.color(&"cyan" if event.flag else &"silver")
	word.scale_factor = 1
	word.life = MISS_LIFE
	word.velocity = Vector2(_rng.randf_range(-10.0, 10.0), -MISS_LEAP)
	word.gravity = MISS_GRAVITY
	word.z_index = 1
	word.follow = keep_text_in_band
	var height: float = _height(target) * CombatEffects.NUMBER_HEIGHT
	word.start(target.position + Vector2(0, -roundf(height)))
	_world.fx.add(word, &"ability_word")


## What a status's strength is a multiple of ([enum AbilityEffect.Scale]), for fighter
## [param source]'s status on [param receiver]: their damage, healing power or maximum health,
## measures that do not change in a fight ([member StatusBook.power]).
func _power(source: int, receiver: int, scale: int) -> float:
	var measured: Combatant = _measures(
		receiver if scale == AbilityEffect.Scale.RECEIVER_MAX_HEALTH else source
	)
	if measured == null:
		return 0.0
	match scale:
		AbilityEffect.Scale.FIGHTER_DAMAGE:
			return measured.damage
		AbilityEffect.Scale.FIGHTER_HEALING:
			return measured.heal_power
	return measured.max_health


## Fighter [param id]'s measures: its fighter in the fight, a hero's own, or a waiting monster's.
func _measures(id: int) -> Combatant:
	var battle: Battle = _simulation.expedition.battle
	var fighter: Combatant = battle.combatant(id) if battle != null else null
	if fighter != null:
		return fighter
	var hero: Hero = _simulation.party.hero(id)
	if hero != null:
		return hero.combatant()
	return _world._monsters.get(id, null)


## True when [param event] comes from a summon, by its id.
func _summoned(event: SimEvent) -> bool:
	return SummonSprites.is_summon_id(event.source_id) and _world.summons != null


func _died(id: int) -> void:
	_stop_glow(id, true)
	_dust.erase(id)
	_blocked.erase(id)
	for attacker: int in _aims.keys():
		if _aims[attacker] == id and _glows.has(attacker):
			_stop_glow(attacker, true)  # the simulation drops a wind-up whose target died


# --- Names ---------------------------------------------------------------------


## Names [param ability] over fighter [param id]: a name already showing there starts again; a
## third pushes out the oldest.
func _announce(id: int, ability: AbilityDef) -> void:
	if _world.character(id) == null:
		return
	var over: Array[FxText] = []
	for text: FxText in _names():
		if text.follow_id == id:
			if text.text == ability.display_name:
				text.age = 0.0
				return
			over.append(text)
	var taken: Dictionary[int, bool] = {}
	for text: FxText in over:
		taken[text.slot] = true
	if over.size() >= MAX_NAMES:
		var oldest: FxText = over[0]
		for text: FxText in over:
			if text.age > oldest.age:
				oldest = text
		taken.erase(oldest.slot)
		_world.fx.remove(oldest)
	var slot: int = 0
	while taken.has(slot):
		slot += 1
	var name_text := FxText.new()
	name_text.name = "Name"
	name_text.kind = &"name"
	name_text.text = ability.display_name
	name_text.color = _fighter_color(id)
	name_text.scale_factor = 1
	name_text.outline = true
	name_text.life = NAME_LIFE
	name_text.velocity = Vector2(0, -NAME_DRIFT)
	name_text.follow_id = id
	name_text.z_index = 2
	name_text.slot = slot
	name_text.follow = _place_name
	_place_name(name_text)
	_world.fx.add(name_text, &"ability_name")


## The names showing, oldest first.
func _names() -> Array[FxText]:
	var found: Array[FxText] = []
	found.assign(_world.fx.nodes(&"ability_name"))
	return found


## Puts [param text] over its fighter's head in its slot, inside the band; false (it goes) once
## the fighter is gone, as nothing is left over a fighter that has gone.
func _place_name(text: FxText) -> bool:
	var sprite: CharacterSprite = _world.character(text.follow_id)
	if sprite == null or not sprite.visible:
		return false
	var head: float = SpriteBounds.body_rect(sprite).position.y
	var anchor := Vector2(sprite.position.x, head - NAME_RAISE - text.slot * NAME_STEP)
	text.set_anchor(anchor)
	var shift: Vector2 = _band_shift(text.rect())
	if shift != Vector2.ZERO:
		text.set_anchor(anchor + shift)
	return true


## The name colour of fighter [param id]: a hero's class colour (its tally bar's), a summon's
## summoner's, a monster's most vivid sheet colour, or white.
func _fighter_color(id: int) -> Color:
	if SummonSprites.is_summon_id(id) and _world.summons != null:
		var summoner: StringName = _world.summons.colour_of(id)
		return Palette.color(summoner if summoner != &"" else &"white")
	if id < Expedition.FIRST_MONSTER_ID:
		var hero: Hero = _simulation.party.hero(id)
		if hero != null:
			var colours: Array = TallyWindow.CLASS_BARS.get(hero.class_id, TallyWindow.OTHER_BAR)
			var first: StringName = colours[0]
			return Palette.color(first)
		return Palette.color(&"white")
	var sprite: CharacterSprite = _world.character(id)
	return _vivid(sprite) if sprite != null else Palette.color(&"white")


## The most vivid colour of [param sprite]'s sheet, read once per sheet.
func _vivid(sprite: CharacterSprite) -> Color:
	var sheet: Texture2D = SpriteBounds.sheet_of(sprite)
	if sheet == null:
		return Palette.color(&"white")
	var path: String = sheet.resource_path
	if not _sheet_colors.has(path):
		var best: Color = Palette.color(&"white")
		var best_score: float = -1.0
		for colour: Color in CombatEffects.sheet_colors(sheet):
			var score: float = colour.s * colour.v + 0.3 * colour.v
			if colour.v >= 0.5 and score > best_score:
				best = colour
				best_score = score
		_sheet_colors[path] = best
	return _sheet_colors[path]


# --- Ongoing -------------------------------------------------------------------


func _light(id: int) -> void:
	var sprite: CharacterSprite = _world.character(id)
	if sprite == null:
		return
	var wave: float = 0.5 + 0.5 * sin(_glow_time * TAU * GLOW_RATE)
	sprite.set_glow(Palette.color(GLOW_COLOR), lerpf(GLOW_LOW, GLOW_HIGH, wave))


func _advance_glows(delta: float) -> void:
	for id: int in _glows.keys():
		_glows[id] -= delta
		if _glows[id] <= 0.0:
			_stop_glow(id, false)
		else:
			_light(id)


## Puts out the glow of [param id]; [param cancel] also ends its swing short.
func _stop_glow(id: int, cancel: bool) -> void:
	if not _glows.has(id):
		return
	_glows.erase(id)
	_aims.erase(id)
	var sprite: CharacterSprite = _world.character(id)
	if sprite != null:
		sprite.set_glow(Palette.color(GLOW_COLOR), 0.0)
		if cancel:
			sprite.cancel_attack()


func _advance_dust(delta: float) -> void:
	for id: int in _dust.keys():
		_dust[id] -= delta
		var sprite: CharacterSprite = _world.character(id)
		if _dust[id] <= 0.0 or sprite == null:
			_dust.erase(id)
			continue
		var puff: FxParticle = _particle(&"dust")
		if puff == null:
			continue
		puff.shape = FxParticle.Shape.PUFF
		puff.color = Palette.color(&"tan" if _rng.randi_range(0, 1) == 0 else &"silver")
		puff.size = _rng.randi_range(3, 5)
		puff.life = _rng.randf_range(0.25, 0.4)
		puff.velocity = Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-14.0, -4.0))
		puff.start(sprite.position + Vector2(_rng.randf_range(-5.0, 5.0), -2.0).round())


# --- Making and placing --------------------------------------------------------


func _particle(kind: StringName) -> FxParticle:
	var made := FxParticle.new()
	made.name = "Particle"
	made.kind = kind
	return made if _world.fx.add(made, &"ability") else null


## The canvas height of a character's sprite, in pixels.
static func _height(sprite: CharacterSprite) -> float:
	return SpriteBounds.canvas_height(sprite)


## The move that keeps [param rect] (world pixels) inside the band of the screen between the
## HUD's top and bottom bands, in whole pixels.
func _band_shift(rect: Rect2) -> Vector2:
	var camera: WorldCamera = _world.camera
	if camera == null:
		return Vector2.ZERO
	var view: Vector2 = (
		camera.get_viewport_rect().size if camera.is_inside_tree() else WorldCamera.FALLBACK_VIEW
	)
	var zoom: Vector2 = camera.zoom
	var top_left: Vector2 = (rect.position - camera.position - camera.offset) * zoom + view / 2.0
	var size: Vector2 = rect.size * zoom
	var band := Rect2(
		Vector2(BAND_MARGIN, HudFrame.TOP_BAND + BAND_MARGIN),
		Vector2(
			view.x - 2.0 * BAND_MARGIN,
			view.y - HudFrame.TOP_BAND - HudFrame.BOTTOM_BAND - 2.0 * BAND_MARGIN
		)
	)
	var shift := Vector2.ZERO
	if top_left.x < band.position.x:
		shift.x = band.position.x - top_left.x
	elif top_left.x + size.x > band.end.x:
		shift.x = band.end.x - top_left.x - size.x
	if top_left.y < band.position.y:
		shift.y = band.position.y - top_left.y
	elif top_left.y + size.y > band.end.y:
		shift.y = band.end.y - top_left.y - size.y
	return (shift / zoom).round()
