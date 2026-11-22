class_name Showcase
extends Node
## A development scene that plays the loop's moments on demand, one after another, each labelled
## on screen: travel, a crit, a kill, a heal, a level up, a rest, going on a stage and back (the
## crossing), a wipe and the revival, a stage becoming stable, a fight in each other area, a
## guardian's fight, each class's hero using its actions, every status on a row of fighters (each
## labelled with its statuses), side quests (one done, one nobody can do, a tripwire sprung and a
## microskill learned), a dark room lighting as the party walks in, a side path (its gate being
## opened, its cache opening, and a gate nobody can open), the shop, the area map with two areas
## open and the rest closed, a journey
## to the Claypits and the arrival there (with the map open on the way), the four areas' looks in
## turn, the knight's talent tree (a node taken and a path chosen) and the report after time away.
##
## It runs a real [Main] (with no save store) and steers its simulation only through the
## simulation's own classes: hero health, level and XP, a combatant's crit chance, the expedition's
## target depth, stable time and place, and [method Arrival.from_save] to cut to another depth.
## The pictures are the game's own. Everything moves in [method advance], so a test can drive a
## pass.
##
## Run it with [code]godot --path . res://game/dev/showcase.tscn[/code].

## Emitted when a moment starts.
signal moment_started(moment: StringName)
## Emitted once, when the last moment is over.
signal finished

