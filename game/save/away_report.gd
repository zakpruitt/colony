class_name AwayReport
extends RefCounted
## What the party did while the game was closed (spec 019): filled in by an [AwayReplay] and
## shown to the player by an [AwayPanel].

## How long the game was away, after the 8-hour cap, in seconds.
var seconds: float
## Gold the party earned.
var gold_gained: int
## Levels each hero gained, by hero id.
var levels_gained: Dictionary[int, int] = {}
## The depth the party was at when the save loaded, and when the replay ended.
var depth_before: int
var depth_after: int
## Monsters slain: monster deaths, not gains of gold (spec 031).
var kills: int
## Times the whole party fell.
var wipes: int
## Camp upgrades auto-buy bought (spec 022).
var upgrades_bought: int
## Guardians slain (spec 031), and the monster def id of the deepest one, or &"".
var guardians_slain: int
var deepest_guardian: StringName
## Side quests done and walked past for want of a microskill (spec 031).
var side_quests_done: int
var side_quests_missed: int
## The microskill the missed side quests needed most often, or &"" when nothing was missed.
var most_needed_microskill: StringName
## Each microskill learned, in order: (hero id, position in [method Content.microskill_ids]).
var microskills_learned: Array[Vector2i] = []
