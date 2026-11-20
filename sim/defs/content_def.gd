class_name ContentDef
extends Resource
## A definition of one kind of content, saved as a .tres under res://data and loaded by
## [Content]. Each kind's class extends this, keeps its own [code]id[/code] and
## [code]display_name[/code] (a field here would rewrite every .tres), and answers both methods.


## What Content finds this definition by. Each kind's class answers it; one that does not is
## reported here, and its key is empty.
func key() -> StringName:
	push_error("ContentDef: %s does not say what it is found by (key())" % resource_path)
	return &""


## One line per problem; empty when the definition is sound. Each kind's class answers it.
func validate() -> PackedStringArray:
	return PackedStringArray(["validate() is not given for this kind of definition"])
