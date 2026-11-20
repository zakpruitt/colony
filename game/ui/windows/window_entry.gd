class_name WindowEntry
extends RefCounted
## One window on the button bar, all in one place: what [UiRoot] makes it from, what its button
## and tooltip say, its line in the help and where a new game puts it. [WindowBook] lists them.

## The window's name in the settings file and to [UiWindows].
var id: StringName
## The name in its title bar.
var title: String
## The one word for the window wherever it is named beside others: its button, the help's key
## list, tooltips ([code]Camp[/code] for the window titled [code]Camp upgrades[/code]).
var short_name: String
## The key that opens and closes it.
var key: Key
## What the window is for, the end of its button's tooltip after its title and key.
var about: String
## Makes (or hands over) the window's content: [code]() -> WindowContent[/code]. A content that
## cannot be had (the shop with no HUD) is null, and the window is not made.
var make_content: Callable
## Its part of the window icons' sheet ([constant UiRoot.ICONS_PATH]); its id unless given.
var icon_part: StringName
## Where a new game puts it, worked out for the room:
## [code](window: UiWindow, room: Vector2, top: float, windows: UiWindows) -> Vector2[/code], where
## [code]top[/code] is the first line under the HUD's top band. [method WindowBook.top_left] and
## its neighbours are the usual ones.
var place: Callable
## The help's line for its key; "Open or close the <short name>" unless given.
var help_line: String = ""
## True when whoever made the content advances it (the [Hud] its shop, map and tally); else
## [UiRoot] advances it every frame.
var advanced_elsewhere: bool = false


func _init(
	window_id: StringName,
	window_title: String,
	word: String,
	window_key: Key,
	what_for: String,
	maker: Callable,
	where: Callable = WindowBook.top_left
) -> void:
	id = window_id
	title = window_title
	short_name = word
	key = window_key
	about = what_for
	make_content = maker
	icon_part = window_id
	place = where


## The help's line for the window's key.
func help_text() -> String:
	return help_line if not help_line.is_empty() else "Open or close the %s" % short_name


## Its button's tooltip: its title, its key and what it is for.
func tip() -> String:
	var named: String = "%s (%s)" % [title, KeyBook.key_name(key)]
	return named if about.is_empty() else "%s: %s" % [named, about]
