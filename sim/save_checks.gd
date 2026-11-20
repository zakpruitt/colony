class_name SaveChecks
extends RefCounted
## The checks every part of the save shares: whole numbers read from JSON, which may arrive as
## floats, and dictionaries of counts by known id. Each problem is one line naming its field.

## The largest whole number a JSON float holds exactly (2^53).
const _LARGEST_WHOLE: int = 9_007_199_254_740_992


## True for an int, or a float that is a whole number an int holds exactly.
static func is_whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number: float = value
	return is_finite(number) and number == floorf(number) and absf(number) <= _LARGEST_WHOLE


## [param value] as an int when [method is_whole] accepts it, else [param fallback].
static func whole(value: Variant, fallback: int = 0) -> int:
	if not is_whole(value):
		return fallback
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return int(number)
	var number_int: int = value
	return number_int


## Adds a problem unless [param data][[param key]] is a whole number of at least [param least].
## The problem names the field after [param where].
static func check_whole(
	problems: PackedStringArray, data: Dictionary, key: String, least: int, where: String = ""
) -> void:
	var value: Variant = data.get(key)
	if not is_whole(value):
		problems.append("%s%s: missing or not a whole number" % [where, key])
	elif whole(value) < least:
		problems.append("%s%s: below %d" % [where, key, least])


## Adds a problem unless [param data] is a dictionary of [param known] ids to whole counts of at
## least [param least]. [param what] is the field, a plural: one entry is named by it without its
## final "s".
static func check_counts(
	problems: PackedStringArray, data: Variant, what: String, known: Array[StringName], least: int
) -> void:
	if not (data is Dictionary):
		problems.append("%s: missing or not a dictionary of counts" % what)
		return
	var counts: Dictionary = data
	for key: Variant in counts:
		if typeof(key) != TYPE_STRING or not known.has(StringName(key as String)):
			problems.append("%s.%s: unknown %s" % [what, str(key), what.trim_suffix("s")])
			continue
		check_whole(problems, counts, key as String, least, what + ".")
