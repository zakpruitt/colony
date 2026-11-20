class_name WindowContent
extends VBoxContainer
## What every window on the button bar shows: each is the content of a [UiWindow] on the UI
## layer, made by its [WindowEntry] (the shop, the map and the tally by the [Hud], so they hear
## the simulation from the start) and put in its window by [UiRoot]. Opening and closing go
## through the window and its [UiWindows], so the content opens at the front; without a window
## (a HUD on its own) it never opens.
##
## As it opens, by any way in (its key, its button on the bar, a goal, a saved window put back),
## it closes the "While you were away" report if [member closes_away] is set (but not as it opens
## under the report, left open last session), and [method _shown] lets it bring itself up to date.

## Emitted when what the window's tag on the button bar says changes: [param text], or "" for no
## tag.
signal badge_changed(text: String)

## True when its opening closes the away report: the shop, the map and the tally do; help, the
## journal and the orders open beside it.
var closes_away: bool = true
## True from the content's opening to its closing, so [method _shown] runs once per opening.
var _was_open: bool = false
## The count on the window's tag, as last told: 0 for none.
var _badge: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	var open_now: bool = is_open()
	if open_now and not _was_open:
		_was_open = true
		var holder: UiWindow = window()
		if holder != null and closes_away:
			AwayWindow.close_in(holder.get_parent() as UiWindows)
		_shown()
	elif not open_now and _was_open:
		_was_open = false
		_hidden()


## The window holding this content, or null.
func window() -> UiWindow:
	var node: Node = get_parent()
	while node != null and not node is UiWindow:
		node = node.get_parent()
	return node as UiWindow


## True while its window is open.
func is_open() -> bool:
	var holder: UiWindow = window()
	return holder != null and holder.is_open()


## Opens its window at the front.
func open() -> void:
	var holder: UiWindow = window()
	if holder == null:
		return
	var windows: UiWindows = holder.get_parent() as UiWindows
	if windows != null:
		windows.open_window(holder.window_id)
	else:
		holder.open()


## Closes its window.
func close() -> void:
	var holder: UiWindow = window()
	if holder != null:
		holder.close()


## Opens its window if it is closed, closes it if it is open.
func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## Brings what it shows up to date and runs its animations on by [param _delta] seconds. Called
## every frame by whoever made it ([UiRoot], or the [Hud] for its own); tests call it.
func advance(_delta: float) -> void:
	pass


## The count on the window's tag on the bar, as last told: 0 for none. A window takes it as it is
## built, since the content may have told it before anything listened.
func badge() -> int:
	return _badge


## Puts [param count] on the window's tag on the bar (no tag for 0 or less), telling the bar only
## when it changes.
func _show_badge(count: int) -> void:
	var shown: int = maxi(count, 0)
	if shown == _badge:
		return
	_badge = shown
	badge_changed.emit(str(shown) if shown > 0 else "")


## Gives the content [param _tips], the tooltip it shares with the bar, for its controls.
func add_tips(_tips: UiTip) -> void:
	pass


## Called as the window opens: bring what it shows up to date.
func _shown() -> void:
	pass


## Called as the window closes.
func _hidden() -> void:
	pass
