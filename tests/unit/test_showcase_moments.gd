extends ColonyTest
## Spec 053's showcase moments stand on their own: each can be started with skip_to and shows
## what it is about well before the showcase gives up on it.

const SHOWCASE_SCENE: String = "res://game/dev/showcase.tscn"
const FRAME: float = 1.0 / 30.0


func _run_moment(moment: StringName) -> Showcase:
	var showcase: Showcase = (load(SHOWCASE_SCENE) as PackedScene).instantiate() as Showcase
	add_child_autofree(showcase)
	showcase.set_process(false)
	showcase.skip_to(moment)
	var start: float = showcase.elapsed
	while showcase.moment() == moment and showcase.elapsed - start < Showcase.GIVE_UP_SECONDS:
		showcase.advance(FRAME)
		if showcase.evidence.has(moment):
			break
	return showcase


func test_journey_on_its_own() -> void:
	var showcase: Showcase = _run_moment(&"journey")
	assert_true(showcase.evidence.has(&"journey"), "the party arrives in the Claypits")
	assert_eq(showcase.main.simulation.expedition.place, &"claypits", "it is there")


func test_area_map_on_its_own() -> void:
	var showcase: Showcase = _run_moment(&"area_map")
	assert_true(showcase.evidence.has(&"area_map"), "the map opens")
	assert_true(showcase.main.simulation.is_area_open(&"claypits"), "with the Claypits open")
