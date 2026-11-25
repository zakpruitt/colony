class_name QuestEffects
extends Node
## The effects of quests and microskills: a done quest's prop bursting in its own colours under
## words in the reward's colour, with its own payoff (coins out of an opened chest, a stone's runes
## flaring and sending a mote to each living hero, a snip where the wire was; a wanderer's is its
## heal light, [QuestStory]'s), dust at a stuck door's foot at each shove, a miss's muted "Needs
## <microskill>" rising from the prop, a sprung trap's red "Sprung!" with a shake and every hero
## flashing, and "Learned <microskill>" over a hero; and of side paths: "Needs a <microskill>"
## rising from a gate nobody can open, and a cache bursting into sparks as it opens. The coins and
## XP of a reward come from their own events, through [CombatEffects].
##
## [CombatEffects] makes it. It listens to [signal World.sim_event] and makes its words and
## particles through the world's [FxPool], at most [constant MAX_PARTICLES] particles at once.
## An event that may not animate ([method World.may_animate]) shows nothing.

## The most particles these effects make at once.
const MAX_PARTICLES: int = FxPool.QUEST
## The words' font multiples: a done quest and a sprung trap large, a miss and a lesson small.
const DONE_SCALE: int = 2
const MISS_SCALE: int = 1
const LEARNED_SCALE: int = 1
## Seconds each kind of words stays.
const DONE_LIFE: float = 1.6
const MISS_LIFE: float = 1.8
const SPRUNG_LIFE: float = 1.2
const LEARNED_LIFE: float = 2.0
const SEALED_LIFE: float = 2.0
## The sparks of a cache opening: how many, their colours, and how high over its floor they
## start.
const CACHE_SPARKS_MIN: int = 16
const CACHE_SPARKS_MAX: int = 22
const CACHE_COLOURS: Array[StringName] = [&"yellow", &"amber", &"white"]
const CACHE_RAISE: float = 8.0
## How fast the words rise, in pixels per second.
const RISE: float = 14.0
## Pixels between the top of a prop and the baseline of its words.
const OVER_PROP: float = 6.0
## How far above a hero's feet "Learned ..." sits: over LEVEL UP, which comes with it.
const LEARNED_RAISE: float = CombatEffects.LEVEL_UP_RAISE + 16.0
## The burst of a done quest's prop.
const BURST_MIN: int = 12
const BURST_MAX: int = 16
const BURST_GRAVITY: float = 360.0
## The coins out of an opened chest: how many, and how high over the floor they leave.
const CHEST_COINS_MIN: int = 5
const CHEST_COINS_MAX: int = 8
const CHEST_RAISE: float = 8.0
## The XP motes leaving a read stone, and the flare of its runes: how high, how large, how long.
const RUNE_RAISE: float = 14.0
const FLARE_SIZE: int = 14
const FLARE_LIFE: float = 0.35
const FLARE_SPARKS: int = 8
## The snip where a wire was cut: how high over the floor, and its sparks.
const SNIP_RAISE: float = 3.0
const SNIP_SPARKS: int = 5
## The dust a shove at a door raises at its foot: how many puffs, and how far from its middle.
const DUST_PUFFS: int = 3
const DUST_SPREAD: float = 6.0
## Pixels above a hero's feet a chest's coin or a stone's mote flies to.
const CHEST_HEIGHT: float = 14.0
## The camera's shake when a trap springs (a crit is 2.5, a hero's death 6).
const SPRUNG_SHAKE: float = 5.0
## The words' colours: a miss's, a trap's, a lesson's; a done quest's by its reward.
const MISS_COLOUR: StringName = &"steel"
const SPRUNG_COLOUR: StringName = &"red"
const LEARNED_COLOUR: StringName = &"yellow"
const REWARD_COLOURS: Dictionary[QuestDef.Reward, StringName] = {
	QuestDef.Reward.GOLD: &"yellow",
	QuestDef.Reward.XP: &"cyan",
}

var _world: World
var _simulation: Simulation
var _rng := RandomNumberGenerator.new()


