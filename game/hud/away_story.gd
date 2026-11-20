class_name AwayStory
extends RefCounted
## What the report after time away says: how long the party was away and what changed, as rows
## of a short list, each a label and a value (a number, where there is one). A row is shown only
## when there is something to say. [AwayWindow] draws it, the values right-aligned.

## The report's title.
const TITLE: String = "While you were away"
## Microskills learned get a row each up to this many, then one "and N more".
const MAX_LEARNED_LINES: int = 4


## One row of the story: its label, its value ("" for none) and its colour.
class Row:
	extends RefCounted

	var label: String
	var value: String
	var colour: StringName

	func _init(label_in: String, value_in: String, colour_in: StringName) -> void:
		label = label_in
		value = value_in
		colour = colour_in

	## The row as one line of text: the label, then the value.
	func text() -> String:
		return label if value.is_empty() else "%s %s" % [label, value]


## Where the party was and is: "Mossy Hollow 3", "Mossy Hollow 3 to 5", or "Mossy
## Hollow 5 to The Claypits 1".
static func where(report: AwayReport) -> String:
	var after: String = PlaceText.of(report.area_after, report.depth_after)
	if report.area_after != report.area_before:
		return "%s to %s" % [PlaceText.of(report.area_before, report.depth_before), after]
	if report.depth_after == report.depth_before:
		return after
	return "%s to %d" % [PlaceText.of(report.area_before, report.depth_before), report.depth_after]


## [param seconds] as hours and minutes: "8h 0m", "1h 5m", "30m".
static func duration(seconds: float) -> String:
	var minutes: int = floori(seconds / 60.0)
	if minutes < 60:
		return "%dm" % minutes
	return "%dh %dm" % [minutes / 60, minutes % 60]


## The rows telling of [param report], in order; [param party] names the heroes.
static func rows(report: AwayReport, party: Party) -> Array[Row]:
	var made: Array[Row] = []
	made.append(Row.new("Away", duration(report.seconds), &"white"))
	made.append(Row.new("Gold", "+" + UiFormat.group_thousands(report.gold_gained), &"yellow"))
	_resource_rows(report, made)
	made.append(Row.new(where(report), "", &"silver"))
	made.append(Row.new("Slain", UiFormat.group_thousands(report.kills), &"silver"))
	made.append(Row.new("Wipes", str(report.wipes), &"silver"))
	_quest_rows(report, made)
	for hero: Hero in party.heroes:
		var gained: int = report.levels_gained.get(hero.id, 0)
		var word: String = "level" if gained == 1 else "levels"
		var colour: StringName = &"green" if gained > 0 else &"steel"
		made.append(Row.new(hero.def().display_name, "+%d %s" % [gained, word], colour))
	_learned_rows(report, party, made)
	if report.upgrades_bought > 0:
		made.append(Row.new("Upgrades bought", str(report.upgrades_bought), &"green"))
	return made


## Guardians slain, side quests done and missed, and the microskill the misses needed most.
static func _quest_rows(report: AwayReport, made: Array[Row]) -> void:
	if report.guardians_slain > 0:
		made.append(
			Row.new("Guardians slain", UiFormat.group_thousands(report.guardians_slain), &"amber")
		)
		var deepest: String = (
			Content.monster(report.deepest_guardian).display_name
			if report.deepest_guardian != &""
			else "?"
		)
		made.append(Row.new("Furthest guardian", deepest, &"amber"))
	if report.side_quests_done > 0:
		made.append(
			Row.new("Side quests done", UiFormat.group_thousands(report.side_quests_done), &"green")
		)
	if report.side_quests_missed > 0:
		made.append(
			Row.new(
				"Side quests missed", UiFormat.group_thousands(report.side_quests_missed), &"orange"
			)
		)
		if report.most_needed_microskill != &"":
			var skill: String = Content.microskill(report.most_needed_microskill).display_name
			made.append(Row.new("Most needed:", skill, &"orange"))


## The resources gathered, on one row: "Gathered 12 glowcaps, 3 clay"; none when nothing was
## gathered. Then the firsts the journal did not see.
static func _resource_rows(report: AwayReport, made: Array[Row]) -> void:
	var parts: PackedStringArray = []
	for id: StringName in Content.resource_ids():
		var gained: int = report.resources_gained.get(id, 0)
		if gained > 0:
			parts.append("%s %s" % [UiFormat.group_thousands(gained), ResourceIcon.plural(id)])
	if not parts.is_empty():
		made.append(Row.new("Gathered", ", ".join(parts), &"tan"))
	for id: StringName in report.resources_first:
		var from: String = PlaceText.area_name(Content.area_of_resource(id))
		made.append(Row.new("First %s, from %s" % [ResourceIcon.plural(id), from], "", &"tan"))


## One row per microskill learned, at most [constant MAX_LEARNED_LINES], then "and N more".
static func _learned_rows(report: AwayReport, party: Party, made: Array[Row]) -> void:
	var ids: Array[StringName] = Content.microskill_ids()
	var shown: int = mini(report.microskills_learned.size(), MAX_LEARNED_LINES)
	for i: int in shown:
		var learned: Vector2i = report.microskills_learned[i]
		var hero: Hero = party.hero(learned.x)
		var who: String = hero.def().display_name if hero != null else "A hero"
		var skill: String = (
			Content.microskill(ids[learned.y]).display_name
			if learned.y >= 0 and learned.y < ids.size()
			else "?"
		)
		made.append(Row.new("%s learned %s" % [who, skill], "", &"cyan"))
	var rest: int = report.microskills_learned.size() - shown
	if rest > 0:
		made.append(Row.new("and %d more" % rest, "", &"steel"))
