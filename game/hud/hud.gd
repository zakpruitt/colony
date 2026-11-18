class_name Hud
extends Control
## The HUD (spec 011): what the screen tells of the party, around the world. Since spec 062 it draws
## nothing in the world's pixels but the dark of a crossing ([CrossingVeil], with the world's own
## title): everything else is on the sharp layer.
##
## The HUD only reads the simulation, and listens to [signal World.sim_event] for hits and
## level-ups; the player's choices reach the simulation through [method Simulation.set_target_depth]
## and [method Simulation.set_auto_push]. It keeps to the top [constant TOP_BAND] and the bottom
## [constant BOTTOM_BAND] pixels of the 640x360 screen.
##
## Spec 027 makes the party readable: the place panel says what the party is doing and why ([method
## status_text]) and how long until this stage is stable ([method stable_text]), and a [Journal]
## keeps the last happenings, with a ticker over the frames (its list is the Journal window on the
## UI layer, spec 058). Spec 039 makes that note count down to auto-push's next push once the depth
## is stable.
##
## Spec 061 draws the frame of the screen on the sharp layer, in the UI font: the [PlacePanel] and
## the [Countdown] at the top left, the [Purse] at the top right, the [BossBarView] between them in
## a guardian fight, and a [HeroFrameView] per hero along the bottom, all inside the two bands. They
## hang from [member screen_frame], which [UiRoot] takes onto its layer; a HUD on its own (a test)
## keeps it, scaled so that its 960x540 UI pixels cover the 640x360 screen. The texts are made here
## and only drawn there; their tooltips are [member frame_tip], spec 058's tooltip.
##
## Spec 062 moves the rest there too: the goals ([GoalsView]) under the place panel, the stage list
## ([StageList]) at the right edge, the [Ticker] over the hero frames, and the note after a defeat
## ([DefeatNoteView]), which [UiRoot] lifts over every window. [Goals], [Journal] and [DefeatNote]
## still decide what they say; they draw nothing.

## The screen the HUD is laid out on, in pixels.
const SCREEN: Vector2 = Vector2(640, 360)
## The HUD's two bands: everything lies within the top or bottom this many pixels.
const TOP_BAND: float = 28.0
const BOTTOM_BAND: float = 40.0
## Space between the HUD and the screen's edge, and between frames.
const MARGIN: float = 4.0
const GAP: float = 4.0
## The top panels' top edge and height.
const TOP_Y: float = 2.0
const TOP_HEIGHT: float = 24.0
## How far above the screen's margin the hero frames reach, in the world's pixels, for a HUD with
## no UI layer; on the layer [method frames_line] gives their true top.
const FRAMES_HEIGHT: float = 34.0
## The sheet of HUD icons: a portrait per hero class, a skull and a coin.
const ICONS_PATH: String = "res://assets/sprites/ui/hud_icons.png"
## Seconds after the last coin before a shown gold count that is still behind catches up.
const GOLD_CATCH_UP_SECONDS: float = 3.0
## Seconds the gold count bumps on each coin.
const GOLD_BUMP_SECONDS: float = 0.15
## Seconds the depth number is emphasised after a change of depth.
const DEPTH_EMPHASIS_SECONDS: float = 0.6
## The frame of the screen, in UI pixels: its top, the space from the room's sides and bottom,
## and between two pieces.
const FRAME_TOP: float = 1.0
const FRAME_EDGE: float = 6.0
const FRAME_GAP: float = 6.0
## The word for each expedition state, and its colour. A state with no line of its own in
## [method status_text] shows its word.
const STATE_WORDS: Dictionary[Expedition.State, String] = {
	Expedition.State.TRAVELLING: "Travelling",
	Expedition.State.FIGHTING: "Fighting",
	Expedition.State.RESTING: "Resting",
	Expedition.State.CLIMBING: "Moving on",
	Expedition.State.REVIVING: "Reviving",
	Expedition.State.WORKING: "Working",
	Expedition.State.JOURNEYING: "On the way",
}
const STATE_COLOURS: Dictionary[Expedition.State, StringName] = {
	Expedition.State.TRAVELLING: &"silver",
	Expedition.State.FIGHTING: &"orange",
	Expedition.State.RESTING: &"green",
	Expedition.State.CLIMBING: &"tan",
	Expedition.State.REVIVING: &"pink",
	Expedition.State.WORKING: &"amber",
	Expedition.State.JOURNEYING: &"tan",
}
## Each piece's tooltip, as the old pieces had them (spec 030 R4).
const STAGE_TIP: String = "The stage the party is on now."
const STATUS_TIP: String = "What the party is doing right now, and why."
const SAFE_TIP: String = "The last safe stage: a wipe sends the party back there."
const TARGET_TIP: String = "The stage the party is heading for."
const MINUS_TIP: String = "Set the target one stage back."
const PLUS_TIP: String = "Set the target one stage further."
const AUTO_TIP: String = (
	"When on, the party goes a stage further each time it holds its target " + "long enough."
)
const SPEED_TIP: String = "How fast the game runs: click (or press F) for 1x, 2x or 4x."
const GOLD_TIP: String = "Gold from fights, to spend in the Shop."
const BOSS_TIP: String = "A guardian holds the way on: beat it to go further."
const AREA_TIP: String = "The area the party is in: click (or press W) for the map of every area."

