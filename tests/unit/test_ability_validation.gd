extends GutTest
## Unit tests for spec 050's AbilityDef and AbilityEffect validation, beyond the cases R1 shows.


func _effect(does: AbilityEffect.Does, lands: AbilityEffect.Lands) -> AbilityEffect:
	var effect := AbilityEffect.new()
	effect.does = does
	effect.lands = lands
	return effect


func _status(kind: AbilityEffect.Status, amount: float) -> AbilityEffect:
	var effect: AbilityEffect = _effect(AbilityEffect.Does.STATUS, AbilityEffect.Lands.SELF)
	effect.status = kind
	effect.seconds = 1.0
	effect.amount = amount
	return effect


func _ability(kind: AbilityDef.Kind, effect: AbilityEffect) -> AbilityDef:
	var ability := AbilityDef.new()
	ability.id = &"unit"
	ability.display_name = "Unit"
	ability.description = "A test."
	ability.kind = kind
	ability.anywhere = true
	ability.effects.append(effect)
	return ability


func test_each_status_amount_must_do_something() -> void:
	var good: Dictionary = {
		AbilityEffect.Status.STUNNED: 0.0,
		AbilityEffect.Status.TAUNTING: 0.0,
		AbilityEffect.Status.SHIELDED: 0.2,
		AbilityEffect.Status.BURNING: 0.2,
		AbilityEffect.Status.BLEEDING: 0.2,
		AbilityEffect.Status.MENDING: 0.2,
		AbilityEffect.Status.HASTED: 0.8,
		AbilityEffect.Status.SLOWED: 1.5,
		AbilityEffect.Status.MIGHTY: 1.5,
		AbilityEffect.Status.WEAKENED: 0.8,
		AbilityEffect.Status.MARKED: 1.5,
		AbilityEffect.Status.NIMBLE: 0.3,
	}
	var bad: Dictionary = {
		AbilityEffect.Status.SHIELDED: 0.0,
		AbilityEffect.Status.BURNING: -1.0,
		AbilityEffect.Status.HASTED: 1.0,
		AbilityEffect.Status.SLOWED: 0.9,
		AbilityEffect.Status.MIGHTY: 1.0,
		AbilityEffect.Status.WEAKENED: 0.0,
		AbilityEffect.Status.MARKED: 1.0,
		AbilityEffect.Status.NIMBLE: 1.5,
	}
	for kind: int in good:
		var amount: float = good[kind]
		var effect: AbilityEffect = _status(kind as AbilityEffect.Status, amount)
		assert_eq(effect.validate(), PackedStringArray(), "%d at %s" % [kind, amount])
	for kind: int in bad:
		var amount: float = bad[kind]
		var effect: AbilityEffect = _status(kind as AbilityEffect.Status, amount)
		assert_eq(effect.validate().size(), 1, "%d at %s" % [kind, amount])


func test_effect_numbers() -> void:
	var heal: AbilityEffect = _effect(AbilityEffect.Does.HEAL, AbilityEffect.Lands.SELF)
	assert_eq(heal.validate(), PackedStringArray())
	heal.scale = AbilityEffect.Scale.FIGHTER_DAMAGE
	assert_eq(heal.validate().size(), 1, "a heal is not a multiple of damage")
	var push: AbilityEffect = _effect(AbilityEffect.Does.PUSH, AbilityEffect.Lands.TARGET)
	assert_eq(push.validate().size(), 1, "a push of no tiles")
	var hit: AbilityEffect = _effect(AbilityEffect.Does.DAMAGE, AbilityEffect.Lands.TARGET)
	hit.life_steal = 1.5
	hit.low_health_below = 0.3
	assert_eq(hit.validate().size(), 2, "too much life steal; a low-health bonus of nothing")
	hit.radius = -1.0
	assert_eq(hit.validate().size(), 3)


func test_sides_by_trigger() -> void:
	var revive: AbilityEffect = _effect(AbilityEffect.Does.REVIVE, AbilityEffect.Lands.TARGET)
	revive.revive_share = 0.5
	var guardian: AbilityDef = _ability(AbilityDef.Kind.PASSIVE, revive)
	guardian.trigger = AbilityDef.Trigger.ALLY_DIES
	assert_eq(guardian.validate(), PackedStringArray(), "a fallen ally can be revived")
	guardian.trigger = AbilityDef.Trigger.KILLS
	assert_eq(guardian.validate().size(), 1, "a killed enemy cannot")

	var explode: AbilityEffect = _effect(
		AbilityEffect.Does.DAMAGE, AbilityEffect.Lands.AROUND_TARGET
	)
	explode.radius = 2.0
	var on_kill: AbilityDef = _ability(AbilityDef.Kind.PASSIVE, explode)
	on_kill.trigger = AbilityDef.Trigger.KILLS
	assert_eq(on_kill.validate(), PackedStringArray(), "around the dead is fine")
	on_kill.trigger = AbilityDef.Trigger.FIGHT_STARTS
	assert_eq(on_kill.validate().size(), 1, "around the fighter itself hurts its side")

	var bless: AbilityDef = _ability(
		AbilityDef.Kind.ACTION, _status(AbilityEffect.Status.MIGHTY, 1.5)
	)
	bless.effects[0].lands = AbilityEffect.Lands.TARGET
	bless.aim = AbilityDef.Aim.WEAKEST_ALLY
	assert_eq(bless.validate(), PackedStringArray(), "a buff on an ally")
	bless.aim = AbilityDef.Aim.WEAKEST_ENEMY
	assert_eq(bless.validate().size(), 1, "a buff on an enemy")


func test_action_and_passive_numbers() -> void:
	var hit: AbilityEffect = _effect(AbilityEffect.Does.DAMAGE, AbilityEffect.Lands.TARGET)
	var action: AbilityDef = _ability(AbilityDef.Kind.ACTION, hit)
	action.cooldown = -1.0
	action.condition = AbilityDef.Condition.ENEMIES_AT_LEAST
	assert_eq(action.validate().size(), 2, "a negative cooldown; at least 0 enemies")
	action.cooldown = 0.0
	action.condition = AbilityDef.Condition.SELF_BELOW
	action.condition_share = 1.5
	assert_eq(action.validate().size(), 1, "a share above 1")
	var passive: AbilityDef = _ability(
		AbilityDef.Kind.PASSIVE, _status(AbilityEffect.Status.MIGHTY, 1.5)
	)
	passive.trigger = AbilityDef.Trigger.FALLS_BELOW
	passive.trigger_share = 1.0
	assert_eq(passive.validate().size(), 1, "it can never fall below all its health")
