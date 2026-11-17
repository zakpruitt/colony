class_name QuestEffects
extends Node
## The effects of side quests and microskills (spec 028): a done quest's prop bursting in its own
## colours under words in the reward's colour, a miss's muted "Needs <microskill>" rising from the
## prop, a sprung trap's red "Sprung!" with a shake and every hero flashing, and "Learned
## <microskill>" over a hero. The coins and XP of a reward come from their own events, through
## [CombatEffects].
##
## [CombatEffects] makes it, and advances it from its own [method CombatEffects.advance]. It
## listens to [signal World.sim_event] and draws on [member World.effects_layer]. Events too old
## to animate ([method World.is_recent]) show nothing.

## The words' font multiples: a done quest and a sprung trap large, a miss and a lesson small.
const DONE_SCALE: int = 2
const MISS_SCALE: int = 1
const LEARNED_SCALE: int = 1
## Seconds each kind of words stays.
const DONE_LIFE: float = 1.6
const MISS_LIFE: float = 1.8
const SPRUNG_LIFE: float = 1.2
const LEARNED_LIFE: float = 2.0
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
## The camera's shake when a trap springs (a crit is 2.5, a hero's death 6).
const SPRUNG_SHAKE: float = 5.0
## The words' colours: a miss's, a trap's, a lesson's; a done quest's by its reward.
const MISS_COLOUR: StringName = &"steel"
const SPRUNG_COLOUR: StringName = &"red"
const LEARNED_COLOUR: StringName = &"yellow"
const REWARD_COLOURS: Dictionary[SideQuestDef.Reward, StringName] = {
	SideQuestDef.Reward.GOLD: &"yellow",
	SideQuestDef.Reward.XP: &"cyan",
}

var _world: World
var _simulation: Simulation
var _rng := RandomNumberGenerator.new()
var _texts: Array[FxText] = []
var _particles: Array[FxParticle] = []


## Call once, before the first advance.
func setup(world: World, simulation: Simulation) -> void:
	_world = world
	_simulation = simulation
	_rng.seed = 28
	if not _world.sim_event.is_connected(_on_sim_event):
		_world.sim_event.connect(_on_sim_event)


## Moves every effect on by [param delta] seconds.
func advance(delta: float) -> void:
	for bit: FxParticle in _particles.duplicate():
		if not bit.advance(delta):
			_particles.erase(bit)
			bit.queue_free()
	for text: FxText in _texts.duplicate():
		if text.follow_id >= 0 and _world.character(text.follow_id) != null:
			text.set_anchor(_world.feet_position(text.follow_id) + text.screen_offset)
		if not text.advance(delta):
			_texts.erase(text)
			text.queue_free()


func _on_sim_event(event: SimEvent) -> void:
	if _world.quest_props == null or not _world.is_recent(event):
		return
	match event.kind:
		SimEvent.Kind.SIDE_QUEST_DONE:
			_done(_quest(event.target_id))
		SimEvent.Kind.SIDE_QUEST_MISSED:
			if event.flag:
				_sprung(_quest(event.target_id))
			else:
				_missed(_quest(event.target_id), event.amount)
		SimEvent.Kind.MICROSKILL_LEARNED:
			_learned(event.source_id, event.target_id)


func _done(quest: StringName) -> void:
	var def: SideQuestDef = Content.side_quest(quest)
	if def == null:
		return
	var at: Vector2 = _prop_spot()
	var height: float = _prop_height(quest)
	var colour: StringName = REWARD_COLOURS.get(def.reward, &"yellow")
	var words: String = QuestProps.DONE_WORDS.get(quest, def.display_name)
	_words(words, colour, DONE_SCALE, DONE_LIFE, at + Vector2(0, -height - OVER_PROP))
	_burst(quest, at, height)


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
	text.start(_world.feet_position(hero_id) + text.screen_offset)


## The prop's colours flying out from its middle, with a puff.
func _burst(quest: StringName, feet: Vector2, height: float) -> void:
	var colours: PackedColorArray = _prop_colours(quest)
	if colours.is_empty():
		return
	var middle: Vector2 = feet + Vector2(0, -roundf(height * 0.5))
	for i: int in _rng.randi_range(BURST_MIN, BURST_MAX):
		var bit: FxParticle = _particle(&"quest_burst")
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
	_world.effects_layer.add_child(text)
	_texts.append(text)
	text.start(at)
	return text


func _particle(kind: StringName) -> FxParticle:
	var made := FxParticle.new()
	made.name = "QuestParticle"
	made.kind = kind
	_world.effects_layer.add_child(made)
	_particles.append(made)
	return made


# --- Reading -------------------------------------------------------------------


func _quest(index: int) -> StringName:
	var ids: Array[StringName] = Content.side_quest_ids()
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
