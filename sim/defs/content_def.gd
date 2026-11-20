class_name ContentDef
extends Resource
## A definition of one kind of content, saved as a .tres under res://data and loaded by
## [Content]. Each kind's class extends this, keeps its own [code]id[/code] and
## [code]display_name[/code] (a field here would rewrite every .tres), and answers both methods.


## What Content finds this definition by.
func key() -> StringName:
	return &""


## One line per problem; empty when the definition is sound.
func validate() -> PackedStringArray:
	return PackedStringArray()
