class_name AwayReport
extends RefCounted
## What the party did while the game was closed: filled in by an [AwayReplay] and
## shown to the player by an [AwayWindow].

## How long the game was away, after the 8-hour cap, in seconds.
var seconds: float
## Gold the party earned.
var gold_gained: int
## Each resource the party gathered, by id: drops and quests, before any was
## spent.
var resources_gained: Dictionary[StringName, int] = {}
## The resources the party gathered for the first time while away, in the order it did: the
## journal, which did not see them, notes no first for them.
var resources_first: Array[StringName] = []
## Levels each hero gained, by hero id.
var levels_gained: Dictionary[int, int] = {}
## The depth the party was at when the save loaded, and when the replay ended.
var depth_before: int
var depth_after: int
## The area those depths are stages of, before and after.
var area_before: StringName
var area_after: StringName
## Monsters slain: monster deaths, not gains of gold.
var kills: int
## Times the whole party fell.
var wipes: int
## Camp upgrades auto-buy bought.
var upgrades_bought: int
## Guardians slain, and the monster def id of the deepest one, or &"".
var guardians_slain: int
var deepest_guardian: StringName
## Quests done and walked past for want of a microskill.
var quests_done: int
var quests_missed: int
## The microskill the missed quests needed most often, or &"" when nothing was missed.
var most_needed_microskill: StringName
## Caches opened on side paths (what they paid is in the gold, the resources and the levels).
var caches_opened: int
## The kind of gate passed most often with nobody able to open it, a [GateDef] id, and how many
## times; &"" and 0 when none was.
var most_sealed_gate: StringName
var gates_sealed: int
## Each microskill learned, in order: (hero id, position in [method Content.microskill_ids]).
var microskills_learned: Array[Vector2i] = []