## Call once, before the first advance.
func setup(world: World, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation
	_rng.seed = 28
	if not _world.sim_event.is_connected(_on_sim_event):
		_world.sim_event.connect(_on_sim_event)
	var props: QuestProps = _world.quest_props
	if props != null and not props.worked.is_connected(_on_worked):
		props.worked.connect(_on_worked)


## The particles these effects show now.
func live_particles() -> int:
	return _world.fx.count(&"quest")


func _on_sim_event(event: SimEvent) -> void:
	if _world.quest_props == null or not _world.may_animate(event):
		return
	match event.kind:
		SimEvent.Kind.QUEST_DONE:
			_done(_quest(event.target_id), event.source_id)
		SimEvent.Kind.QUEST_MISSED:
			if event.flag:
				_sprung(_quest(event.target_id))
			else:
				_missed(_quest(event.target_id), event.amount)
		SimEvent.Kind.MICROSKILL_LEARNED:
			_learned(event.source_id, event.target_id)
		SimEvent.Kind.GATE_SEALED:
			_sealed(event.target_id, event.amount)
		SimEvent.Kind.CACHE_OPENED:
			_cache_opened(event.amount)


## [param quest] is done by [param opener], its lead.
func _done(quest: StringName, opener: int) -> void:
	var def: QuestDef = Content.quest(quest)
	if def == null:
		return
	var at: Vector2 = _prop_spot()
	var height: float = _prop_height(quest)
	var colour: StringName = REWARD_COLOURS.get(def.reward, &"yellow")
	var words: String = QuestProps.DONE_WORDS.get(quest, def.display_name)
	_words(words, colour, DONE_SCALE, DONE_LIFE, at + Vector2(0, -height - OVER_PROP))
	_burst(quest, at, height)
	match quest:
		&"locked_chest":
			_spill_coins(at, opener)
		&"rune_stone":
			_flare(at)
		&"tripwire":
			_snip(at)


## A shove at a stuck door (a cycle of the worker's pose) puffs dust at the door's foot.
func _on_worked(_hero_id: int) -> void:
	if _simulation.expedition.working_quest() != &"stuck_door":
		return
	var foot: Vector2 = _prop_spot()
	for i: int in DUST_PUFFS:
		var puff: FxParticle = _particle(&"door_dust")
		if puff == null:
			return
		puff.shape = FxParticle.Shape.PUFF
		puff.color = Palette.color(&"sand" if i % 2 == 0 else &"silver")
		puff.size = _rng.randi_range(3, 5)
		puff.life = _rng.randf_range(0.35, 0.55)
		puff.velocity = Vector2(_rng.randf_range(-14.0, 14.0), -_rng.randf_range(4.0, 10.0))
		puff.start((foot + Vector2(_rng.randf_range(-DUST_SPREAD, DUST_SPREAD), -1.0)).round())


## Coins spill out of the open chest, bounce, and fly to [param opener], who opened it.
func _spill_coins(feet: Vector2, opener: int) -> void:
	for i: int in _rng.randi_range(CHEST_COINS_MIN, CHEST_COINS_MAX):
		var coin := FxCoin.new()
		coin.name = "ChestCoin"
		coin.share = 0
		coin.floor_y = feet.y - 1.0
		coin.velocity = Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-170.0, -110.0))
		coin.rest_time = 0.45 + 0.06 * i
		coin.age = _rng.randf_range(0.0, 0.3)
		coin.start(feet + Vector2(_rng.randf_range(-3.0, 3.0), -CHEST_RAISE).round())
		coin.target = _hero_chest.bind(opener, feet)
		_world.fx.add(coin, &"quest")


## The stone's runes flare, and a mote of XP drifts from it to each living hero.
func _flare(feet: Vector2) -> void:
	var runes: Vector2 = feet + Vector2(0, -RUNE_RAISE)
	var flare: FxParticle = _particle(&"rune_flare")
	if flare != null:
		flare.shape = FxParticle.Shape.PUFF
		flare.color = Palette.color(&"cyan")
		flare.size = FLARE_SIZE
		flare.life = FLARE_LIFE
		flare.start(runes)
	for i: int in FLARE_SPARKS:
		var spark: FxParticle = _particle(&"rune_flare")
		if spark == null:
			break
		spark.color = Palette.color(&"white" if i % 2 == 0 else &"cyan")
		spark.size = 1 + i % 2
		var angle: float = TAU * (i + _rng.randf()) / FLARE_SPARKS
		spark.velocity = Vector2.from_angle(angle) * _rng.randf_range(30.0, 60.0)
		spark.life = _rng.randf_range(0.3, 0.5)
		spark.start(runes.round())
	for hero: Hero in _simulation.party.heroes:
		if not hero.is_alive() or _world.character(hero.id) == null:
			continue
		var mote := FxMote.new()
		mote.name = "StoneMote"
		mote.hero_id = hero.id
		mote.velocity = Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-70.0, -40.0))
		mote.start(runes + Vector2(_rng.randf_range(-3.0, 3.0), 0.0).round())
		mote.target = _hero_chest.bind(hero.id, Vector2.INF)
		_world.fx.add(mote, &"quest")


