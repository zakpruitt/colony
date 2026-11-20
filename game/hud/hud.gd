class_name Hud
extends Control
## The HUD: what the screen tells of the party, around the world. It draws nothing in the world's
## pixels but the dark of a crossing ([CrossingVeil], with the world's own title): everything else
## is on the sharp layer.
##
## The HUD only reads the simulation, and listens to [signal World.sim_event] for hits and
## level-ups; the player's choices reach the simulation through [method Simulation.set_target_depth]
## and [method Simulation.set_auto_push]. It keeps to the top [constant HudFrame.TOP_BAND] and the
## bottom [constant HudFrame.BOTTOM_BAND] pixels of the 640x360 screen. It answers its own keys
## only (the target's, Auto's and the clock's, as [KeyBook] has them); the windows' are
## [WindowKeys]'.
##
## The place panel says what the party is doing and why ([method status_text]) and how long until
## this stage is stable, or until auto-push's next push once it is ([method stable_text]); a
## [Journal] keeps the last happenings, with a ticker over the frames (its list is the Journal
## window on the UI layer).
##
## The frame of the screen is on the sharp layer, in the UI font. Its panels are [FramePiece]s,
## held in [member pieces] and driven alike (advanced every frame, caught up after a stall, given
## their tooltips once): the [PlacePanel] and the [Countdown] at the top left, the [Purse] at the
## top right, the [BossBarView] between them in a guardian fight, the goals ([GoalsView]) under the
## place panel, the stage list ([StageList]) at the right edge and the [Ticker] over the hero
## frames. Beside them are a [HeroFrameView] per hero along the bottom and the note after a defeat
## ([DefeatNoteView]), which [UiRoot] lifts over every window. They hang from
## [member screen_frame], which [UiRoot] takes onto its layer; a HUD on its own (a test) keeps it,
## scaled so that its 960x540 UI pixels cover the 640x360 screen. The frame is laid out when the
## room changes or a piece's size or visibility does, not on an idle frame. The place's texts are
## made here, worded only when what they say changed, and only drawn there; the tooltips are
## [member frame_tip]. [Goals], [Journal] and [DefeatNote] decide what they say; they draw nothing,
## and are handed in their setup what they reach. It also makes and advances the shop, the map and
## the tally, windows' content, and the dark of a crossing ([CrossingVeil]).

## Space between the HUD and the screen's edge.
const MARGIN: float = 4.0
## Seconds after the last coin before a shown gold count that is still behind catches up.
const GOLD_CATCH_UP_SECONDS: float = 3.0
## Seconds the gold count bumps on each coin.
const GOLD_BUMP_SECONDS: float = 0.15
## Seconds the depth number is emphasised after a change of depth.
const DEPTH_EMPHASIS_SECONDS: float = 0.6
## The colour of each expedition state's line ([member HudFrame.STATE_WORDS] has its word).
const STATE_COLOURS: Dictionary[Expedition.State, StringName] = {
	Expedition.State.TRAVELLING: &"silver",
	Expedition.State.FIGHTING: &"orange",
	Expedition.State.RESTING: &"green",
	Expedition.State.CLIMBING: &"tan",
	Expedition.State.REVIVING: &"pink",
	Expedition.State.WORKING: &"amber",
	Expedition.State.JOURNEYING: &"tan",
}

