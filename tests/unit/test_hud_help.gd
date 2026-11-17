extends GutTest
## The help panel's key labels and the tooltip's placement at the screen's edges (spec 030).


func test_key_labels_name_their_keys() -> void:
	assert_eq(HelpPanel.keycodes("H"), [KEY_H] as Array[int])
	assert_eq(HelpPanel.keycodes("Esc"), [KEY_ESCAPE] as Array[int])
	assert_eq(HelpPanel.keycodes("Tab"), [KEY_TAB] as Array[int])
	assert_eq(HelpPanel.keycodes("F3"), [KEY_F3] as Array[int])
	assert_eq(
		HelpPanel.keycodes("1-3"), [KEY_1, KEY_2, KEY_3] as Array[int], "a run of number keys"
	)
	var both: Array[int] = HelpPanel.keycodes("- +")
	for code: int in [KEY_MINUS, KEY_KP_SUBTRACT, KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		assert_has(both, code, "- + stands for %s" % OS.get_keycode_string(code))
	assert_eq(HelpPanel.keycodes("Nothing"), [] as Array[int], "a word that is no key")


func test_every_listed_key_names_a_key() -> void:
	for entry: Array in HelpPanel.KEYS:
		var label: String = entry[0]
		assert_false(HelpPanel.keycodes(label).is_empty(), "%s names a key" % label)
		var does: String = entry[1]
		assert_lte(PixelText.width(does), 300, "%s: a short line" % does)


## A tooltip on a control pressed against a corner of the screen stays on the screen and clear
## of the control.
func test_the_box_stays_on_screen_and_off_its_element() -> void:
	var corners: Array[Vector2] = [
		Vector2(0, 0), Vector2(620, 0), Vector2(0, 340), Vector2(620, 340), Vector2(300, 170)
	]
	for corner: Vector2 in corners:
		var hud := Hud.new()
		add_child_autofree(hud)
		var element := Control.new()
		element.position = corner
		element.size = Vector2(20, 20)
		hud.add_child(element)
		var tooltip := HudTooltip.new()
		hud.add_child(tooltip)
		tooltip.setup(hud)  # a HUD without a simulation: no element of its own
		tooltip._tip([element], "A sentence long enough to need pushing back on the screen.")
		tooltip.point_at(corner + Vector2(10, 10))
		tooltip.advance(HudTooltip.DELAY)
		assert_ne(tooltip.shown_text(), "", "%s: shown" % corner)
		var box: Rect2 = tooltip.box.get_global_rect()
		var screen := Rect2(Vector2.ZERO, Hud.SCREEN)
		assert_true(screen.encloses(box), "%s: on the screen %s" % [corner, box])
		assert_false(
			box.intersects(element.get_global_rect()), "%s: clear of it %s" % [corner, box]
		)
