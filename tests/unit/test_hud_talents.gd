extends GutTest
## Unit tests for the talent tree's small pieces (spec 055): every node has a picture of its kind,
## and the text helpers the Talents tab is built from. Since spec 060 the kind is the ability's
## own [member AbilityDef.picture] and the tab is [HeroTalentsTab] in a hero window.

const KIND_NAMES: Array[StringName] = [
	&"strike", &"guard", &"heal", &"fire", &"frost", &"shadow", &"light", &"rally"
]


func test_every_tree_node_has_a_kind_with_a_picture() -> void:
	var sheet: PixelSheet = PixelSheet.load_sheet(TalentNode.ICONS_PATH)
	for kind: StringName in KIND_NAMES:
		assert_true(sheet.has_part(kind), "the sheet draws %s" % kind)
		assert_eq(sheet.part(kind).get_size(), Vector2(12, 12), "%s is 12x12" % kind)
	for class_id: StringName in Content.hero_class_ids():
		var tree: TalentTreeDef = Content.talent_tree(class_id)
		var ids: Array[StringName] = tree.trunk.duplicate()
		ids.append_array(tree.path_a)
		ids.append_array(tree.path_b)
		for id: StringName in ids:
			assert_has(
				KIND_NAMES, Content.ability(id).picture, "%s's kind is one of the eight" % id
			)
			assert_not_null(TalentNode.picture(id), "%s has a picture" % id)


func test_wrap_words_keeps_every_line_inside_the_width() -> void:
	var text: String = "Bashes the nearest enemy for 1.5x damage and stuns it for 1.5 s. Every 8 s."
	var lines: Array[String] = WindowText.wrap(text, 120.0)
	assert_gt(lines.size(), 1, "a long text takes several lines")
	for line: String in lines:
		# The ink: the advance less the spacing after the last letter.
		assert_lte(UiText.width(line) - UiText.SPACING, 120, "'%s' fits" % line)
	assert_eq(" ".join(PackedStringArray(lines)), text, "no word lost or changed")
	assert_eq(WindowText.wrap("Taunt", 120.0), ["Taunt"] as Array[String], "a short text")
	assert_eq(WindowText.wrap("", 120.0), [] as Array[String], "nothing to wrap")


func test_title_and_kind_text() -> void:
	var sim := Simulation.new(7)
	var knight: Hero = sim.party.heroes[0]
	assert_eq(HeroTalentsTab.title(knight), "Knight", "no path yet: the class alone")
	var tree: TalentTreeDef = Content.talent_tree(knight.class_id)
	var walked: Array[StringName] = tree.trunk.duplicate()
	walked.append(tree.path_b[0])
	knight.level = 8
	knight.set_talents(walked)
	assert_eq(HeroTalentsTab.title(knight), "Knight, %s" % tree.path_names[1], "with its path")
	for id: StringName in Content.ability_ids():
		var ability: AbilityDef = Content.ability(id)
		var kind: String = HeroTalentsTab.kind_text(id)
		if ability.is_action():
			assert_string_starts_with(kind, "Action, every ", "%s is an action" % id)
		else:
			assert_eq(kind, "Passive", "%s is a passive" % id)