## The frame of the screen: the room-sized control its pieces hang from.
var screen_frame: Control
## The frame's panels, in the order they are advanced and given their tooltips.
var pieces: Array[FramePiece] = []
## How many times the frame has been laid out, and how many times the place's status line and road
## to stable have been worded: a frame where nothing changed adds to neither.
var layouts: int = 0
var worded: int = 0
## Where the party is: the area, the stage, the safe stage, the target, Auto and the status line.
var place_panel: PlacePanel
## The road to stable, beside the place panel.
var countdown: Countdown
## The gold, the resources and the game-speed button. Main connects the button's click and tells
## the purse the speed ([method Purse.show_speed]).
var purse: Purse
## One frame per hero, in formation order, left to right.
var frames: Array[HeroFrameView] = []
## The guardian's health during a guardian fight.
var boss_bar: BossBarView
## The tooltips of the frame's pieces.
var frame_tip: UiTip
## Main's tick readout, for developers: bottom right, dim, hidden until F3; null without one.
var clock_label: Label
## The upgrade shop: the content of the Shop window on the UI layer, made here so it hears the
## simulation from the start; [UiRoot] puts it in its window.
var shop: ShopWindow
## The last happenings, behind the ticker over the party frames and the Journal window.
var journal: Journal
## The journal's newest line over the hero frames; a click opens the Journal.
var ticker: Ticker
## The dark of a crossing and its title: the world's own, all the HUD draws in the world's pixels.
var veil: CrossingVeil
## A window per hero on the UI layer, opened by clicking its frame or with Tab; null
## when there is no UI layer (a HUD on its own in a test). Set by [method UiRoot.setup], and handed
## on to the goals and the note after a defeat, which open them.
var hero_windows: HeroWindows:
	set(value):
		hero_windows = value
		if goals != null:
			goals.hero_windows = value
			defeat_note.hero_windows = value
		if value != null:
			value.changed.connect(_mark_frames)
			_mark_frames()
## The stages of this area down the right edge; L hides it.
var ladder: StageList
## The next few things within reach; G hides them. [member goals_view] draws them under the place
## panel.
var goals: Goals
var goals_view: GoalsView
## The windows on the UI layer, which hold help, the journal's list and the orders;
## null when there is no UI layer (a HUD on its own in a test). Handed on to the goals and the
## note after a defeat.
var windows: UiWindows:
	set(value):
		windows = value
		if goals != null:
			goals.windows = value
			defeat_note.windows = value
		if frame_tip != null and value != null:
			frame_tip.covered = _covered
## What beat the party and what would help; its [member DefeatNote.panel] is drawn over every
## window.
var defeat_note: DefeatNote
## The party tally: who deals, heals and takes the damage; the content of the Party tally window,
## made here so it counts from the start.
var tally: TallyWindow
## The area map: where the party can go, opened with W or the area's name; the content of the
## Area map window.
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
## stall since then and the frame shows where things are, not how they got there.
var _seen_tick: int = -1
## True once [method lift_tip] has put the frame's tooltip on the UI layer.
var _tip_lifted: bool = false
## True once the pieces have been given their tooltips.
var _tips_given: bool = false
## The gold count's words and the count they were made for: worded again only on a change.
var _gold_text: String = ""
var _gold_text_of: int = 0
## What the frame was last laid out from: each piece's size and visibility, and where the coin is.
var _laid_from: ShownValues = ShownValues.new()
## What the place's words were last made from, and those words: the area's name, the status line,
## the road to stable's two parts and how far its bar has filled.
var _worded_from: ShownValues = ShownValues.new()
var _area_text: String = ""
var _status: String = ""
var _road: PackedStringArray = PackedStringArray(["", ""])
var _road_filled: float = 0.0


func _ready() -> void:
	process_priority = 3  # after the world and the effects
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = KeyBook.fresh_key(event)
	if key == null or _simulation == null:
		return
	var target: PackedStringArray = KeyBook.label(&"target").split(" ")  # back, then further
	if KeyBook.stands_for(key, target[0]):
		_step_target(-1)
	elif KeyBook.stands_for(key, target[1]):
		_step_target(1)
	elif KeyBook.stands_for(key, KeyBook.label(&"auto")):
		_toggle_auto()
	elif KeyBook.stands_for(key, KeyBook.label(&"clock")):
		if clock_label != null:
			clock_label.visible = not clock_label.visible
	else:
		return
	get_viewport().set_input_as_handled()


## The world the HUD was set up with, or null before [method setup].
func world_view() -> World:
	return _world


