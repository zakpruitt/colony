class_name World
extends Node2D
## The running simulation on screen: the labyrinth around the party, a sprite for every hero and
## for every monster waiting in a built level, fights acted out from the simulation's events, and
## the camera on the party (spec 008).
##
## The world only reads the simulation. Each frame [method sync] drains its events, acts them out
## and emits each as [signal sim_event], then eases every sprite toward where the simulation says
## it is. Sprite animation and the camera are advanced from [method sync] too (their own
## [code]_process[/code] is turned off), so a test that calls [method sync] sees exactly what a
## frame would show.
##
## Children, in draw order: the labyrinth view, the ambience, QuestProps, Characters, Effects,
## and the camera.

## Every simulation event, once, in order, in the frame it happened.
signal sim_event(event: SimEvent)

const TILE: float = LabyrinthView.TILE
## How high above its feet a character is aimed at, in pixels: bolts fly at this height.
const AIM_HEIGHT: float = 12.0
## Events at most this many ticks old (half a second) start animations; older events, seen after a
## stall, only bring the picture up to date.
const ANIMATE_TICKS: int = Simulation.TICKS_PER_SECOND / 2
## More ticks than this between two syncs is a stall: every sprite jumps to its place.
const STALL_TICKS: int = ANIMATE_TICKS
## The party's walking speed, in pixels per second.
const WALK_SPEED: float = Expedition.PARTY_SPEED * TILE
## The fastest a sprite runs to a new place (lining up, regrouping, onto the ladder).
const RUN_SPEED: float = 3.0 * WALK_SPEED
## How fast a sprite closes on its simulation position: each second it covers all but e^-rate of
## the gap, so in steady walking it trails by about WALK_SPEED / FOLLOW_RATE pixels and moves on
## every frame. Capped at RUN_SPEED.
const FOLLOW_RATE: float = 8.0
## Closer than this many pixels, a sprite settles exactly on its place.
const SETTLE: float = 0.1
## Further than this many pixels from its place, a sprite walks to it.
const MOVING_GAP: float = 2.0
## Seconds between checks for chambers that have refilled.
const SCAN_SECONDS: float = 0.25
## How far ahead of the party the camera looks, and how far above its feet, in pixels.
const LOOK_AHEAD: float = 3.0 * TILE
const LOOK_ABOVE: float = 3.0 * TILE
## A sprite's pivot pixel is the bottom row of its feet, drawn just below the node's position.
## The characters are lifted by that one row, so feet stand on the floor line instead of sinking
## one pixel into it, while every position (and [method feet_position]) keeps the spec's pixel.
const FEET_LIFT: Vector2 = Vector2(0, -1)
## The effects layer's absolute z: over the ambience's darkness and glow.
const EFFECTS_Z: int = 110
## How far above the feet the party's light sits, in pixels.
const PARTY_LIGHT_HEIGHT: float = 14.0

## Set before entering the tree.
var simulation: Simulation

var labyrinth_view: LabyrinthView
var camera: WorldCamera
## World-space parent for effects, drawn above characters.
var effects_layer: Node2D
## Light, darkness and decoration around the labyrinth view.
var ambience: Ambience
## The arrow over the party pointing toward its target depth (spec 027 R5).
var target_marker: TargetMarker
## The side quests waiting in chambers, and the work on one (spec 028).
var quest_props: QuestProps

