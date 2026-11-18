extends GutTest
## The fighters, abilities and event helpers the tests of spec 050 share. It has no tests of
## its own; the acceptance tests and the unit tests of abilities extend it.
##
## The tests build their own fighters and abilities, so no shipped data can move the numbers.
## Ability damage and healing carry no roll, so their amounts are exact; ordinary strikes still
## roll, so the tests only bound them. Effects and abilities are written with the names of
## their enum values ("DAMAGE", "TARGET", "aim": "SELF") to keep them on one line.

const SEED: int = 5050
## A duration long enough that it never comes round in a test.
const NEVER: float = 100_000.0
const TPS: int = Simulation.TICKS_PER_SECOND
const STILL: Dictionary = {"windup": NEVER}
const BY_DAMAGE: Dictionary = {"scale": "FIGHTER_DAMAGE"}
const BY_HEALTH: Dictionary = {"scale": "RECEIVER_MAX_HEALTH"}
## The enum each property named by an ability's or effect's props takes.
const ENUMS: Dictionary = {
	"aim": AbilityDef.Aim,
	"condition": AbilityDef.Condition,
	"trigger": AbilityDef.Trigger,
	"does": AbilityEffect.Does,
	"lands": AbilityEffect.Lands,
	"status": AbilityEffect.Status,
	"scale": AbilityEffect.Scale,
}

var _save_path: String = "user://test_050_ability_%d.tres" % OS.get_process_id()

# --- Helpers -----------------------------------------------------------------


func after_each() -> void:
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))


func after_all() -> void:
	after_each()


func _hero_def(role: HeroClassDef.Role, overrides: Dictionary) -> HeroClassDef:
	var def := HeroClassDef.new()
	def.id = &"test_hero"
	def.display_name = "Test hero"
	def.role = role
	def.max_health = 100
	def.damage = 10
	def.attack_interval = 1.0
	def.windup = 0.3
	def.attack_range = 1.0
	def.move_speed = 2.0
	_set_all(def, overrides)
	return def


func _monster_def(overrides: Dictionary) -> MonsterDef:
	var def := MonsterDef.new()
	def.id = &"test_monster"
	def.display_name = "Test monster"
	def.base_level = 1  # min_depth before spec 049
	def.max_health = 100
	def.damage = 5
	def.attack_interval = 1.0
	def.windup = 0.3
	def.attack_range = 1.0
	def.move_speed = 1.0
	_set_all(def, overrides)
	return def


## Sets each property in [param props] on [param target]; for a property that takes an enum,
## a value may be given by its name.
func _set_all(target: Object, props: Dictionary) -> void:
	for key: String in props:
		var value: Variant = props[key]
		if ENUMS.has(key) and value is String:
			var values: Dictionary = ENUMS[key]
			value = values[value]
		target.set(key, value)


func _hero(id: int, overrides: Dictionary = {}, role := HeroClassDef.Role.MELEE) -> Combatant:
	return Combatant.from_hero(_hero_def(role, overrides), 1, id)


## A monster that stands still and never finishes an attack.
func _dummy(id: int, overrides: Dictionary = {}) -> Combatant:
	var values: Dictionary = {
		"max_health": 1000, "windup": NEVER, "attack_range": 1000.0, "move_speed": 0.0
	}
	values.merge(overrides, true)
	return Combatant.from_monster(_monster_def(values), 1, id)


## A monster that stands still and shoots every second.
func _shooter(id: int, overrides: Dictionary = {}) -> Combatant:
	return _dummy(id, {"max_health": 100, "windup": 0.3}.merged(overrides, true))


func _typed(list: Array) -> Array[Combatant]:
	var typed: Array[Combatant] = []
	typed.assign(list)
	return typed


func _battle(heroes: Array, monsters: Array, right: float = 16.0, seed_value := SEED) -> Battle:
	return Battle.new(_typed(heroes), _typed(monsters), 0.0, right, true, SimRng.new(seed_value))


## Steps until the battle is over or [param ticks] have passed, collecting every event.
func _run(battle: Battle, ticks: int = Battle.MAX_TICKS + 10) -> Array[SimEvent]:
	var events: Array[SimEvent] = battle.drain_events()
	var stepped: int = 0
	while battle.result() == Battle.Result.ONGOING and stepped < ticks:
		battle.step()
		events.append_array(battle.drain_events())
		stepped += 1
	return events


