class_name UiMoment
extends Control
## The moment a gain is marked: one, on the UI layer above the windows and
## under the note after a defeat and the tooltips ([member UiRoot.moment], made by
## [method UiRoot.setup]). Which gains are marked is the callers' to decide.
##
## [method burst] marks a gain on a control: for [constant BURST_SECONDS] its frame flashes white,
## a ring of sparks spreads from it and the control pops to [constant POP] times its size about its
## middle and settles, all drawn here in code and moving nothing in the layout (only the control's
## [member Control.scale] changes, and comes back; a container that sorts its children resets
## their scale, so the pop is put back each time the control's container sorts).
##
## [method announce] queues a banner that unrolls at the top middle of the room, under the boss
## bar's place: the picture at three times its size, a headline in bold and a line under it. It
## stays [constant BANNER_SECONDS], or until clicked. It is never wider than the room between the
## middle and the nearest of [member keep_clear] (the goals and the stage list in a game): its line
## wraps to at most two lines, the last shortened with "..." when it would run longer, and nothing
## is cut.
## [method announce_picture] takes the picture itself in place of an id: it is shown at
## the largest whole multiple of its own size that fits [constant BANNER_PICTURE], at its own size
## when it is larger (a guardian's sprite), and the banner grows to hold it.
## Banners wait their turn, at most [constant MAX_WAITING]; a newer one replaces the oldest
## waiting. One announced shows from the next [method advance], so of many announced at once only
## the newest that can wait are ever shown.
##
## Only for what just happened: with [member world] set, neither starts while the world is
## catching up, nor for an [param event] that is not recent ([method World.is_recent]); and when a
## catch-up starts, what waits and what is running are dropped. The burst plays the small gain's
## sound and the banner the grand one, through [member sound]; a [code]quiet[/code] one plays
## none (for an event that has a sound of its own).

## How long a burst lasts, how long its frame flashes, and when the pop is at its biggest.
const BURST_SECONDS: float = 0.6
const FLASH_SECONDS: float = 0.24
const POP_PEAK_SECONDS: float = 0.15
## How big the control pops, as a multiple of its size.
const POP: float = 1.3
## The sparks in a burst's ring, how far past the control's edge they spread, and their size.
const SPARKS: int = 12
const SPARK_SPREAD: float = 20.0
const SPARK_SIZE: float = 3.0
## Seconds a banner stays, and how long it takes to unroll.
const BANNER_SECONDS: float = 2.5
const UNROLL_SECONDS: float = 0.18
## The most banners waiting their turn.
const MAX_WAITING: int = 3
## A banner's picture: the 16x16 picture at three times its size.
const BANNER_PICTURE: Vector2 = Vector2(48, 48)
## Space inside the banner's edge, between its picture and its words, and the widest its line runs
## before it wraps.
const BANNER_PAD: float = 8.0
const BANNER_GAP: float = 10.0
const BANNER_LINE_WIDTH: float = 460.0
## The most lines the banner's line wraps to.
const BANNER_LINES: int = 2
## What ends a line shortened to fit.
const SHORTENED: String = "..."
## The banner's top, in UI pixels: just under the top band of the frame of the screen, where the
## place panel, the boss bar and the purse stand.
const BANNER_TOP: float = Hud.FRAME_TOP + PlacePanel.HEIGHT + Hud.FRAME_GAP
## The sounds of a small gain and a grand one.
const SMALL_SOUND: StringName = &"gain_small"
const GRAND_SOUND: StringName = &"gain_grand"

## The world whose events the moments mark: null (a specimen, a test) starts everything.
var world: World
## Plays the sounds; null for silence.
var sound: SoundPlayer
## Controls on the UI layer the banner never overlaps (sideways: it narrows to stay between them).
var keep_clear: Array[Control] = []
## The banner, its picture, its headline and its line.
var banner: Panel
var banner_picture: TextureRect
var banner_picture_frame: Panel
var banner_headline: Label
var banner_line: Label

var _bursts: Array[Burst] = []
var _waiting: Array[Banner] = []
var _shown: Banner
var _shown_time: float = 0.0
var _bursts_seen: int = 0
## The banner's whole size, once unrolled, and the widest it was let be when laid out.
var _banner_full: Vector2 = Vector2.ZERO
var _banner_room: float = -1.0


