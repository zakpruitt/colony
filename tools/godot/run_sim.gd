extends SceneTree
## Runs the simulation headless for some game time and prints one JSON summary.
##
## Run: godot --headless --path . -s res://tools/godot/run_sim.gd -- --seed=1 --minutes=10
##      [--target-depth=3] [--stable-seconds=120] [--buy-upgrades=true] [--timeline=true]
##      [--area=claypits] [--spend-talents=true] [--winding=true]
## or, more simply: python tools/dev.py sim --seed=1 --minutes=10
##
## With --buy-upgrades the run buys the cheapest upgrade it can afford whenever it can.
## With --timeline the summary gains "timeline": the game time in seconds of each first,
## or null for one that did not happen. "level_2" and "level_5" are when every hero had reached
## that level; "upgrade_affordable" is when the party first held the price of an upgrade.
## With --area the party is sent to that area at the start (opened for the run if it is not open),
## at the target depth's stage if one is given, else stage 1. The summary names the area
## the party is in and its stage ("area", "stage"), each area's safe and furthest stage ("areas")
## and the open areas ("open_areas"); a run that ends on the way to another area also names where
## the party will arrive ("journeying_to").
## With --spend-talents each hero spends its points as they come ([TalentSpender]): its
## first path tier by tier, then the other paths, and every paragon point into Power. Each hero in
## the summary lists the nodes it took ("talents"). "slime_king_won" is the game time of the first
## win over the Slime King, or null, and "wipes_before_slime_king" counts the wipes before it (all
## of the run's, without one).
## The summary names the resources the party holds at the end ("resources").
## With --winding the simulation's stages are winding ones ([constant Labyrinth.Shape.WINDING]);
## the summary also counts the caches the party opened on their side paths ("caches_opened").
## The summary is printed on one line that starts with "[sim] ".

## The firsts --timeline reports, in order.
const TIMELINE_KEYS: Array[String] = [
	"level_2",
	"level_5",
	"depth_2",
	"depth_5",
	"upgrade_affordable",
	"guardian_met",
	"guardian_beaten",
]