## The frame of the screen (spec 061): the room-sized control its pieces hang from.
var screen_frame: Control
## Where the party is: the area, the stage, the safe stage, the target, Auto and the status line.
var place_panel: PlacePanel
## The road to stable, beside the place panel.
var countdown: Countdown
## The gold, the resources and the game-speed button. Main connects the button's click and tells
## the HUD the speed through [method show_speed].
var purse: Purse
## One frame per hero, in formation order, left to right.
var frames: Array[HeroFrameView] = []
## The guardian's health during a guardian fight (spec 024).
var boss_bar: BossBarView
## The tooltips of the frame's pieces (spec 061 R7).
var frame_tip: UiTip
## Main's tick readout, for developers: bottom right, dim, hidden until F3.
var clock_label: Label
## The upgrade shop (spec 017): since spec 059 the content of the Shop window on the UI layer,
## made here so it hears the simulation from the start; [UiRoot] puts it in its window.
var shop: ShopWindow
## The last happenings, the ticker over the party frames and the J panel (spec 027).
var journal: Journal
## The journal's newest line over the hero frames (spec 062 R3); a click opens the Journal.
var ticker: Ticker
## A window per hero on the UI layer (spec 060), opened by clicking its frame or with Tab; null
## when there is no UI layer (a HUD on its own in a test). Set by [method UiRoot.setup].
var hero_windows: HeroWindows:
	set(value):
		hero_windows = value
		if value != null:
			value.changed.connect(_mark_frames)
			_mark_frames()
## The stages of this area down the right edge (spec 033, spec 062 R2); L hides it.
var ladder: StageList
## The next few things within reach (spec 037); G hides them. [member goals_view] draws them under
## the place panel (spec 062 R1).
var goals: Goals
var goals_view: GoalsView
## The windows on the UI layer (spec 058), which hold help, the journal's list and the orders;
## null when there is no UI layer (a HUD on its own in a test).
var windows: UiWindows:
	set(value):
		windows = value
		if frame_tip != null and value != null:
			frame_tip.covered = value.covers
## What beat the party and what would help (spec 041); its [member DefeatNote.panel] is drawn over
## every window (spec 062 R4).
var defeat_note: DefeatNote
## The party tally (spec 045): who deals, heals and takes the damage; the content of the Party
## tally window since spec 059, made here so it counts from the start.
var tally: TallyWindow
## The area map (spec 053): where the party can go, opened with W or the area's name; the content
## of the Area map window since spec 059.
var area_map: AreaMapWindow

var _simulation: Simulation
var _world: World
var _effects: CombatEffects
## The UI layer the frame of the screen is on, or null.
var _ui: UiRoot
var _icons: PixelSheet
var _frames_by_id: Dictionary[int, HeroFrameView] = {}
var _shown_gold: int = 0
var _since_coin: float = 0.0
var _gold_bump: float = 0.0
var _depth: int = 0
var _depth_emphasis: float = 0.0
## A target asked for that the simulation has not applied yet (it applies on the next tick), or 0.
var _asked_target: int = 0
var _auto_on: bool = false
## The room the frame of the screen is laid out in, in UI pixels.
var _frame_room: Vector2 = Vector2(UiRoot.MIN_ROOM)
## The simulation's tick at the last [method advance] (-1 before the first): more ticks than a
## stall since then and the frame shows where things are, not how they got there (spec 061 R9).
var _seen_tick: int = -1


