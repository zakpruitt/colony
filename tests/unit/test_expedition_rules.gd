extends ColonyTest
## More checks of spec 005's rules, here because the acceptance file is at gdlint's
## 1000-line limit: a level-up during a fight (R8), the battle limit and a wipe on
## depth 1 (R11), and a command given while the party is down (R13).

const SEED: int = 1234
const EPSILON: float = 0.001


## Steps until an event of [param kind] appears (that step included); returns that step's events.
func _step_to_kind(sim: Simulation, kind: SimEvent.Kind, limit: int) -> Array[SimEvent]:
	for i: int in limit:
		sim.step()
		var fresh: Array[SimEvent] = sim.drain_events()
		if not _of_kind(fresh, kind).is_empty():
			return fresh
	fail_test("no %s within %d ticks" % [SimEvent.Kind.keys()[kind], limit])
	return []


## Puts the party on depth 1 one step outside its first populated chamber, walking in.
func _approach_first_fight(sim: Simulation) -> void:
	var e: Expedition = sim.expedition
	sim.set_auto_push(false)
	for room: LabyrinthChamber in sim.labyrinth.level(1).chambers:
		if e.is_populated(1, room.index):
			e.x = room.rect.position.x - 0.1
			e.facing = 1
			return


func test_r8_level_up_during_a_fight() -> void:
	var sim := Simulation.new(SEED)
	_approach_first_fight(sim)
	for hero: Hero in sim.party.heroes:
		hero.xp = Hero.xp_for_level(2) - 1
	sim.step()
	var fight: Battle = sim.expedition.battle
	assert_not_null(fight)
	if fight == null:
		return
	var knight: Combatant = fight.combatant(1)
	var def: HeroClassDef = Content.hero_class(&"knight")
	var max_before: int = knight.max_health
	var damage_before: int = knight.damage
	var health_before: int = knight.health
	var events: Array[SimEvent] = []
	for i: int in 3000:
		health_before = knight.health
		sim.step()
		events = sim.drain_events()
		if not _of_kind(events, SimEvent.Kind.LEVEL_UP).is_empty():
			break
	assert_true(knight.is_alive(), "the knight was standing when the monster fell")
	# What the fight itself did to the knight on that tick, before the level was added.
	var change: int = 0
	for e: SimEvent in events:
		if e.target_id == 1 and e.kind == SimEvent.Kind.HIT:
			change -= e.amount
		elif e.target_id == 1 and e.kind == SimEvent.Kind.HEALED:
			change += e.amount
	assert_eq(knight.level, 2, "the fighter is level 2 in the battle")
	assert_eq(knight.max_health, max_before + def.health_per_level, "max health grew mid-fight")
	assert_eq(knight.damage, damage_before + def.damage_per_level, "damage grew mid-fight")
	assert_eq(knight.health, health_before + change + def.health_per_level, "healed by the gain")
	assert_eq(sim.party.hero(1).level, 2)


func test_r11_a_fight_past_the_limit_overwhelms_the_party() -> void:
	var sim := Simulation.new(SEED)
	_approach_first_fight(sim)
	for id: int in [1, 2, 3]:
		sim.party.hero(id).health = 0  # a lone cleric
	sim.step()
	var fight: Battle = sim.expedition.battle
	assert_not_null(fight)
	if fight == null:
		return
	for m: Combatant in fight.monsters:  # it can neither win nor lose
		m.max_health = 1_000_000
		m.health = m.max_health
		m.damage = 1
	var limit: int = ticks_in(Expedition.BATTLE_LIMIT_SECONDS)
	while fight.tick < limit - 1:
		sim.step()
		sim.drain_events()
	assert_eq(
		sim.expedition.state, Expedition.State.FIGHTING, "still fighting just before the limit"
	)
	assert_true(fight.combatant(4).is_alive(), "the cleric is holding on")
	sim.step()
	var events: Array[SimEvent] = sim.drain_events()
	assert_eq(fight.tick, limit)
	var deaths: Array[SimEvent] = _of_kind(events, SimEvent.Kind.DIED)
	assert_eq(deaths.size(), 1, "one death event, for the hero still standing")
	if deaths.size() == 1:
		assert_eq(deaths[0].source_id, 4)
		assert_eq(deaths[0].tick, sim.tick)
	var ended: Array[SimEvent] = _of_kind(events, SimEvent.Kind.ENCOUNTER_ENDED)
	assert_eq(ended.size(), 1)
	if ended.size() == 1:
		assert_false(ended[0].flag, "the heroes lost")
	assert_eq(_of_kind(events, SimEvent.Kind.PARTY_WIPED).size(), 1, "the party is wiped")
	assert_eq(sim.expedition.state, Expedition.State.REVIVING)
	for hero: Hero in sim.party.heroes:
		assert_eq(hero.health, 0)


func test_r11_a_wipe_on_depth_1_revives_in_the_start_chamber() -> void:
	var sim := Simulation.new(SEED)
	sim.set_auto_push(false)
	sim.step()
	for hero: Hero in sim.party.heroes:
		hero.health = 0
	_step_to_kind(sim, SimEvent.Kind.PARTY_WIPED, 5)
	_step_to_kind(sim, SimEvent.Kind.PARTY_REVIVED, ticks_in(Expedition.REVIVE_SECONDS) + 1)
	var start: LabyrinthChamber = sim.expedition.chamber()
	assert_not_null(start)
	if start == null:
		return
	assert_eq(start.kind, LabyrinthChamber.Kind.START, "back in the START chamber")
	var middle: float = (start.rect.position.x + start.rect.end.x - 1) / 2.0
	assert_almost_eq(sim.expedition.x, middle, EPSILON, "in its middle")
	assert_eq(sim.expedition.depth, 1)
	for hero: Hero in sim.party.heroes:
		assert_eq(hero.health, hero.max_health())


func test_r13_a_target_set_while_down_wins_over_the_fallback() -> void:
	var sim := Simulation.new(SEED)
	sim.set_auto_push(false)
	sim.expedition.depth = 2
	sim.expedition.target_depth = 2
	sim.expedition.x = sim.labyrinth.shaft_column(1)
	sim.step()
	for hero: Hero in sim.party.heroes:
		hero.health = 0
	_step_to_kind(sim, SimEvent.Kind.PARTY_WIPED, 5)
	sim.set_target_depth(3)
	var revived: Array[SimEvent] = _step_to_kind(
		sim, SimEvent.Kind.PARTY_REVIVED, ticks_in(Expedition.REVIVE_SECONDS) + 1
	)
	assert_eq(sim.expedition.depth, 1, "fell back to the last stable depth")
	assert_eq(sim.expedition.target_depth, 3, "the player's target, not the fallback")
	var targets: Array[SimEvent] = _of_kind(revived, SimEvent.Kind.TARGET_DEPTH_CHANGED)
	assert_gt(targets.size(), 0)
	if targets.size() > 0:
		assert_eq(targets[-1].amount, 3, "the last target reported is the player's")
