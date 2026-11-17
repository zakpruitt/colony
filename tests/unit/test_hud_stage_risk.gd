extends GutTest
## The one risk rule (spec 043, shared by spec 053): the depth ladder and the area map both judge
## a stage through StageRisk, so the two cannot drift.

const SEED: int = 7


func test_the_rule() -> void:
	var safe: DepthLadder.Risk = DepthLadder.Risk.SAFE
	var reach: DepthLadder.Risk = DepthLadder.Risk.REACHABLE
	var danger: DepthLadder.Risk = DepthLadder.Risk.DANGEROUS
	# judge(stage, safe stage, level of the stage, lowest hero level)
	assert_eq(StageRisk.judge(3, 3, 3, 1), safe, "at the safe stage")
	assert_eq(StageRisk.judge(4, 3, 4, 3), reach, "level up to lowest + 1")
	assert_eq(StageRisk.judge(5, 3, 5, 3), danger, "beyond")
	assert_eq(StageRisk.judge(1, 1, 6, 2), safe, "safe whatever the level")
	# The map's extra condition: a stage is safe only once reached.
	assert_eq(StageRisk.judge(1, 1, 6, 2, 0), danger, "an area never visited: judged by level")
	assert_eq(StageRisk.judge(1, 1, 6, 5, 0), reach, "within reach")
	assert_eq(StageRisk.judge(1, 1, 6, 2, 1), safe, "reached: safe")


func test_ladder_and_map_agree_here() -> void:
	var sim := Simulation.new(SEED)
	sim.expedition.last_stable_depth = 3
	sim.expedition.deepest_depth = 6
	var world := World.new()
	world.simulation = sim
	add_child_autofree(world)
	world.set_process(false)
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.setup(sim, world, null)
	for level: int in [1, 3, 5, 9]:
		for hero: Hero in sim.party.heroes:
			hero.level = level
		for stage: int in range(1, 12):
			assert_eq(
				hud.area_map.risk(sim.expedition.place, stage),
				hud.ladder.risk(stage),
				"stage %d for level %d" % [stage, level]
			)