func _ready() -> void:
	process_priority = 3  # after the world and the effects
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or _simulation == null:
		return
	var handled: bool = true
	# Specs 059 and 060: a window's keys act only while it is the front window of all (Esc, which
	# closes the front window, is the windows' own).
	var top: UiWindow = windows.front() if windows != null else null
	var hero_top: HeroWindow = top as HeroWindow
	match key.keycode:
		KEY_MINUS, KEY_KP_SUBTRACT:
			_step_target(-1)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_step_target(1)
		KEY_A:
			_toggle_auto()
		KEY_F3:
			if clock_label != null:
				clock_label.visible = not clock_label.visible
		KEY_TAB:
			# The next hero's window to the front, whatever is in front; Shift+Tab closes the
			# front hero window.
			if hero_windows == null or (key.shift_pressed and hero_top == null):
				handled = false
			elif key.shift_pressed:
				hero_top.close()
			else:
				hero_windows.open_next()
		KEY_B:
			handled = _in_front(shop)
			if handled:
				shop.toggle_auto_buy()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			# The shop's rows while it is the front window (spec 059 R2); paragon points while a
			# hero window on its Talents tab is (spec 034, spec 055, spec 060).
			var training: bool = hero_top != null and hero_top.page() == HeroWindow.Page.TALENTS
			if _in_front(shop):
				shop.buy_row(key.keycode - KEY_1)
			elif training and key.keycode <= KEY_3:
				hero_top.train_row(key.keycode - KEY_1)
			else:
				handled = false
		KEY_Q, KEY_E:
			# The front window's previous and next tab: a hero window's pages (spec 034, spec
			# 060) or the tally's measures (spec 059 R4).
			if hero_top != null:
				if key.keycode == KEY_Q:
					hero_top.previous_page()
				else:
					hero_top.next_page()
			elif _in_front(tally):
				if key.keycode == KEY_Q:
					tally.previous_measure()
				else:
					tally.next_measure()
			else:
				handled = false
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Call once, before the first advance.
func setup(simulation: Simulation, world: World, effects: CombatEffects) -> void:
	_simulation = simulation
	_world = world
	_effects = effects
	_icons = PixelSheet.load_sheet(ICONS_PATH)
	var veil := CrossingVeil.new()  # spec 054: first, so the rest of the HUD is drawn over it
	add_child(veil)
	veil.setup(world)
	_build_screen_frame()
	_build_shop()
	_adopt_clock()
	journal = Journal.new()
	add_child(journal)
	journal.setup(simulation, world)
	_build_ladder()
	goals = Goals.new()
	add_child(goals)
	goals.setup(simulation, world)
	# Spec 059: the tally and the area map are windows on the UI layer, which [UiRoot] makes.
	tally = TallyWindow.new()
	tally.setup(simulation, world, self)
	area_map = AreaMapWindow.new()
	area_map.setup(simulation, world, self)
	_build_news()
	place_panel.area_button.pressed.connect(area_map.toggle)
	purse.setup(simulation, effects.resource_effects if effects != null else null)
	defeat_note = DefeatNote.new()  # spec 041
	add_child(defeat_note)
	defeat_note.setup(simulation, world, self)
	screen_frame.add_child(defeat_note.panel)
	screen_frame.move_child(frame_tip, -1)  # the tooltips over everything else
	_tip_frame()
	_shown_gold = simulation.party.gold
	_depth = simulation.expedition.depth
	if world != null:
		world.sim_event.connect(_on_sim_event)
	if effects != null:
		effects.coin_collected.connect(_on_coin_collected)
	advance(0.0)


## Brings the HUD up to date and advances its animations. Called every frame; tests call it.
func advance(delta: float) -> void:
	if _simulation == null:
		return
	var stalled: bool = _seen_tick >= 0 and _simulation.tick - _seen_tick > _stall_ticks()
	_seen_tick = _simulation.tick
	var reviving: bool = _simulation.expedition.state == Expedition.State.REVIVING
	var battle: Battle = _simulation.expedition.battle
	var fighting: bool = _simulation.expedition.state == Expedition.State.FIGHTING
	for hero: Hero in _simulation.party.heroes:
		var frame: HeroFrameView = _frames_by_id.get(hero.id, null)
		if frame != null:
			frame.recovering = reviving
			frame.gold = _simulation.party.gold  # for its marker (spec 037 R4)
			frame.fighter = battle.combatant(hero.id) if fighting and battle != null else null
			frame.refresh(hero, delta)
			if stalled:
				frame.snap()
	purse.advance(delta)
	if stalled:
		purse.catch_up()
		_gold_bump = 0.0
		_depth_emphasis = 0.0
		_depth = _simulation.expedition.depth
	_advance_gold(delta)
	_advance_depth(delta)
	_advance_shop(delta)
	if hero_windows != null:
		hero_windows.advance(delta)
	boss_bar.advance(delta)
	if stalled:
		boss_bar.snap()
	journal.advance(delta)
	ladder.advance(delta)
	goals.advance(delta)
	tally.advance(delta)
	area_map.advance(delta)
	_mark_area()
	_lay_out_frame()
	defeat_note.advance(delta)
	frame_tip.advance(delta)


## Puts the frame of the screen on [param ui]'s layer (spec 061), under its windows, filling its
## room; its tooltip treats a point under a window as nowhere. Called by [method UiRoot.setup].
func adopt_frame(ui: UiRoot) -> void:
	_ui = ui
	screen_frame.reparent(ui.frame, false)
	ui.frame.move_child(screen_frame, 0)
	screen_frame.theme = null  # the layer's frame carries the theme
	screen_frame.scale = Vector2.ONE
	fit_frame(ui.room())


