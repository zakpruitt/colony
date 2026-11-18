class_name Hud
extends Control
## The party frames, the purse, the depth and the target-depth control (spec 011).
##
## The HUD only reads the simulation, and listens to [signal World.sim_event] for hits and
## level-ups; the player's choices reach the simulation through [method Simulation.set_target_depth]
## and [method Simulation.set_auto_push]. It keeps to the top [constant TOP_BAND] and the bottom
## [constant BOTTOM_BAND] pixels of the 640x360 screen, and every text and bar sits on a dark
## [HudPanel]. Laid out in screen pixels from the top-left corner.
##
## Spec 027 makes the party readable: the depth panel says what the party is doing and why
## ([method status_text]) and how long until this depth is stable ([method stable_text]), and a
## [Journal] keeps the last happenings, with a ticker over the frames (its list is the Journal
## window on the UI layer, spec 058).
## Spec 039 makes that note count down to auto-push's next push once the depth is stable.

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
## Pixels between the Shop button and its panel's right edge: room for the marker.
const SHOP_TAB_RIGHT: float = 6.0
## The sheet of HUD icons: a portrait per hero class, a skull and a coin.
const ICONS_PATH: String = "res://assets/sprites/ui/hud_icons.png"
## Seconds after the last coin before a shown gold count that is still behind catches up.
const GOLD_CATCH_UP_SECONDS: float = 3.0
## Seconds the gold count bumps on each coin.
const GOLD_BUMP_SECONDS: float = 0.15
## Seconds the depth number is emphasised after a change of depth.
const DEPTH_EMPHASIS_SECONDS: float = 0.6
## The road to stable (spec 027 R2): the bar's size in pixels.
const STABLE_BAR: Vector2 = Vector2(40, 5)
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

## One frame per hero, in formation order, left to right.
var frames: Array[HeroFrame] = []
var gold_panel: HudPanel
var gold_label: Label
var coin_icon: TextureRect
## The resources the party holds, after the gold in its panel (spec 052).
var resource_purse: ResourcePurse
var depth_panel: HudPanel
## The current depth, in the big font.
var depth_label: Label
var depth_caption: Label
## The line between the depth and the rest of the panel.
var depth_divider: ColorRect
## "Safe N": the last stable depth, the one the party falls back to (spec 028 R8).
var stable_label: Label
var target_caption: Label
## The target depth's number, between the - and + buttons.
var target_label: Label
## What the party is doing and why, in a short sentence: [method status_text].
var state_label: Label
## The road to stable (spec 027 R2), right of the target: "Stable in m:ss" or "Further in m:ss"
## over a thin bar and what happens next, or "Stable" (spec 039 R2).
var stable_note: Label
var stable_bar: Control
var stable_next: Label
var stable_divider: ColorRect
var minus_button: HudButton
var plus_button: HudButton
var auto_button: HudButton
## Main's tick readout, for developers: bottom right, dim, hidden until F3.
var clock_label: Label
## The upgrade shop (spec 017), its button beside the gold and the marker on it.
var shop: ShopPanel
var shop_button: HudButton
## The game's speed (spec 032), left of the Shop button on its tab: "1x", "2x" or "4x", lit above
## 1x. Main connects its click and tells it the speed through [method show_speed].
var speed_button: HudButton
## The small panel the Shop button sits on.
var shop_tab: HudPanel
var shop_marker: ShopMarker
## The guardian's health during a guardian fight (spec 024).
var boss_bar: BossBar
## The last happenings, the ticker over the party frames and the J panel (spec 027).
var journal: Journal
## A window per hero on the UI layer (spec 060), opened by clicking its frame or with Tab; null
## when there is no UI layer (a HUD on its own in a test). Set by [method UiRoot.setup].
var hero_windows: HeroWindows:
	set(value):
		hero_windows = value
		if value != null:
			value.changed.connect(_mark_frames)
			_mark_frames()
## The whole descent as a ladder of depths down the right edge (spec 033); L hides it.
var ladder: DepthLadder
## The next few things within reach, under the depth panel (spec 037); G hides it.
var goals: Goals
## The tooltips on the HUD's elements (spec 030).
var tooltip: HudTooltip
## The windows on the UI layer (spec 058), which hold help, the journal's list and the orders;
## null when there is no UI layer (a HUD on its own in a test).
var windows: UiWindows
## What beat the party and what would help (spec 041), under the top band in the middle.
var defeat_note: DefeatNote
## The party tally (spec 045): who deals, heals and takes the damage, and its button beside the
## party frames.
var tally: TallyPanel
var tally_button: HudButton
## The area map (spec 053): where the party can go, opened with W or the area's name.
var area_map: AreaMap