var _characters: Node2D
var _sprites: Dictionary[int, CharacterSprite] = {}
## Where each sprite is heading this frame, in world pixels.
var _goals: Dictionary[int, Vector2] = {}
## Each character's attack range in tiles, to tell a ranged attack from a melee one.
var _ranges: Dictionary[int, float] = {}
## Each monster's combatant (the simulation's own, never changed here) and its feet's pixel row.
var _monsters: Dictionary[int, Combatant] = {}
var _floors: Dictionary[int, float] = {}
## Monsters waiting in built levels at the last scan.
var _waiting: Dictionary[int, bool] = {}
## Monsters that have died, with the depth they died on: never shown again. Forgotten when that
## level is freed, as its dead are never asked about again.
var _gone: Dictionary[int, int] = {}
## The combatant each of those was. A chamber refilled often enough hands its ids out again (spec
## 023), to new combatants: a monster is only kept hidden while it is the very one that died.
var _gone_as: Dictionary[int, Combatant] = {}
## Attacks winding up: attacker id to Vector2i(target id, the tick it strikes on).
var _windups: Dictionary[int, Vector2i] = {}
var _bolts: Array[Bolt] = []
var _new_bolts: Array[Bolt] = []
var _built: Array[int] = []
var _scan_due: bool = true
var _scan_in: float = 0.0
## The simulation tick at the last sync, or -1 before the first.
var _last_tick: int = -1
## True for the sync in progress when it is to put every sprite (or only the heroes) in place.
var _snap_all: bool = false
var _snap_heroes: bool = false
## Seconds left in which character animation stands still (a crit's hit-stop, spec 010).
var _frozen: float = 0.0


func _ready() -> void:
	# After the SimDriver (priority 0), so a frame shows the ticks it stepped.
	process_priority = 1
	labyrinth_view = LabyrinthView.new()
	labyrinth_view.name = "LabyrinthView"
	labyrinth_view.labyrinth = simulation.labyrinth
	add_child(labyrinth_view)
	# After the view and before the characters, so props draw behind the heroes.
	ambience = Ambience.new()
	ambience.name = "Ambience"
	ambience.process_priority = 2  # after this node has placed the party's light
	add_child(ambience)
	ambience.setup(labyrinth_view)
	# Props stand on the floor behind the characters.
	quest_props = QuestProps.new()
	quest_props.name = "QuestProps"
	add_child(quest_props)
	quest_props.setup(self, simulation)
	_characters = Node2D.new()
	_characters.name = "Characters"
	_characters.position = FEET_LIFT
	add_child(_characters)
	effects_layer = Node2D.new()
	effects_layer.name = "Effects"
	# Above the darkness and glow, so bolts, numbers and sparks keep their true colours.
	effects_layer.z_index = EFFECTS_Z
	effects_layer.z_as_relative = false
	add_child(effects_layer)
	target_marker = TargetMarker.new()
	target_marker.z_index = EFFECTS_Z
	target_marker.z_as_relative = false
	add_child(target_marker)
	camera = WorldCamera.new()
	camera.name = "WorldCamera"
	add_child(camera)
	camera.set_process(false)
	sync(0.0)