func _init() -> void:
	var options: Dictionary[String, String] = _options()
	var seed_value: int = _option(options, "seed", "1").to_int()
	var minutes: float = _option(options, "minutes", "10").to_float()
	var shape: Labyrinth.Shape = Labyrinth.Shape.FLAT
	if options.has("winding"):
		shape = Labyrinth.Shape.WINDING
	var sim := Simulation.new(seed_value, shape)
	if options.has("stable-seconds"):
		sim.expedition.stable_seconds = _option(options, "stable-seconds", "").to_float()
	if options.has("target-depth"):
		sim.set_target_depth(_option(options, "target-depth", "").to_int())
	if options.has("area"):
		var area := StringName(_option(options, "area", ""))
		if Content.area(area) == null:
			push_error("run_sim: unknown area '%s'" % area)
			quit(1)
			return
		sim.expedition.travel.open[area] = true
		sim.set_destination(area, maxi(_option(options, "target-depth", "1").to_int(), 1))
	var buying: bool = options.has("buy-upgrades")
	var spending: bool = options.has("spend-talents")
	var king_won: Variant = null
	var wipes_before_king: int = 0
	var firsts: Dictionary[String, float] = {}
	var guardian_fight: bool = false

	var won: int = 0
	var lost: int = 0
	var wipes: int = 0
	var caches: int = 0
	var kills: Dictionary[String, int] = {}
	var ticks: int = roundi(minutes * 60.0 * Simulation.TICKS_PER_SECOND)
	for i: int in ticks:
		# A battle can end within the step, so remember it to name the dead.
		var fight: Battle = sim.expedition.battle
		if buying:
			var cheapest: StringName = sim.upgrades.cheapest_affordable(sim.party)
			if cheapest != &"":
				sim.buy_upgrade(cheapest)
		if spending:
			TalentSpender.spend(sim)
		sim.step()
		var now: float = sim.seconds()
		if sim.upgrades.cheapest_affordable(sim.party) != &"":
			_first(firsts, "upgrade_affordable", now)
		for event: SimEvent in sim.drain_events():
			match event.kind:
				SimEvent.Kind.ENCOUNTER_STARTED:
					guardian_fight = _holds_guardian(sim.expedition)
					if guardian_fight:
						_first(firsts, "guardian_met", now)
				SimEvent.Kind.GUARDIAN_SLAIN:
					_first(firsts, "guardian_beaten", now)
					var slain: Combatant = fight.combatant(event.source_id) if fight else null
					if king_won == null and slain != null and slain.def_id == &"slime_king":
						king_won = now
				SimEvent.Kind.DEPTH_CHANGED:
					if event.amount == 2 or event.amount == 5:
						_first(firsts, "depth_%d" % event.amount, now)
				SimEvent.Kind.LEVEL_UP:
					var lowest: int = _lowest_level(sim.party)
					if lowest >= 2:
						_first(firsts, "level_2", now)
					if lowest >= 5:
						_first(firsts, "level_5", now)
				SimEvent.Kind.ENCOUNTER_ENDED:
					if event.flag:
						won += 1
					else:
						lost += 1
				SimEvent.Kind.PARTY_WIPED:
					wipes += 1
					if king_won == null:
						wipes_before_king += 1
				SimEvent.Kind.CACHE_OPENED:
					caches += 1
				SimEvent.Kind.DIED:
					var dead: Combatant = fight.combatant(event.source_id) if fight else null
					if dead != null and dead.team == Combatant.Team.MONSTERS:
						var kind: String = String(dead.def_id)
						var so_far: int = kills.get(kind, 0)
						kills[kind] = so_far + 1

	var heroes: Array[Dictionary] = []
	for hero: Hero in sim.party.heroes:
		var talents: Array[String] = []
		for node: StringName in hero.talents():
			talents.append(String(node))
		(
			heroes
			. append(
				{
					"class": String(hero.class_id),
					"level": hero.level,
					"xp": hero.xp,
					"talents": talents,
				}
			)
		)
	var sorted_kills: Dictionary = {}
	var kill_ids: Array[String] = []
	kill_ids.assign(kills.keys())
	kill_ids.sort()
	for id: String in kill_ids:
		sorted_kills[id] = kills[id]
	var upgrades: Dictionary = {}
	for id: StringName in Content.upgrade_ids():
		upgrades[String(id)] = sim.upgrades.rank(id)
	var resources: Dictionary = {}
	for id: StringName in Content.resource_ids():
		resources[String(id)] = sim.party.resource(id)
	var summary: Dictionary = {
		"seed": seed_value,
		"minutes": minutes,
		"final_depth": sim.expedition.depth,
		"last_stable_depth": sim.expedition.last_stable_depth,
		"target_depth": sim.expedition.target_depth,
		"deepest_depth": sim.expedition.deepest_depth,
		"battles_won": won,
		"battles_lost": lost,
		"wipes": wipes,
		"gold": sim.party.gold,
		"heroes": heroes,
		"kills": sorted_kills,
		"upgrades": upgrades,
		"resources": resources,
		# The area the party stands in and its stage; on its way elsewhere, the area it left.
		"area": String(sim.expedition.place),
		"stage": sim.expedition.depth,
		"areas": _areas(sim),
		"open_areas": _open_areas(sim),
		"slime_king_won": king_won,
		"wipes_before_slime_king": wipes_before_king,
	}
	if options.has("winding"):
		summary["caches_opened"] = caches
	var travel: AreaTravel = sim.expedition.travel
	if sim.expedition.state == Expedition.State.JOURNEYING:
		var stage: int = travel.journey_stage(sim.expedition)
		summary["journeying_to"] = {"area": String(sim.expedition.area), "stage": stage}
	if options.has("timeline"):
		var timeline: Dictionary = {}
		for key: String in TIMELINE_KEYS:
			timeline[key] = firsts.get(key, null)
		summary["timeline"] = timeline
	print("[sim] " + JSON.stringify(summary))
	quit(0)


## Each area's safe and furthest stage, by id.
func _areas(sim: Simulation) -> Dictionary:
	var areas: Dictionary = {}
	for id: StringName in Content.area_ids():
		var kept: Vector2i = sim.area_progress(id)
		areas[String(id)] = {"safe": kept.x, "furthest": kept.y}
	return areas


## The open areas' ids, in area order.
func _open_areas(sim: Simulation) -> Array[String]:
	var open: Array[String] = []
	for id: StringName in Content.area_ids():
		if sim.is_area_open(id):
			open.append(String(id))
	return open


## Records [param seconds] as the time of [param key] unless that first already happened.
func _first(firsts: Dictionary[String, float], key: String, seconds: float) -> void:
	if not firsts.has(key):
		firsts[key] = seconds


## The level of the party's lowest hero.
func _lowest_level(party: Party) -> int:
	var lowest: int = party.heroes[0].level
	for hero: Hero in party.heroes:
		lowest = mini(lowest, hero.level)
	return lowest


## True if the fight just started is against a guardian.
func _holds_guardian(expedition: Expedition) -> bool:
	if expedition.battle == null:
		return false
	for monster: Combatant in expedition.battle.monsters:
		if Content.monster(monster.def_id).guardian:
			return true
	return false


## The --name=value options after the "--" on the command line.
func _options() -> Dictionary[String, String]:
	var found: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
			found[parts[0]] = parts[1]
	return found


func _option(options: Dictionary[String, String], name: String, fallback: String) -> String:
	var value: String = options.get(name, fallback)
	return value
