class_name Gallery
extends Control
## Shows every baked sheet under assets/sprites/ so a person can judge the art: each part at 4x,
## the parts composed at 4x and at 1x, on a mid-dark background, with the sheet's name.
## Run: python tools/dev.py shot --scene=res://game/art/gallery.tscn --name=gallery

const SPRITES_DIR: String = "res://assets/sprites"
## How much bigger than 1x each part is drawn.
const ZOOM: int = 4
const GAP: int = 6
const FONT_SIZE: int = 8

var _shown: PackedStringArray = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Palette.color(&"dusk")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, GAP)
	scroll.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", GAP * 2)
	margin.add_child(rows)

	for png_path: String in _find_sheets(SPRITES_DIR):
		var sheet: PixelSheet = PixelSheet.load_sheet(png_path)
		if sheet != null:
			rows.add_child(_sheet_row(png_path, sheet))
			_shown.append(png_path)
	if _shown.is_empty():
		rows.add_child(_label("No baked sheets under %s yet." % SPRITES_DIR))


## The baked PNGs this gallery is showing, as res:// paths.
func shown_sheets() -> PackedStringArray:
	return _shown


func _sheet_row(png_path: String, sheet: PixelSheet) -> Control:
	var row := VBoxContainer.new()
	var title: String = png_path.trim_prefix(SPRITES_DIR + "/").get_basename()
	row.add_child(_label("%s  (%s, %dx%d)" % [title, sheet.category, sheet.size.x, sheet.size.y]))
	var cells := HFlowContainer.new()
	cells.add_theme_constant_override("h_separation", GAP)
	cells.add_theme_constant_override("v_separation", GAP)
	row.add_child(cells)
	for part_name: String in sheet.part_names:
		var picture: Control = _picture(sheet, [StringName(part_name)], ZOOM)
		cells.add_child(_cell(picture, part_name))
	var all_parts: Array[StringName] = []
	for part_name: String in sheet.part_names:
		all_parts.append(StringName(part_name))
	cells.add_child(_cell(_picture(sheet, all_parts, ZOOM), "composed"))
	cells.add_child(_cell(_picture(sheet, all_parts, 1), "1x"))
	return row


## The given parts stacked in order on one canvas, scaled by [param zoom].
func _picture(sheet: PixelSheet, parts: Array[StringName], zoom: int) -> Control:
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(sheet.size * zoom)
	for part_name: StringName in parts:
		var layer := TextureRect.new()
		layer.texture = sheet.part(part_name)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.size = canvas.custom_minimum_size
		canvas.add_child(layer)
	return canvas


func _cell(picture: Control, caption: String) -> Control:
	var cell := VBoxContainer.new()
	cell.add_child(picture)
	cell.add_child(_label(caption))
	return cell


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Palette.color(&"silver"))
	return label


func _find_sheets(dir: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "json":
			var png_path: String = dir.path_join(file.get_basename() + ".png")
			if ResourceLoader.exists(png_path):
				found.append(png_path)
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_find_sheets(dir.path_join(sub)))
	found.sort()
	return found