## Adds [param piece] to the frame: on [member screen_frame], in [member pieces], given its tooltips
## (at once if the frame's are given already). [method _lay_out_frame] says where it goes.
func add_piece(piece: FramePiece) -> void:
	pieces.append(piece)
	screen_frame.add_child(piece)
	if _tips_given:
		piece.add_tips(frame_tip)
		if not _tip_lifted:
			screen_frame.move_child(frame_tip, -1)  # the tooltips over everything else


## Call once, before the first advance. [param clock] is Main's tick readout, which the HUD dims
## and hides until F3 (null for none).
func setup(
	simulation: Simulation, world: World, effects: CombatEffects, clock: Label = null
) -> void:
	_simulation = simulation
	_world = world
	_effects = effects
	_icons = PixelSheet.load_sheet(HudFrame.ICONS_PATH)
	veil = CrossingVeil.new()
	add_child(veil)
	veil.setup(world)
	_build_screen_frame()
	_build_shop()
	_adopt_clock(clock)
	journal = Journal.new()
	add_child(journal)
	journal.setup(simulation, world)
	_build_ladder()
	# The tally and the area map are the content of windows on the UI layer, which [UiRoot] makes.
	tally = TallyWindow.new()
	tally.setup(simulation, world)
	area_map = AreaMapWindow.new()
	area_map.setup(simulation, world, ladder, journal)
	area_map.target_asked.connect(_on_ladder_target)
	goals = Goals.new()
	add_child(goals)
	goals.setup(simulation, world, journal, shop, area_map, ladder)
	_build_news()
	place_panel.area_button.pressed.connect(area_map.toggle)
	purse.setup(simulation, effects.resource_effects if effects != null else null)
	defeat_note = DefeatNote.new()
	add_child(defeat_note)
	defeat_note.setup(simulation, world, shop, frame_tip, screen_frame)
	journal.defeat_note = defeat_note
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
			frame.gold = _simulation.party.gold  # for its marker
			frame.fighter = battle.combatant(hero.id) if fighting and battle != null else null
			frame.refresh(hero, delta)
			if stalled:
				frame.snap()
	if stalled:
		_gold_bump = 0.0
		_depth_emphasis = 0.0
		_depth = _simulation.expedition.depth
	# The journal before the stage list, which writes to it; the purse before the gold and the
	# resources are shown from its counts.
	journal.advance(delta)
	for piece: FramePiece in pieces:
		piece.advance(delta)
		if stalled:
			piece.catch_up()
	_advance_gold(delta)
	_advance_depth(delta)
	_advance_shop(delta)
	if hero_windows != null:
		hero_windows.advance(delta)
	goals.advance(delta)
	tally.advance(delta)
	area_map.advance(delta)
	_mark_area()
	if _frame_moved():
		_lay_out_frame()
	defeat_note.advance(delta)
	frame_tip.advance(delta)
	veil.refresh()


## Puts the frame of the screen on [param ui]'s layer, under its windows, filling its
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
	var fit: float = HudFrame.fit(room)
	screen_frame.position = Vector2.ZERO
	screen_frame.scale = Vector2.ONE * fit
	_frame_room = Vector2(room) / fit
	# Lifted onto the layer ([method lift_tip]), the tip keeps to the layer's own room.
	frame_tip.room = Vector2(room) if _tip_lifted else _frame_room
	_lay_out_frame()


## Puts the note after a defeat over every window on [param ui]'s layer ([method DefeatNote.lift]),
## and the frame's tooltip over everything else (the button bar, every window and the note),
## unscaled, in the layer's room. Called by [method UiRoot.setup] once all is on it.
func lift_tip(ui: UiRoot) -> void:
	defeat_note.lift(ui)
	frame_tip.reparent(ui.frame, false)
	ui.frame.move_child(frame_tip, -1)
	frame_tip.scale = Vector2.ONE
	frame_tip.z_index = 2  # over the stage list's line, which draws at 1
	frame_tip.room = Vector2(ui.room())
	_tip_lifted = true


