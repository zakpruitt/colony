extends GutTest
## Unit tests for the parts of spec 050's statuses the acceptance tests reach only through a
## battle: which amount is stronger, and what a fighter's statuses multiply.


func _fighter() -> Combatant:
	var def := HeroClassDef.new()
	def.id = &"unit"
	def.display_name = "Unit"
	def.max_health = 100
	def.damage = 10
	def.attack_interval = 1.0
	def.windup = 0.3
	def.attack_range = 1.0
	def.move_speed = 1.0
	return Combatant.from_hero(def, 1, 1)


func _put(c: Combatant, kind: AbilityEffect.Status, amount: float) -> void:
	c.statuses[kind] = CombatStatus.new(kind, 1, &"test", amount, 0, 10)


func test_stronger_means_further_from_nothing() -> void:
	var haste := CombatStatus.new(AbilityEffect.Status.HASTED, 1, &"a", 0.8, 0, 10)
	assert_true(haste.weaker_than(0.5), "a smaller haste multiplier is stronger")
	assert_false(haste.weaker_than(0.9))
	var weak := CombatStatus.new(AbilityEffect.Status.WEAKENED, 1, &"a", 0.8, 0, 10)
	assert_true(weak.weaker_than(0.5), "a smaller weakening is stronger")
	var burn := CombatStatus.new(AbilityEffect.Status.BURNING, 1, &"a", 3.0, 0, 10)
	assert_true(burn.weaker_than(4.0), "a bigger burn is stronger")
	assert_false(burn.weaker_than(3.0), "an equal one is not")
	assert_eq(burn.end_tick, 10)
	assert_eq(burn.pulse_tick, Simulation.TICKS_PER_SECOND, "it works a second after it began")


func test_multipliers_are_exactly_one_without_statuses() -> void:
	var c: Combatant = _fighter()
	assert_eq(c.dealt_multiplier(), 1.0)
	assert_eq(c.taken_multiplier(), 1.0)
	assert_eq(c.strike_interval_ticks(), c.attack_interval_ticks)
	assert_false(c.has_status(AbilityEffect.Status.STUNNED))


func test_statuses_multiply() -> void:
	var c: Combatant = _fighter()
	_put(c, AbilityEffect.Status.HASTED, 0.5)
	_put(c, AbilityEffect.Status.SLOWED, 1.5)
	assert_eq(c.strike_interval_ticks(), 8, "10 ticks times 0.5 times 1.5, rounded")
	_put(c, AbilityEffect.Status.MIGHTY, 2.0)
	_put(c, AbilityEffect.Status.WEAKENED, 0.5)
	assert_eq(c.dealt_multiplier(), 1.0, "might and weakness cancel")
	_put(c, AbilityEffect.Status.MARKED, 1.25)
	assert_eq(c.taken_multiplier(), 1.25)
	assert_true(c.has_status(AbilityEffect.Status.MARKED))


func test_a_new_battle_clears_what_the_last_left() -> void:
	var c: Combatant = _fighter()
	var action := AbilityDef.new()
	action.id = &"later"
	action.cooldown = 2.0
	c.abilities.append(action)
	_put(c, AbilityEffect.Status.STUNNED, 0.0)
	c.spent[&"once"] = true
	c.strikes = 7
	c.reset_abilities()
	assert_true(c.statuses.is_empty())
	assert_true(c.spent.is_empty())
	assert_eq(c.strikes, 0)
	assert_eq(c.action_ready_tick[&"later"], 20, "not ready at the start: one cooldown in")
	action.ready_at_start = true
	c.reset_abilities()
	assert_eq(c.action_ready_tick[&"later"], 0)
