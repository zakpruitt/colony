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
