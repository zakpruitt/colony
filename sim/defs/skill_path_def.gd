class_name SkillPathDef
extends Resource
## One path of a class's talent tree: a name, a line saying what it makes of a hero, and five
## nodes in four tiers. Kept as a sub-resource of its [TalentTreeDef], as an [AbilityEffect] is of
## its [AbilityDef].

@export var display_name: String
## One short line saying what a hero on this path becomes. A view hint: no rule reads it.
@export var summary: String
## Five ability ids: tier 1, tier 2 left, tier 2 right, tier 3, tier 4.
@export var nodes: Array[StringName] = []
