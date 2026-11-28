class_name SummonDef
extends Resource
## A short-lived fighter an ability brings onto the heroes' side: a sub-resource of the
## [AbilityEffect] that summons it, as that effect is of its [AbilityDef]. Its health, damage and
## healing are shares of its summoner's at the moment it comes; the rest are its own.

## Names the summon's sheet and its line in the tally.
@export var id: StringName
@export var display_name: String
## Shares of the summoner's maximum health, damage and healing power. With no damage share it
## makes no ordinary strike and acts only through its abilities (an aura); with no healing share
## it never heals.
@export var health_share: float = 0.3
@export var damage_share: float = 0.3
@export var heal_share: float = 0.0
@export var armor: int = 0
@export var crit_chance: float = 0.0
## Seconds.
@export var attack_interval: float = 1.2
@export var windup: float = 0.2
## Tiles.
@export var attack_range: float = 1.0
## Tiles per second; 0 for one that never moves (a turret, a totem).
@export var move_speed: float = 0.0
## Tiles from its summoner toward the enemy where it appears.
@export var ahead: float = 1.0
## How long it stays, in seconds.
@export var seconds: float = 10.0
## The ids of the abilities it fights with; empty for none.
@export var abilities: Array[StringName] = []


## One line per problem; empty when the summon can fight. Its abilities must be known to
## [Content], and none of them may summon in turn.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = DefChecks.naming_problems(id, display_name)
	if health_share <= 0.0:
		problems.append("health_share %s is not positive" % health_share)
	for share: Array in [["damage_share", damage_share], ["heal_share", heal_share]]:
		if (share[1] as float) < 0.0:
			problems.append("%s %s is negative" % share)
	if seconds <= 0.0:
		problems.append("seconds %s is not positive" % seconds)
	if armor < 0:
		problems.append("armor %d is negative" % armor)
	for distance: Array in [["move_speed", move_speed], ["ahead", ahead]]:
		if (distance[1] as float) < 0.0:
			problems.append("%s %s is negative" % distance)
	var timing: Array = [
		["attack_interval", attack_interval], ["windup", windup], ["attack_range", attack_range]
	]
	for each: Array in timing:
		if (each[1] as float) <= 0.0:
			problems.append("%s %s is not positive" % each)
	for i: int in abilities.size():
		var ability: AbilityDef = Content.ability(abilities[i])
		if ability == null:
			problems.append("abilities[%d]: no ability %s" % [i, abilities[i]])
		elif _summons(ability):
			problems.append("abilities[%d]: %s summons in turn" % [i, abilities[i]])
	return problems


static func _summons(ability: AbilityDef) -> bool:
	for effect: AbilityEffect in ability.effects:
		if effect != null and effect.does == AbilityEffect.Does.SUMMON:
			return true
	return false