## What the party is doing and why, as the place panel shows it: "Heading on to stage 5",
## "Fighting 3 monsters", "Resting, 64% health", "On the way to The Claypits 3" and so on (the
## area's name names the area the stages are in).
func status_text() -> String:
	var e: Expedition = _simulation.expedition
	var line: String = HudFrame.STATE_WORDS.get(e.state, "")
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
			var to: int = ClimbProgress.stage_to(e)  # on or back, never down or up
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


## The road to stable: "Stable in m:ss" while the party must still hold
## this depth, "Further in m:ss" while auto-push counts down to the next, "Stable" otherwise, or
## "Holding" at a guardian, followed by what happens next (", then stage N",
## ", staying on stage N", ", Orders (O) to go in").
func stable_text() -> String:
	var parts: PackedStringArray = _stable_parts()
	return parts[0] if parts[1].is_empty() else "%s, %s" % [parts[0], parts[1]]


## How far the bar beside the note has filled, from 0 to 1: toward stable on this depth, or, once
## it is stable, toward auto-push's next push.
func stable_progress() -> float:
	var e: Expedition = _simulation.expedition
	if e.stable_seconds <= 0.0:
		return 1.0
	var left: float = e.seconds_to_push() if _pushing() else e.seconds_to_stable()
	return clampf(1.0 - left / e.stable_seconds, 0.0, 1.0)


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


# --- Building ------------------------------------------------------------------


## The frame of the screen: its pieces, on a room-sized control that [UiRoot] takes
## onto its layer, or that stays on the HUD scaled to the screen when there is no UI layer.
func _build_screen_frame() -> void:
	screen_frame = Control.new()
	screen_frame.name = "ScreenFrame"
	screen_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_frame.theme = UiTheme.theme()
	# It draws nothing itself and takes no room: its pieces are laid out in [member _frame_room].
	_frame_room = Vector2(UiRoot.MIN_ROOM)
	screen_frame.scale = HudFrame.SCREEN / Vector2(UiRoot.MIN_ROOM)
	add_child(screen_frame)
	place_panel = PlacePanel.new()
	add_piece(place_panel)
	place_panel.minus_button.pressed.connect(_step_target.bind(-1))
	place_panel.plus_button.pressed.connect(_step_target.bind(1))
	place_panel.auto_button.pressed.connect(_toggle_auto)
	countdown = Countdown.new()
	add_piece(countdown)
	boss_bar = BossBarView.new()
	add_piece(boss_bar)
	boss_bar.setup(_simulation, _world)
	purse = Purse.new(icon(&"coin"))
	add_piece(purse)
	for hero: Hero in _simulation.party.heroes:
		var frame := HeroFrameView.new(hero, self)
		screen_frame.add_child(frame)
		frames.append(frame)
		_frames_by_id[hero.id] = frame
		frame.clicked.connect(_on_frame_clicked)
	frame_tip = UiTip.new()
	frame_tip.name = "FrameTip"
	frame_tip.follows_mouse = true
	frame_tip.set_process(false)  # advanced with the HUD
	frame_tip.room = _frame_room
	screen_frame.add_child(frame_tip)


## Gives each piece of the frame its tooltips, then each hero frame its own. The first control
## under the mouse wins: a piece gives its small controls theirs before its panel's.
func _tip_frame() -> void:
	for piece: FramePiece in pieces:
		piece.add_tips(frame_tip)
	for frame: HeroFrameView in frames:
		# The class and its path once one is chosen, then the statuses.
		frame_tip.attach(frame, frame.tip, frame.tip_title)
	_tips_given = true


## The shop: the content of the Shop window, which [UiRoot] puts in its window (the Shop button is
## on the bar).
func _build_shop() -> void:
	shop = ShopWindow.new()
	shop.setup(_simulation, _world)


