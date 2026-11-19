extends ColonyTest
## StatusBook (spec 056): the statuses on every fighter, from the events alone, as the sim keeps
## them: a stronger status put on again takes its new source; a shield wears down by what the
## flagged MISSED events say it absorbed.

const WEAK: int = 1
const STRONG: int = 3
const KNIGHT: int = 1
const FOE: int = Expedition.FIRST_MONSTER_ID + 1

var _book: StatusBook


func before_each() -> void:
	_book = StatusBook.new()
	# Each fighter's damage is 10 times its id; every maximum health is 200.
	_book.power = func(source: int, _receiver: int, scale: int) -> float:
		return 200.0 if scale == AbilityEffect.Scale.RECEIVER_MAX_HEALTH else source * 10.0


func _tell(
	kind: SimEvent.Kind,
	tick: int,
	source: int,
	target: int,
	amount: int,
	ability: StringName,
	status: int
) -> void:
	var event := SimEvent.new(kind, tick, source, target, amount, kind == SimEvent.Kind.MISSED)
	event.ability_id = ability
	event.status = status as AbilityEffect.Status
	_book.observe(event)


func test_a_stronger_status_put_on_again_takes_its_source() -> void:
	var burning: int = AbilityEffect.Status.BURNING
	# Ignite burns for 0.3 of its fighter's damage, Wildfire for 0.15.
	_tell(SimEvent.Kind.STATUS_BEGAN, 0, WEAK, FOE, 30, &"ignite", burning)
	assert_eq(_book.find(FOE, burning).source_id, WEAK, "the first")
	_tell(SimEvent.Kind.STATUS_BEGAN, 5, STRONG, FOE, 30, &"wildfire", burning)
	assert_eq(_book.find(FOE, burning).source_id, STRONG, "4.5 a second beats 3: the new source")
	assert_eq(_book.find(FOE, burning).ability_id, &"wildfire", "and ability")
	assert_eq(_book.find(FOE, burning).begin_tick, 0, "its once-a-second clock stays")
	_tell(SimEvent.Kind.STATUS_BEGAN, 8, WEAK, FOE, 30, &"ignite", burning)
	assert_eq(_book.find(FOE, burning).source_id, STRONG, "a weaker one only moves its end")
	assert_eq(_book.find(FOE, burning).end_tick, 38, "which it does")


func test_a_shield_wears_down_by_what_it_absorbed() -> void:
	var shielded: int = AbilityEffect.Status.SHIELDED
	# Bulwark shields for 0.15 of the knight's maximum health: 30.
	_tell(SimEvent.Kind.STATUS_BEGAN, 0, KNIGHT, KNIGHT, 60, &"bulwark", shielded)
	assert_eq(_book.shield_left(KNIGHT), 1.0, "whole")
	_tell(SimEvent.Kind.MISSED, 2, FOE, KNIGHT, 20, &"", -1)
	assert_almost_eq(_book.shield_left(KNIGHT), 1.0 / 3.0, 0.001, "a third left")
	_tell(SimEvent.Kind.STATUS_BEGAN, 3, KNIGHT, KNIGHT, 60, &"bulwark", shielded)
	assert_eq(_book.shield_left(KNIGHT), 1.0, "put on again whole")