## A small white snip where the wire was cut.
func _snip(feet: Vector2) -> void:
	var at: Vector2 = feet + Vector2(0, -SNIP_RAISE)
	var flash: FxParticle = _particle(&"snip")
	if flash != null:
		flash.shape = FxParticle.Shape.PUFF
		flash.color = Palette.color(&"white")
		flash.size = 5
		flash.life = 0.15
		flash.start(at)
	for i: int in SNIP_SPARKS:
		var spark: FxParticle = _particle(&"snip")
		if spark == null:
			break
		spark.color = Palette.color(&"white")
		spark.size = 1
		var angle: float = _rng.randf_range(PI * 1.05, PI * 1.95)
		spark.velocity = Vector2(cos(angle), sin(angle)) * _rng.randf_range(40.0, 80.0)
		spark.gravity = BURST_GRAVITY
		spark.floor_y = feet.y
		spark.life = _rng.randf_range(0.2, 0.35)
		spark.start(at.round())


## Where a coin or mote for hero [param hero_id] flies to now: its chest; [param otherwise] once
## it is gone.
func _hero_chest(hero_id: int, otherwise: Vector2) -> Vector2:
	if _world.character(hero_id) == null:
		return otherwise
	return _world.feet_position(hero_id) + Vector2(0, -CHEST_HEIGHT)


func _missed(quest: StringName, skill_index: int) -> void:
	var skills: Array[StringName] = Content.microskill_ids()
	if skill_index < 0 or skill_index >= skills.size():
		return
	var skill: MicroskillDef = Content.microskill(skills[skill_index])
	var at: Vector2 = _prop_spot() + Vector2(0, -_prop_height(quest) - OVER_PROP)
	_words("Needs %s" % skill.display_name, MISS_COLOUR, MISS_SCALE, MISS_LIFE, at)


func _sprung(quest: StringName) -> void:
	var at: Vector2 = _prop_spot() + Vector2(0, -_prop_height(quest) - OVER_PROP)
	_words("Sprung!", SPRUNG_COLOUR, DONE_SCALE, SPRUNG_LIFE, at)
	_world.camera.shake(SPRUNG_SHAKE)
	# Every hero flashes as a hit does, even one too hurt to lose more (no HIT for it).
	for hero: Hero in _simulation.party.heroes:
		var sprite: CharacterSprite = _world.character(hero.id)
		if sprite != null and not sprite.is_dead():
			sprite.play_hit()


func _learned(hero_id: int, skill_index: int) -> void:
	var skills: Array[StringName] = Content.microskill_ids()
	if skill_index < 0 or skill_index >= skills.size() or _world.character(hero_id) == null:
		return
	var skill: MicroskillDef = Content.microskill(skills[skill_index])
	var text: FxText = _words(
		"Learned %s" % skill.display_name, LEARNED_COLOUR, LEARNED_SCALE, LEARNED_LIFE, Vector2.ZERO
	)
	text.velocity = Vector2(0, -4)
	text.z_index = 2
	text.follow_id = hero_id
	text.screen_offset = Vector2(0, -LEARNED_RAISE)
	text.follow = _keep_over_hero
	text.start(_world.feet_position(hero_id) + text.screen_offset)


## "Needs a <microskill>" rising from the gate nobody can open.
func _sealed(gate_index: int, skill_index: int) -> void:
	var props: SideProps = _world.side_props
	var words: String = GateTip.sealed_line(skill_index)
	var index: int = props.nearest(gate_index) if props != null else -1
	if index < 0 or words.is_empty():
		return
	var stage: int = _simulation.expedition.depth
	var height: float = maxf(SideProps.height_of(props.gate(stage, index)), 16.0)
	var at: Vector2 = props.gate_spot(stage, index) + Vector2(0, -height - OVER_PROP)
	_words(words, MISS_COLOUR, MISS_SCALE, SEALED_LIFE, at)