func _fx(does: String, lands: String, props: Dictionary = {}) -> AbilityEffect:
	var effect := AbilityEffect.new()
	_set_all(effect, {"does": does, "lands": lands})
	_set_all(effect, props)
	return effect


func _st(kind: String, seconds: float, amount: float, lands: String, props := {}) -> AbilityEffect:
	var values: Dictionary = {"status": kind, "seconds": seconds, "amount": amount}
	values.merge(props, true)
	return _fx("STATUS", lands, values)


func _ability(id: StringName, kind: AbilityDef.Kind, effects: Array, props := {}) -> AbilityDef:
	var ability := AbilityDef.new()
	ability.id = id
	ability.display_name = String(id).capitalize()
	ability.description = "Does what the test needs."
	ability.move = &"flourish"
	ability.picture = &"strike"  # spec 060: every ability names its picture
	ability.kind = kind
	ability.effects.assign(effects)
	_set_all(ability, props)
	return ability


## An action that is ready at once, aims anywhere, winds up for one tick and never comes
## round again.
func _action(id: StringName, effects: Array, props: Dictionary = {}) -> AbilityDef:
	var values: Dictionary = {
		"cooldown": NEVER, "windup": 0.1, "ready_at_start": true, "anywhere": true
	}
	values.merge(props, true)
	return _ability(id, AbilityDef.Kind.ACTION, effects, values)


func _passive(id: StringName, trigger: String, effects: Array, props := {}) -> AbilityDef:
	var values: Dictionary = {"trigger": trigger}
	values.merge(props, true)
	return _ability(id, AbilityDef.Kind.PASSIVE, effects, values)


## A passive that only says it fired: a moment of might, which changes no timing.
func _marker(id: StringName, trigger: String, props: Dictionary = {}) -> AbilityDef:
	return _passive(id, trigger, [_st("MIGHTY", 0.1, 1.1, "SELF")], props)


func _give(c: Combatant, abilities: Array) -> Combatant:
	c.abilities.assign(abilities)
	return c


func _of(events: Array[SimEvent], kind: SimEvent.Kind, source: int = -2) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for e: SimEvent in events:
		if e.kind == kind and (source == -2 or e.source_id == source):
			found.append(e)
	return found


func _used(events: Array[SimEvent], id: StringName) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for e: SimEvent in _of(events, SimEvent.Kind.ABILITY_USED):
		if e.ability_id == id:
			found.append(e)
	return found


func _ticks(events: Array[SimEvent]) -> Array[int]:
	return _ints(events.map(func(e: SimEvent) -> int: return e.tick))


func _amounts(events: Array[SimEvent]) -> Array[int]:
	return _ints(events.map(func(e: SimEvent) -> int: return e.amount))


func _targets(events: Array[SimEvent]) -> Array[int]:
	return _ints(events.map(func(e: SimEvent) -> int: return e.target_id))


func _ints(list: Array) -> Array[int]:
	var typed: Array[int] = []
	typed.assign(list)
	return typed


func _line(e: SimEvent) -> String:
	var kind: String = SimEvent.Kind.keys()[e.kind]
	return "%s %d %d %d %d %s" % [kind, e.tick, e.source_id, e.target_id, e.amount, e.flag]


func _full_line(e: SimEvent) -> String:
	return "%s %s %d" % [_line(e), e.ability_id, e.status]


## The events of the tick of the first ABILITY_USED of [param id], from it on.
func _landing(events: Array[SimEvent], id: StringName) -> Array[SimEvent]:
	var used: Array[SimEvent] = _used(events, id)
	var found: Array[SimEvent] = []
	if used.is_empty():
		return found
	for i: int in range(events.find(used[0]), events.size()):
		if events[i].tick != used[0].tick:
			break
		found.append(events[i])
	return found


## Gives [param hero] the action [param ability] (ready, anywhere, a one-tick wind-up) and
## returns the events of the two ticks it takes, in a room 16 tiles wide.
func _use_once(hero: Combatant, ability: AbilityDef, others: Array, foes: Array) -> Array[SimEvent]:
	_give(hero, [ability])
	return _run(_battle([hero] + others, foes), 2)


# --- R9 ------------------------------------------------------------------------


