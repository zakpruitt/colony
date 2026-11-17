class_name SpriteBounds
extends RefCounted
## Where a sprite's pixels are (spec 038): the box around the opaque pixels of a character's
## sheet at rest, or of one part of a sheet, and how far they reach through a fight's poses (spec
## 048). Read from the baked sheets once each, then cached.

## The wind-up of the attack played to measure a reach, in seconds, and how long each attack is
## watched for: past its strike, its hold and its settling back.
const REACH_WINDUP: float = 0.4
const REACH_SECONDS: float = 1.5

## Per sheet path: the opaque box of every part at rest, relative to the sheet's pivot pixel.
static var _bodies: Dictionary[String, Rect2i] = {}
## Per sheet path and region: the opaque box of that region, within it.
static var _regions: Dictionary[String, Rect2i] = {}
## Per sheet path: how far its pixels reach from its feet through a fight's poses.
static var _reaches: Dictionary[String, float] = {}


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


## How far [param sprite]'s pixels reach either side of its feet through a fight's poses (spec 048
## R7): breathing, walking, a melee or a ranged attack (a lunge, a swing), a flinch. Its wider side
## either way, as [method half_width], so it does not change when it turns. Worked out once a sheet
## by playing those poses on a copy of the character, then cached.
static func reach(sprite: CharacterSprite) -> float:
	var path: String = _sheet_path(sprite)
	if path.is_empty():
		return 0.0
	if _reaches.has(path):
		return _reaches[path]
	var posed: CharacterSprite = CharacterSprite.create(path)
	var low: float = 0.0
	var high: float = 0.0
	if posed != null:
		var span: Vector2 = _posed_span(posed)
		low = span.x
		high = span.y
		posed.free()
	var found: float = maxf(-low, high)
	_reaches[path] = found
	return found


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


## The baked sheet [param sprite] is drawn from, or "" when it has none.
static func _sheet_path(sprite: CharacterSprite) -> String:
	for node: Node in sprite.find_children("*", "Sprite2D", true, false):
		var atlas: AtlasTexture = (node as Sprite2D).texture as AtlasTexture
		if atlas != null and atlas.atlas != null:
			return atlas.atlas.resource_path
	return ""


## The leftmost and rightmost pixel edges (x, y) of [param posed]'s parts, facing right, from its
## feet, through the poses of a fight, a frame at a time.
static func _posed_span(posed: CharacterSprite) -> Vector2:
	var span := Vector2(INF, -INF)
	var frame: float = 1.0 / 60.0
	for walking: bool in [false, true]:
		if walking:
			posed.play_walk()
		for ranged: bool in [false, true]:
			posed.play_attack(REACH_WINDUP, ranged)
			for i: int in roundi(REACH_SECONDS / frame):
				if i == roundi(REACH_SECONDS / frame / 2.0):
					posed.play_hit()
				posed.advance(frame)
				span = _widest(span, _drawn_span(posed))
	return span


## The leftmost and rightmost pixel edges (x, y) of [param posed]'s opaque parts as posed now.
static func _drawn_span(posed: CharacterSprite) -> Vector2:
	var span := Vector2(INF, -INF)
	for node: Node in posed.find_children("*", "Sprite2D", true, false):
		var part: Sprite2D = node as Sprite2D
		var box: Rect2i = opaque(part.texture as AtlasTexture)
		if not part.visible or box.size == Vector2i.ZERO:
			continue
		var drawn: Transform2D = part.transform
		var parent: Node = part.get_parent()
		while parent != posed and parent is Node2D:
			drawn = (parent as Node2D).transform * drawn
			parent = parent.get_parent()
		var at: Vector2 = part.offset + Vector2(box.position)
		var size := Vector2(box.size)
		for corner: Vector2 in [at, at + Vector2(size.x, 0), at + Vector2(0, size.y), at + size]:
			var x: float = (drawn * corner).x
			span = Vector2(minf(span.x, x), maxf(span.y, x))
	return span


static func _widest(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(minf(a.x, b.x), maxf(a.y, b.y))


static func _image_of(sheet: Texture2D) -> Image:
	var image: Image = sheet.get_image()
	if image == null or image.is_empty():
		image = Image.load_from_file(ProjectSettings.globalize_path(sheet.resource_path))
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	return image
