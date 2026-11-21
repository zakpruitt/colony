extends ColonyTest
## Acceptance tests for specs/069-sim-tidy/spec.md. R1 is the unedited suite and the lead's
## comparison of the sim JSON; R2 is held by the check's harness step; R3, R6 and R7 are for the
## reviewer.


func test_r5_every_def_reports_a_missing_name_the_same_way() -> void:
	var named: PackedStringArray = ["id is empty", "display_name is empty", "description is empty"]
	# What each def, made with its id, name and third text empty, reported first on dev.
	var expected: Dictionary = {
		"TrainingDef": [TrainingDef.new(), named],
		"MicroskillDef": [MicroskillDef.new(), named],
		"UpgradeDef": [UpgradeDef.new(), named],
		"SideQuestDef": [SideQuestDef.new(), named],
		"AbilityDef": [AbilityDef.new(), named],
		"ResourceDef":
		[
			ResourceDef.new(),
			PackedStringArray(["id is empty", "display_name is empty", "plural is empty"])
		],
		"AreaDef": [AreaDef.new(), PackedStringArray(["id is empty", "display_name is empty"])],
	}
	for def_name: String in expected:
		var entry: Array = expected[def_name]
		var def: Resource = entry[0]
		var wanted: PackedStringArray = entry[1]
		var problems: PackedStringArray = def.call("validate")
		assert_eq(
			problems.slice(0, wanted.size()), wanted, "%s reports them first, in order" % def_name
		)
		if wanted.size() == 2:
			assert_false(problems.has("description is empty"), "%s has no third text" % def_name)
	var names: PackedStringArray = ["id is empty", "display_name is empty"]
	assert_eq(DefChecks.naming_problems(&"", "", "", ""), names, "no third check without a field")
	assert_eq(DefChecks.naming_problems(&"a", "A", "x", "plural"), PackedStringArray(), "all set")
	assert_eq(
		DefChecks.naming_problems(&"a", "A", "", "plural"), PackedStringArray(["plural is empty"])
	)
