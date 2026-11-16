extends SceneTree
## Runs the simulation headless for some game time and prints one JSON summary.
##
## Run: godot --headless --path . -s res://tools/godot/run_sim.gd -- --seed=1 --minutes=10
##      [--target-depth=3] [--stable-seconds=120] [--buy-upgrades=true]
## or, more simply: python tools/dev.py sim --seed=1 --minutes=10
##
## With --buy-upgrades the run buys the cheapest upgrade it can afford whenever it can.
## The summary is printed on one line that starts with "[sim] ".


func _init() -> void:
	var options: Dictionary[String, String] = _options()
	var seed_value: int = _option(options, "seed", "1").to_int()
	var minutes: float = _option(options, "minutes", "10").to_float()
	var sim := Simulation.new(seed_value)
	if options.has("stable-seconds"):
		sim.expedition.stable_seconds = _option(options, "stable-seconds", "").to_float()
	if options.has("target-depth"):
		sim.set_target_depth(_option(options, "target-depth", "").to_int())
	var buying: bool = options.has("buy-upgrades")

	var won: int = 0
	var lost: int = 0
	var wipes: int = 0
	var kills: Dictionary[String, int] = {}
	var ticks: int = roundi(minutes * 60.0 * Simulation.TICKS_PER_SECOND)
	for i: int in ticks:
		# A battle can end within the step, so remember it to name the dead.
		var fight: Battle = sim.expedition.battle
		if buying:
			var cheapest: StringName = sim.upgrades.cheapest_affordable(sim.party.gold)
			if cheapest != &"":
				sim.buy_upgrade(cheapest)
		sim.step()
		for event: SimEvent in sim.drain_events():
			match event.kind:
				SimEvent.Kind.ENCOUNTER_ENDED:
					if event.flag:
						won += 1
					else:
						lost += 1
				SimEvent.Kind.PARTY_WIPED:
					wipes += 1
				SimEvent.Kind.DIED:
					var dead: Combatant = fight.combatant(event.source_id) if fight else null
					if dead != null and dead.team == Combatant.Team.MONSTERS:
						var kind: String = String(dead.def_id)
						var so_far: int = kills.get(kind, 0)
						kills[kind] = so_far + 1

	var heroes: Array[Dictionary] = []
	for hero: Hero in sim.party.heroes:
		heroes.append({"class": String(hero.class_id), "level": hero.level, "xp": hero.xp})
	var sorted_kills: Dictionary = {}
	var kill_ids: Array[String] = []
	kill_ids.assign(kills.keys())
	kill_ids.sort()
	for id: String in kill_ids:
		sorted_kills[id] = kills[id]
	var upgrades: Dictionary = {}
	for id: StringName in Content.upgrade_ids():
		upgrades[String(id)] = sim.upgrades.rank(id)
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
	}
	print("[sim] " + JSON.stringify(summary))
	quit(0)


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