func _process(delta: float) -> void:
	sync(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or camera == null:
		return
	if key.keycode == KEY_Z:
		toggle_zoom()
		get_viewport().set_input_as_handled()


## Switches between the normal view and the close one (spec 018 R1), eased by the camera.
func toggle_zoom() -> void:
	camera.set_zoom_level(2 if camera.zoom_level() == 1 else 1)


## The sprite of a hero (ids 1-4) or monster (ids from 100), or null.
func character(id: int) -> CharacterSprite:
	return _sprites.get(id, null)


## Pixel position of that character's feet, or Vector2.ZERO if there is none.
func feet_position(id: int) -> Vector2:
	var sprite: CharacterSprite = character(id)
	return sprite.position if sprite != null else Vector2.ZERO


## False for an event so old (after a stall) that it should start no animation or effect. Listeners
## to [signal sim_event] use this rather than working it out again.
func is_recent(event: SimEvent) -> bool:
	return simulation != null and simulation.tick - event.tick <= ANIMATE_TICKS


## Holds every character's animation still for [param seconds] (a hit-stop): [method sync] goes on
## following the simulation, but does not advance the sprites' animation until it is over. A
## shorter freeze does not cut a longer one short.
func freeze(seconds: float) -> void:
	_frozen = maxf(_frozen, seconds)


## Brings the picture up to date with the simulation. Called every frame after the driver; tests
## call it.
func sync(delta: float) -> void:
	if simulation == null or labyrinth_view == null:
		return
	var now: int = simulation.tick
	_snap_all = _last_tick < 0 or now - _last_tick > STALL_TICKS
	_snap_heroes = false
	_last_tick = now

	labyrinth_view.set_focus(simulation.expedition.hero_position(_leader_id()))
	var built: Array[int] = labyrinth_view.built_depths()
	if built != _built:
		_built = built
		for dead: int in _gone.keys():
			if not _built.has(_gone[dead]):
				_gone.erase(dead)
				_gone_as.erase(dead)
		_scan_due = true
	_scan_in -= delta
	_ensure_heroes()
	if _scan_due or _snap_all or _scan_in <= 0.0:
		_scan_waiting()
	_ensure_fighters()

	for event: SimEvent in simulation.drain_events():
		_show(event, is_recent(event))
		sim_event.emit(event)
	if _scan_due:
		_scan_waiting()

	_settle_heroes()
	_remove_unwanted()
	_follow(delta)
	_act()
	quest_props.animate(delta)
	if _frozen > 0.0:
		_frozen -= delta
	else:
		for sprite: CharacterSprite in _sprites.values():
			sprite.advance(delta)
	_remove_finished()
	_fly_bolts(delta)
	_place_party_light()
	target_marker.follow(simulation, _party_feet(), delta)
	_aim_camera(delta)


# --- Characters ----------------------------------------------------------------


## Centres the party's light on the heroes that are showing.
func _place_party_light() -> void:
	var feet: Vector2 = _party_feet()
	if feet.is_finite():
		ambience.party_light_position = feet - Vector2(0, PARTY_LIGHT_HEIGHT)


## The middle of the heroes that are showing, at their feet; not finite when none is showing.
func _party_feet() -> Vector2:
	var low: float = INF
	var high: float = -INF
	var feet_y: float = 0.0
	for hero: Hero in simulation.party.heroes:
		var sprite: CharacterSprite = character(hero.id)
		if sprite == null or not sprite.visible:
			continue
		low = minf(low, sprite.position.x)
		high = maxf(high, sprite.position.x)
		feet_y = sprite.position.y
	if low > high:
		return Vector2(INF, INF)
	return Vector2((low + high) / 2.0, feet_y)


func _leader_id() -> int:
	var heroes: Array[Hero] = simulation.party.heroes
	return heroes[0].id if not heroes.is_empty() else 1


func _hero_feet(hero_id: int) -> Vector2:
	return _feet(simulation.expedition.hero_position(hero_id))


## The feet pixel of a simulation position: the bottom of the row it stands in.
static func _feet(tiles: Vector2) -> Vector2:
	return Vector2(tiles.x * TILE, (tiles.y + 1.0) * TILE)


func _add_sprite(id: int, sprite: CharacterSprite, at: Vector2) -> void:
	_characters.add_child(sprite)
	sprite.set_process(false)
	sprite.position = at
	_sprites[id] = sprite
	_goals[id] = at


func _ensure_heroes() -> void:
	# The front of the formation is drawn last, on top of the heroes behind it.
	var heroes: Array[Hero] = simulation.party.heroes.duplicate()
	heroes.reverse()
	for hero: Hero in heroes:
		if _sprites.has(hero.id):
			continue
		var sprite: CharacterSprite = CharacterSprite.for_hero(hero.class_id)
		if sprite == null:
			continue
		_ranges[hero.id] = hero.def().attack_range
		_add_sprite(hero.id, sprite, _hero_feet(hero.id))
		sprite.set_facing(simulation.expedition.facing)


func _add_monster(monster: Combatant, floor_pixels: float) -> void:
	if _gone.has(monster.id) and _gone_as.get(monster.id, null) != monster:
		_gone.erase(monster.id)  # its id handed out again, to a new monster
		_gone_as.erase(monster.id)
	if _sprites.has(monster.id) or _gone.has(monster.id):
		return
	var sprite: CharacterSprite = CharacterSprite.for_monster(monster.def_id)
	if sprite == null:
		return
	_monsters[monster.id] = monster
	_floors[monster.id] = floor_pixels
	_ranges[monster.id] = monster.attack_range
	_add_sprite(monster.id, sprite, Vector2(monster.x * TILE, floor_pixels))


## Finds the monsters waiting in every built level and gives each new one a sprite.
func _scan_waiting() -> void:
	_scan_due = false
	_scan_in = SCAN_SECONDS
	_waiting.clear()
	var expedition: Expedition = simulation.expedition
	for depth: int in _built:
		var level: LabyrinthLevel = simulation.labyrinth.level(depth)
		var floor_pixels: float = (level.floor_y + 1) * TILE
		for chamber_index: int in level.chambers.size():
			if not expedition.is_populated(depth, chamber_index):
				continue
			for monster: Combatant in expedition.monsters_in(depth, chamber_index):
				_waiting[monster.id] = true
				_add_monster(monster, floor_pixels)
	quest_props.scan(_built)


## Gives a sprite to every living monster in the fight that has none (after a stall, say).
func _ensure_fighters() -> void:
	var battle: Battle = simulation.expedition.battle
	if battle == null:
		return
	var level: LabyrinthLevel = simulation.labyrinth.level(simulation.expedition.depth)
	for monster: Combatant in battle.monsters:
		if monster.is_alive():
			_add_monster(monster, (level.floor_y + 1) * TILE)


func _in_fight(id: int) -> bool:
	var battle: Battle = simulation.expedition.battle
	if battle == null:
		return false
	var fighter: Combatant = battle.combatant(id)
	return fighter != null and fighter.is_alive()


## Heroes go down when the simulation has them down, even with no event to say so (a wipe outside
## a fight), and stand again when they are alive (the revival, or a rest that heals the fallen).
func _settle_heroes() -> void:
	var expedition: Expedition = simulation.expedition
	for hero: Hero in simulation.party.heroes:
		var sprite: CharacterSprite = character(hero.id)
		if sprite == null:
			continue
		var alive: bool = hero.is_alive()
		if expedition.state == Expedition.State.FIGHTING and expedition.battle != null:
			alive = _in_fight(hero.id)
		elif expedition.state == Expedition.State.REVIVING:
			alive = false
		if not alive and not sprite.is_dead():
			_kill(sprite, not _snap_all)
		elif alive and sprite.is_dead() and not sprite.visible:
			sprite.revive()


func _kill(sprite: CharacterSprite, animate: bool) -> void:
	sprite.play_death()
	if not animate:
		# Play the whole collapse at once: hidden now, with nothing left to show.
		sprite.advance(CharacterSprite.DEATH_TIME)


func _remove(id: int) -> void:
	var sprite: CharacterSprite = _sprites[id]
	_sprites.erase(id)
	_goals.erase(id)
	_ranges.erase(id)
	_monsters.erase(id)
	_floors.erase(id)
	_windups.erase(id)
	_characters.remove_child(sprite)
	sprite.free()


## Monsters that are neither waiting in a built level nor fighting go, unless they are dying.
func _remove_unwanted() -> void:
	for id: int in _monsters.keys():
		if _sprites[id].is_dead() or _waiting.has(id) or _in_fight(id):
			continue
		_remove(id)


## Monsters whose death has played out go.
func _remove_finished() -> void:
	for id: int in _monsters.keys():
		if _sprites[id].is_dead() and not _sprites[id].visible:
			_remove(id)


# --- Events --------------------------------------------------------------------


## Acts out one event. Older events ([param animate] false) only change what is shown.
func _show(event: SimEvent, animate: bool) -> void:
	var age: float = float(simulation.tick - event.tick) / Simulation.TICKS_PER_SECOND
	match event.kind:
		SimEvent.Kind.ATTACK_STARTED:
			_windups[event.source_id] = Vector2i(event.target_id, event.tick + event.amount)
			var attacker: CharacterSprite = character(event.source_id)
			if animate and attacker != null:
				var windup: float = float(event.amount) / Simulation.TICKS_PER_SECOND
				var reach: float = _ranges.get(event.source_id, 0.0)
				attacker.play_attack(maxf(windup - age, 0.0), reach > Battle.MELEE_REACH)
		SimEvent.Kind.PROJECTILE_LAUNCHED:
			_struck(event.source_id, event.tick)
			if animate:
				_launch(event, age)
		SimEvent.Kind.HIT:
			_struck(event.source_id, event.tick)
			var target: CharacterSprite = character(event.target_id)
			if animate and target != null:
				target.play_hit()
		SimEvent.Kind.DIED:
			_died(event.source_id, animate)
		SimEvent.Kind.ENCOUNTER_STARTED:
			_scan_due = true
		SimEvent.Kind.SIDE_QUEST_DONE, SimEvent.Kind.SIDE_QUEST_MISSED:
			_scan_due = true  # a cleared quest's prop goes at once
		SimEvent.Kind.ENCOUNTER_ENDED:
			_cut_short_everything()
			_scan_due = true
		SimEvent.Kind.PARTY_REVIVED:
			for hero: Hero in simulation.party.heroes:
				var sprite: CharacterSprite = character(hero.id)
				if sprite != null:
					sprite.revive()
			_snap_heroes = true


## A wind-up of [param attacker] that struck by [param tick] is over.
func _struck(attacker: int, tick: int) -> void:
	if _windups.has(attacker) and _windups[attacker].y <= tick:
		_windups.erase(attacker)


func _died(id: int, animate: bool) -> void:
	_windups.erase(id)
	for attacker: int in _windups.keys():
		var windup: Vector2i = _windups[attacker]
		if windup.x != id:
			continue
		# The killing blow's wind-up was already ended by its HIT, so every wind-up still aimed here
		# is one the simulation cancelled, even one due on this very tick.
		var attacking: CharacterSprite = character(attacker)
		if attacking != null:
			attacking.cancel_attack()
		_windups.erase(attacker)
	if id >= Expedition.FIRST_MONSTER_ID:
		_gone[id] = simulation.expedition.depth
		var battle: Battle = simulation.expedition.battle
		var fallen: Combatant = battle.combatant(id) if battle != null else null
		_gone_as[id] = fallen if fallen != null else _monsters.get(id, null)
	var dying: CharacterSprite = character(id)
	if dying == null or dying.is_dead():
		return
	if animate:
		dying.play_death()
	elif id >= Expedition.FIRST_MONSTER_ID:
		_remove(id)
	else:
		_kill(dying, false)


## The fight is over: wind-ups still pending stop, and bolts in flight vanish.
func _cut_short_everything() -> void:
	for attacker: int in _windups:
		var sprite: CharacterSprite = character(attacker)
		if sprite != null:
			sprite.cancel_attack()
	_windups.clear()
	for bolt: Bolt in _bolts:
		effects_layer.remove_child(bolt)
		bolt.free()
	_bolts.clear()
	_new_bolts.clear()


func _launch(event: SimEvent, age: float) -> void:
	var source: CharacterSprite = character(event.source_id)
	var target: CharacterSprite = character(event.target_id)
	var flight: float = float(event.amount) / Simulation.TICKS_PER_SECOND
	if source == null or target == null or age >= flight:
		return
	var aim := Vector2(0, -AIM_HEIGHT)
	var bolt: Bolt = Bolt.launch(
		source.position + aim, target.position + aim, flight, age, event.flag, event.target_id
	)
	effects_layer.add_child(bolt)
	_bolts.append(bolt)
	_new_bolts.append(bolt)


func _fly_bolts(delta: float) -> void:
	for bolt: Bolt in _bolts.duplicate():
		if bolt.arrived():
			_bolts.erase(bolt)
			effects_layer.remove_child(bolt)
			bolt.free()
			continue
		var target: CharacterSprite = character(bolt.target_id)
		if target != null:
			bolt.to = target.position + Vector2(0, -AIM_HEIGHT)
		bolt.advance(0.0 if _new_bolts.has(bolt) else delta)
	_new_bolts.clear()


# --- Movement and poses --------------------------------------------------------


func _follow(delta: float) -> void:
	var climbing: bool = simulation.expedition.state == Expedition.State.CLIMBING
	for id: int in _sprites:
		var goal: Vector2
		if _monsters.has(id):
			goal = Vector2(_monsters[id].x * TILE, _floors[id])
		else:
			goal = quest_props.goal_for(id, _hero_feet(id))
		_goals[id] = goal
		var sprite: CharacterSprite = _sprites[id]
		if _snap_all or (_snap_heroes and not _monsters.has(id)):
			sprite.position = goal
		else:
			sprite.position = _eased(sprite.position, goal, delta, climbing)


## One frame's move from [param from] toward [param goal]: a share of the gap, at most RUN_SPEED.
## Off the floor and across, it goes one way at a time: across first while the party is
## climbing (to the ladder, then down it), down or up first otherwise (off the ladder, then across).
static func _eased(from: Vector2, goal: Vector2, delta: float, climbing: bool) -> Vector2:
	var aim: Vector2 = goal
	if absf(goal.x - from.x) > SETTLE and absf(goal.y - from.y) > SETTLE:
		aim = Vector2(goal.x, from.y) if climbing else Vector2(from.x, goal.y)
	var gap: Vector2 = aim - from
	var distance: float = gap.length()
	var step: float = minf(distance * (1.0 - exp(-FOLLOW_RATE * delta)), RUN_SPEED * delta)
	if distance - step <= SETTLE and aim == goal:
		return goal
	if distance <= 0.0:
		return from
	return from + gap * (step / distance)


## Walking or standing, and facing, for every character, from the simulation's state.
func _act() -> void:
	var expedition: Expedition = simulation.expedition
	var fighting: bool = expedition.state == Expedition.State.FIGHTING and expedition.battle != null
	for id: int in _sprites:
		var sprite: CharacterSprite = _sprites[id]
		if sprite.is_dead():
			continue
		var gap: Vector2 = _goals[id] - sprite.position
		var moving: bool = gap.length() > MOVING_GAP
		var facing: int = expedition.facing
		var walking: bool = moving
		if fighting and expedition.battle.combatant(id) != null:
			var fighter: Combatant = expedition.battle.combatant(id)
			walking = moving or fighter.state == Combatant.State.MOVING
			facing = _toward(sprite, fighter.target_id, facing)
		elif _monsters.has(id):
			# Waiting: facing the side the party is on.
			facing = 1 if expedition.x * TILE >= sprite.position.x else -1
		else:
			match expedition.state:
				Expedition.State.TRAVELLING, Expedition.State.CLIMBING:
					walking = true
				Expedition.State.REVIVING:
					walking = false
			if absf(gap.x) > MOVING_GAP:
				facing = 1 if gap.x > 0.0 else -1
		sprite.set_facing(facing)
		if walking:
			sprite.play_walk()
		else:
			sprite.play_idle()


## 1 or -1 toward the sprite of [param target_id], or [param otherwise] if there is none.
func _toward(sprite: CharacterSprite, target_id: int, otherwise: int) -> int:
	var target: CharacterSprite = character(target_id)
	if target == null or target == sprite or is_equal_approx(target.position.x, sprite.position.x):
		return otherwise
	return 1 if target.position.x > sprite.position.x else -1


func _aim_camera(delta: float) -> void:
	var leader: CharacterSprite = character(_leader_id())
	var at: Vector2 = leader.position if leader != null else _hero_feet(_leader_id())
	# The look-ahead is a share of the view, so the closer view stays centred on the party.
	var look := Vector2(simulation.expedition.facing * LOOK_AHEAD, -LOOK_ABOVE) / camera.zoom.x
	camera.target = at + look.round()
	if _snap_all or _snap_heroes:
		camera.snap_to(camera.target)
	else:
		camera._process(delta)