var _simulation: Simulation
var _world: World
## The old panels shown at the last [method advance], so one that has just opened is seen.
var _panels_shown: Array[Control] = []
var _effects: CombatEffects
var _icons: PixelSheet
var _frames_by_id: Dictionary[int, HeroFrame] = {}
var _shown_gold: int = 0
var _since_coin: float = 0.0
var _gold_bump: float = 0.0
var _depth: int = 0
var _depth_emphasis: float = 0.0
## A target asked for that the simulation has not applied yet (it applies on the next tick), or 0.
var _asked_target: int = 0
var _auto_on: bool = false
## The small meter drawn on the tally button.
var _tally_meter: Control


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
		KEY_U:
			_toggle_shop()
		KEY_ESCAPE:
			handled = shop.is_open()
			shop.close()
		KEY_TAB:
			# Spec 060: the next hero's window to the front, or Shift+Tab closes the front one.
			if hero_windows == null:
				handled = false
			elif key.shift_pressed:
				hero_windows.close_front()
			else:
				hero_windows.open_next()
		KEY_B:
			handled = shop.is_open()
			if handled:
				shop.toggle_auto_buy()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			# The shop first; else the front hero window spends paragon points, on its Talents tab
			# only (spec 034, spec 055, spec 060).
			var front: HeroWindow = hero_windows.front() if hero_windows != null else null
			var training: bool = front != null and front.page() == HeroWindow.Page.TALENTS
			if shop.is_open():
				shop.buy_row(key.keycode - KEY_1)
			elif training and key.keycode <= KEY_3:
				front.train_row(key.keycode - KEY_1)
			else:
				handled = false
		KEY_Q, KEY_E:
			# The tally's previous and next measure while it is open (spec 045), else the front
			# hero window's previous and next tab (spec 034, spec 060).
			var shown: HeroWindow = hero_windows.front() if hero_windows != null else null
			if tally.is_open():
				if key.keycode == KEY_Q:
					tally.previous_measure()
				else:
					tally.next_measure()
			elif shown != null:
				if key.keycode == KEY_Q:
					shown.previous_page()
				else:
					shown.next_page()
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
	_build_frames()
	_build_depth()
	_build_gold()
	_build_shop()
	for frame: HeroFrame in frames:  # spec 060: a click opens or closes the hero's window
		frame.clicked.connect(_on_frame_clicked)
	_adopt_clock()
	boss_bar = BossBar.new()
	add_child(boss_bar)
	boss_bar.setup(simulation, world)
	journal = Journal.new()
	add_child(journal)
	journal.setup(simulation, world)
	_build_ladder()
	goals = Goals.new()  # spec 037: before the tooltips, so its lines get them
	add_child(goals)
	goals.setup(simulation, world)
	_build_tally()  # spec 045: before the tooltips, so its tabs get them
	_build_tooltip()
	area_map = AreaMap.new()  # spec 053: after the tooltips, which it gives its controls
	add_child(area_map)
	area_map.setup(simulation, world)
	area_map.add_tips(tooltip)
	resource_purse.setup(simulation, effects.resource_effects if effects != null else null)
	resource_purse.add_tips(tooltip)  # spec 052
	shop.add_tips(tooltip)
	defeat_note = DefeatNote.new()  # spec 041: after the tooltips exist, so it can give its own
	add_child(defeat_note)
	defeat_note.setup(simulation, world, self)
	move_child(tooltip, -1)  # drawn over the note
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
	var reviving: bool = _simulation.expedition.state == Expedition.State.REVIVING
	var battle: Battle = _simulation.expedition.battle
	var fighting: bool = _simulation.expedition.state == Expedition.State.FIGHTING
	for hero: Hero in _simulation.party.heroes:
		var frame: HeroFrame = _frames_by_id.get(hero.id, null)
		if frame != null:
			frame.recovering = reviving
			frame.gold = _simulation.party.gold  # for its marker (spec 037 R4)
			frame.fighter = battle.combatant(hero.id) if fighting and battle != null else null
			frame.refresh(hero, delta)
	resource_purse.advance(delta)
	_advance_gold(delta)
	_advance_depth(delta)
	_advance_shop(delta)
	if hero_windows != null:
		hero_windows.advance(delta)
	boss_bar.advance(delta)
	journal.advance(delta)
	ladder.advance(delta)
	goals.advance(delta)
	tally.advance(delta)
	_light_tally_button()
	area_map.advance(delta)
	defeat_note.advance(delta)
	tooltip.advance(delta)
	_make_room_for_panels()


