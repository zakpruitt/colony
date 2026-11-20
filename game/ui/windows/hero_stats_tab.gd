class_name HeroStatsTab
extends Control
## A hero window's Stats tab: each stat on a line of its own, its name, its value,
## and beside it in green what raises it and by how much, in words
## ([code]Damage 14   +15% Sharp Blades, +6% Power[/code]): each camp upgrade that raises it, by
## its name, and the paragon stat that does. Every value is read from the simulation at each
## [method refresh].

## The stats, top to bottom.
const KEYS: Array[StringName] = [
	&"stat_health",
	&"stat_damage",
	&"stat_healing",
	&"stat_armor",
	&"stat_attack_speed",
	&"stat_crit",
	&"stat_range",
]
const STAT_NAMES: Dictionary[StringName, String] = {
	&"stat_health": "Health",
	&"stat_damage": "Damage",
	&"stat_armor": "Armor",
	&"stat_healing": "Healing",
	&"stat_attack_speed": "Attack speed",
	&"stat_crit": "Crit chance",
	&"stat_range": "Range",
}
## Where each column starts, and a line's height, in UI pixels.
const VALUE_X: float = 104.0
const REASON_X: float = 196.0
const ROW: float = 19.0

## Each stat's name, value and reasons, by key.
var name_labels: Dictionary[StringName, Label] = {}
var value_labels: Dictionary[StringName, Label] = {}
var reason_labels: Dictionary[StringName, Label] = {}

var _simulation: Simulation
var _hero_id: int = -1
## What the stats were last worked out from: the hero's level, health and the multipliers of its
## camp upgrades and paragon points. Only a change builds the hero's fighter again.
var _shown: ShownValues = ShownValues.new()


## The tab of hero [param hero_id], [param width] UI pixels wide.
func _init(simulation: Simulation, hero_id: int, width: float) -> void:
	name = "StatsPage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_simulation = simulation
	_hero_id = hero_id
	var y: float = 0.0
	for key: StringName in KEYS:
		var stem: String = STAT_NAMES[key].replace(" ", "")
		name_labels[key] = _add(WindowText.label(stem, STAT_NAMES[key], &"steel"), 0.0, y)
		value_labels[key] = _add(WindowText.label(stem + "Value", "", &"white"), VALUE_X, y)
		reason_labels[key] = _add(WindowText.label(stem + "Reasons", "", &"green"), REASON_X, y)
		y += ROW
	size = Vector2(width, y)
	custom_minimum_size = size


## Brings every line up to date with the hero. The window calls it on every advance.
func refresh() -> void:
	var hero: Hero = _simulation.party.hero(_hero_id) if _simulation != null else null
	if hero == null:
		return
	_shown.begin()
	_shown.see(hero.level)
	_shown.see(hero.max_health())
	_shown.see(_simulation.upgrades.multiplier(UpgradeDef.Stat.DAMAGE))
	_shown.see(_simulation.upgrades.multiplier(UpgradeDef.Stat.HEALTH))
	_shown.see(hero.paragon_rank(TrainingDef.Stat.POWER))
	_shown.see(hero.paragon_rank(TrainingDef.Stat.TOUGHNESS))
	_shown.see(hero.paragon_rank(TrainingDef.Stat.QUICKNESS))
	if not _shown.changed():
		return
	var def: HeroClassDef = hero.def()
	var fighter: Combatant = hero.combatant()
	var power: Array[String] = _reasons(UpgradeDef.Stat.DAMAGE, hero, TrainingDef.Stat.POWER)
	var tough: Array[String] = _reasons(UpgradeDef.Stat.HEALTH, hero, TrainingDef.Stat.TOUGHNESS)
	var quick: Array[String] = _reasons(-1, hero, TrainingDef.Stat.QUICKNESS)
	var none: Array[String] = []
	_show(&"stat_health", UiFormat.group_thousands(hero.max_health()), tough)
	_show(&"stat_damage", UiFormat.group_thousands(fighter.damage), power)
	_show(&"stat_armor", str(fighter.armor), none)
	var speed: float = hero.paragon_multiplier(TrainingDef.Stat.QUICKNESS)
	_show(&"stat_attack_speed", "%.1f/s" % (speed / maxf(def.attack_interval, 0.01)), quick)
	_show(&"stat_crit", "%d%%" % roundi(def.crit_chance * 100.0), none)
	var reach: String = "Melee"
	if def.attack_range > Battle.MELEE_REACH:
		reach = "%s tiles" % HeroWindow.tiles(def.attack_range)
	_show(&"stat_range", reach, none)
	var heals: bool = def.heal_power > 0
	_show(&"stat_healing", UiFormat.group_thousands(fighter.heal_power), power)
	for label: Label in [
		name_labels[&"stat_healing"], value_labels[&"stat_healing"], reason_labels[&"stat_healing"]
	]:
		label.visible = heals
	var y: float = 0.0
	for key: StringName in KEYS:
		if not name_labels[key].visible:
			continue
		for label: Label in [name_labels[key], value_labels[key], reason_labels[key]]:
			label.position.y = y
		y += ROW


## The line of stat [param key] as it reads: its name, its value and what raises it
## ([code]Damage 14 +15% Sharp Blades, +6% Power[/code]); "" for a stat not shown.
func line(key: StringName) -> String:
	if not name_labels.has(key) or not name_labels[key].visible:
		return ""
	var text: String = "%s %s" % [name_labels[key].text, value_labels[key].text]
	if not reason_labels[key].text.is_empty():
		text += " " + reason_labels[key].text
	return text


## What raises a stat, each as [code]+15% Sharp Blades[/code]: every camp upgrade of
## [param upgrade_stat] (-1 for none) the party has a rank of, then [param hero]'s paragon points in
## [param paragon].
func _reasons(upgrade_stat: int, hero: Hero, paragon: TrainingDef.Stat) -> Array[String]:
	var found: Array[String] = []
	if upgrade_stat >= 0:
		for id: StringName in Content.upgrade_ids():
			var def: UpgradeDef = Content.upgrade(id)
			var rank: int = _simulation.upgrades.rank(id)
			if def != null and def.stat == upgrade_stat and rank > 0:
				found.append("+%d%% %s" % [roundi(rank * def.per_rank * 100.0), def.display_name])
	for id: StringName in Content.training_ids():
		var training: TrainingDef = Content.training(id)
		var points: int = hero.paragon_rank(paragon)
		if training != null and training.stat == paragon and points > 0:
			var bonus: int = roundi(points * training.per_rank * 100.0)
			found.append("+%d%% %s" % [bonus, training.display_name])
	return found


func _show(key: StringName, value: String, reasons: Array[String]) -> void:
	WindowText.set_text(value_labels[key], value)
	WindowText.set_text(reason_labels[key], ", ".join(PackedStringArray(reasons)))


func _add(label: Label, x: float, y: float) -> Label:
	label.position = Vector2(x, y)
	add_child(label)
	return label
