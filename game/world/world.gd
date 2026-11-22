class_name World
extends Node2D
## The running simulation on screen: the labyrinth around the party, a sprite for every hero and
## for every monster waiting in a built level, fights acted out from the simulation's events, and
## the camera on the party.
##
## The world only reads the simulation. Each frame [method sync] drains its events, acts them out
## and emits each as [signal sim_event], then eases every sprite toward where the simulation says
## it is. Sprite animation and the camera are advanced from [method sync] too (their own
## [code]_process[/code] is turned off), so a test that calls [method sync] sees exactly what a
## frame would show.
##
## Children, in draw order: the labyrinth view, the ambience, QuestProps, Characters, Effects,
## and the camera; and FallenParty, which keeps the fallen on screen and tells a wipe,
## and ZoneCrossing, which dims the screen between places.
##
## The world shows one stage at a time, as its own place ([member LabyrinthView.zoned]).
## The party never climbs on screen: it walks into a doorway, the screen dims, the world changes
## to the stage it is going to while it is dark ([method ZoneCrossing.stage_shown]) and opens on
## the party stepping out of a doorway there. Nothing on screen moves up or down between stages.

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
## one pixel into it, while every position (and [method feet_position]) is the floor pixel itself.
const FEET_LIFT: Vector2 = Vector2(0, -1)
## The effects layer's absolute z: over the ambience's darkness and glow.
const EFFECTS_Z: int = 110
## How far above the feet the party's light sits, in pixels.
const PARTY_LIGHT_HEIGHT: float = 14.0

## Set before entering the tree.
var simulation: Simulation
## How many times real time the simulation runs, set by Main. Ticks come that many
## times faster, so the windows above (in ticks) widen by it, and sprites and bolts move by that
## many seconds of game time a second: the same game as at 1x, sooner.
var speed: int = 1

var labyrinth_view: LabyrinthView
var camera: WorldCamera
## World-space parent for effects, drawn above characters.
var effects_layer: Node2D
## Every passing effect on [member effects_layer], made and freed through it.
var fx: FxPool
## Which fighters are guardians, kept from the events.
var guardians: GuardianRecord = GuardianRecord.new()
## Light, darkness and decoration around the labyrinth view.
var ambience: Ambience
## The arrow over the party pointing toward its target depth.
var target_marker: TargetMarker
## The side quests waiting in chambers, and the work on one.
var quest_props: QuestProps
## The fallen heroes, and the story of a wipe.
var fallen_party: FallenParty
## The dimming and the title between places.
var crossing: ZoneCrossing

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
## The combatant each of those was. A chamber refilled often enough hands its ids out again, to
## new combatants: a monster is only kept hidden while it is the very one that died.
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
## True for the sync in progress when it catches up on a stall.
var _catching_up: bool = false
## Seconds left in which character animation stands still (a crit's hit-stop).
var _frozen: float = 0.0
## Heroes kept out of a fighting guardian's body.
var _spacing := GuardianSpacing.new()
## The heroes' moves, started and ended from the events.
var _fight_moves := FightMoves.new()
## True for the sync in progress when the camera is to jump to the party.
var _snap_camera: bool = false
## The stage shown, or 0 before the first.
var _shown: int = 0
## The ladders a hero may climb on the level shown, its side paths' among them; made once a level.
var _ladders: Array[Rect2i] = []
var _ladders_of: LabyrinthLevel


func _ready() -> void:
	# After the SimDriver (priority 0), so a frame shows the ticks it stepped.
	process_priority = 1
	labyrinth_view = LabyrinthView.new()
	labyrinth_view.name = "LabyrinthView"
	labyrinth_view.labyrinth = simulation.labyrinth
	labyrinth_view.zoned = true
	labyrinth_view.area = simulation.expedition.place
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
	fx = FxPool.new()
	fx.setup(effects_layer)
	guardians.note(simulation)
	target_marker = TargetMarker.new()
	target_marker.z_index = EFFECTS_Z
	target_marker.z_as_relative = false
	add_child(target_marker)
	camera = WorldCamera.new()
	camera.name = "WorldCamera"
	add_child(camera)
	camera.set_process(false)
	fallen_party = FallenParty.new()
	fallen_party.name = "FallenParty"
	add_child(fallen_party)
	fallen_party.setup(self)
	crossing = ZoneCrossing.new()
	crossing.name = "ZoneCrossing"
	add_child(crossing)
	sync(0.0)


