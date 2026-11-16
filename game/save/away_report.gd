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
## Monsters slain.
var kills: int
## Times the whole party fell.
var wipes: int
## Camp upgrades auto-buy bought (spec 022).
var upgrades_bought: int