## Closes every UI-layer window over an old panel that has just opened (spec 058), keeping the
## window's place: the shop, the tally, the area map or the away report. Until specs 059 and 061
## move those panels onto the UI layer, they would open hidden under a window.
func _make_room_for_panels() -> void:
	var shown: Array[Control] = []
	var layer: Node = get_parent()
	var panels: Array[Node] = [shop, tally, area_map]
	if layer != null:
		panels.append_array(
			layer.get_children().filter(func(n: Node) -> bool: return n is AwayPanel)
		)
	for node: Node in panels:
		var panel: Control = node as Control
		if panel == null or not panel.is_visible_in_tree() or panel.is_queued_for_deletion():
			continue
		shown.append(panel)
		if windows != null and not _panels_shown.has(panel):
			windows.close_over(panel.get_global_rect())
	_panels_shown = shown


## What the party is doing and why, as the depth panel shows it: "Heading on to stage 5",
## "Fighting 3 monsters", "Resting, 64% health", "On the way to The Claypits 3" and so on (spec
## 027 R1, spec 049 R9: the panel's caption names the area the stages are in).
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


# --- Building ------------------------------------------------------------------


func _build_frames() -> void:
	var count: int = _simulation.party.heroes.size()
	var row: float = count * HeroFrame.SIZE.x + maxi(count - 1, 0) * GAP
	var x: float = floorf((SCREEN.x - row) / 2.0)  # the row is centred
	var y: float = SCREEN.y - MARGIN - HeroFrame.SIZE.y
	for hero: Hero in _simulation.party.heroes:
		var frame := HeroFrame.new(hero, self)
		frame.position = Vector2(x, y)
		add_child(frame)
		frames.append(frame)
		_frames_by_id[hero.id] = frame
		x += HeroFrame.SIZE.x + GAP


func _build_depth() -> void:
	depth_panel = HudPanel.new()
	depth_panel.name = "DepthPanel"
	depth_panel.position = Vector2(MARGIN, TOP_Y)
	depth_panel.size = Vector2(200, TOP_HEIGHT)
	add_child(depth_panel)
	depth_divider = ColorRect.new()
	depth_divider.name = "Divider"
	depth_divider.color = Palette.color(&"dusk")
	depth_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	depth_panel.add_child(depth_divider)
	depth_caption = _label(depth_panel, "DepthCaption", "Stage", &"steel", Vector2(5, 3))
	depth_label = _label(depth_panel, "StageNumber", "1", &"white", Vector2(5, 10))
	_make_big(depth_label)
	state_label = _label(depth_panel, "State", "", &"silver", Vector2(0, 3))
	stable_label = _label(depth_panel, "Stable", "", &"silver", Vector2(0, 14))
	stable_divider = ColorRect.new()
	stable_divider.name = "StableDivider"
	stable_divider.color = Palette.color(&"dusk")
	stable_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	depth_panel.add_child(stable_divider)
	stable_note = _label(depth_panel, "StableNote", "", &"silver", Vector2(0, 3))
	stable_bar = Control.new()
	stable_bar.name = "StableBar"
	stable_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stable_bar.size = STABLE_BAR
	stable_bar.draw.connect(_draw_stable_bar)
	depth_panel.add_child(stable_bar)
	stable_next = _label(depth_panel, "StableNext", "", &"steel", Vector2(0, 14))
	target_caption = _label(depth_panel, "TargetCaption", "Target", &"steel", Vector2(0, 14))
	minus_button = _button("Minus", "-", HudButton.HEIGHT)
	minus_button.pressed.connect(_step_target.bind(-1))
	target_label = _label(depth_panel, "Target", "", &"yellow", Vector2(0, 14))
	plus_button = _button("Plus", "+", HudButton.HEIGHT)
	plus_button.pressed.connect(_step_target.bind(1))
	auto_button = _button("Auto", "Auto off", 0.0)
	auto_button.pressed.connect(_toggle_auto)