## The moments, in order, one row each: its name, what the label says, the seconds it goes on
## showing once seen, how it begins (&"x" calls [ShowcaseMoments]' _begin_x with its name; &""
## for nothing), and how it is known to have been seen: an event of that kind, or &"x", which
## calls _watch_x there.
const ROWS: Array[Array] = [
	[&"travelling", "TRAVELLING IN A TUNNEL", 1.0, &"", &"travelling"],
	[&"crit", "A FIGHT WITH A CRIT", 1.2, &"", &"crit"],
	[&"monster_death", "A MONSTER DIES: COINS AND XP", 1.2, &"", SimEvent.Kind.GOLD_GAINED],
	[&"heal", "THE CLERIC HEALS", 1.2, &"", &"heal"],
	[&"level_up", "A LEVEL UP", 1.2, &"level_up", SimEvent.Kind.LEVEL_UP],
	[&"resting", "RESTING", 1.5, &"", &"resting"],
	[&"climb_down", "ON TO THE NEXT STAGE", 1.0, &"climb_down", &"climb"],
	[&"climb_up", "BACK A STAGE", 1.0, &"climb_up", &"climb"],
	[&"wipe", "THE PARTY IS WIPED", 1.8, &"wipe", SimEvent.Kind.PARTY_WIPED],
	[&"revival", "THE REVIVAL", 1.5, &"", SimEvent.Kind.PARTY_REVIVED],
	[&"depth_stable", "A STAGE BECOMES STABLE", 1.0, &"depth_stable", &"stable"],
	[&"clay_fight", "A FIGHT IN THE CLAYPITS, FOR CLAY", 1.5, &"band", &"band"],
	[&"stone_fight", "A FIGHT IN THE OLD CRYPT, FOR OLD BONES", 1.5, &"band", &"band"],
	[&"deep_fight", "A FIGHT IN EMBER DEEP, FOR EMBERS", 1.5, &"band", &"band"],
	# The fight, then the guardian falls and its banner shows.
	[&"guardian_fight", "A GUARDIAN HOLDS THE WAY ON", 7.0, &"guardian", &"guardian"],
	[&"knight_actions", "THE KNIGHT'S ACTIONS", 1.2, &"class", &"class"],
	[&"rogue_actions", "THE ROGUE'S ACTIONS", 1.2, &"class", &"class"],
	[&"mage_actions", "THE MAGE'S ACTIONS", 1.2, &"class", &"class"],
	[&"cleric_actions", "THE CLERIC'S ACTIONS", 1.2, &"class", &"class"],
	[&"statuses", "EVERY STATUS, ON A ROW OF FIGHTERS", 2.0, &"class", &"statuses"],
	[&"quest_done", "A SIDE QUEST: THE ROGUE PICKS A LOCK", 1.0, &"quest", &"quest_done"],
	[&"quest_missed", "A SIDE QUEST NOBODY CAN DO", 1.0, &"quest", &"missed"],
	[&"tripwire_sprung", "A TRIPWIRE NOBODY SPOTS", 1.0, &"quest", &"sprung"],
	[&"microskill_learned", "THE ROGUE LEARNS A MICROSKILL", 1.0, &"quest", &"learned"],
	[&"room_lit", "A DARK ROOM LIGHTS AS THE PARTY WALKS IN", 1.5, &"room", &"room"],
	[&"gate_opened", "A SIDE PATH: ITS GATE IS OPENED", 0.5, &"gate", SimEvent.Kind.GATE_OPENED],
	[&"cache_opened", "THE CACHE AT ITS END", 1.5, &"", SimEvent.Kind.CACHE_OPENED],
	[&"gate_sealed", "A GATE NOBODY CAN OPEN", 2.0, &"gate", SimEvent.Kind.GATE_SEALED],
	[&"shop", "THE CAMP WINDOW: A FIFTH RANK BOUGHT", 2.5, &"shop", &"shop"],
	[&"area_map", "THE MAP: WHERE THE PARTY CAN GO", 1.5, &"area_map", &"area_map"],
	[&"journey", "A JOURNEY TO THE CLAYPITS", 1.2, &"journey", &"journey"],
	[&"four_areas", "THE FOUR AREAS", 0.2, &"four_areas", &"four_areas"],
	# The path's banner shows after the node's.
	[&"talent_tree", "THE KNIGHT CHOOSES A PATH", 2.5, &"talent_tree", &"talent_tree"],
	[&"away_report", "THE AWAY REPORT", 2.0, &"away_report", &"away_report"],
]
## The caption's place on screen, in the world's pixels: along the bottom, or, where the button
## bar would cover part of that, in the room left of the bar, CAPTION_GAP pixels from it.
const CAPTION_PLACE := Rect2(0, 296, 640, 20)
const CAPTION_GAP: float = 4.0
## A moment whose event has not come after this many seconds is given up (and has no evidence).
const GIVE_UP_SECONDS: float = 20.0
## How much faster than real time the simulation runs while the party walks to its next fight.
const WALK_SPEED_UP: float = 3.0
## How many times their health the monsters of the first fight have.
const TOUGHER: int = 3
## Where the showcase's Main would keep a save: a per-process name under user:// that is only
## ever read (it does not exist), never written. The store is dropped as soon as Main is ready.
const NO_SAVE_PATH: String = "user://showcase_no_save_%d.json"
## Each class's moment, and the path its hero takes there (the one whose actions look most
## unlike the trunk's).
const CLASS_MOMENTS: Dictionary[StringName, StringName] = {
	&"knight_actions": &"knight",
	&"rogue_actions": &"rogue",
	&"mage_actions": &"mage",
	&"cleric_actions": &"cleric",
}
const CLASS_PATHS: Dictionary[StringName, int] = {
	&"knight": 1, &"rogue": 1, &"mage": 0, &"cleric": 1
}
## How many times their health the monsters of a class's moment have, so the hero's actions are
## seen.
const CLASS_TOUGHER: int = 6
## In the statuses' moment, the statuses on each hero (by place in the party) and on
## each monster (by place in the fight; the last also takes any left over), the ability each is
## said to come from, and how long each lasts. The fight needs this many monsters at least.
const HERO_STATUSES: Array[Array] = [
	[AbilityEffect.Status.TAUNTING, AbilityEffect.Status.SHIELDED],
	[AbilityEffect.Status.UNTOUCHABLE, AbilityEffect.Status.HASTED],
	[AbilityEffect.Status.NIMBLE, AbilityEffect.Status.MIGHTY],
	[AbilityEffect.Status.MENDING],
]
const MONSTER_STATUSES: Array[Array] = [
	[AbilityEffect.Status.STUNNED, AbilityEffect.Status.BURNING],
	[AbilityEffect.Status.BLEEDING, AbilityEffect.Status.SLOWED],
	[AbilityEffect.Status.CHILLED, AbilityEffect.Status.WEAKENED],
	[AbilityEffect.Status.MARKED],
]
const STATUS_FROM: Dictionary[int, StringName] = {
	AbilityEffect.Status.STUNNED: &"shield_bash",
	AbilityEffect.Status.TAUNTING: &"taunt",
	AbilityEffect.Status.SHIELDED: &"bulwark",
	AbilityEffect.Status.BURNING: &"ignite",
	AbilityEffect.Status.BLEEDING: &"poisoned_blades",
	AbilityEffect.Status.MENDING: &"renewal",
	AbilityEffect.Status.HASTED: &"battle_hymn",
	AbilityEffect.Status.SLOWED: &"caltrops",
	AbilityEffect.Status.MIGHTY: &"killing_spree",
	AbilityEffect.Status.WEAKENED: &"smite",
	AbilityEffect.Status.MARKED: &"mark_for_death",
	AbilityEffect.Status.NIMBLE: &"smoke_step",
	AbilityEffect.Status.UNTOUCHABLE: &"vanish",
	AbilityEffect.Status.CHILLED: &"blizzard",
}
const STATUS_SECONDS: float = 30.0
const STATUS_MONSTERS: int = 3
## The game, as the main scene builds it.
var main: Main
## The moment showing now (an index into [method table]), or its size once the pass is over.
var moment_index: int = -1
## Per moment: true once the matching state or event was really present in the simulation.
var evidence: Dictionary[StringName, bool] = {}
## Seconds since the pass started.
var elapsed: float = 0.0
## True once every moment has been shown.
var done: bool = false