## The twelve abilities of R9, by id.
func _twelve() -> Dictionary:
	var t: Dictionary = {}
	var effects: Array = [_fx("DAMAGE", "TARGET", {"multiplier": 1.5})]
	effects.append(_st("STUNNED", 2.0, 0.0, "TARGET"))
	var props: Dictionary = {"anywhere": false, "reach": 1.0, "cooldown": 6.0, "windup": 0.4}
	t["shield_bash"] = _action(&"shield_bash", effects, props)
	props = {"aim": "SELF", "cooldown": 8.0, "windup": 0.2}
	t["taunt"] = _action(&"taunt", [_st("TAUNTING", 4.0, 0.0, "SELF")], props)
	props = {"anywhere": false, "reach": 1.0, "cooldown": 5.0}
	props.merge({"condition": "ENEMIES_AT_LEAST", "condition_count": 2})
	t["whirlwind"] = _action(&"whirlwind", [_fx("DAMAGE", "ENEMIES", {"radius": 2.0})], props)
	effects = [_st("SHIELDED", 5.0, 0.3, "SELF", BY_HEALTH)]
	effects.append(_st("MENDING", 5.0, 0.04, "SELF", BY_HEALTH))
	props = {"trigger_share": 0.3, "once_per_fight": true}
	t["last_stand"] = _passive(&"last_stand", "FALLS_BELOW", effects, props)
	effects = [_fx("DAMAGE", "TARGET", {"multiplier": 3.0})]
	effects.append(_st("BLEEDING", 4.0, 0.3, "TARGET", BY_DAMAGE))
	props = {"aim": "FURTHEST_ENEMY", "anywhere": false, "reach": 1.0, "cooldown": 10.0}
	t["backstab"] = _action(&"backstab", effects, props)
	var low: Dictionary = {"low_health_below": 0.25, "low_multiplier": 2.0}
	props = {"aim": "WEAKEST_ENEMY", "anywhere": false, "reach": 1.0, "cooldown": 4.0}
	props.merge({"condition": "TARGET_BELOW", "condition_share": 0.25})
	t["finisher"] = _action(&"finisher", [_fx("DAMAGE", "TARGET", low)], props)
	effects = [_fx("DAMAGE", "AROUND_TARGET", {"multiplier": 1.2, "radius": 1.0})]
	var burn: Dictionary = {"radius": 1.0}
	burn.merge(BY_DAMAGE)
	effects.append(_st("BURNING", 3.0, 0.2, "AROUND_TARGET", burn))
	props = {"anywhere": false, "reach": 6.0, "cooldown": 6.0, "windup": 0.6}
	t["fireball"] = _action(&"fireball", effects, props)
	effects = [_st("SLOWED", 3.0, 1.5, "ENEMIES", {"radius": 2.5})]
	effects.append(_fx("PUSH", "ENEMIES", {"radius": 2.5, "push_tiles": 2.0}))
	props = {"aim": "SELF", "cooldown": 8.0}
	props.merge({"condition": "ENEMY_WITHIN", "condition_tiles": 1.5})
	t["frost_nova"] = _action(&"frost_nova", effects, props)
	effects = [_fx("DAMAGE", "ENEMIES", {"multiplier": 0.3})]
	t["chain_spark"] = _passive(&"chain_spark", "LANDS_CRIT", effects)
	props = {"aim": "WEAKEST_ALLY", "cooldown": 8.0, "windup": 0.5}
	props.merge({"condition": "ALLY_BELOW", "condition_share": 0.6})
	t["prayer"] = _action(&"prayer", [_fx("HEAL", "ALLIES")], props)
	effects = [_fx("REVIVE", "TARGET", {"revive_share": 0.5})]
	props = {"once_per_fight": true}
	t["guardian_angel"] = _passive(&"guardian_angel", "ALLY_DIES", effects, props)
	effects = [_st("HASTED", 10.0, 0.8, "ALLIES")]
	t["battle_hymn"] = _passive(&"battle_hymn", "FIGHT_STARTS", effects)
	return t


## [param c] with the abilities of [method _twelve] named in [param ids].
func _give_twelve(c: Combatant, ids: Array) -> Combatant:
	var t: Dictionary = _twelve()
	var abilities: Array = []
	for id: String in ids:
		abilities.append(t[id])
	return _give(c, abilities)