func _init() -> void:
	name = "Moment"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = Panel.new()
	banner.name = "Banner"
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	banner.clip_contents = true
	banner.visible = false
	banner.add_theme_stylebox_override(&"panel", UiTheme.box(&"night", &"amber"))
	banner.gui_input.connect(_on_banner_input)
	add_child(banner)
	banner_picture_frame = Panel.new()  # a gold frame round the picture
	banner_picture_frame.name = "PictureFrame"
	banner_picture_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_picture_frame.add_theme_stylebox_override(&"panel", UiTheme.box(&"ink", &"yellow"))
	banner_picture_frame.position = Vector2.ONE * (BANNER_PAD - 2.0)
	banner_picture_frame.size = BANNER_PICTURE + Vector2(4, 4)
	banner.add_child(banner_picture_frame)
	banner_picture = TextureRect.new()
	banner_picture.name = "Picture"
	banner_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner_picture.stretch_mode = TextureRect.STRETCH_SCALE
	banner_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner_picture.position = Vector2.ONE * BANNER_PAD
	banner_picture.size = BANNER_PICTURE
	banner.add_child(banner_picture)
	banner_headline = WindowText.label("Headline", "", &"yellow", true)
	banner.add_child(banner_headline)
	banner_line = WindowText.label("Line", "", &"silver")
	banner.add_child(banner_line)


func _process(delta: float) -> void:
	advance(delta)


## Gives the moment the whole room, [param room] UI pixels.
func fit_room(room: Vector2i) -> void:
	position = Vector2.ZERO
	size = Vector2(room)
	_place_banner()


## Marks a gain on [param control]: a flash, a ring of sparks and a pop (see the class
## description). Nothing starts for an [param event] that is not recent, or while the world is
## catching up. A second burst on a control that is bursting starts it again. A [param quiet]
## burst plays no sound.
func burst(control: Control, event: SimEvent = null, quiet: bool = false) -> void:
	if control == null or not _may_start(event):
		return
	var running: Burst = _burst_of(control)
	if running == null:
		running = Burst.new()
		running.control = control
		running.scale = control.scale
		running.pivot = control.pivot_offset
		running.container = control.get_parent() as Container
		if running.container != null:
			running.container.sort_children.connect(_on_sorted.bind(running))
		_bursts.append(running)
	running.time = 0.0
	control.pivot_offset = control.size / 2.0
	_bursts_seen += 1
	if sound != null and not quiet:
		sound.play(SMALL_SOUND)
	queue_redraw()


## Queues a banner: [param picture_id]'s picture, [param headline] in bold and [param line] under
## it. Nothing is queued for an [param event] that is not recent, or while the world is catching
## up. It shows from the next [method advance] once the banners before it have gone.
func announce(
	picture_id: StringName, headline: String, line: String, event: SimEvent = null
) -> void:
	announce_picture(UiIcon.picture(picture_id), headline, line, event)


## Queues a banner as [method announce] does, its picture [param picture] itself (a guardian's
## sprite, an area's resource), shown at a whole multiple of its size ([method
## picture_size]). A [param quiet] banner plays no sound when it shows.
func announce_picture(
	picture: Texture2D, headline: String, line: String, event: SimEvent = null, quiet: bool = false
) -> void:
	if not _may_start(event):
		return
	var made := Banner.new()
	made.picture = picture
	made.quiet = quiet
	made.headline = headline
	made.line = line
	_waiting.append(made)
	while _waiting.size() > MAX_WAITING:
		_waiting.remove_at(0)


## How many banners wait their turn (the one showing not counted).
func waiting() -> int:
	return _waiting.size()


## The headline of the banner showing, or "" when none is.
func shown_headline() -> String:
	return _shown.headline if _shown != null else ""


## Runs the bursts and the banners on by [param delta] seconds. Called every frame; tests call it.
func advance(delta: float) -> void:
	if world != null and world.catching_up():
		_drop_all()
		return
	for running: Burst in _bursts.duplicate():
		running.time += delta
		if not is_instance_valid(running.control) or running.time >= BURST_SECONDS:
			_end(running)
			continue
		running.control.scale = running.scale * _pop(running.time)
	if _shown != null:
		_shown_time += delta
		if _shown_time >= BANNER_SECONDS:
			_hide_banner()
	if _shown == null and not _waiting.is_empty():
		var next: Banner = _waiting.pop_front()
		_show_banner(next)
	if _shown != null:
		_place_banner()
	queue_redraw()


## True while [param control] is bursting.
func is_bursting(control: Control) -> bool:
	return _burst_of(control) != null


## True while [param control]'s frame flashes white.
func is_flashing(control: Control) -> bool:
	var running: Burst = _burst_of(control)
	return running != null and running.time < FLASH_SECONDS


## How many sparks are in the air now.
func spark_count() -> int:
	return _bursts.size() * SPARKS


## How far from its control's middle the furthest spark is now, in UI pixels; 0 with none.
func spark_reach() -> float:
	var reach: float = 0.0
	for running: Burst in _bursts:
		reach = maxf(reach, _reach(running))
	return reach


## Sends the banner showing away, as a click on it does.
func banner_clicked() -> void:
	if _shown != null:
		_hide_banner()