## Gives the frame of the screen a room of [param room] UI pixels, and lays it out. A room smaller
## than [constant UiRoot.MIN_ROOM] (a window under 960x540, as a headless test's is) has the frame
## laid out at that size and scaled down to fit, so it still keeps to the two bands.
func fit_frame(room: Vector2i) -> void:
	var fit: float = _fit(room)
	screen_frame.position = Vector2.ZERO
	screen_frame.scale = Vector2.ONE * fit
	_frame_room = Vector2(room) / fit
	# Lifted onto the layer ([method lift_tip]), the tip keeps to the layer's own room.
	frame_tip.room = _frame_room if frame_tip.get_parent() == screen_frame else Vector2(room)
	_lay_out_frame()


## The top of the hero frames on the UI layer in a room of [param room] UI pixels: where
## [method _lay_out_frame] puts them, scaled as [method fit_frame] scales the frame.
static func frames_line(room: Vector2i) -> float:
	var fit: float = _fit(room)
	return (float(room.y) / fit - FRAME_EDGE - HeroFrameView.SIZE.y) * fit


## The fraction the frame is drawn at in a room of [param room] UI pixels: 1, or less in a room
## smaller than [constant UiRoot.MIN_ROOM].
static func _fit(room: Vector2i) -> float:
	return minf(1.0, minf(float(room.x) / UiRoot.MIN_ROOM.x, float(room.y) / UiRoot.MIN_ROOM.y))


## Puts the note after a defeat over every window on [param ui]'s layer (spec 062 R4), and the
## frame's tooltip over everything else (the button bar, every window and the note), unscaled, in
## the layer's room. Called by [method UiRoot.setup] once all is on it.
func lift_tip(ui: UiRoot) -> void:
	var note: DefeatNoteView = defeat_note.panel
	note.reparent(ui.frame, false)
	ui.frame.move_child(note, -1)
	note.scale = Vector2.ONE
	note.z_index = 1  # as the tags on the bar's buttons, so a tag never draws over it
	frame_tip.reparent(ui.frame, false)
	ui.frame.move_child(frame_tip, -1)
	frame_tip.scale = Vector2.ONE
	frame_tip.z_index = 2  # over the tags on the bar's buttons, which draw at 1
	frame_tip.room = Vector2(ui.room())


## True while the window holding [param content] is the front window on the UI layer (spec 059).
func _in_front(content: Control) -> bool:
	var top: UiWindow = windows.front() if windows != null else null
	return top != null and top.content == content


## What the party is doing and why, as the place panel shows it: "Heading on to stage 5",
## "Fighting 3 monsters", "Resting, 64% health", "On the way to The Claypits 3" and so on (spec
## 027 R1, spec 049 R9: the area's name names the area the stages are in).
func status_text() -> String:
	var e: Expedition = _simulation.expedition
	var line: String = STATE_WORDS.get(e.state, "")
	match e.state:
		Expedition.State.TRAVELLING:
			line = "Hunting on stage %d" % e.depth
			if e.is_holding():
				var held: int = e.depth if e.target_depth > e.depth else e.depth - 1
				line = "Holding at the %s" % Content.monster(e.guardian_of(held)).display_name
			elif e.target_depth > e.depth:
				line = "Heading on to stage %d" % e.target_depth
			elif e.target_depth < e.depth:
				line = "Heading back to stage %d" % e.target_depth
		Expedition.State.FIGHTING:
			line = _fight_text(e.battle)
		Expedition.State.RESTING:
			line = "Resting, %d%% health" % _party_health_percent()
		Expedition.State.CLIMBING:
			var to: int = ClimbProgress.stage_to(e)  # spec 054: on or back, never down or up
			line = ("Going on to stage %d" if to > e.depth else "Going back to stage %d") % to
		Expedition.State.REVIVING:
			line = "Chased home! Regrouping"
		Expedition.State.WORKING:
			var quest: SideQuestDef = Content.side_quest(e.working_quest())
			if quest != null:
				line = "Working: %s" % quest.display_name
		Expedition.State.JOURNEYING:
			line = "On the way to " + PlaceText.of(e.area, e.travel.journey_stage(e))
	return line


## The road to stable (spec 027 R2, spec 039 R2): "Stable in m:ss" while the party must still hold
## this depth, "Further in m:ss" while auto-push counts down to the next, "Stable" otherwise, or
## "Holding" at a guardian, followed by what happens next (", then stage N",
## ", staying on stage N", ", Orders (O) to go in").
func stable_text() -> String:
	var parts: PackedStringArray = _stable_parts()
	return parts[0] if parts[1].is_empty() else "%s, %s" % [parts[0], parts[1]]


## How far the bar beside the note has filled, from 0 to 1: toward stable on this depth, or, once
## it is stable, toward auto-push's next push (spec 039 R2).
func stable_progress() -> float:
	var e: Expedition = _simulation.expedition
	if e.stable_seconds <= 0.0:
		return 1.0
	var left: float = e.seconds_to_push() if _pushing() else e.seconds_to_stable()
	return clampf(1.0 - left / e.stable_seconds, 0.0, 1.0)