var _moment_time: float = 0.0
## Seconds since the moment's evidence appeared, or -1 before it does.
var _since_evidence: float = -1.0
var _caption: Label
## How each moment begins and is seen.
var _moments := ShowcaseMoments.new()
## Battles already steered in this moment (by its first combatant's id), so a change is made once.
var _steered: Dictionary[int, bool] = {}
## The statuses' moment's labels, one under each fighter bearing a status.
var _status_labels: Array[Label] = []


func _ready() -> void:
	main = (load("res://game/main.tscn") as PackedScene).instantiate() as Main
	main.name = "Main"
	# A store on a file that does not exist makes Main start a new game rather than load the
	# player's; it is dropped before Main could ever write.
	main.save_store = SaveStore.new(NO_SAVE_PATH % OS.get_process_id())
	add_child(main)
	main.save_store = null
	main.driver.set_process(false)
	main.world.set_process(false)
	main.effects.set_process(false)
	main.world.sim_event.connect(_on_sim_event)
	_moments.main = main
	var layer := CanvasLayer.new()
	layer.name = "Caption"
	layer.layer = 20
	add_child(layer)
	_caption = PixelText.label("", &"white")
	_caption.add_theme_font_size_override(&"font_size", PixelText.SIZE * 2)
	_caption.add_theme_constant_override(&"shadow_offset_x", 2)
	_caption.add_theme_constant_override(&"shadow_offset_y", 2)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_caption)
	_place_caption()
	_next_moment()


func _process(delta: float) -> void:
	advance(delta)


## The moments' names, in order.
static func names() -> Array[StringName]:
	var found: Array[StringName] = []
	for row: Array in ROWS:
		found.append(row[0])
	return found


## What the label says during moment [param wanted], or "" for no moment.
static func caption(wanted: StringName) -> String:
	var index: int = names().find(wanted)
	return ROWS[index][1] if index >= 0 else ""


## Starts the moment [param wanted] now, skipping those before it (for tests and a quick look).
func skip_to(wanted: StringName) -> void:
	var index: int = names().find(wanted)
	if index < 0 or done:
		return
	moment_index = index - 1
	_next_moment()


## The moment showing now, or &"" once the pass is over.
func moment() -> StringName:
	return _row()[0] if not _row().is_empty() else &""


## The row of the moment showing now (see [constant ROWS]), or an empty one.
func _row() -> Array:
	return ROWS[moment_index] if moment_index >= 0 and moment_index < ROWS.size() else []


## Moves the showcase on by [param delta] seconds: steers the simulation, steps it, and brings
## the world, the effects and the moment up to date. Called every frame; tests call it.
func advance(delta: float) -> void:
	if main == null:
		return
	elapsed += delta
	var speed: float = 1.0
	if _walks_to_a_fight() or _on_a_journey() or _moments.walks_to_a_gate(moment()):
		speed = WALK_SPEED_UP
	_steer()
	main.driver.advance(roundi(delta * speed * 1_000_000.0))
	_watch(null)
	main.world.sync(delta)
	main.effects.advance(delta)
	_label_statuses()
	_place_caption()
	if done:
		return
	_moment_time += delta
	if _since_evidence >= 0.0:
		_since_evidence += delta
	var linger: float = _row()[2]
	if _since_evidence >= linger or _moment_time >= GIVE_UP_SECONDS:
		_end_moment()
		_next_moment()


# --- Moments -------------------------------------------------------------------


func _next_moment() -> void:
	moment_index += 1
	_moment_time = 0.0
	_since_evidence = -1.0
	_steered.clear()
	var row: Array = _row()
	if row.is_empty():
		done = true
		_caption.text = "THE SHOWCASE IS OVER"
		finished.emit()
		return
	_caption.text = "%d/%d  %s" % [moment_index + 1, ROWS.size(), row[1]]
	var how: StringName = row[3]
	_moments.begin(how, moment())
	moment_started.emit(row[0])


func _see() -> void:
	if not evidence.get(moment(), false):
		evidence[moment()] = true
		_since_evidence = 0.0


