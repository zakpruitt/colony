extends ColonyTest
## Unit tests for Hero and Party (spec 005).


func _def() -> HeroClassDef:
	var def := HeroClassDef.new()
	def.id = &"test_hero"
	def.display_name = "Test hero"
	def.role = HeroClassDef.Role.MELEE
	def.max_health = 100
	def.damage = 10
	def.health_per_level = 10
	def.damage_per_level = 2
	def.attack_interval = 1.0
	def.windup = 0.3
	def.attack_range = 1.0
	def.move_speed = 2.0
	return def


func test_negative_xp_is_ignored() -> void:
	var hero := Hero.new(1, _def())
	hero.gain_xp(-10)
	assert_eq(hero.xp, 0)
	assert_eq(hero.level, 1)


func test_a_dead_hero_is_not_alive_and_fights_dead() -> void:
	var hero := Hero.new(1, _def())
	hero.health = 0
	assert_false(hero.is_alive())
	assert_eq(hero.combatant().health, 0)


func test_combatant_carries_id_class_and_level() -> void:
	var hero := Hero.new(7, _def())
	hero.gain_xp(Hero.xp_for_level(3))
	var c: Combatant = hero.combatant()
	assert_eq(c.id, 7)
	assert_eq(c.def_id, &"test_hero")
	assert_eq(c.level, 3)
	assert_eq(c.max_health, 120)
	assert_eq(c.damage, 14)


func test_party_lookup_and_alive() -> void:
	var party := Party.new()
	assert_null(party.hero(99), "no such hero")
	assert_true(party.any_alive())
	for hero: Hero in party.heroes:
		hero.health = 0
	assert_false(party.any_alive())


func test_hash_parts_follow_party_state() -> void:
	var a := Party.new()
	var b := Party.new()
	assert_eq(hash(a.hash_parts()), hash(b.hash_parts()))
	b.heroes[2].xp += 1
	assert_ne(hash(a.hash_parts()), hash(b.hash_parts()))