## [param seconds] as a countdown, "m:ss", rounded up to the whole second.
static func clock(seconds: float) -> String:
	var whole: int = ceili(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


## The gold count currently displayed.
func shown_gold() -> int:
	return _shown_gold


## The texture of one part of the HUD icon sheet (a class id, [code]skull[/code] or
## [code]coin[/code]).
func icon(part: StringName) -> Texture2D:
	if _icons == null or not _icons.has_part(part):
		return null
	return _icons.part(part)


## True when the HUD shows auto-push as on.
func auto_on() -> bool:
	return _auto_on


## Seconds of the gold count's bump left; 0 when still.
func gold_bump() -> float:
	return _gold_bump


## Seconds of the depth number's emphasis left; 0 when still.
func depth_emphasis() -> float:
	return _depth_emphasis


## [param amount] with a comma between each group of three digits: 1234567 is "1,234,567".
static func group_thousands(amount: int) -> String:
	var digits: String = str(absi(amount))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + grouped


## [param amount] short enough for the top bar: as [method group_thousands] below 10,000, then
## rounded down to three figures with k or M ("12.3k", "123k", "9.9M", "123M"), so a count never
## shows more than it is.
static func short_count(amount: int) -> String:
	if absi(amount) < 10_000:
		return group_thousands(amount)
	var minus: String = "-" if amount < 0 else ""
	var value: int = absi(amount)
	var suffix: String = "k"
	var unit: int = 1000
	if value >= 1_000_000:
		suffix = "M"
		unit = 1_000_000
	var whole: int = value / unit
	if whole >= 100:
		return "%s%s%s" % [minus, group_thousands(whole), suffix]
	var tenths: int = (value * 10 / unit) % 10
	return "%s%d.%d%s" % [minus, whole, tenths, suffix]


## Where [param control] is, as a rectangle in the screen's 640x360 pixels (where input events
## and the old HUD are), wherever it is drawn: through its canvas layer's transform, never a
## camera's (a [Hud] built alone in a test sits on no layer, beside a world's camera).
static func on_screen(control: Control) -> Rect2:
	var xform: Transform2D = _screen_transform(control)
	return Rect2(xform.origin, control.size * xform.get_scale())


## From [param item]'s own pixels to the screen's: its canvas layer's transform, if any, times its
## global transform.
static func _screen_transform(item: CanvasItem) -> Transform2D:
	var layer: CanvasLayer = item.get_canvas_layer_node()
	var xform: Transform2D = item.get_global_transform()
	return layer.get_final_transform() * xform if layer != null else xform


# --- Building ------------------------------------------------------------------


## The frame of the screen (spec 061): its pieces, on a room-sized control that [UiRoot] takes
## onto its layer, or that stays on the HUD scaled to the screen when there is no UI layer.
func _build_screen_frame() -> void:
	screen_frame = Control.new()
	screen_frame.name = "ScreenFrame"
	screen_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_frame.theme = UiTheme.theme()
	# It draws nothing itself and takes no room: its pieces are laid out in [member _frame_room].
	_frame_room = Vector2(UiRoot.MIN_ROOM)
	screen_frame.scale = SCREEN / Vector2(UiRoot.MIN_ROOM)
	add_child(screen_frame)
	place_panel = PlacePanel.new()
	screen_frame.add_child(place_panel)
	place_panel.minus_button.pressed.connect(_step_target.bind(-1))
	place_panel.plus_button.pressed.connect(_step_target.bind(1))
	place_panel.auto_button.pressed.connect(_toggle_auto)
	countdown = Countdown.new()
	screen_frame.add_child(countdown)
	boss_bar = BossBarView.new()
	screen_frame.add_child(boss_bar)
	boss_bar.setup(_simulation, _world)
	purse = Purse.new(icon(&"coin"))
	screen_frame.add_child(purse)
	for hero: Hero in _simulation.party.heroes:
		var frame := HeroFrameView.new(hero, self)
		screen_frame.add_child(frame)
		frames.append(frame)
		_frames_by_id[hero.id] = frame
		frame.clicked.connect(_on_frame_clicked)  # spec 060: a click opens or closes its window
	frame_tip = UiTip.new()
	frame_tip.name = "FrameTip"
	frame_tip.follows_mouse = true
	frame_tip.set_process(false)  # advanced with the HUD
	frame_tip.room = _frame_room
	screen_frame.add_child(frame_tip)


## Gives each piece of the frame its tooltip (spec 061 R7): the old pieces' sentences, under a
## bold title where there is one. The first control under the mouse wins, so the small ones come
## before the panels that hold them.
func _tip_frame() -> void:
	frame_tip.attach(place_panel.area_button, AREA_TIP, place_panel.area_button.get_text)
	frame_tip.attach(place_panel.stage_label, STAGE_TIP)
	frame_tip.attach(place_panel.status_label, STATUS_TIP)
	frame_tip.attach(place_panel.safe_label, SAFE_TIP)
	frame_tip.attach(place_panel.target_label, TARGET_TIP)
	frame_tip.attach(place_panel.target_caption, TARGET_TIP)
	frame_tip.attach(place_panel.minus_button, MINUS_TIP)
	frame_tip.attach(place_panel.plus_button, PLUS_TIP)
	frame_tip.attach(place_panel.auto_button, AUTO_TIP)
	frame_tip.attach(countdown, _countdown_tip)
	for id: StringName in Content.resource_ids():
		frame_tip.attach(purse.icons[id], purse.tip_text.bind(id))
		frame_tip.attach(purse.labels[id], purse.tip_text.bind(id))
	frame_tip.attach(purse.speed_button, SPEED_TIP)
	frame_tip.attach(purse, GOLD_TIP, "Gold")
	frame_tip.attach(boss_bar, BOSS_TIP, boss_bar.shown_name)
	# Spec 037 R5: each goal says how to get there; spec 042 R3: then what a click does.
	for i: int in goals_view.rows.size():
		frame_tip.attach(goals_view.rows[i], goals_view.tip.bind(i))
	for frame: HeroFrameView in frames:
		# Spec 055 R9: the class and its path once one is chosen; spec 056 R5: the statuses.
		frame_tip.attach(frame, frame.tip, frame.tip_title)


## The countdown's tooltip (spec 039 R2): what decides what happens next.
func _countdown_tip() -> String:
	var note: String = countdown.note_label.text
	if note.begins_with("Further in"):
		return "Time left until Auto takes the party a stage further."
	if note == "Holding":
		return "The Hold order keeps the party from the guardian: Orders (O) sends it in."
	if countdown.bar.visible:
		return "Time left until this stage is safe."
	if countdown.next_label.text.begins_with("staying"):
		return "Safe, and Auto is off: the party stays until Auto is on or the target is further."
	return "This stage is safe: a wipe comes back here."


## The shop: the content of the Shop window since spec 059, which [UiRoot] puts in its window (the
## Shop button is on the bar).
func _build_shop() -> void:
	shop = ShopWindow.new()
	shop.setup(_simulation, _world, self)


## Shows the game's speed (spec 032) on the purse's speed button: its label, lit above 1x.
func show_speed(value: int) -> void:
	purse.speed_button.text = "%dx" % value
	purse.speed_button.lit = value > 1


## A click on hero [param hero_id]'s frame opens or closes its window (spec 060).
func _on_frame_clicked(hero_id: int) -> void:
	if hero_windows != null:
		hero_windows.toggle(hero_id)


## The stage list (spec 033, spec 062 R2): it hides itself on L and while the shop is open; a click
## on a row asks for a target, which the target number shows at once, as the - and + buttons do.
func _build_ladder() -> void:
	ladder = StageList.new()
	screen_frame.add_child(ladder)
	ladder.setup(_simulation, journal, shop)
	ladder.target_asked.connect(_on_ladder_target)


func _on_ladder_target(depth: int) -> void:
	_asked_target = depth
	_advance_depth(0.0)


## The goals and the ticker on the frame of the screen (spec 062 R1, R3).
func _build_news() -> void:
	goals_view = GoalsView.new()
	screen_frame.add_child(goals_view)
	goals_view.setup(goals)
	ticker = Ticker.new()
	screen_frame.add_child(ticker)
	ticker.clicked.connect(_on_ticker_clicked)


## A click on the ticker opens the Journal window (spec 062 R3).
func _on_ticker_clicked() -> void:
	if windows != null:
		windows.open_window(UiRoot.JOURNAL)


## The room the note after a defeat is laid out in, in its own UI pixels: the layer's room once it
## is lifted over the windows, else the frame of the screen's.
func note_room() -> Vector2:
	if _ui != null and defeat_note.panel.get_parent() == _ui.frame:
		return Vector2(_ui.room())
	return _frame_room


## [param world_px], a point in the screen's 640x360 pixels, in the note's own UI pixels.
func world_to_note(world_px: Vector2) -> Vector2:
	if _ui != null and defeat_note.panel.get_parent() == _ui.frame:
		return _ui.world_to_ui(world_px)
	var layer_px: Vector2 = world_px if _ui == null else _ui.world_to_ui(world_px)
	return screen_frame.get_transform().affine_inverse() * layer_px


func _mark_frames() -> void:
	for hero: Hero in _simulation.party.heroes:
		var frame: HeroFrameView = _frames_by_id.get(hero.id, null)
		if frame != null:
			frame.marked = hero_windows != null and hero_windows.is_open(hero.id)
			frame.refresh(hero, 0.0)
	_advance_shop(0.0)


## Takes over Main's tick readout, if there is one beside the HUD: dim, on an ink backing, hidden.
func _adopt_clock() -> void:
	if get_parent() == null:
		return
	clock_label = get_parent().get_node_or_null("ClockLabel") as Label
	if clock_label == null:
		return
	clock_label.add_theme_color_override(&"font_color", Palette.color(&"slate"))
	var backing := StyleBoxFlat.new()
	backing.bg_color = Palette.color(&"ink")
	backing.set_content_margin_all(2)
	backing.anti_aliasing = false
	clock_label.add_theme_stylebox_override(&"normal", backing)
	clock_label.visible = false


# --- Updating ------------------------------------------------------------------


func _advance_gold(delta: float) -> void:
	var gold: int = _simulation.party.gold
	_gold_bump = maxf(_gold_bump - delta, 0.0)
	if _shown_gold > gold:
		_shown_gold = gold
	if _shown_gold < gold:
		_since_coin += delta
		if _since_coin >= GOLD_CATCH_UP_SECONDS:
			_shown_gold = gold
	if _shown_gold >= gold:
		_since_coin = 0.0
	_show_gold()


func _show_gold() -> void:
	var lift: float = 1.0 if _gold_bump > GOLD_BUMP_SECONDS / 2.0 else 0.0
	var colour: StringName = &"white" if _gold_bump > 0.0 else &"yellow"
	# Spec 052: short, so the resources fit beside it.
	purse.show_gold(short_count(_shown_gold), colour, lift, PlacePanel.HEIGHT)


func _advance_depth(delta: float) -> void:
	var expedition: Expedition = _simulation.expedition
	_depth_emphasis = maxf(_depth_emphasis - delta, 0.0)
	if expedition.depth != _depth:
		_depth = expedition.depth
		_depth_emphasis = DEPTH_EMPHASIS_SECONDS
	if _asked_target > 0 and expedition.target_depth == _asked_target:
		_asked_target = 0
	var target: int = _asked_target if _asked_target > 0 else expedition.target_depth
	_auto_on = expedition.auto_push
	var emphasis: bool = _depth_emphasis > 0.0
	var lift: float = 1.0 if _depth_emphasis > DEPTH_EMPHASIS_SECONDS - 0.15 else 0.0
	var state_colour: StringName = STATE_COLOURS.get(expedition.state, &"silver")
	place_panel.show_place(
		PlaceText.area_name(expedition.place),
		_depth,
		&"yellow" if emphasis else &"white",
		lift,
		expedition.last_stable_depth,
		target,
		_auto_on,
		status_text(),
		state_colour
	)
	var road: PackedStringArray = _stable_parts()
	countdown.show_road(road[0], road[1], stable_progress(), PlacePanel.HEIGHT)


## The area's name marks each area opened since the map was last opened (spec 053 R6).
func _mark_area() -> void:
	var mark: UiBadge = place_panel.area_mark
	mark.count = area_map.news.unseen if area_map.news != null else 0
	var shown: bool = area_map.has_mark()
	if mark.visible != shown:
		mark.visible = shown
		place_panel.lay_out()
	place_panel.area_button.lit = area_map.is_open()


## Lays the frame of the screen out in its room (spec 061 R10): the place panel and the countdown at
## the top left, the purse at the top right, the boss bar centred between them, and the hero frames
## in a row along the bottom. Everything stays in the two bands; the effects are told where the
## counters and frames are.
func _lay_out_frame() -> void:
	var room: Vector2 = _frame_room
	place_panel.position = Vector2(FRAME_EDGE, FRAME_TOP)
	countdown.position = Vector2(place_panel.position.x + place_panel.size.x + FRAME_GAP, FRAME_TOP)
	purse.position = Vector2(room.x - FRAME_EDGE - purse.size.x, FRAME_TOP)
	var row: float = frames.size() * HeroFrameView.SIZE.x + maxi(frames.size() - 1, 0) * FRAME_GAP
	var x: float = floorf((room.x - row) / 2.0)
	for frame: HeroFrameView in frames:
		frame.position = Vector2(x, room.y - FRAME_EDGE - HeroFrameView.SIZE.y)
		x += HeroFrameView.SIZE.x + FRAME_GAP
	# The boss bar: centred on the room when it can be, between the countdown and the purse.
	var left: float = place_panel.position.x + place_panel.size.x + FRAME_GAP
	if countdown.visible:
		left = countdown.position.x + countdown.size.x + FRAME_GAP
	var right: float = purse.position.x - FRAME_GAP
	var widest: float = minf(BossBarView.MAX_WIDTH, room.x * BossBarView.ROOM_SHARE)
	var width_bar: float = floorf(minf(widest, right - left))
	var bar_x: float = clampf(floorf((room.x - width_bar) / 2.0), left, right - width_bar)
	boss_bar.place(Vector2(bar_x, FRAME_TOP), width_bar, PlacePanel.HEIGHT)
	# Spec 062: the goals under the place panel, the stage list at the right edge under the purse,
	# and the ticker just above the hero frames.
	var under: float = FRAME_TOP + PlacePanel.HEIGHT + FRAME_GAP
	goals_view.position = Vector2(FRAME_EDGE, under)
	ladder.position = Vector2(room.x - FRAME_EDGE - StageList.WIDTH, under)
	var frames_y: float = room.y - FRAME_EDGE - HeroFrameView.SIZE.y
	ticker.show_line(journal.ticker_text(), journal.ticker_colour(), room.x, frames_y)
	_aim_effects()


## Tells the effects where the frame's counters and frames are on the screen: coins fly to the
## coin, a resource's icons to its counter and XP motes to their hero's frame (spec 061 R4).
func _aim_effects() -> void:
	if _effects == null:
		return
	_effects.gold_screen_target = on_screen(purse.coin_icon).get_center()
	var ids: Array[StringName] = Content.resource_ids()
	for i: int in ids.size() if _effects.resource_effects != null else 0:
		_effects.resource_effects.targets[i] = on_screen(purse.icons[ids[i]]).get_center()
	for frame: HeroFrameView in frames:
		_effects.frame_screen_targets[frame.hero_id] = on_screen(frame).get_center()


## More ticks than this between two advances is a stall: as the world's own (spec 057 R7).
func _stall_ticks() -> int:
	return World.STALL_TICKS * maxi(_world.speed if _world != null else 1, 1)


## The road to stable's two parts (spec 039 R2): the note ("Stable in m:ss" while this depth is
## not yet stable, "Further in m:ss" while auto-push counts down to the next, "Stable", or
## "Holding" at a guardian) and what happens next at the target ("then stage N", "staying on
## stage N", "Orders (O) to go in", or "").
func _stable_parts() -> PackedStringArray:
	var e: Expedition = _simulation.expedition
	if e.is_holding():
		return PackedStringArray(["Holding", "Orders (O) to go in"])
	if e.state == Expedition.State.REVIVING:
		return PackedStringArray(["Stable", ""])
	if e.state == Expedition.State.JOURNEYING:
		return PackedStringArray(["", ""])
	var at_target: bool = e.depth == e.target_depth
	var next: String = "then stage %d" % (e.depth + 1) if at_target and e.auto_push else ""
	if e.depth > e.last_stable_depth:
		return PackedStringArray(["Stable in " + clock(e.seconds_to_stable()), next])
	if _pushing():
		return PackedStringArray(["Further in " + clock(e.seconds_to_push()), next])
	if at_target and not e.auto_push:
		next = "staying on stage %d" % e.depth
	return PackedStringArray(["Stable", next])


## True while this depth is stable and auto-push is counting down to the next (spec 039 R2).
func _pushing() -> bool:
	var e: Expedition = _simulation.expedition
	return (
		e.auto_push
		and e.depth == e.target_depth
		and e.depth <= e.last_stable_depth
		and e.state != Expedition.State.REVIVING
	)


func _fight_text(battle: Battle) -> String:
	if battle == null:
		return STATE_WORDS[Expedition.State.FIGHTING]
	var alive: int = 0
	for monster: Combatant in battle.monsters:
		var def: MonsterDef = Content.monster(monster.def_id)
		if def != null and def.guardian and monster.is_alive():
			return "Fighting the %s" % def.display_name
		if monster.is_alive():
			alive += 1
	return "Fighting %d monster%s" % [alive, "" if alive == 1 else "s"]


## The party's health together, as a whole percentage of its most.
func _party_health_percent() -> int:
	var health: int = 0
	var most: int = 0
	for hero: Hero in _simulation.party.heroes:
		health += hero.health
		most += hero.max_health()
	return floori(100.0 * health / maxi(most, 1))


func _advance_shop(delta: float) -> void:
	shop.advance(delta)


# --- Reacting ------------------------------------------------------------------


func _on_sim_event(event: SimEvent) -> void:
	if event.kind == SimEvent.Kind.PARAGON_SPENT and hero_windows != null:
		hero_windows.flash_paragon(event.source_id, event.target_id)
	if event.kind == SimEvent.Kind.UPGRADE_BOUGHT:
		# The purchase spent gold: the count drops to the real gold at once.
		_shown_gold = _simulation.party.gold
		_since_coin = 0.0
		_show_gold()
		return
	if _world != null and not _world.is_recent(event):
		return
	var frame: HeroFrameView = _frames_by_id.get(event.target_id, null)
	if frame == null:
		return
	match event.kind:
		SimEvent.Kind.HIT:
			frame.hit()
		SimEvent.Kind.LEVEL_UP:
			frame.level_up()


func _on_coin_collected(amount: int) -> void:
	_shown_gold = mini(_shown_gold + maxi(amount, 0), _simulation.party.gold)
	_since_coin = 0.0
	_gold_bump = GOLD_BUMP_SECONDS
	_show_gold()


func _step_target(by: int) -> void:
	var from: int = _asked_target if _asked_target > 0 else _simulation.expedition.target_depth
	_asked_target = maxi(from + by, 1)
	_simulation.set_target_depth(_asked_target)
	_advance_depth(0.0)


func _toggle_auto() -> void:
	_simulation.set_auto_push(not _simulation.expedition.auto_push)
	_advance_depth(0.0)