## A click on hero [param hero_id]'s frame opens or closes its window.
func _on_frame_clicked(hero_id: int) -> void:
	if hero_windows != null:
		hero_windows.toggle(hero_id)


## The stage list: it hides itself on L and while the shop is open; a click
## on a row asks for a target, which the target number shows at once, as the - and + buttons do.
func _build_ladder() -> void:
	ladder = StageList.new()
	add_piece(ladder)
	ladder.setup(_simulation, journal)
	ladder.target_asked.connect(_on_ladder_target)


func _on_ladder_target(depth: int) -> void:
	_asked_target = depth
	_advance_depth(0.0)


## The goals and the ticker on the frame of the screen.
func _build_news() -> void:
	goals_view = GoalsView.new()
	add_piece(goals_view)
	goals_view.setup(goals)
	ticker = Ticker.new()
	add_piece(ticker)
	ticker.clicked.connect(_on_ticker_clicked)
	journal.ticker_changed.connect(_show_ticker)


## Shows the journal's newest line in the ticker, just above the hero frames, clear of the button
## bar beside it. Called as the frame is laid out and whenever the line changes.
func _show_ticker() -> void:
	var room: Vector2 = _frame_room
	var frames_y: float = room.y - HudFrame.FRAME_EDGE - HeroFrameView.SIZE.y
	var bar_left: float = room.x
	if _ui != null and _ui.bar != null:
		var bar_at: Vector2 = _ui.bar.rect_in(Vector2i(_ui.room())).position
		bar_left = (screen_frame.get_transform().affine_inverse() * bar_at).x
	ticker.show_line(journal.ticker_text(), journal.ticker_colour(), room.x, frames_y, bar_left)


## True when [param at] (the viewport's coordinates) lies on a window or the button bar and not on
## the note after a defeat, which is drawn over them: the frame's tip treats such a
## point as nowhere.
func _covered(at: Vector2) -> bool:
	if windows == null or not windows.covers(at):
		return false
	return not (defeat_note.is_shown() and UiFormat.on_screen(defeat_note.panel).has_point(at))


## A click on the ticker opens the Journal window.
func _on_ticker_clicked() -> void:
	if windows != null:
		windows.open_window(UiRoot.JOURNAL)


func _mark_frames() -> void:
	for hero: Hero in _simulation.party.heroes:
		var frame: HeroFrameView = _frames_by_id.get(hero.id, null)
		if frame != null:
			frame.marked = hero_windows != null and hero_windows.is_open(hero.id)
			frame.refresh(hero, 0.0)
	_advance_shop(0.0)


## Takes over Main's tick readout, [param clock], if there is one: dim, on an ink backing, hidden.
func _adopt_clock(clock: Label) -> void:
	clock_label = clock
	if clock_label == null:
		return
	WindowText.set_colour(clock_label, &"slate")
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
	if _gold_text.is_empty() or _shown_gold != _gold_text_of:
		_gold_text_of = _shown_gold
		_gold_text = UiFormat.short_count(_shown_gold)  # short, so the resources fit beside it
	purse.show_gold(_gold_text, colour, lift, PlacePanel.HEIGHT)


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
	if _place_changed():
		worded += 1
		_area_text = PlaceText.area_name(expedition.place)
		_status = status_text()
		_road = _stable_parts()
		_road_filled = stable_progress()
	place_panel.show_place(
		_area_text,
		_depth,
		&"yellow" if emphasis else &"white",
		lift,
		expedition.last_stable_depth,
		target,
		_auto_on,
		_status,
		state_colour
	)
	countdown.show_road(_road[0], _road[1], _road_filled, PlacePanel.HEIGHT)