func _build_gold() -> void:
	gold_panel = HudPanel.new()
	gold_panel.name = "GoldPanel"
	gold_panel.size = Vector2(60, TOP_HEIGHT)
	add_child(gold_panel)
	coin_icon = TextureRect.new()
	coin_icon.name = "Coin"
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP
	coin_icon.texture = icon(&"coin")
	coin_icon.size = Vector2(16, 16)
	coin_icon.position = Vector2(4, 7)
	gold_panel.add_child(coin_icon)
	gold_label = _label(gold_panel, "Gold", "0", &"yellow", Vector2(23, 7))
	_make_big(gold_label)
	resource_purse = ResourcePurse.new()
	gold_panel.add_child(resource_purse)


## The Shop button in its own small panel left of the gold, the marker on it, and the shop.
func _build_shop() -> void:
	shop_tab = HudPanel.new()
	shop_tab.name = "ShopTab"
	add_child(shop_tab)
	speed_button = HudButton.new("4x")  # the widest label, kept for every speed
	speed_button.name = "SpeedButton"
	speed_button.custom_minimum_size = speed_button.size
	speed_button.text = "1x"
	speed_button.position = Vector2(4, 7)
	shop_tab.add_child(speed_button)
	shop_button = HudButton.new("Shop")
	shop_button.name = "ShopButton"
	shop_button.position = Vector2(speed_button.position.x + speed_button.size.x + 3.0, 7)
	shop_button.pressed.connect(_toggle_shop)
	shop_tab.add_child(shop_button)
	var tab_width: float = shop_button.position.x + shop_button.size.x + SHOP_TAB_RIGHT
	shop_tab.size = Vector2(tab_width, TOP_HEIGHT)
	shop_marker = ShopMarker.new()
	shop_marker.visible = false
	shop_tab.add_child(shop_marker)
	shop = ShopPanel.new()
	add_child(shop)
	shop.setup(_simulation, _world)


## Shows the game's speed (spec 032) on [member speed_button]: its label, lit above 1x.
func show_speed(value: int) -> void:
	speed_button.text = "%dx" % value
	speed_button.lit = value > 1


## A click on hero [param hero_id]'s frame opens or closes its window (spec 060).
func _on_frame_clicked(hero_id: int) -> void:
	if hero_windows != null:
		hero_windows.toggle(hero_id)


## The depth ladder (spec 033): it hides itself on L and while the shop is open; a click on a
## rung asks for a target, which the target number shows at once, as the - and + buttons do.
func _build_ladder() -> void:
	ladder = DepthLadder.new()
	add_child(ladder)
	ladder.setup(_simulation, _world)
	ladder.target_asked.connect(_on_ladder_target)


func _on_ladder_target(depth: int) -> void:
	_asked_target = depth
	_advance_depth(0.0)


## The tooltips (spec 030), made late so they are drawn over everything else. Help and the
## orders moved onto the UI layer (spec 058), with their buttons.
func _build_tooltip() -> void:
	tooltip = HudTooltip.new()
	add_child(tooltip)
	tooltip.setup(self)


## The party tally (spec 045): its panel, and its button beside the party frames, left of the first,
## as tall as a frame, with a small meter drawn on it.
func _build_tally() -> void:
	tally = TallyPanel.new()
	add_child(tally)
	tally.setup(_simulation, _world)
	var first: float = frames[0].position.x if not frames.is_empty() else SCREEN.x / 2.0
	var width: float = maxf(first - GAP - MARGIN, HudButton.HEIGHT)
	tally_button = HudButton.new("")
	tally_button.name = "TallyButton"
	tally_button.custom_minimum_size = Vector2(width, HeroFrame.SIZE.y)
	tally_button.size = tally_button.get_combined_minimum_size()
	tally_button.position = Vector2(first - GAP - width, SCREEN.y - MARGIN - HeroFrame.SIZE.y)
	tally_button.pressed.connect(
		func() -> void:
			tally.toggle()
			_light_tally_button()
	)
	add_child(tally_button)
	_tally_meter = Control.new()
	_tally_meter.name = "Meter"
	_tally_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tally_meter.size = tally_button.size
	_tally_meter.draw.connect(_draw_tally_meter.bind(_tally_meter))
	tally_button.add_child(_tally_meter)


