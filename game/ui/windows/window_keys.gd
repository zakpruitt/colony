class_name WindowKeys
extends Node
## The keys the windows answer beyond their own key and Esc: each acts only while its window is
## the front window of all ([method UiWindows.front]). [kbd]B[/kbd] switches the shop's auto-buy
## and [kbd]1[/kbd] to [kbd]5[/kbd] buy its rows; [kbd]1[/kbd] to [kbd]3[/kbd] put a paragon point
## into a stat on a hero window's Talents tab; [kbd]Q[/kbd] and [kbd]E[/kbd] step a hero window's
## tabs or the tally's measures. [kbd]Tab[/kbd] opens the next hero's window in front whatever is
## in front, and [kbd]Shift+Tab[/kbd] closes the front window when it is a hero's.

var _windows: UiWindows
var _hero_windows: HeroWindows
var _shop: ShopWindow
var _tally: TallyWindow


func _init() -> void:
	name = "WindowKeys"


## Call once: the keys act on [param windows]' front window, [param hero_windows] (may be null),
## [param shop] and [param tally] (each may be null).
func setup(
	windows: UiWindows, hero_windows: HeroWindows, shop: ShopWindow, tally: TallyWindow
) -> void:
	_windows = windows
	_hero_windows = hero_windows
	_shop = shop
	_tally = tally


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = KeyBook.fresh_key(event)
	if key == null or _windows == null:
		return
	var top: UiWindow = _windows.front()
	var hero_top: HeroWindow = top as HeroWindow
	var handled: bool = true
	match key.keycode:
		KEY_TAB:
			if _hero_windows == null or (key.shift_pressed and hero_top == null):
				handled = false
			elif key.shift_pressed:
				hero_top.close()
			else:
				_hero_windows.open_next()
		KEY_B:
			handled = _in_front(top, _shop)
			if handled:
				_shop.toggle_auto_buy()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var training: bool = hero_top != null and hero_top.page() == HeroWindow.Page.TALENTS
			if _in_front(top, _shop):
				_shop.buy_row(key.keycode - KEY_1)
			elif training and key.keycode <= KEY_3:
				hero_top.train_row(key.keycode - KEY_1)
			else:
				handled = false
		KEY_Q, KEY_E:
			if hero_top != null:
				if key.keycode == KEY_Q:
					hero_top.previous_page()
				else:
					hero_top.next_page()
			elif _in_front(top, _tally):
				if key.keycode == KEY_Q:
					_tally.previous_measure()
				else:
					_tally.next_measure()
			else:
				handled = false
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


## True while [param top], the front window, holds [param content].
static func _in_front(top: UiWindow, content: Control) -> bool:
	return top != null and content != null and top.content == content