## True when anything the status line and the road to stable are made from has changed since they
## were last worded: the simulation's tick (everything the simulation does moves on with it) and
## what a command or a test changes between ticks.
func _place_changed() -> bool:
	var e: Expedition = _simulation.expedition
	_worded_from.begin()
	_worded_from.see(_simulation.tick)
	_worded_from.see(e.state)
	_worded_from.see(e.place)
	_worded_from.see(e.area)
	_worded_from.see(e.depth)
	_worded_from.see(e.target_depth)
	_worded_from.see(e.deepest_depth)
	_worded_from.see(e.last_stable_depth)
	_worded_from.see(e.auto_push)
	_worded_from.see(e.guardian_order)
	_worded_from.see(e.stable_seconds)
	_worded_from.see(e.battle != null)
	_worded_from.see(_alive_monsters(e.battle))
	for hero: Hero in _simulation.party.heroes:
		_worded_from.see(hero.health)
		_worded_from.see(hero.level)
	return _worded_from.changed()


## The area's name marks each area opened since the map was last opened.
func _mark_area() -> void:
	var mark: UiBadge = place_panel.area_mark
	mark.count = area_map.news.unseen if area_map.news != null else 0
	var shown: bool = area_map.has_mark()
	if mark.visible != shown:
		mark.visible = shown
		place_panel.lay_out()
	place_panel.area_button.lit = area_map.is_open()


## Lays the frame of the screen out in its room: the place panel and the countdown at
## the top left, the purse at the top right, the boss bar centred between them, and the hero frames
## in a row along the bottom. Everything stays in the two bands; the effects are told where the
## counters and frames are. A new piece is placed here.
func _lay_out_frame() -> void:
	layouts += 1
	var room: Vector2 = _frame_room
	place_panel.position = Vector2(HudFrame.FRAME_EDGE, HudFrame.FRAME_TOP)
	countdown.position = Vector2(
		place_panel.position.x + place_panel.size.x + HudFrame.FRAME_GAP, HudFrame.FRAME_TOP
	)
	purse.position = Vector2(room.x - HudFrame.FRAME_EDGE - purse.size.x, HudFrame.FRAME_TOP)
	var row: float = (
		frames.size() * HeroFrameView.SIZE.x + maxi(frames.size() - 1, 0) * HudFrame.FRAME_GAP
	)
	var x: float = floorf((room.x - row) / 2.0)
	for frame: HeroFrameView in frames:
		frame.position = Vector2(x, room.y - HudFrame.FRAME_EDGE - HeroFrameView.SIZE.y)
		x += HeroFrameView.SIZE.x + HudFrame.FRAME_GAP
	# The boss bar: centred on the room when it can be, between the countdown and the purse.
	var left: float = place_panel.position.x + place_panel.size.x + HudFrame.FRAME_GAP
	if countdown.visible:
		left = countdown.position.x + countdown.size.x + HudFrame.FRAME_GAP
	var right: float = purse.position.x - HudFrame.FRAME_GAP
	var widest: float = minf(BossBarView.MAX_WIDTH, room.x * BossBarView.ROOM_SHARE)
	var width_bar: float = floorf(minf(widest, right - left))
	var bar_x: float = clampf(floorf((room.x - width_bar) / 2.0), left, right - width_bar)
	boss_bar.place(Vector2(bar_x, HudFrame.FRAME_TOP), width_bar, PlacePanel.HEIGHT)
	# The goals under the place panel, the stage list at the right edge under the purse, and the
	# ticker just above the hero frames.
	var under: float = HudFrame.FRAME_TOP + PlacePanel.HEIGHT + HudFrame.FRAME_GAP
	goals_view.position = Vector2(HudFrame.FRAME_EDGE, under)
	ladder.position = Vector2(room.x - HudFrame.FRAME_EDGE - StageList.WIDTH, under)
	_show_ticker()
	_aim_effects()
	_frame_moved()  # what it was laid out from, so the next frame lays it out only on a change


## True when a piece's size or visibility, or the coin in the purse, has moved since the frame was
## last laid out.
func _frame_moved() -> bool:
	_laid_from.begin()
	for piece: FramePiece in pieces:
		_laid_from.see(piece.size)
		_laid_from.see(piece.visible)
	_laid_from.see(purse.coin_icon.position)
	return _laid_from.changed()