## How many bursts have started since the moment was made.
func bursts_seen() -> int:
	return _bursts_seen


func _draw() -> void:
	for running: Burst in _bursts:
		if not is_instance_valid(running.control):
			continue
		var middle: Vector2 = _middle(running.control)
		var half: Vector2 = _half(running.control) * _pop(running.time)
		if running.time < FLASH_SECONDS:
			var colour: StringName = &"white" if running.time < FLASH_SECONDS / 2.0 else &"silver"
			var box := Rect2(middle - half, half * 2.0).grow(1.0)
			draw_rect(box, Palette.color(colour), false, 2.0)
		var spark_colour: StringName = &"yellow"
		if running.time > BURST_SECONDS * 0.66:
			spark_colour = &"orange"
		elif running.time > BURST_SECONDS * 0.33:
			spark_colour = &"amber"
		var reach: float = _reach(running)
		for i: int in SPARKS:
			var turn: float = TAU * float(i) / SPARKS
			var at: Vector2 = (middle + Vector2.from_angle(turn) * reach).round()
			var square := Rect2(at - Vector2.ONE * SPARK_SIZE / 2.0, Vector2.ONE * SPARK_SIZE)
			draw_rect(square.grow(1.0), Palette.color(&"ink"))
			draw_rect(square, Palette.color(spark_colour))


## True when a moment may start for [param event] now: it is recent and the world is not catching
## up. Callers ask it before starting a moment of their own, such as a path closing.
func may_start(event: SimEvent) -> bool:
	return _may_start(event)


## True when a moment may start for [param event] (null: for no event in particular) now.
func _may_start(event: SimEvent) -> bool:
	return world == null or event == null or world.may_animate(event)


## The pop's size at [param time] into a burst: up to [constant POP] at
## [constant POP_PEAK_SECONDS], then easing back to 1 by [constant BURST_SECONDS].
func _pop(time: float) -> float:
	if time <= POP_PEAK_SECONDS:
		return 1.0 + (POP - 1.0) * sin(time / POP_PEAK_SECONDS * PI / 2.0)
	var settle: float = clampf((time - POP_PEAK_SECONDS) / (BURST_SECONDS - POP_PEAK_SECONDS), 0, 1)
	return 1.0 + (POP - 1.0) * pow(1.0 - settle, 2.0)


func _reach(running: Burst) -> float:
	if not is_instance_valid(running.control):
		return 0.0
	var half: Vector2 = _half(running.control)
	var from: float = maxf(half.x, half.y)
	var spread: float = 1.0 - pow(1.0 - clampf(running.time / BURST_SECONDS, 0.0, 1.0), 2.0)
	return from + 4.0 + SPARK_SPREAD * spread


## [param control]'s middle, in this moment's pixels (the pop turns about it, so it never moves).
func _middle(control: Control) -> Vector2:
	var to_here: Transform2D = get_global_transform().affine_inverse()
	return to_here * (control.get_global_transform() * (control.size / 2.0))


## Half [param control]'s unpopped size, in this moment's pixels.
func _half(control: Control) -> Vector2:
	var parent: CanvasItem = control.get_parent() as CanvasItem
	var outer: Vector2 = (
		parent.get_global_transform().get_scale() if parent != null else Vector2.ONE
	)
	var mine: Vector2 = get_global_transform().get_scale()
	return control.size / 2.0 * outer / mine


func _burst_of(control: Control) -> Burst:
	for running: Burst in _bursts:
		if running.control == control:
			return running
	return null


## Ends [param running]: its control back at its own size.
func _end(running: Burst) -> void:
	if is_instance_valid(running.control):
		running.control.scale = running.scale
		running.control.pivot_offset = running.pivot
	if is_instance_valid(running.container):
		running.container.sort_children.disconnect(_on_sorted.bind(running))
	_bursts.erase(running)


## Puts [param running]'s pop back after its container sorted its children, which resets scale.
func _on_sorted(running: Burst) -> void:
	if is_instance_valid(running.control):
		running.control.pivot_offset = running.control.size / 2.0
		running.control.scale = running.scale * _pop(running.time)


## Drops every banner waiting and showing and ends every burst: the world is catching up.
func _drop_all() -> void:
	_waiting.clear()
	if _shown != null:
		_hide_banner()
	for running: Burst in _bursts.duplicate():
		_end(running)
	queue_redraw()


func _show_banner(shown: Banner) -> void:
	_shown = shown
	_shown_time = 0.0
	banner_picture.texture = shown.picture
	_lay_out_banner()
	banner.visible = true
	_place_banner()
	if sound != null and not shown.quiet:
		sound.play(GRAND_SOUND)