## Tells the moment showing of [param event], or with null of the frame's state: it is seen once
## its row says so.
func _watch(event: SimEvent) -> void:
	var row: Array = _row()
	if done or row.is_empty():
		return
	if row[4] is int:
		if event != null and event.kind == row[4]:
			_see()
		return
	var how: StringName = row[4]
	if _moments.watch(how, moment(), event, _moment_time, _since_evidence):
		_see()


func _end_moment() -> void:
	var sim: Simulation = main.simulation
	match moment():
		&"crit":
			# Crits were for this moment only: the heroes go back to their own chances.
			var battle: Battle = sim.expedition.battle
			if battle != null:
				for hero: Hero in sim.party.heroes:
					var fighter: Combatant = battle.combatant(hero.id)
					if fighter != null:
						var own: Combatant = Combatant.from_hero(hero.def(), hero.level, hero.id)
						fighter.crit_chance = own.crit_chance
		&"resting":
			# The rest has been seen: everyone is whole, and the party moves on.
			for hero: Hero in sim.party.heroes:
				hero.health = hero.max_health()
		&"depth_stable":
			sim.expedition.stable_seconds = 600.0
		&"gate_sealed":
			_moments.end_gates()
		&"shop":
			main.hud.shop.close()
		&"area_map", &"journey":
			main.hud.area_map.close()
		&"statuses":
			for hero: Hero in sim.party.heroes:
				hero.set_talents([])  # the class moments' trees are for those moments only
		&"talent_tree":
			main.hud.hero_windows.close_all()
		&"away_report":
			if is_instance_valid(main.away_window):
				main.away_window.close()


## Changes made every frame while a moment waits for its event: in a fight, once per fight.
func _steer() -> void:
	var expedition: Expedition = main.simulation.expedition
	var battle: Battle = expedition.battle
	if done or expedition.state != Expedition.State.FIGHTING or battle == null:
		return
	if evidence.get(moment(), false) or battle.heroes.is_empty():
		return
	var key: int = battle.monsters[0].id if not battle.monsters.is_empty() else 0
	match moment():
		&"crit":
			for fighter: Combatant in battle.heroes:
				fighter.crit_chance = 1.0
			if _steered.has(key):
				return
			_steered[key] = true
			# Tougher monsters: this one fight holds the crit, a death, a heal and a level up.
			for monster: Combatant in battle.monsters:
				monster.max_health = monster.max_health * TOUGHER
				monster.health = monster.max_health
		&"heal":
			if _steered.has(key):
				return
			_steered[key] = true
			var front: Combatant = battle.heroes[0]
			if front.is_alive():
				front.health = maxi(1, front.max_health * 2 / 5)
		&"knight_actions", &"rogue_actions", &"mage_actions", &"cleric_actions":
			if _steered.has(key):
				return
			_steered[key] = true
			for monster: Combatant in battle.monsters:
				monster.max_health = monster.max_health * CLASS_TOUGHER
				monster.health = monster.max_health
		&"statuses":
			if not _steered.has(key):
				_steered[key] = true
				_put_on_statuses(battle)
		&"resting":
			if _steered.has(key):
				return
			_steered[key] = true
			# Hurt the heroes and weaken the monsters: the fight ends soon, and they need a rest.
			for fighter: Combatant in battle.heroes:
				if fighter.is_alive():
					fighter.health = maxi(1, fighter.max_health * 3 / 10)
			for monster: Combatant in battle.monsters:
				if monster.is_alive():
					monster.health = 1


func _on_sim_event(event: SimEvent) -> void:
	_watch(event)


## Puts the caption where CAPTION_PLACE says for the room the UI has now; nothing when it is there.
func _place_caption() -> void:
	var place: Rect2 = CAPTION_PLACE
	var ui: UiRoot = main.ui
	if ui != null and ui.bar != null:
		var bar: Rect2 = ui.bar.get_rect()
		var bar_on_screen := Rect2(ui.ui_to_world(bar.position), ui.ui_to_world(bar.size))
		if place.intersects(bar_on_screen):
			place.size.x = floorf(bar_on_screen.position.x - CAPTION_GAP) - place.position.x
	if _caption.position != place.position or _caption.size != place.size:
		_caption.position = place.position
		_caption.size = place.size


## True while the moment waits for a fight the party is still walking to.
func _walks_to_a_fight() -> bool:
	if done or main.simulation.expedition.state != Expedition.State.TRAVELLING:
		return false
	var current: StringName = moment()
	return current in [&"crit", &"monster_death", &"heal", &"level_up", &"resting"]