## Tells the effects where the frame's counters and frames are on the screen: coins fly to the
## coin, a resource's icons to its counter and XP motes to their hero's frame.
func _aim_effects() -> void:
	if _effects == null:
		return
	_effects.gold_screen_target = UiFormat.on_screen(purse.coin_icon).get_center()
	var ids: Array[StringName] = Content.resource_ids()
	for i: int in ids.size() if _effects.resource_effects != null else 0:
		_effects.resource_effects.targets[i] = UiFormat.on_screen(purse.icons[ids[i]]).get_center()
	for frame: HeroFrameView in frames:
		_effects.frame_screen_targets[frame.hero_id] = UiFormat.on_screen(frame).get_center()


## More ticks than this between two advances is a stall, as for the world.
func _stall_ticks() -> int:
	return World.STALL_TICKS * maxi(_world.speed if _world != null else 1, 1)


## The road to stable's two parts: the note ("Stable in m:ss" while this depth is
## not yet stable, "Further in m:ss" while auto-push counts down to the next, "Stable", or
## "Holding" at a guardian) and what happens next at the target ("then stage N", "staying on
## stage N", "Orders (O) to go in", or "").
func _stable_parts() -> PackedStringArray:
	var e: Expedition = _simulation.expedition
	if e.is_holding():
		return PackedStringArray(["Holding", HudFrame.holding_next()])
	if e.state == Expedition.State.REVIVING:
		return PackedStringArray(["Stable", ""])
	if e.state == Expedition.State.JOURNEYING:
		return PackedStringArray(["", ""])
	var at_target: bool = e.depth == e.target_depth
	var next: String = "then stage %d" % (e.depth + 1) if at_target and e.auto_push else ""
	if e.depth > e.last_stable_depth:
		return PackedStringArray(["Stable in " + UiFormat.clock(e.seconds_to_stable()), next])
	if _pushing():
		return PackedStringArray(["Further in " + UiFormat.clock(e.seconds_to_push()), next])
	if at_target and not e.auto_push:
		next = "staying on stage %d" % e.depth
	return PackedStringArray(["Stable", next])


## True while this depth is stable and auto-push is counting down to the next.
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
		return HudFrame.STATE_WORDS[Expedition.State.FIGHTING]
	var guardian: Combatant = CombatEffects.battle_guardian(_simulation)
	if guardian != null and guardian.is_alive():
		return "Fighting the %s" % Content.monster(guardian.def_id).display_name
	var alive: int = _alive_monsters(battle)
	return "Fighting %d monster%s" % [alive, "" if alive == 1 else "s"]


## How many of [param battle]'s monsters are alive; 0 with no battle.
func _alive_monsters(battle: Battle) -> int:
	var alive: int = 0
	if battle == null:
		return alive
	for monster: Combatant in battle.monsters:
		if monster.is_alive():
			alive += 1
	return alive


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
	if event.kind == SimEvent.Kind.PARAGON_SPENT and hero_windows != null and _fresh(event):
		hero_windows.flash_paragon(event.source_id, event.target_id)
	if event.kind == SimEvent.Kind.UPGRADE_BOUGHT:
		# The purchase spent gold: the count drops to the real gold at once.
		_shown_gold = _simulation.party.gold
		_since_coin = 0.0
		_show_gold()
		return
	if not _fresh(event):
		return
	var frame: HeroFrameView = _frames_by_id.get(event.target_id, null)
	if frame == null:
		return
	match event.kind:
		SimEvent.Kind.HIT:
			frame.hit()
		SimEvent.Kind.LEVEL_UP:
			frame.level_up()


## True when [param event] may start a flash: it is recent and the world is not catching up.
func _fresh(event: SimEvent) -> bool:
	return _world == null or _world.may_animate(event)


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
