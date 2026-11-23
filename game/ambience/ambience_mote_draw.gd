class_name AmbienceMoteDraw
extends RefCounted
## Draws the small things that move on a level ([AmbienceMote]) for [AmbienceLevel]: what is lit
## like the world (dust, drips, critters) and what shines over the darkness (embers, glints).


## The motes lit like the world, onto [param canvas], [param time] seconds into the level's run.
static func lit(canvas: CanvasItem, motes: Array[AmbienceMote], time: float) -> void:
	var critters: PixelSheet = PixelSheet.load_sheet(AmbienceLevel.DIR + "critters.png")
	var step: int = floori(time * 8.0)
	for mote: AmbienceMote in motes:
		var at: Vector2 = mote.position.round()
		match mote.kind:
			&"dust":
				canvas.draw_rect(Rect2(at, Vector2.ONE), Palette.color(&"sand"))
			&"drip":
				var swell: bool = mote.age < AmbienceLevel.DRIP_SWELL * 0.5
				canvas.draw_rect(Rect2(at, Vector2(1, 1 if swell else 2)), Palette.color(&"cyan"))
			&"splash":
				canvas.draw_rect(Rect2(at, Vector2.ONE), Palette.color(&"cyan"))
			&"beetle":
				var beetle: Texture2D = critters.part(&"beetle_%d" % (step % 2))
				flipped(canvas, beetle, at + Vector2(-4, -7), mote.velocity.x < 0.0)
			&"moth":
				var moth: Texture2D = critters.part(&"moth_%d" % ((step + 1) % 2))
				canvas.draw_texture(moth, at - Vector2(4, 4))


## The motes that shine on their own, onto [param canvas].
static func glow(canvas: CanvasItem, motes: Array[AmbienceMote]) -> void:
	var sparkle: PixelSheet = PixelSheet.load_sheet(AmbienceLevel.DIR + "sparkle.png")
	for mote: AmbienceMote in motes:
		match mote.kind:
			&"ember":
				var t: float = mote.progress()
				var color: Color = Palette.color(&"yellow")
				if t > 0.7:
					color = Palette.color(&"red")
				elif t > 0.35:
					color = Palette.color(&"orange")
				canvas.draw_rect(Rect2(mote.position.round(), Vector2.ONE), color)
			&"glint":
				var big: bool = mote.progress() > 0.3 and mote.progress() < 0.7
				var part: Texture2D = sparkle.part(&"big" if big else &"small")
				canvas.draw_texture(part, mote.position - Vector2(3, 3))


## [param texture] at [param at] on [param canvas], mirrored if [param flip].
static func flipped(canvas: CanvasItem, texture: Texture2D, at: Vector2, flip: bool) -> void:
	if not flip:
		canvas.draw_texture(texture, at)
		return
	var size := Vector2(texture.get_size())
	canvas.draw_texture_rect(
		texture, Rect2(at + Vector2(size.x, 0), Vector2(-size.x, size.y)), false
	)
