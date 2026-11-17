extends GutTest
## Unit tests for the HUD's small pieces: the gold format and the eased bar value.


func test_group_thousands() -> void:
	assert_eq(Hud.group_thousands(0), "0")
	assert_eq(Hud.group_thousands(999), "999")
	assert_eq(Hud.group_thousands(1000), "1,000")
	assert_eq(Hud.group_thousands(12345), "12,345")
	assert_eq(Hud.group_thousands(1234567), "1,234,567")
	assert_eq(Hud.group_thousands(-4500), "-4,500")


func test_eased_value_settles_on_its_goal() -> void:
	var eased := EasedValue.new(0.3)
	eased.snap(1.0)
	eased.advance(0.0, 0.1)
	assert_between(eased.value, 0.0, 1.0, "partway")
	var first: float = 1.0 - eased.value
	eased.advance(0.0, 0.1)
	var second: float = (1.0 - first) - eased.value
	assert_lt(second, first, "fast at first, then slower")
	eased.advance(0.0, 0.1)
	assert_eq(eased.value, 0.0, "exactly on the goal after its time")


func test_eased_value_restarts_from_where_it_is() -> void:
	var eased := EasedValue.new(0.3)
	eased.snap(1.0)
	eased.advance(0.0, 0.15)
	var midway: float = eased.value
	eased.advance(1.0, 0.0)
	assert_eq(eased.value, midway, "a new goal starts from the value shown, never jumps")
	eased.advance(1.0, 0.3)
	assert_eq(eased.value, 1.0)


func test_hero_sheet_tiles_reads_as_words() -> void:
	assert_eq(HeroSheet.tiles(7.0), "7", "whole tiles without a decimal")
	assert_eq(HeroSheet.tiles(6.5), "6.5", "a half tile with one")
	assert_eq(HeroSheet.tiles(1.75), "1.8", "one decimal at most")


func test_hero_sheet_eases_its_bars_but_not_its_numbers() -> void:
	var sim := Simulation.new(5)
	var sheet := HeroSheet.new()
	add_child_autofree(sheet)
	sheet.setup(sim, null)
	var hero: Hero = sim.party.heroes[0]
	sheet.open(hero.id)
	assert_eq(sheet.bar_fraction(&"health"), 1.0, "opening shows the bar at once")
	hero.health = hero.max_health() / 2
	sheet.advance(0.05)
	assert_eq(sheet.line(&"health"), "%d / %d" % [hero.health, hero.max_health()], "numbers jump")
	assert_gt(sheet.bar_fraction(&"health"), 0.5, "the bar eases")
	sheet.advance(HeroFrame.EASE_SECONDS)
	var half: float = float(hero.health) / hero.max_health()
	assert_almost_eq(sheet.bar_fraction(&"health"), half, 0.001, "and arrives")
	sheet.open(sim.party.heroes[1].id)
	assert_eq(sheet.bar_fraction(&"health"), 1.0, "switching hero snaps to the new hero's bar")
