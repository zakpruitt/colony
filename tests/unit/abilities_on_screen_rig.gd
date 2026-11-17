extends GutTest
## The rig of spec 056's acceptance tests (tests/acceptance/test_056_abilities_on_screen.gd): a
## World on a seeded simulation, the CombatEffects that listen to it and, where asked, the Hud;
## and the helpers that feed them events and measure what shows. Not a test script itself.

const SEED: int = 56
const FRAME: float = 1.0 / 60.0
const KNIGHT: int = 1
const ROGUE: int = 2
const MAGE: int = 3
const CLERIC: int = 4
const HERO_IDS: Array[int] = [KNIGHT, ROGUE, MAGE, CLERIC]
const TPS: int = Simulation.TICKS_PER_SECOND
## The heroes' level in the fights of full trees (every talent point earned), and the path each
## class takes: the ones with a status that works each second (bleeding, burning).
const TREE_LEVEL: int = 14
const PATHS: Dictionary[StringName, int] = {&"knight": 1, &"rogue": 0, &"mage": 0, &"cleric": 1}
## How many times their health the monsters of a watched fight have, so it lasts.
const TOUGHER: int = 8
## A shield as Bulwark puts it on (its real effect, so its strength can be known).
const BULWARK_SHIELD: int = 1
## The longest a test waits for something, in ticks.
const LIMIT_TICKS: int = 20000
## R8: how long a name or number may cover a health bar, in seconds: a moment.
const MOMENT: float = 0.1
const BY: Dictionary[Tally.Measure, String] = {
	Tally.Measure.DAMAGE: "damage", Tally.Measure.HEALING: "healing"
}

var _sim: Simulation
var _world: World
var _fx: CombatEffects
var _hud: Hud
## The simulation tick a test's battle began on: its events are stamped from it.
var _base: int = 0
## Every event the world told of, oldest first.
var _heard: Array[SimEvent] = []
## Ticks added to the events a test makes, so each part of a test is on ticks of its own.
var _at: int = 0
## Game seconds owed to the simulation by [method _play_frame].
var _owed: float = 0.0


func before_each() -> void:
	_heard.clear()
	_hud = null
	_at = 0
	_owed = 0.0
	_build(Simulation.new(SEED))


func after_each() -> void:
	_mouse(Vector2(-1000, -1000))


# --- Helpers -------------------------------------------------------------------


func _build(simulation: Simulation, with_hud: bool = false) -> void:
	_sim = simulation
	_world = World.new()
	_world.simulation = _sim
	add_child_autofree(_world)
	_world.set_process(false)
	_fx = CombatEffects.new()
	add_child_autofree(_fx)
	_fx.set_process(false)
	_fx.setup(_world, _sim)
	_world.sim_event.connect(func(event: SimEvent) -> void: _heard.append(event))
	if with_hud:
		var layer := CanvasLayer.new()
		layer.layer = 129
		add_child_autofree(layer)
		_hud = Hud.new()
		layer.add_child(_hud)
		_hud.set_process(false)
		_hud.setup(_sim, _world, _fx)
		_hud.advance(0.0)


func _abilities() -> AbilityEffects:
	return _fx.ability_effects


func _marks() -> StatusMarks:
	return _fx.ability_effects.marks


## The id of a monster the world shows.
func _monster() -> int:
	for id: int in _world._monsters:
		if _world.character(id) != null:
			return id
	return -1


## A battle of the party's fighters and the shown monster [param monster_id] (the simulation's own
## combatant, left standing where it waits), begun on this tick.
func _battle(monster_id: int) -> Battle:
	var heroes: Array[Combatant] = []
	for hero: Hero in _sim.party.heroes:
		heroes.append(hero.combatant())
	var monster: Combatant = _world._monsters[monster_id]
	var x: float = monster.x
	var battle := Battle.new(heroes, [monster], x - 8.0, x + 8.0, true, SimRng.new(SEED))
	monster.x = x
	_base = _sim.tick
	return battle


## The status effect [param kind] for [param seconds], strong enough to show.
func _status(kind: int, seconds: float = 6.0) -> AbilityEffect:
	var effect := AbilityEffect.new()
	effect.does = AbilityEffect.Does.STATUS
	effect.status = kind as AbilityEffect.Status
	effect.seconds = seconds
	effect.scale = AbilityEffect.Scale.RECEIVER_MAX_HEALTH
	match kind:
		AbilityEffect.Status.SHIELDED:
			effect.amount = 0.5
		AbilityEffect.Status.BURNING, AbilityEffect.Status.BLEEDING:
			effect.amount = 0.01
		AbilityEffect.Status.CHILLED, AbilityEffect.Status.MENDING:
			effect.amount = 0.01
		AbilityEffect.Status.HASTED, AbilityEffect.Status.WEAKENED:
			effect.amount = 0.7
		AbilityEffect.Status.NIMBLE:
			effect.amount = 1.0
		_:
			effect.amount = 1.3
	return effect


## Hands [param battle]'s events to the simulation, stamped from [member _base], and shows a frame.
func _deliver(battle: Battle) -> Array[SimEvent]:
	var events: Array[SimEvent] = battle.drain_events()
	for event: SimEvent in events:
		event.tick = _base + event.tick
	_sim._events.append_array(events)
	_frame()
	return events


