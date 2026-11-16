extends GutTest
## Unit tests for the light formula of spec 012 (AmbienceMood), which darkness.gdshader mirrors.


func test_falloff_comes_in_rings() -> void:
	var radius: float = 90.0
	var values: Dictionary[float, bool] = {}
	var last: float = 2.0
	for distance: int in range(0, 100):
		var value: float = AmbienceMood.falloff(distance, radius)
		assert_true(value <= last, "it never gets brighter further out (%d px)" % distance)
		last = value
		values[value] = true
	assert_eq(values.size(), AmbienceMood.STEPS + 1, "STEPS rings and the dark: %s" % [values])
	assert_eq(AmbienceMood.falloff(0.0, radius), 1.0, "full strength at the centre")
	assert_eq(AmbienceMood.falloff(radius, radius), 0.0, "nothing at the edge")
	assert_eq(AmbienceMood.falloff(5.0, 0.0), 0.0, "a light with no reach lights nothing")


func test_light_at_adds_lamps_clamps_and_respects_exposure() -> void:
	var lamp := AmbienceLight.new(&"torch", Vector2(100, 100), 60.0, 2.0, Color.WHITE)
	var lamps: Array[AmbienceLight] = [lamp]
	var none: Array[AmbienceLight] = []
	var dark: Color = AmbienceMood.light_at(Vector2(100, 100), none)
	assert_eq(dark, AmbienceMood.ambient_color(1), "ambient alone with no lamp")
	var lit: Color = AmbienceMood.light_at(Vector2(100, 100), lamps)
	assert_eq(lit, Color(1, 1, 1), "a strong lamp saturates to unlit, never past it")
	var shielded: Color = AmbienceMood.light_at(Vector2(100, 100), lamps, 0.0)
	assert_gt(AmbienceMood.brightness(shielded), AmbienceMood.brightness(dark), "earth is lifted")
	assert_lt(AmbienceMood.brightness(shielded), 0.6, "but no lamp reaches deep earth")
	assert_eq(AmbienceMood.light_at(Vector2(100, -1), none), Color.WHITE, "daylight above")
	assert_gt(AmbienceMood.daylight(4.0), AmbienceMood.daylight(40.0), "daylight fades down")
	assert_eq(AmbienceMood.daylight(400.0), 0.0, "and is gone a few rows down")


func test_stepped_share() -> void:
	assert_eq(AmbienceMood.stepped_share(0.0), 0.0)
	assert_eq(AmbienceMood.stepped_share(1.0), 1.0)
	assert_eq(AmbienceMood.stepped_share(0.49), 0.5)
	assert_eq(AmbienceMood.stepped_share(0.13), 0.25)


func test_flicker_is_stepped_and_repeatable() -> void:
	var a := AmbienceLight.new(&"torch", Vector2.ZERO, 80.0, 1.0, Color.WHITE, 0.2, 7)
	var b := AmbienceLight.new(&"torch", Vector2.ZERO, 80.0, 1.0, Color.WHITE, 0.2, 7)
	var seen: Dictionary[float, bool] = {}
	for frame: int in 120:
		var time: float = frame / 60.0
		a.advance(time)
		b.advance(time)
		assert_eq(a.energy, b.energy, "the same seed flickers the same")
		assert_between(a.energy, 0.8, 1.2, "a flicker is slight")
		assert_eq(a.radius, roundf(a.radius), "the pool's edge moves by whole pixels")
		seen[a.energy] = true
	assert_between(seen.size(), 2, 30, "it changes a few times a second, not every frame")