## Lights the tally button while the tally is open, and redraws its face (the key turns white).
func _light_tally_button() -> void:
	if tally_button.lit != tally.is_open():
		tally_button.lit = tally.is_open()
		_tally_meter.queue_redraw()


## The tally button's face: three bars of falling length in the first three classes' bar colours,
## each on an ink edge, and the key, T, under them.
func _draw_tally_meter(meter: Control) -> void:
	var colours: Array[StringName] = [&"red", &"blue", &"amber"]
	var lengths: Array[float] = [1.0, 0.7, 0.45]
	var inner: float = meter.size.x - 8.0
	for i: int in colours.size():
		var bar := Rect2(4.0, 6.0 + i * 6.0, roundf(inner * lengths[i]), 5.0)
		meter.draw_rect(bar, Palette.color(&"ink"))
		meter.draw_rect(bar.grow(-1.0), Palette.color(colours[i]))
	var key: String = "T"
	var x: float = floorf((meter.size.x - PixelText.width(key) + 1.0) / 2.0)
	var ink: StringName = &"white" if tally.is_open() else &"silver"
	meter.draw_string(
		PixelText.font(),
		Vector2(x, 30.0),
		key,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		PixelText.SIZE,
		Palette.color(ink)
	)


func _mark_frames() -> void:
	for hero: Hero in _simulation.party.heroes:
		var frame: HeroFrame = _frames_by_id.get(hero.id, null)
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


func _label(
	parent: Control, label_name: String, text: String, colour: StringName, at: Vector2
) -> Label:
	var made: Label = PixelText.label(text, colour)
	made.name = label_name
	made.position = at
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(made)
	return made


func _make_big(label: Label) -> void:
	label.add_theme_font_size_override(&"font_size", PixelText.SIZE * 2)
	label.add_theme_constant_override(&"shadow_offset_x", PixelText.SHADOW_OFFSET * 2)
	label.add_theme_constant_override(&"shadow_offset_y", PixelText.SHADOW_OFFSET * 2)


func _button(button_name: String, text: String, min_width: float) -> HudButton:
	var made := HudButton.new(text)
	made.name = button_name
	made.custom_minimum_size = Vector2(min_width, HudButton.HEIGHT)
	made.size = made.get_combined_minimum_size()
	depth_panel.add_child(made)
	return made


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
	var text: String = short_count(_shown_gold)  # spec 052: short, so the purse fits beside it
	if gold_label.text != text:
		gold_label.text = text
		gold_label.reset_size()
	var lift: float = 1.0 if _gold_bump > GOLD_BUMP_SECONDS / 2.0 else 0.0
	gold_label.position = Vector2(23, 7 - lift)
	coin_icon.position = Vector2(4, 7 - lift)
	var colour: StringName = &"white" if _gold_bump > 0.0 else &"yellow"
	gold_label.add_theme_color_override(&"font_color", Palette.color(colour))
	var width: float = 23.0 + gold_label.size.x + 3.0
	resource_purse.position = Vector2(width + 3.0, 0)
	if not resource_purse.shown_ids().is_empty():
		width += 3.0 + resource_purse.size.x + 4.0
	gold_panel.size = Vector2(width, TOP_HEIGHT)
	gold_panel.position = Vector2(SCREEN.x - MARGIN - width, TOP_Y)
	shop_tab.position = Vector2(gold_panel.position.x - GAP - shop_tab.size.x, TOP_Y)
	if _effects != null:
		_effects.gold_screen_target = gold_panel.position + coin_icon.position + Vector2(8, 8)


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
	var changed: bool = false
	changed = _set_text(depth_caption, PlaceText.area_name(expedition.place)) or changed
	changed = _set_text(depth_label, str(_depth)) or changed
	changed = _set_text(stable_label, "Safe %d" % expedition.last_stable_depth) or changed
	changed = _set_text(target_label, str(target)) or changed
	changed = _set_text(state_label, status_text()) or changed
	var road: PackedStringArray = _stable_parts()
	changed = _set_text(stable_note, road[0]) or changed
	changed = _set_text(stable_next, road[1]) or changed
	var counting: bool = road[0].contains(" in ")
	if stable_bar.visible != counting:
		stable_bar.visible = counting
		changed = true
	stable_note.add_theme_color_override(
		&"font_color", Palette.color(&"green" if road[0] == "Stable" else &"silver")
	)
	stable_bar.queue_redraw()
	var auto_text: String = "Auto on" if _auto_on else "Auto off"
	if auto_button.text != auto_text:
		auto_button.text = auto_text
		changed = true
	auto_button.lit = _auto_on
	if changed:
		_layout_depth()
	var state_colour: StringName = STATE_COLOURS.get(expedition.state, &"silver")
	state_label.add_theme_color_override(&"font_color", Palette.color(state_colour))
	var emphasis: bool = _depth_emphasis > 0.0
	var lift: float = 1.0 if _depth_emphasis > DEPTH_EMPHASIS_SECONDS - 0.15 else 0.0
	depth_label.position.y = 10.0 - lift
	depth_label.add_theme_color_override(
		&"font_color", Palette.color(&"yellow" if emphasis else &"white")
	)


