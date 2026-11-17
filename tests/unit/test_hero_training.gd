extends GutTest
## Unit tests for a hero's training ranks (spec 029).


func _knight() -> Hero:
	return Hero.new(1, Content.hero_class(&"knight"))


func test_ranks_are_clamped_and_unknown_ids_ignored() -> void:
	var hero: Hero = _knight()
	hero.set_training_rank(&"power", 99)
	assert_eq(hero.training_rank(&"power"), 20, "clamped to the maximum")
	hero.set_training_rank(&"power", -4)
	assert_eq(hero.training_rank(&"power"), 0, "clamped to 0")
	assert_false(hero.is_trained(), "rank 0 is untrained")
	hero.set_training_rank(&"agility", 3)
	assert_eq(hero.training_rank(&"agility"), 0, "an unknown training is ignored")
	assert_false(hero.is_trained())


func test_untrained_numbers_are_the_class_numbers() -> void:
	var hero: Hero = _knight()
	var base: Combatant = Combatant.from_hero(hero.def(), hero.level, hero.id)
	var made: Combatant = hero.combatant()
	assert_eq(made.damage, base.damage)
	assert_eq(made.max_health, base.max_health)
	assert_eq(made.attack_interval_ticks, base.attack_interval_ticks)
	for stat: TrainingDef.Stat in TrainingDef.Stat.values():
		assert_eq(hero.training_multiplier(stat), 1.0, "no bonus for %d" % stat)


func test_each_training_raises_only_its_stat() -> void:
	var hero: Hero = _knight()
	var base: Combatant = hero.combatant()
	hero.set_training_rank(&"toughness", 10)
	var tough: Combatant = hero.combatant()
	assert_eq(tough.max_health, roundi(base.max_health * 1.5), "+50% health")
	assert_eq(tough.damage, base.damage, "damage untouched")
	assert_eq(tough.attack_interval_ticks, base.attack_interval_ticks, "speed untouched")
	hero.set_training_rank(&"toughness", 0)
	hero.set_training_rank(&"quickness", 10)
	var quick: Combatant = hero.combatant()
	assert_lt(quick.attack_interval_ticks, base.attack_interval_ticks, "quicker")
	assert_eq(quick.max_health, base.max_health, "health untouched")
	assert_eq(quick.damage, base.damage, "damage untouched")


func test_a_trained_hero_hashes_its_ranks() -> void:
	var party := Party.new()
	var before: Array = party.hash_parts()
	party.heroes[2].set_training_rank(&"quickness", 1)
	assert_ne(party.hash_parts(), before, "a rank is part of the state")
	party.heroes[2].set_training_rank(&"quickness", 0)
	assert_eq(party.hash_parts(), before, "back to untrained, back to the old hash")
