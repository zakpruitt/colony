class_name WindowContent
extends VBoxContainer
## What the Shop, Area map and Party tally windows share: each is the content of a
## [UiWindow] on the UI layer, made by the [Hud] (so it hears the simulation from the start) and
## put in its window by [UiRoot]. Opening and closing go through the window and its [UiWindows],
## so the content opens at the front; without a window (a HUD on its own) it never opens.
##
## As it opens, by any way in (its key, its button on the bar, a goal, a saved window put back),
## it closes the "While you were away" report (but not as it opens under the report, left open
## last session), and [method _shown] lets it bring itself up to date.

## The HUD that made it, or null. Only the windows built on this one read it.
@warning_ignore("unused_private_class_variable")
var _hud: Hud
## True from the content's opening to its closing, so [method _shown] runs once per opening.
var _was_open: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	var open_now: bool = is_open()
	if open_now and not _was_open:
		_was_open = true
		var holder: UiWindow = window()
		if holder != null:
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


## Called as the window opens: bring what it shows up to date.
func _shown() -> void:
	pass


## Called as the window closes.
func _hidden() -> void:
	pass