## Puts every status on the fight's fighters through the battle's own rules (each with
## its STATUS_BEGAN), for STATUS_SECONDS, and makes the fight harmless and long, so the row stands
## still to be read. A fight with too few monsters is ended and the next one taken.
func _put_on_statuses(battle: Battle) -> void:
	if battle.monsters.size() < STATUS_MONSTERS:
		_moments.settle_now()
		_moments.cut_to_fight()
		return
	# Spread out in their order and kept where they stand (each strikes from there, for 1), so
	# every fighter's marks and label can be read.
	var row: Array[Combatant] = battle.heroes + battle.monsters
	row.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.x < b.x)
	# Evenly between the outermost two, which the fight's bounds already hold.
	var first: float = row[0].x
	var step: float = (row[row.size() - 1].x - first) / maxf(row.size() - 1, 1)
	for i: int in row.size():
		var fighter: Combatant = row[i]
		fighter.x = first + i * step
		fighter.max_health *= 100
		fighter.health = fighter.max_health
		fighter.damage = 1
		fighter.move_speed = 0.0
		fighter.attack_range = 100.0
		fighter.abilities = []
	var left: Array = MONSTER_STATUSES.duplicate()
	for i: int in battle.monsters.size():
		var kinds: Array = []
		if i == battle.monsters.size() - 1:
			for rest: Array in left:
				kinds.append_array(rest)
		elif not left.is_empty():
			kinds = left.pop_front()
		for kind: int in kinds:
			_put_on(battle, battle.heroes[0], battle.monsters[i], kind)
	for i: int in mini(battle.heroes.size(), HERO_STATUSES.size()):
		for kind: int in HERO_STATUSES[i]:
			_put_on(battle, battle.heroes[i], battle.heroes[i], kind)


func _put_on(battle: Battle, source: Combatant, receiver: Combatant, kind: int) -> void:
	var effect := AbilityEffect.new()
	effect.does = AbilityEffect.Does.STATUS
	effect.status = kind as AbilityEffect.Status
	effect.seconds = STATUS_SECONDS
	effect.scale = AbilityEffect.Scale.RECEIVER_MAX_HEALTH
	match kind:
		AbilityEffect.Status.SHIELDED:
			effect.amount = 0.5
		AbilityEffect.Status.BURNING, AbilityEffect.Status.BLEEDING:
			effect.amount = 0.001
		AbilityEffect.Status.CHILLED, AbilityEffect.Status.MENDING:
			effect.amount = 0.001
		AbilityEffect.Status.HASTED, AbilityEffect.Status.WEAKENED:
			effect.amount = 0.7
		AbilityEffect.Status.NIMBLE:
			effect.amount = 0.5
		_:
			effect.amount = 1.3
	BattleStatuses.apply(battle, source, receiver, effect, STATUS_FROM[kind])


func _x_of(id: int) -> float:
	var sprite: CharacterSprite = main.world.character(id)
	return sprite.position.x if sprite != null else 0.0


## While the statuses' moment shows, a label under each fighter names its statuses.
func _label_statuses() -> void:
	var marks: StatusMarks = main.effects.ability_effects.marks
	var ids: Array[int] = []
	if moment() == &"statuses":
		ids = marks.book.fighters()
		ids.sort_custom(func(a: int, b: int) -> bool: return _x_of(a) < _x_of(b))
	var camera: WorldCamera = main.world.camera
	var view: Vector2 = camera.get_viewport_rect().size
	var shown: int = 0
	for id: int in ids:
		var sprite: CharacterSprite = main.world.character(id)
		var kinds: Array[int] = marks.shown(id)
		if sprite == null or kinds.is_empty():
			continue
		if shown >= _status_labels.size():
			var made: Label = PixelText.label("", &"white")
			made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_caption.get_parent().add_child(made)
			_status_labels.append(made)
		var label: Label = _status_labels[shown]
		shown += 1
		var said: PackedStringArray = []
		for kind: int in kinds:
			said.append(ShownStatus.status_name(kind))
		label.text = "\n".join(said)
		label.reset_size()
		var feet: Vector2 = (
			(sprite.position - camera.position - camera.offset) * camera.zoom + view / 2.0
		)
		# Every other label a tier lower, so neighbours never run into each other.
		var tier: float = (shown % 2) * 2.0 * (PixelText.SIZE + 1)
		label.position = Vector2(roundf(feet.x - label.size.x / 2.0), roundf(feet.y + 3.0 + tier))
		label.visible = true
	for i: int in range(shown, _status_labels.size()):
		_status_labels[i].visible = false


## True while the journey's moment waits for the party to arrive.
func _on_a_journey() -> bool:
	if done or moment() != &"journey":
		return false
	return main.simulation.expedition.state == Expedition.State.JOURNEYING