## Hands [param events] (made here) to the simulation as they are, and shows a frame.
func _tell(events: Array[SimEvent]) -> void:
	_sim._events.append_array(events)
	_frame()


func _event(
	kind: SimEvent.Kind, source: int, target: int, amount: int = 0, ability: StringName = &""
) -> SimEvent:
	var event := SimEvent.new(kind, _sim.tick + _at, source, target, amount)
	event.ability_id = ability
	return event


## One frame of [param seconds] (the world, the effects and the HUD), the simulation left as it is.
func _frame(seconds: float = FRAME) -> void:
	_world.sync(seconds)
	_fx.advance(seconds)
	if _hud != null:
		_hud.advance(seconds)


func _wait(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_frame(minf(FRAME, left))
		left -= FRAME


## The damage numbers showing, oldest first.
func _numbers() -> Array[FxText]:
	var found: Array[FxText] = []
	for text: FxText in _fx._texts:
		if text.kind == &"damage" or text.kind == &"heal":
			found.append(text)
	return found


## Every hero at [constant TREE_LEVEL] with its class's trunk and path ([param paths], by class),
## full health.
func _full_trees(paths: Dictionary[StringName, int] = PATHS) -> void:
	for hero: Hero in _sim.party.heroes:
		hero.gain_xp(Hero.xp_for_level(TREE_LEVEL) - hero.xp)
		var tree: TalentTreeDef = Content.talent_tree(hero.class_id)
		var nodes: Array[StringName] = tree.trunk.duplicate()
		nodes.append_array(tree.path_nodes(paths[hero.class_id]))
		hero.set_talents(nodes)
		hero.health = hero.max_health()


func _fighting() -> bool:
	return _sim.expedition.state == Expedition.State.FIGHTING and _sim.expedition.battle != null


## Steps the simulation, a frame of [param ticks] ticks at a time, until a fight starts with at
## least [param monsters] monsters; others on the way are ended at once. The monsters of the fight
## found get [param tougher] times their health. True if one was found.
func _find_fight(monsters: int, ticks: int = 1, sync: bool = true, tougher: int = TOUGHER) -> bool:
	for i: int in LIMIT_TICKS:
		_sim.step()
		if sync and i % ticks == 0:
			_frame()
		if not _fighting():
			continue
		var battle: Battle = _sim.expedition.battle
		if battle.tick <= 1 and battle.monsters.size() >= monsters:
			for monster: Combatant in battle.monsters:
				monster.max_health *= tougher
				monster.health = monster.max_health
			return true
		for monster: Combatant in battle.monsters:
			monster.health = mini(monster.health, 1)
	return false


func _mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


func _click_at(at: Vector2) -> void:
	_mouse(at)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
	_mouse(Vector2(320, 200))


## One real frame of play at the world's speed: the simulation steps as many ticks as it owes.
func _play_frame() -> void:
	_owed += FRAME * maxi(_world.speed, 1)
	while _owed >= 1.0 / TPS:
		_owed -= 1.0 / TPS
		_sim.step()
	_frame()


## Every part of [param sprite]'s pose, to tell whether it moved.
func _pose_of(sprite: CharacterSprite) -> Array:
	var pose: Array = []
	for node: Node in sprite.find_children("*", "Node2D", true, false):
		var part: Node2D = node as Node2D
		pose.append([part.position, part.rotation, part.scale])
	return pose


## Hero [param id] is up: alive on screen, upright, neither lying nor rising.
func _assert_up(id: int, why: String) -> void:
	var sprite: CharacterSprite = _world.character(id)
	assert_false(sprite.is_dead(), "%s: on its feet" % why)
	assert_true(sprite.visible, "%s: seen" % why)
	assert_eq(sprite.rotation, 0.0, "%s: upright" % why)
	assert_false(_world.fallen_party.is_lying(id), "%s: not lying" % why)
	assert_false(_world.fallen_party.is_standing(id), "%s: risen" % why)


## Bulwark's shield effect.
func _bulwark_shield() -> AbilityEffect:
	return Content.ability(&"bulwark").effects[BULWARK_SHIELD]


## The share of its tint [param sprite] is drawn with, and its opacity, as the screen has them.
func _tint_of(sprite: CharacterSprite) -> float:
	var material: ShaderMaterial = sprite._flash
	return material.get_shader_parameter("tint_share")


func _opacity_of(sprite: CharacterSprite) -> float:
	return (sprite.get_node("Mirror") as Node2D).modulate.a


## The world point drawn at [param screen].
func _to_world(screen: Vector2) -> Vector2:
	var camera: WorldCamera = _world.camera
	var view: Vector2 = camera.get_viewport_rect().size
	return (screen - view / 2.0) / camera.zoom + camera.position + camera.offset


## [param rect] (world pixels) on the screen, through the world's camera.
func _on_screen(rect: Rect2) -> Rect2:
	var camera: WorldCamera = _world.camera
	var view: Vector2 = camera.get_viewport_rect().size
	var at: Vector2 = (rect.position - camera.position - camera.offset) * camera.zoom + view / 2.0
	return Rect2(at, rect.size * camera.zoom)
