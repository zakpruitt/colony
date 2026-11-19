extends ColonyTest
## AbilityCredit (spec 056): what each blow and heal was, from the events alone and in their order.

const KNIGHT: int = 1
const MAGE: int = 3
const CLERIC: int = 4
const FOE: int = Expedition.FIRST_MONSTER_ID + 1
const OTHER_FOE: int = Expedition.FIRST_MONSTER_ID + 2

var _credit: AbilityCredit


func before_each() -> void:
	_credit = AbilityCredit.new()


func _tell(
	kind: SimEvent.Kind,
	tick: int,
	source: int,
	target: int,
	amount: int = 0,
	ability: StringName = &"",
	status: int = -1
) -> void:
	var event := SimEvent.new(kind, tick, source, target, amount)
	event.ability_id = ability
	if status >= 0:
		event.status = status as AbilityEffect.Status
	_credit.observe(event)


func test_an_action_keeps_its_hits_past_a_passive_that_fires_between() -> void:
	_tell(SimEvent.Kind.ABILITY_USED, 10, MAGE, FOE, 0, &"meteor")
	_tell(SimEvent.Kind.HIT, 10, MAGE, FOE, 40)
	assert_eq(_credit.ability_id, &"meteor", "the first receiver")
	_tell(SimEvent.Kind.ABILITY_USED, 10, MAGE, FOE, 0, &"ignite")
	_tell(SimEvent.Kind.STATUS_BEGAN, 10, MAGE, FOE, 30, &"ignite", AbilityEffect.Status.BURNING)
	_tell(SimEvent.Kind.HIT, 10, MAGE, OTHER_FOE, 40)
	assert_eq(_credit.ability_id, &"meteor", "the second, after Ignite fired")


func test_a_passive_that_deals_nothing_is_never_credited_with_damage() -> void:
	_tell(SimEvent.Kind.ATTACK_STARTED, 0, MAGE, FOE, 5)
	_tell(SimEvent.Kind.HIT, 5, MAGE, FOE, 20)
	assert_eq(_credit.ability_id, &"", "the strike")
	_tell(SimEvent.Kind.ABILITY_USED, 5, MAGE, FOE, 0, &"wildfire")
	_tell(
		SimEvent.Kind.STATUS_BEGAN,
		5,
		MAGE,
		OTHER_FOE,
		30,
		&"wildfire",
		AbilityEffect.Status.BURNING
	)
	_tell(SimEvent.Kind.HIT, 5, MAGE, OTHER_FOE, 20)
	assert_ne(_credit.ability_id, &"wildfire", "Wildfire deals nothing itself")
	assert_eq(_credit.label(), AbilityCredit.STRIKES, "a blow begun before")


func test_a_heal_goes_only_to_what_heals() -> void:
	_tell(SimEvent.Kind.ABILITY_USED, 3, MAGE, FOE, 0, &"meteor")
	_tell(SimEvent.Kind.HEALED, 3, MAGE, MAGE, 10)
	assert_eq(_credit.ability_id, &"", "Meteor heals nobody")
	assert_eq(_credit.label(true), AbilityCredit.HEALS, "an ordinary heal")
	_tell(SimEvent.Kind.ABILITY_USED, 4, CLERIC, KNIGHT, 0, &"prayer")
	_tell(SimEvent.Kind.HEALED, 4, CLERIC, KNIGHT, 30)
	assert_eq(_credit.ability_id, &"prayer", "Prayer heals")


func test_a_wind_up_an_action_replaced_is_lost() -> void:
	_tell(SimEvent.Kind.ATTACK_STARTED, 0, KNIGHT, FOE, 4)
	_tell(SimEvent.Kind.ABILITY_STARTED, 1, KNIGHT, FOE, 3, &"shield_bash")
	_tell(SimEvent.Kind.ABILITY_USED, 4, KNIGHT, FOE, 0, &"shield_bash")
	_tell(SimEvent.Kind.HIT, 4, KNIGHT, FOE, 45)
	assert_eq(_credit.ability_id, &"shield_bash", "the action's blow, not the lost strike's")


func test_a_wind_up_a_stun_or_a_death_ended_is_lost() -> void:
	_tell(SimEvent.Kind.ATTACK_STARTED, 0, KNIGHT, FOE, 4)
	_tell(
		SimEvent.Kind.STATUS_BEGAN, 1, FOE, KNIGHT, 20, &"shield_bash", AbilityEffect.Status.STUNNED
	)
	_tell(SimEvent.Kind.ABILITY_USED, 4, KNIGHT, FOE, 0, &"whirlwind")
	_tell(SimEvent.Kind.HIT, 4, KNIGHT, FOE, 30)
	assert_eq(_credit.ability_id, &"whirlwind", "a stun took the strike's wind-up")
	_tell(SimEvent.Kind.ATTACK_STARTED, 10, KNIGHT, FOE, 4)
	_tell(SimEvent.Kind.ATTACK_STARTED, 10, FOE, KNIGHT, 4)
	_tell(SimEvent.Kind.DIED, 11, FOE, -1)
	assert_false(_credit._windups.has(KNIGHT), "a wind-up at the fallen is lost")
	assert_false(_credit._windups.has(FOE), "and the fallen's own")


func test_a_strike_boost_takes_its_strike_and_its_life_steal() -> void:
	_tell(SimEvent.Kind.ATTACK_STARTED, 0, KNIGHT, FOE, 4)
	_tell(SimEvent.Kind.ABILITY_USED, 4, KNIGHT, FOE, 0, &"reckless_swing")
	_tell(SimEvent.Kind.HIT, 4, KNIGHT, FOE, 60)
	assert_eq(_credit.ability_id, &"reckless_swing", "the boosted strike")
	_tell(SimEvent.Kind.HEALED, 4, KNIGHT, KNIGHT, 30)
	assert_eq(_credit.ability_id, &"reckless_swing", "its life steal")