func _set_text(label: Label, text: String) -> bool:
	if label.text == text:
		return false
	label.text = text
	label.reset_size()
	return true


## Lays out the depth panel from left to right: the depth, a divider, the state over the
## stable and target row, then sizes the panel to fit.
func _layout_depth() -> void:
	var column: float = maxf(depth_caption.size.x, depth_label.size.x) + 5.0 + 6.0
	state_label.position.x = column
	var x: float = column
	for control: Control in [stable_label, target_caption, minus_button, target_label]:
		var spacing: float = 8.0 if control == target_caption else 3.0
		if control == stable_label:
			spacing = 0.0
		x += spacing
		control.position.x = x
		x += control.size.x
	x += 3.0
	plus_button.position = Vector2(x, 12)
	x += plus_button.size.x + 6.0
	auto_button.position = Vector2(x, 12)
	minus_button.position.y = 12
	x += auto_button.size.x
	# The road to stable, in a column of its own after a second divider.
	var road: float = maxf(x, column + state_label.size.x) + 11.0
	stable_divider.position = Vector2(road - 5.0, 4.0)
	stable_divider.size = Vector2(1.0, TOP_HEIGHT - 8.0)
	# On the way to another area (spec 049) the road has nothing to say, and no divider.
	stable_divider.visible = stable_note.text != "" or stable_next.text != ""
	stable_note.position.x = road
	var next_x: float = road
	if stable_bar.visible:
		stable_bar.position = Vector2(road, 15.0)
		next_x += STABLE_BAR.x + 4.0
	stable_next.position.x = next_x
	var right: float = maxf(road + stable_note.size.x, next_x + stable_next.size.x)
	depth_panel.size = Vector2(right + 5.0, TOP_HEIGHT)
	depth_divider.position = Vector2(column - 5.0, 4.0)
	depth_divider.size = Vector2(1.0, TOP_HEIGHT - 8.0)
	depth_panel.queue_redraw()


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


func _draw_stable_bar() -> void:
	HudPanel.draw_bar(
		stable_bar,
		Rect2(Vector2.ZERO, STABLE_BAR),
		stable_progress(),
		Palette.color(&"yellow"),
		Palette.color(&"amber"),
		Palette.color(&"ink")
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
	shop_button.lit = shop.is_open()
	shop_marker.count = shop.affordable_count()
	shop_marker.visible = shop_marker.count > 0 and not shop.is_open()
	shop_marker.advance(delta)
	shop_marker.position = Vector2(
		shop_button.position.x + shop_button.size.x - 3.0, shop_button.position.y - 5.0
	)


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
	var frame: HeroFrame = _frames_by_id.get(event.target_id, null)
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


func _toggle_shop() -> void:
	if shop.is_open():
		shop.close()
	else:
		shop.open()
	_advance_shop(0.0)


func _step_target(by: int) -> void:
	var from: int = _asked_target if _asked_target > 0 else _simulation.expedition.target_depth
	_asked_target = maxi(from + by, 1)
	_simulation.set_target_depth(_asked_target)
	_advance_depth(0.0)


func _toggle_auto() -> void:
	_simulation.set_auto_push(not _simulation.expedition.auto_push)
	_advance_depth(0.0)
