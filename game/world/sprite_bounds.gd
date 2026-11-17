class_name SpriteBounds
extends RefCounted
## Where a sprite's pixels are (spec 038): the box around the opaque pixels of a character's
## sheet at rest, or of one part of a sheet. Read from the baked sheets once each, then cached.

## Per sheet path: the opaque box of every part at rest, relative to the sheet's pivot pixel.
static var _bodies: Dictionary[String, Rect2i] = {}
## Per sheet path and region: the opaque box of that region, within it.
static var _regions: Dictionary[String, Rect2i] = {}


## The body of [param sprite] in world pixels, standing at [param feet] (its position, by
## default): its opaque pixels at rest, as wide either side of the feet as its wider side, so the
## box does not change when it turns. An empty Rect2 at the feet if it has no sheet.
static func body_rect(sprite: CharacterSprite, feet: Vector2 = Vector2.INF) -> Rect2:
	var at: Vector2 = sprite.position if feet == Vector2.INF else feet
	var box: Rect2i = box_of(sprite)
	if box.size == Vector2i.ZERO:
		return Rect2(at, Vector2.ZERO)
	var half: float = maxf(float(-box.position.x), float(box.end.x))
	var top: float = at.y + World.FEET_LIFT.y + box.position.y
	return Rect2(at.x - half, top, 2.0 * half, box.size.y)


## Half the width of [method body_rect]: how far its body reaches either side of its feet.
static func half_width(sprite: CharacterSprite) -> float:
	return body_rect(sprite, Vector2.ZERO).size.x / 2.0


## The opaque pixels of [param texture] (a region of a baked sheet), within that region. An
## empty Rect2i when it has none or cannot be read.
static func opaque(texture: AtlasTexture) -> Rect2i:
	if texture == null or texture.atlas == null:
		return Rect2i()
	var region := Rect2i(texture.region)
	var key: String = "%s %s" % [texture.atlas.resource_path, region]
	if _regions.has(key):
		return _regions[key]
	var image: Image = _image_of(texture.atlas)
	var low := Vector2i(region.size)
	var high := Vector2i(-1, -1)
	if image != null:
		for y: int in region.size.y:
			for x: int in region.size.x:
				if image.get_pixel(region.position.x + x, region.position.y + y).a < 0.5:
					continue
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	var found := Rect2i()
	if high.x >= 0:
		found = Rect2i(low, high - low + Vector2i.ONE)
	_regions[key] = found
	return found


## The box around the opaque pixels of [param sprite]'s parts at rest, facing right, in pixels
## from its sheet's pivot pixel (which covers 0 to 1). Empty when it has no sheet.
static func box_of(sprite: CharacterSprite) -> Rect2i:
	var path: String = ""
	var parts: Array[AtlasTexture] = []
	for node: Node in sprite.find_children("*", "Sprite2D", true, false):
		var atlas: AtlasTexture = (node as Sprite2D).texture as AtlasTexture
		if atlas != null and atlas.atlas != null:
			parts.append(atlas)
			path = atlas.atlas.resource_path
	if path.is_empty():
		return Rect2i()
	if _bodies.has(path):
		return _bodies[path]
	var sheet: PixelSheet = PixelSheet.load_sheet(path)
	var box := Rect2i()
	if sheet != null:
		for atlas: AtlasTexture in parts:
			var part: Rect2i = opaque(atlas)
			if part.size == Vector2i.ZERO:
				continue
			part.position -= sheet.pivot
			box = part if box.size == Vector2i.ZERO else box.merge(part)
	_bodies[path] = box
	return box


static func _image_of(sheet: Texture2D) -> Image:
	var image: Image = sheet.get_image()
	if image == null or image.is_empty():
		image = Image.load_from_file(ProjectSettings.globalize_path(sheet.resource_path))
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	return image
