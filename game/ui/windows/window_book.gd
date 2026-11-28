class_name WindowBook
extends RefCounted
## The windows on the button bar, one [WindowEntry] each, in the bar's order. [UiRoot] makes the
## windows from [method entries], the bar takes each button's name, key and tooltip from them and
## [KeyBook] the help's line for each. A new window is a new entry here.
##
## Help, the journal and the orders are made here, and [UiRoot] advances them. The shop, the map
## and the tally are the [Hud]'s, made as it is set up so they hear the simulation from the start;
## their entries hand the HUD's over, and the HUD advances them.

## Entries added beside the bar's own while the game runs ([method add]), after them in order.
static var _added: Array[WindowEntry] = []
## The bar's own entries made once without contents, for reading names and keys
## ([method key_of], [method listed]).
static var _named: Array[WindowEntry] = []


## Every window on the bar, in order, made anew: their contents are made with
## [param simulation], [param hud] and [param tips] (the tooltip they share).
static func entries(simulation: Simulation, hud: Hud, tips: UiTip) -> Array[WindowEntry]:
	var made: Array[WindowEntry] = _own(simulation, hud, tips)
	made.append_array(_added)
	return made


## Every window on the bar, in order, to read their names and keys: made once, so no
## [member WindowEntry.make_content] of the bar's own may be called.
static func listed() -> Array[WindowEntry]:
	if _named.is_empty():
		_named = _own(null, null, null)
	var made: Array[WindowEntry] = _named.duplicate()
	made.append_array(_added)
	return made


## The key of the window [param id], or 0 for no window on the bar.
static func key_of(id: StringName) -> int:
	if _named.is_empty():
		_named = _own(null, null, null)
	for entry: WindowEntry in _named:
		if entry.id == id:
			return entry.key
	for entry: WindowEntry in _added:
		if entry.id == id:
			return entry.key
	return 0


## The bar's own entries, in order, their contents made with [param simulation], [param hud] and
## [param tips].
static func _own(simulation: Simulation, hud: Hud, tips: UiTip) -> Array[WindowEntry]:
	var help := WindowEntry.new(
		UiRoot.HELP,
		HelpPanel.TITLE,
		"Help",
		KEY_H,
		"how Colony works, and every key it answers to.",
		func() -> WindowContent: return HelpPanel.new(),
		WindowBook.top_right
	)
	help.help_line = "Open or close Help"
	var journal := WindowEntry.new(
		UiRoot.JOURNAL,
		"Journal",
		"Journal",
		KEY_J,
		"what has happened to the party, newest first.",
		func() -> WindowContent: return _journal_view(hud)
	)
	var orders := WindowEntry.new(
		UiRoot.ORDERS,
		OrdersPanel.TITLE,
		"Orders",
		KEY_O,
		"how careful the party is, and whether it fights guardians.",
		func() -> WindowContent: return _orders_panel(simulation, tips),
		WindowBook.under_both.bind(UiRoot.JOURNAL, UiRoot.HELP)
	)
	var shop := WindowEntry.new(
		ShopWindow.ID,
		ShopWindow.TITLE,
		"Camp",
		KEY_U,
		"spend gold on upgrades, recruit heroes and choose the four who go down.",
		func() -> WindowContent: return _handed(hud.shop if hud != null else null, tips),
		WindowBook.top_right
	)
	var map := WindowEntry.new(
		AreaMapWindow.ID,
		AreaMapWindow.TITLE,
		"Map",
		KEY_W,
		"the areas the party can go to, and what each holds.",
		func() -> WindowContent: return _handed(hud.area_map if hud != null else null, tips),
		WindowBook.between.bind(TallyWindow.ID, ShopWindow.ID)
	)
	var tally := WindowEntry.new(
		TallyWindow.ID,
		TallyWindow.TITLE,
		"Tally",
		KEY_T,
		"who deals, heals and takes the damage.",
		func() -> WindowContent: return _handed(hud.tally if hud != null else null, tips)
	)
	for owned: WindowEntry in [shop, map, tally]:
		owned.advanced_elsewhere = true
	var made: Array[WindowEntry] = [help, journal, orders, shop, map, tally]
	return made


## Adds [param entry] to the bar's windows, after the others, for every layer made from then on.
static func add(entry: WindowEntry) -> void:
	remove(entry.id)
	_added.append(entry)


## Takes the window [param id] added by [method add] off the list again.
static func remove(id: StringName) -> void:
	for i: int in range(_added.size() - 1, -1, -1):
		if _added[i].id == id:
			_added.remove_at(i)


## A place at the room's top left, under the HUD's top band.
static func top_left(_window: UiWindow, _room: Vector2, top: float, _windows: UiWindows) -> Vector2:
	return Vector2(UiRoot.PLACE_GAP, top)


## A place at the room's top right, under the HUD's top band.
static func top_right(window: UiWindow, room: Vector2, top: float, _windows: UiWindows) -> Vector2:
	return Vector2(room.x - UiRoot.PLACE_GAP - window.size.x, top)


## A place at the left under the window [param above] (at the top left), or where
## [param window] already is without it.
static func under(
	window: UiWindow, _room: Vector2, top: float, windows: UiWindows, above: StringName
) -> Vector2:
	var over: UiWindow = windows.window(above)
	if over == null:
		return window.default_place
	return Vector2(UiRoot.PLACE_GAP, top + over.size.y + UiRoot.PLACE_GAP)


## A place at the left under the window [param above], as [method under] gives it, and lower
## where the default place of the window [param beside] reaches over [param window]'s columns:
## then right under that one too, with no gap, for the little room there is above the hero
## frames. Where [param window] already is without both.
static func under_both(
	window: UiWindow,
	_room: Vector2,
	top: float,
	windows: UiWindows,
	above: StringName,
	beside: StringName
) -> Vector2:
	var over: UiWindow = windows.window(above)
	var other: UiWindow = windows.window(beside)
	if over == null or other == null:
		return window.default_place
	var y: float = top + over.size.y + UiRoot.PLACE_GAP
	if other.default_place.x < UiRoot.PLACE_GAP + window.size.x:
		y = maxf(y, other.default_place.y + other.size.y)
	return Vector2(UiRoot.PLACE_GAP, y)


## A place in the middle of the room's top, between the window [param left] (at the top left)
## and [param right] (at the top right), so all three open at once with none over another; where
## [param window] already is without both.
static func between(
	window: UiWindow,
	room: Vector2,
	top: float,
	windows: UiWindows,
	left: StringName,
	right: StringName
) -> Vector2:
	var on_left: UiWindow = windows.window(left)
	var on_right: UiWindow = windows.window(right)
	if on_left == null or on_right == null:
		return window.default_place
	var from: float = UiRoot.PLACE_GAP + on_left.size.x + UiRoot.PLACE_GAP
	var to: float = room.x - UiRoot.PLACE_GAP - on_right.size.x - UiRoot.PLACE_GAP
	var middle: float = floorf((room.x - window.size.x) / 2.0)
	return Vector2(clampf(middle, from, maxf(to - window.size.x, from)), top)


static func _journal_view(hud: Hud) -> WindowContent:
	var view := JournalView.new()
	if hud != null and hud.journal != null:
		view.setup(hud.journal)
	return view


static func _orders_panel(simulation: Simulation, tips: UiTip) -> WindowContent:
	var panel := OrdersPanel.new()
	panel.setup(simulation, tips)
	return panel


## [param content], one of the HUD's, given [param tips] for its tooltips; null without it.
static func _handed(content: WindowContent, tips: UiTip) -> WindowContent:
	if content != null:
		content.add_tips(tips)
	return content