## The cache of side path [param index] on the party's stage bursts into sparks.
func _cache_opened(index: int) -> void:
	if _world.side_props == null:
		return
	var feet: Vector2 = _world.side_props.cache_spot(_simulation.expedition.depth, index)
	var middle: Vector2 = feet + Vector2(0, -CACHE_RAISE)
	for i: int in _rng.randi_range(CACHE_SPARKS_MIN, CACHE_SPARKS_MAX):
		var spark: FxParticle = _particle(&"cache_spark")
		if spark == null:
			break
		spark.color = Palette.color(CACHE_COLOURS[i % CACHE_COLOURS.size()])
		spark.size = 2 + i % 2
		var angle: float = _rng.randf_range(PI * 1.1, PI * 1.9)
		spark.velocity = Vector2(cos(angle), sin(angle)) * _rng.randf_range(70.0, 170.0)
		spark.gravity = BURST_GRAVITY
		spark.floor_y = feet.y
		spark.bounce = 0.35
		spark.life = _rng.randf_range(0.45, 0.85)
		spark.start(
			middle + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-3.0, 3.0)).round()
		)


## After each advance, a text over a hero stays over it while it is there.
func _keep_over_hero(text: FxText) -> bool:
	if _world.character(text.follow_id) != null:
		text.set_anchor(_world.feet_position(text.follow_id) + text.screen_offset)
	return true


## The prop's colours flying out from its middle, with a puff.
func _burst(quest: StringName, feet: Vector2, height: float) -> void:
	var colours: PackedColorArray = _prop_colours(quest)
	if colours.is_empty():
		return
	var middle: Vector2 = feet + Vector2(0, -roundf(height * 0.5))
	for i: int in _rng.randi_range(BURST_MIN, BURST_MAX):
		var bit: FxParticle = _particle(&"quest_burst")
		if bit == null:
			break
		bit.color = colours[_rng.randi_range(0, colours.size() - 1)]
		bit.size = _rng.randi_range(2, 3)
		var angle: float = _rng.randf_range(PI * 1.1, PI * 1.9)
		bit.velocity = Vector2(cos(angle), sin(angle)) * _rng.randf_range(60.0, 150.0)
		bit.gravity = BURST_GRAVITY
		bit.floor_y = feet.y
		bit.bounce = 0.35
		bit.life = _rng.randf_range(0.5, 0.9)
		bit.start(
			middle + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0)).round()
		)
	var puff: FxParticle = _particle(&"quest_puff")
	if puff == null:
		return
	puff.shape = FxParticle.Shape.PUFF
	puff.color = Palette.color(&"white")
	puff.size = CombatEffects.PUFF_SIZE
	puff.life = CombatEffects.PUFF_LIFE
	puff.velocity = Vector2(0, -12)
	puff.start(middle)


## Words rising from [param at] (the centre of their baseline).
func _words(words: String, colour: StringName, factor: int, life: float, at: Vector2) -> FxText:
	var text := FxText.new()
	text.name = "QuestText"
	text.kind = &"quest"
	text.text = words
	text.color = Palette.color(colour)
	text.scale_factor = factor
	text.z_index = 2
	text.life = life
	text.velocity = Vector2(0, -RISE)
	text.start(at)
	_world.fx.add(text, &"quest_text")
	return text


func _particle(kind: StringName) -> FxParticle:
	var made := FxParticle.new()
	made.name = "QuestParticle"
	made.kind = kind
	return made if _world.fx.add(made, &"quest") else null


# --- Reading -------------------------------------------------------------------


func _quest(index: int) -> StringName:
	var ids: Array[StringName] = Content.quest_ids()
	return ids[index] if index >= 0 and index < ids.size() else &""


## Where the prop of the quest just met stands: in the chamber the party is in.
func _prop_spot() -> Vector2:
	var key: Vector2i = _world.quest_props.party_chamber()
	if key.y < 0:
		return _world.feet_position(_simulation.party.heroes[0].id)
	return _world.quest_props.spot(key.x, key.y)


func _prop_height(quest: StringName) -> float:
	var sheet: PixelSheet = QuestProps.sheet_of(quest)
	return float(sheet.size.y) if sheet != null else 16.0


func _prop_colours(quest: StringName) -> PackedColorArray:
	var sheet: PixelSheet = QuestProps.sheet_of(quest)
	if sheet == null:
		return PackedColorArray()
	var part: AtlasTexture = sheet.part(StringName(sheet.part_names[0]))
	return CombatEffects.sheet_colors(part.atlas)