func _process(delta: float) -> void:
	sync(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = KeyBook.fresh_key(event)
	if key == null or camera == null:
		return
	if key.keycode == KEY_Z:
		toggle_zoom()
		get_viewport().set_input_as_handled()


## Switches between the normal view and the close one, eased by the camera.
func toggle_zoom() -> void:
	camera.set_zoom_level(2 if camera.zoom_level() == 1 else 1)


## The sprite of a hero (ids 1-4) or monster (ids from 100), or null.
func character(id: int) -> CharacterSprite:
	return _sprites.get(id, null)


## Pixel position of that character's feet, or Vector2.ZERO if there is none. A hero lying on its
## back has its feet on the floor under it.
func feet_position(id: int) -> Vector2:
	var sprite: CharacterSprite = character(id)
	return fallen_party.feet_of(id, sprite.position) if sprite != null else Vector2.ZERO


## True when [param event] may start a move, an effect, a sound or a flash: it is recent and the
## world is not catching up. Every listener to [signal sim_event] asks this and nothing else.
func may_animate(event: SimEvent) -> bool:
	return is_recent(event) and not catching_up()


## False for an event so old (after a stall) that it should start no animation or effect.
func is_recent(event: SimEvent) -> bool:
	return simulation != null and simulation.tick - event.tick <= ANIMATE_TICKS * maxi(speed, 1)


## True during a sync that catches up on a stall (many ticks in one frame; not the world's first
## picture, which has nothing running to catch up on, nor a move to another stage or area, which
## clears its own): it starts nothing, only brings the picture up to date. What clears its running
## effects then reads it; what starts one asks [method may_animate].
func catching_up() -> bool:
	return _catching_up


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
	_catching_up = _last_tick >= 0 and now - _last_tick > STALL_TICKS * maxi(speed, 1)
	_snap_all = _last_tick < 0 or _catching_up
	_snap_heroes = false
	_snap_camera = false
	_last_tick = now
	if _snap_all:
		_fight_moves.stop_all(self)  # a stall leaves every body at rest

	# When the party has gone to another area, the events from before its arrival are shown in
	# the area it left first, and the world changes area when it reaches AREA_CHANGED (monster
	# ids do not name the area, so a death from before must not touch the new area's monsters).
	var arriving: bool = labyrinth_view.labyrinth != simulation.labyrinth
	if not arriving:
		_catch_up_with_state(delta)
	for event: SimEvent in simulation.drain_events():
		guardians.observe(event, simulation)
		_show(event, may_animate(event))
		crossing.heard(event)
		sim_event.emit(event)
	if labyrinth_view.labyrinth != simulation.labyrinth:
		_change_area()  # no AREA_CHANGED heard: a world made after the arrival
	if arriving:
		_catch_up_with_state(delta)
	var expedition: Expedition = simulation.expedition
	if expedition.state == Expedition.State.REVIVING and not fallen_party.is_telling():
		# Down with no wipe heard (the world made after time away): the story starts part way.
		var left: float = float(expedition.revive_tick - now) / Simulation.TICKS_PER_SECOND
		fallen_party.wiped(Expedition.REVIVE_SECONDS - left)
	crossing.update(simulation)
	if _scan_due:
		_scan_waiting()

	_settle_heroes()
	_remove_unwanted()
	var game_delta: float = delta * maxi(speed, 1)
	_follow(game_delta)
	_act()
	quest_props.animate(delta)
	if _frozen > 0.0:
		_frozen -= delta
		for id: int in _sprites:
			# A hit-stop holds the pose, not a move's blow; a move that ends in it lets go at once.
			var sprite: CharacterSprite = _sprites[id]
			var playing: int = sprite.moves.names().size()
			sprite.moves.advance(delta)
			if sprite.moves.names().size() < playing:
				sprite.advance(0.0)
	else:
		for id: int in _sprites:
			if not fallen_party.animate(id, _sprites[id], delta):
				_sprites[id].advance(delta)
	_show_heroes()
	_remove_finished()
	_fly_bolts(game_delta)
	_place_party_light()
	target_marker.follow(simulation, _party_feet(true), delta)
	_aim_camera(delta)


## Brings the view up to the simulation's state before its events are shown: the levels built
## around the party, the heroes, the waiting monsters and the fighters.
func _catch_up_with_state(delta: float) -> void:
	var stage: int = ZoneCrossing.stage_shown(simulation, _shown)
	if stage != _shown:
		if _shown > 0:
			_change_stage()
		_shown = stage
		camera.rows = WorldCamera.rows_of(simulation.labyrinth, stage)
	var focus: Vector2 = fallen_party.focus(simulation.expedition.hero_position(_leader_id()))
	labyrinth_view.set_focus(Vector2(focus.x, simulation.labyrinth.level(_shown).floor_y))
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


# --- Characters ----------------------------------------------------------------


## Centres the party's light on the heroes that are showing.
func _place_party_light() -> void:
	var feet: Vector2 = _party_feet()
	if feet.is_finite():
		ambience.party_light_position = feet - Vector2(0, PARTY_LIGHT_HEIGHT)


## The middle of the heroes that are showing, at their feet (with [param highest], at the feet of
## the highest of them, which differ on a ladder); not finite when none is showing.
func _party_feet(highest: bool = false) -> Vector2:
	var low: float = INF
	var high: float = -INF
	var feet_y: float = 0.0
	var top: float = INF
	for hero: Hero in simulation.party.heroes:
		var sprite: CharacterSprite = character(hero.id)
		if sprite == null or not sprite.visible:
			continue
		low = minf(low, sprite.position.x)
		high = maxf(high, sprite.position.x)
		feet_y = sprite.position.y
		top = minf(top, feet_y)
	if low > high:
		return Vector2(INF, INF)
	return Vector2((low + high) / 2.0, top if highest else feet_y)


func _leader_id() -> int:
	var heroes: Array[Hero] = simulation.party.heroes
	return heroes[0].id if not heroes.is_empty() else 1


## Where hero [param hero_id] stands, as the simulation has it; while the party changes stage, at
## the doorway it leaves by or arrives by on the stage shown, never on the way up or down.
func _hero_feet(hero_id: int) -> Vector2:
	var e: Expedition = simulation.expedition
	if _shown > 0 and e.state == Expedition.State.CLIMBING:
		return _door_feet()
	if _shown > 0 and e.state == Expedition.State.JOURNEYING and not StageCrossing.by_door(e):
		# A journey that began in a shaft: the heroes stand on the shown floor.
		var column: float = e.hero_position(hero_id).x
		return WorldPlaces.feet(Vector2(column, simulation.labyrinth.level(_shown).floor_y))
	if _shown > 0 and e.state == Expedition.State.JOURNEYING and _shown != e.depth:
		# A journey begun while arriving by a doorway: the simulation still has the party on
		# the stage it left, and the heroes wait at the doorway shown until the area changes.
		return _goals.get(hero_id, WorldPlaces.feet(e.hero_position(hero_id)))
	return WorldPlaces.feet(e.hero_position(hero_id))


## Where the party's anchor is on the stage shown: while it changes stage, the middle of the
## doorway it goes into, then of the one it comes out of.
func _door_feet() -> Vector2:
	var e: Expedition = simulation.expedition
	var at: Vector2 = PartyPlaces.anchor(e)
	if _shown > 0 and e.state == Expedition.State.CLIMBING and not StageCrossing.by_door(e):
		# A shaft joins the two floors in one column, and the climb in it is never shown.
		at.y = simulation.labyrinth.level(_shown).floor_y
	return WorldPlaces.feet(at)


## The stage the world shows: the party's, or the one it is crossing to once the
## screen is dark.
func shown_stage() -> int:
	return _shown


## Heroes go into the doorway and out of it on a change of stage.
func _show_heroes() -> void:
	var door: Vector2 = _door_feet()
	for hero: Hero in simulation.party.heroes:
		var sprite: CharacterSprite = character(hero.id)
		if sprite != null:
			var gap: float = sprite.position.distance_to(door)
			sprite.modulate.a = ZoneCrossing.hero_shown(simulation, gap)


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
		sprite.set_facing(PartyPlaces.world_facing(simulation.expedition))


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
		for chamber_index: int in level.chambers.size():
			if not expedition.is_populated(depth, chamber_index):
				continue
			var floor_pixels: float = WorldPlaces.floor_line(level.chambers[chamber_index])
			for monster: Combatant in expedition.monsters_in(depth, chamber_index):
				_waiting[monster.id] = true
				_add_monster(monster, floor_pixels)
	quest_props.scan(_built)


## Gives a sprite to every living monster in the fight that has none (after a stall, say).
func _ensure_fighters() -> void:
	var battle: Battle = simulation.expedition.battle
	if battle == null:
		return
	var floor_pixels: float = WorldPlaces.fight_line(simulation.expedition)
	for monster: Combatant in battle.monsters:
		if monster.is_alive():
			_add_monster(monster, floor_pixels)


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
		if sprite == null or fallen_party.is_standing(hero.id):
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
				var left: float = maxf(windup - age, 0.0) / maxi(speed, 1)  # in real seconds
				attacker.play_attack(left, reach > Battle.MELEE_REACH)
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
			fallen_party.fell(event.source_id)  # one rising after a revive lies again
			_died(event.source_id, animate)
		SimEvent.Kind.ENCOUNTER_STARTED:
			_scan_due = true
		SimEvent.Kind.AREA_CHANGED:
			if labyrinth_view.labyrinth != simulation.labyrinth:
				_change_area()
		SimEvent.Kind.SIDE_QUEST_DONE, SimEvent.Kind.SIDE_QUEST_MISSED:
			_scan_due = true  # a cleared quest's prop goes at once
		SimEvent.Kind.ENCOUNTER_ENDED:
			_cut_short_everything()
			_scan_due = true
		SimEvent.Kind.PARTY_WIPED:
			fallen_party.wiped(age)
		SimEvent.Kind.REVIVED:
			fallen_party.stand(event.target_id)  # a fallen hero stands up in the fight
		SimEvent.Kind.PARTY_REVIVED:
			# A revival seen as it happens is acted out whole; one heard late, from where it has got to.
			_snap_camera = not fallen_party.revived(0.0 if animate else age)
			_snap_heroes = true
	_fight_moves.heard(self, event, animate)


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


## The party arrived in another area: the world shows that area's labyrinth from now
## on, with none of the last one's monsters, props or bolts, and every sprite and the camera
## jump to their places.
func _change_area() -> void:
	_cut_short_everything()
	for id: int in _monsters.keys():
		_remove(id)
	_gone.clear()
	_gone_as.clear()
	_waiting.clear()
	quest_props.clear()
	labyrinth_view.show_labyrinth(simulation.labyrinth)
	labyrinth_view.area = simulation.expedition.place
	_shown = 0  # the next catch-up shows the stage it arrived on
	_built = []
	_scan_due = true
	_snap_all = true


## The world shows another stage: none of the last one's monsters or bolts are left,
## and every sprite and the camera jump to their places on the new one, out of sight in the dark.
func _change_stage() -> void:
	_cut_short_everything()
	for id: int in _monsters.keys():
		_remove(id)
	_waiting.clear()
	_scan_due = true
	_snap_all = true


## The fight is over: wind-ups and moves still pending stop, and bolts in flight vanish.
func _cut_short_everything() -> void:
	_fight_moves.stop_all(self)
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
	var level: LabyrinthLevel = simulation.labyrinth.level(maxi(_shown, 1))
	if level != _ladders_of:
		_ladders_of = level
		_ladders = level.ladders + level.side_ladders()
	var ladders: Array[Rect2i] = _ladders
	for id: int in _sprites:
		var goal: Vector2
		if _monsters.has(id):
			goal = Vector2(_monsters[id].x * TILE, _floors[id])
		else:
			goal = fallen_party.goal_for(id, quest_props.goal_for(id, _hero_feet(id)))
		_goals[id] = goal
	_spacing.space(self, _goals)
	for id: int in _sprites:
		var goal: Vector2 = _goals[id]
		var sprite: CharacterSprite = _sprites[id]
		if _snap_all or (_snap_heroes and not _monsters.has(id)):
			sprite.position = goal
		elif not ladders.is_empty() and _walks_the_stage(id):
			sprite.position = LadderRoute.eased(ladders, sprite.position, goal, delta)
		else:
			sprite.position = _eased(sprite.position, goal, delta, climbing)
	_spacing.hold_back(self)


## True for a hero on its feet: one that goes from floor to floor by the stage's ladders. A
## monster keeps to its room's floor, and a fallen or rising hero is lifted where it lies.
func _walks_the_stage(id: int) -> bool:
	return not (_monsters.has(id) or fallen_party.is_lying(id) or fallen_party.is_standing(id))


## One frame's move of a sprite on a stage with no ladders of its own: [method LadderRoute.step].
static func _eased(from: Vector2, goal: Vector2, delta: float, climbing: bool) -> Vector2:
	return LadderRoute.step(from, goal, delta, climbing)


## Walking or standing, and facing, for every character, from the simulation's state.
func _act() -> void:
	var expedition: Expedition = simulation.expedition
	var fighting: bool = expedition.state == Expedition.State.FIGHTING and expedition.battle != null
	var ahead: int = PartyPlaces.world_facing(expedition)
	var party_at: float = PartyPlaces.anchor(expedition).x * TILE
	for id: int in _sprites:
		var sprite: CharacterSprite = _sprites[id]
		if sprite.is_dead():
			continue
		var gap: Vector2 = _goals[id] - sprite.position
		var moving: bool = gap.length() > MOVING_GAP
		var facing: int = ahead
		var walking: bool = moving
		if fighting and expedition.battle.combatant(id) != null:
			var fighter: Combatant = expedition.battle.combatant(id)
			walking = moving or fighter.state == Combatant.State.MOVING
			facing = _toward(sprite, fighter.target_id, facing)
		elif _monsters.has(id):
			# Waiting: facing the side the party is on.
			facing = 1 if party_at >= sprite.position.x else -1
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


## Where the camera aims to show a party whose front hero's feet are at [param feet], facing
## [param facing] in the world (1 right, -1 left): ahead of it and above it.
func camera_target(feet: Vector2, facing: int) -> Vector2:
	# The look-ahead is a share of the view, so the closer view stays centred on the party.
	var look := Vector2(facing * LOOK_AHEAD, -LOOK_ABOVE) / camera.zoom.x
	return feet + look.round()


func _aim_camera(delta: float) -> void:
	var leader: CharacterSprite = character(_leader_id())
	var at: Vector2 = leader.position if leader != null else _hero_feet(_leader_id())
	camera.target = camera_target(at, PartyPlaces.world_facing(simulation.expedition))
	if fallen_party.aims_camera(camera, delta, _snap_all):
		return
	if _snap_all or _snap_camera:
		camera.snap_to(camera.target)
	else:
		camera._process(delta)
