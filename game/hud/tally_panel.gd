class_name TallyPanel
extends RefCounted
## What is left of the old tally panel (spec 045) since spec 059 made the tally a window
## ([TallyWindow]): the class bar colours, which [AbilityEffects] still reads by this name. They
## are the window's own.

## Each class's bar: its colour and the darker bottom row.
const CLASS_BARS: Dictionary[StringName, Array] = TallyWindow.CLASS_BARS
const OTHER_BAR: Array[StringName] = TallyWindow.OTHER_BAR