## Lays the banner showing out to the room it has now ([method room_for_banner]): the headline and
## the line wrapped to fit, the line to at most [constant BANNER_LINES] lines.
func _lay_out_banner() -> void:
	_banner_room = room_for_banner()
	var picture: Vector2 = picture_size(_shown.picture)
	banner_picture.size = picture
	banner_picture_frame.size = picture + Vector2(4, 4)
	var words_x: float = BANNER_PAD + picture.x + BANNER_GAP
	var width: float = minf(BANNER_LINE_WIDTH, _banner_room - words_x - BANNER_PAD)
	WindowText.set_text(banner_headline, _shortened(_shown.headline, width, true))
	var lines: Array[String] = WindowText.wrap(_shown.line, width)
	if lines.size() > BANNER_LINES:
		var rest: String = " ".join(PackedStringArray(lines.slice(BANNER_LINES - 1)))
		lines.resize(BANNER_LINES - 1)
		lines.append(_shortened(rest, width, false, true))
	WindowText.set_text(banner_line, "\n".join(PackedStringArray(lines)))
	var words: Vector2 = Vector2(
		maxf(banner_headline.size.x, banner_line.size.x),
		banner_headline.size.y + banner_line.size.y
	)
	var inner_height: float = maxf(picture.y, words.y)
	var words_y: float = BANNER_PAD + floorf((inner_height - words.y) / 2.0)
	banner_headline.position = Vector2(words_x, words_y)
	banner_line.position = Vector2(words_x, words_y + banner_headline.size.y)
	_banner_full = Vector2(words_x + words.x + BANNER_PAD, inner_height + 2.0 * BANNER_PAD).ceil()


## The size [param picture] is shown at on a banner: the largest whole multiple of its own size
## that fits [constant BANNER_PICTURE] (a 16x16 picture at three times), its own size when that is
## larger; [constant BANNER_PICTURE] for none.
static func picture_size(picture: Texture2D) -> Vector2:
	if picture == null or picture.get_width() <= 0 or picture.get_height() <= 0:
		return BANNER_PICTURE
	var own: Vector2 = picture.get_size()
	var times: float = floorf(minf(BANNER_PICTURE.x / own.x, BANNER_PICTURE.y / own.y))
	return own * maxf(times, 1.0)


## The widest the banner may be, centred in the room, in UI pixels: as far as the nearest of
## [member keep_clear] on each side (a frame gap short of it) or the room's edge, twice the nearer.
func room_for_banner() -> float:
	var middle: float = size.x / 2.0
	var half: float = middle - Hud.FRAME_EDGE
	var to_here: Transform2D = get_global_transform().affine_inverse()
	for control: Control in keep_clear:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var box: Rect2 = to_here * control.get_global_rect()
		if box.end.x <= middle:
			half = minf(half, middle - box.end.x - Hud.FRAME_GAP)
		elif box.position.x >= middle:
			half = minf(half, box.position.x - middle - Hud.FRAME_GAP)
	return floorf(half) * 2.0 - 2.0


## [param text] as it fits in [param width] UI pixels: whole, or cut at a word and ended with
## [constant SHORTENED] ([param always_marked]: ended so even when it fits, for a line cut short).
func _shortened(text: String, width: float, bold: bool, always_marked: bool = false) -> String:
	if not always_marked and UiText.width(text, bold) <= width:
		return text
	var words: PackedStringArray = text.split(" ", false)
	while words.size() > 1:
		var tried: String = " ".join(words) + SHORTENED
		if UiText.width(tried, bold) <= width:
			return tried
		words.resize(words.size() - 1)
	var short: String = words[0] if not words.is_empty() else ""
	while short.length() > 1 and UiText.width(short + SHORTENED, bold) > width:
		short = short.left(short.length() - 1)
	return short + SHORTENED


func _hide_banner() -> void:
	_shown = null
	banner.visible = false


## Puts the banner at the top middle, unrolled as far as it has got.
func _place_banner() -> void:
	if _shown == null:
		return
	if room_for_banner() != _banner_room:
		_lay_out_banner()
	var full: Vector2 = _banner_full
	var unrolled: float = clampf(_shown_time / UNROLL_SECONDS, 0.0, 1.0)
	banner.position = Vector2(floorf((size.x - full.x) / 2.0), BANNER_TOP)
	banner.size = Vector2(full.x, maxf(roundf(full.y * unrolled), 2.0))


func _on_banner_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		banner.accept_event()
		banner_clicked()


## A burst running on a control: its own scale and pivot to come back to.
class Burst:
	extends RefCounted
	var control: Control
	var time: float = 0.0
	var scale: Vector2 = Vector2.ONE
	var pivot: Vector2 = Vector2.ZERO
	## The container the control is in, whose sorting puts the pop back; null for none.
	var container: Container


## A banner waiting or showing.
class Banner:
	extends RefCounted
	var picture: Texture2D
	var quiet: bool = false
	var headline: String
	var line: String
