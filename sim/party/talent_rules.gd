class_name TalentRules
extends RefCounted
## The rules of talent and paragon points that do not need a hero (spec 051), beside [Hero].


## How many talent points a hero of level [param level_number] has earned: one at every
## [constant Hero.TALENT_EVERY]th level, up to [constant Hero.TALENT_POINTS].
static func talent_points_at(level_number: int) -> int:
	return clampi(floori(float(level_number) / Hero.TALENT_EVERY), 0, Hero.TALENT_POINTS)


## How many paragon points a hero of level [param level_number] has earned: one for every level
## after the one that earned the last talent point.
static func paragon_points_at(level_number: int) -> int:
	return maxi(level_number - Hero.TALENT_POINTS * Hero.TALENT_EVERY, 0)


## The [TrainingDef] that names paragon stat [param stat], or null.
static func stat_def(stat: TrainingDef.Stat) -> TrainingDef:
	for training_id: StringName in Content.training_ids():
		var found: TrainingDef = Content.training(training_id)
		if found.stat == stat:
			return found
	return null
