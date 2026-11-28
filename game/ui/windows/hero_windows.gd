class_name HeroWindows
extends Node
## The hero windows: one [HeroWindow] per hero, each a window on the UI layer registered
## with [UiWindows] as [code]hero_<n>[/code] (n the hero's place in the party, from 0), so they
## move, layer, close on [kbd]Esc[/kbd] and are remembered like any other window, and any of them
## can be open at once to compare heroes.
##
## A click on a hero's frame opens or closes its window ([method toggle]); [kbd]Tab[/kbd] opens the
## next hero's window and brings it to the front ([method open_next]); [kbd]Shift+Tab[/kbd] closes
## the front one ([method close_front]). Those keys, and [kbd]Q[/kbd], [kbd]E[/kbd] and [kbd]1[/kbd]
## to [kbd]3[/kbd], act on a hero window only while it is the front window of all ([method top]);
## the [Hud] passes them on.
##
## Places go by what is open, not by which hero: a window never dragged takes, as it opens, the
## first free place of a short list ([member _places]), free meaning no other undragged open hero
## window holds it. When the room is wide enough for two windows side by side (1280x720), the list
## is the left column, the right column, then a cascade from the left; so any two heroes compare
## side by side. In a narrower room (960x540) it is a cascade from the top left, each set right of
## the one before and every other one down, so every title shows; there the windows are made short
## enough that two of them stay clear of the frames' line, their tabs' content scrolls, and the
## cascade keeps clear of the button bar.

## Emitted when a hero window opens or closes, or another comes to the front.
signal changed
## Emitted when hero [param hero_id]'s window opens.
signal opened(hero_id: int)

## The start of every hero window's id.
const PREFIX: String = "hero_"
## UI pixels between windows, and between them and the room's edges.
const GAP: float = 8.0
## How far each window of a cascade is set from the one before (less sideways when the room is
## too narrow for that and the button bar).
const CASCADE: Vector2 = Vector2(64, 28)
## Every this many ranks of a paragon stat gets a banner.
const PARAGON_BANNER_EVERY: int = 10

var _ui: UiRoot
var _simulation: Simulation
## The windows by hero id, in the party's order.
var _windows: Dictionary[int, HeroWindow] = {}
var _ids: Array[int] = []
## The content height every window needs to show its tallest tab whole.
var _tallest: float = 0.0
## The places an undragged hero window can take, in the order they are taken, for this room.
var _places: Array[Vector2] = []
## The place each open, undragged hero window holds, by hero id (an index into [member _places]).
var _place_of: Dictionary[int, int] = {}


func _init() -> void:
	name = "HeroWindows"


## The window id of the window of the party's [param place]th hero, from 0 ([code]&"hero_0"[/code]).
static func id_for(place: int) -> StringName:
	return StringName(PREFIX + str(place))


## Call once, after the layer's windows exist: makes a window per hero of [param simulation],
## each the same size, and registers it with [param ui]'s windows. [param tip] gives the windows'
## controls their tooltips (may be null). The windows hear [param world]'s events (none with null).
func setup(simulation: Simulation, ui: UiRoot, tip: UiTip, world: World = null) -> void:
	_simulation = simulation
	_ui = ui
	if world != null and not world.sim_event.is_connected(_on_sim_event):
		world.sim_event.connect(_on_sim_event)
	var tallest: float = 0.0
	for hero: Hero in simulation.party.heroes:
		var made := HeroWindow.new(simulation, hero, _ids.size(), tip)
		_windows[hero.id] = made
		_ids.append(hero.id)
		tallest = maxf(tallest, made.body_height())
	_tallest = tallest
	for hero_id: int in _ids:
		var made: HeroWindow = _windows[hero_id]
		made.set_body_height(tallest)  # every hero's window the same size, to compare
		ui.windows.register(made)
		made.settle()
		made.open_changed.connect(_on_open_changed.bind(hero_id))
		made.moved.connect(_on_moved.bind(hero_id))
	place_defaults()
	for hero_id: int in _ids:
		_windows[hero_id].place_at(_windows[hero_id].default_place, Vector2(ui.room()))
	ui.windows.changed.connect(_on_windows_changed)


## Works out the places hero windows take for the room the layer has now, and each window's
## height (see the class description); an open window keeps the place it holds.
func place_defaults() -> void:
	if _ui == null or _ids.is_empty():
		return
	var room := Vector2(_ui.room())
	var band: float = ceilf(_ui.world_to_ui(Vector2(0, HudFrame.TOP_BAND)).y) + GAP / 2.0
	var frames: float = floorf(_ui.world_to_ui(Vector2(0, _ui.frames_top())).y) - GAP / 2.0
	var bar: Rect2 = _ui.bar.rect_in(_ui.room()).grow(GAP / 2.0) if _ui.bar != null else Rect2()
	_set_heights(_tallest)
	var window_size: Vector2 = _windows[_ids[0]].size
	var left := Rect2(Vector2(GAP, band), window_size)
	var right := Rect2(Vector2(room.x - GAP - window_size.x, band), window_size)
	var side_by_side: bool = (
		room.x >= 2.0 * window_size.x + 3.0 * GAP
		and _clear(left, frames, bar)
		and _clear(right, frames, bar)
	)
	_places.clear()
	if side_by_side:
		_places.append(left.position)
		_places.append(right.position)
		for k: int in range(1, _ids.size() - 1):
			# Set right and down from the left one, but never so far down it meets the frames.
			var place: Vector2 = left.position + CASCADE * k
			place.y = maxf(minf(place.y, frames - window_size.y), band)
			_places.append(place)
	else:
		# Two cascaded windows, one set down from the other, clear of the frames' line.
		var chrome: float = _windows[_ids[0]].chrome_height()
		_set_heights(minf(_tallest, frames - band - CASCADE.y - chrome))
		window_size = _windows[_ids[0]].size
		# The last of the cascade ends left of the button bar.
		var limit: float = (bar.position.x if bar.has_area() else room.x - GAP) - window_size.x
		var step: float = minf(CASCADE.x, floorf((limit - GAP) / maxf(_ids.size() - 1, 1)))
		for k: int in _ids.size():
			_places.append(Vector2(GAP + maxf(step, 0.0) * k, band + CASCADE.y * (k % 2)))
	for hero_id: int in _ids:
		_windows[hero_id].default_place = _places[_place_of.get(hero_id, 0)].round()


## True when [param rect] is clear of the frames' line at [param frames] and of [param bar].
static func _clear(rect: Rect2, frames: float, bar: Rect2) -> bool:
	return rect.end.y <= frames and not (bar.has_area() and rect.intersects(bar))


## Makes every hero window's content [param height] UI pixels tall.
func _set_heights(height: float) -> void:
	for hero_id: int in _ids:
		_windows[hero_id].set_body_height(height)


## Brings every open window up to date with the simulation. The HUD calls it every frame. While
## the world catches up, every tree drops what it was playing for the events before.
func advance(delta: float) -> void:
	var settling: bool = _catching_up()
	for hero_id: int in _ids:
		var shown: HeroWindow = _windows[hero_id]
		if settling:
			shown.talents.tree_view().stop()
		if shown.is_open():
			shown.advance(delta)


## True while the world catches up on a stall: nothing plays for the events it brings.
func _catching_up() -> bool:
	var moment: UiMoment = _ui.moment if _ui != null else null
	return moment != null and moment.world != null and moment.world.catching_up()


## The window of hero [param hero_id], or null.
func window_of(hero_id: int) -> HeroWindow:
	return _windows.get(hero_id, null)


## Opens hero [param hero_id]'s window in front of every other, on tab [param page] if given
## (one of [enum HeroWindow.Page]), else on the tab it had.
func open(hero_id: int, page: int = -1) -> void:
	var shown: HeroWindow = window_of(hero_id)
	if shown == null:
		return
	if page >= 0:
		shown.open_page(page as HeroWindow.Page)
	_ui.windows.open_window(shown.window_id)
	shown.advance(0.0)
	changed.emit()


## Opens hero [param hero_id]'s window, or closes it if it is open.
func toggle(hero_id: int) -> void:
	if is_open(hero_id):
		window_of(hero_id).close()
	else:
		open(hero_id)


## Opens the window of the hero after the front hero window's (the first hero's when none is
## open), wrapping, and brings it to the front, whatever window is in front; the others stay as
## they are (Tab with the shop or the tally in front still steps through the heroes).
func open_next() -> void:
	if _ids.is_empty():
		return
	var shown: HeroWindow = front()
	var index: int = _ids.find(shown.hero_id) if shown != null else -1
	open(_ids[(index + 1) % _ids.size()])


## Closes the front window, if it is a hero window.
func close_front() -> void:
	var shown: HeroWindow = top()
	if shown != null:
		shown.close()


## Closes every hero window.
func close_all() -> void:
	for hero_id: int in _ids:
		_windows[hero_id].close()


## The front window of all (any open window, not only hero windows) when it is a hero window,
## else null: the keys reach a hero window only then.
func top() -> HeroWindow:
	return (_ui.windows.front() if _ui != null else null) as HeroWindow


## The open hero window in front of every other hero window, or null when none is open.
func front() -> HeroWindow:
	var order: Array[UiWindow] = _ui.windows.order() if _ui != null else []
	for index: int in range(order.size() - 1, -1, -1):
		var shown: HeroWindow = order[index] as HeroWindow
		if shown != null and shown.is_open():
			return shown
	return null


## True while hero [param hero_id]'s window is open; with -1, while any hero window is.
func is_open(hero_id: int = -1) -> bool:
	if hero_id < 0:
		return not open_ids().is_empty()
	var shown: HeroWindow = window_of(hero_id)
	return shown != null and shown.is_open()


## The heroes whose windows are open, in the party's order.
func open_ids() -> Array[int]:
	var made: Array[int] = []
	for hero_id: int in _ids:
		if _windows[hero_id].is_open():
			made.append(hero_id)
	return made


## Marks a gain the world just reported, through the layer's [UiMoment]: a node taken bursts on
## its open tree, the line into it lights and a banner names it (a capstone lights its whole path
## and its banner says the path is mastered); a path ranking up bursts its rank and sweeps its
## bar, with a banner when the rank opens a tier or is the top; a paragon point spent bursts
## its medallion, with a banner every tenth rank; a microskill learned gets a banner, and a burst on
## its card while the hero's window is open on Skills. Nothing starts for an event that may not
## animate: the windows show the end state all the same.
func _on_sim_event(event: SimEvent) -> void:
	var moment: UiMoment = _ui.moment if _ui != null else null
	if moment == null:
		return
	match event.kind:
		SimEvent.Kind.TALENT_TAKEN:
			_on_taken(event, moment)
		SimEvent.Kind.PATH_RANKED:
			_on_ranked(event, moment)
		SimEvent.Kind.PARAGON_SPENT:
			_on_paragon(event, moment)
		SimEvent.Kind.MICROSKILL_LEARNED:
			_on_microskill(event, moment)


## Starts the flash of paragon stat [param index] in hero [param hero_id]'s window (a point just
## went in).
func flash_paragon(hero_id: int, index: int) -> void:
	var shown: HeroWindow = window_of(hero_id)
	if shown != null:
		shown.talents.flash_paragon(index)


## The tooltip of hero [param hero_id]'s frame, the one place it is
## built: [code]Click for details[/code], with the class and the path that names it before it once
## it holds a node ([code]Knight, Berserker: click for details[/code]), and between them the
## hero's statuses with their seconds left, [param statuses].
static func frame_tip(hero: Hero, statuses: String = "") -> String:
	var named: bool = hero != null and HeroTalentsTab.path_index(hero) >= 0
	var titled: String = HeroTalentsTab.title(hero) if named else ""
	if statuses.is_empty():
		if titled.is_empty():
			return HeroFrameView.CLICK_TIP
		return "%s: %s" % [titled, UiFormat.lower_first(HeroFrameView.CLICK_TIP)]
	var said: String = statuses if titled.is_empty() else "%s: %s" % [titled, statuses]
	return "%s. %s" % [said, HeroFrameView.CLICK_TIP]


func _on_taken(event: SimEvent, moment: UiMoment) -> void:
	var hero: Hero = _simulation.party.hero(event.source_id)
	var ability: AbilityDef = Content.ability(event.ability_id)
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id) if hero != null else null
	if ability == null or tree == null:
		return
	var path: int = tree.path_of(event.ability_id)
	var last_tier: int = TalentTreeDef.TIERS[TalentTreeDef.TIERS.size() - 1]
	var mastered: bool = tree.tier_of(event.ability_id) == last_tier
	var shown: HeroWindow = _showing(event.source_id, HeroWindow.Page.TALENTS)
	if shown != null and moment.may_start(event):
		var view: TalentTreeView = shown.talents.tree_view()
		shown.advance(0.0)  # the node owned before it bursts
		var node: TalentNode = view.node(event.ability_id)
		if node != null:
			moment.burst(node.slot, event)
		if mastered:
			view.sweep(path)
		else:
			view.light(event.ability_id)
	var headline: String = "%s learned %s" % [hero.def().display_name, ability.display_name]
	if mastered:
		headline = "%s masters %s" % [hero.def().display_name, tree.path(path).display_name]
	moment.announce(event.ability_id, headline, first_sentence(ability.description), event)


## A path ranked up: on the hero's open tree its rank bursts and its bar fills and starts again;
## a rank that opens a tier gets a banner naming the nodes it opens, and so does the top rank.
func _on_ranked(event: SimEvent, moment: UiMoment) -> void:
	var hero: Hero = _simulation.party.hero(event.source_id)
	var tree: TalentTreeDef = Content.talent_tree(hero.class_id) if hero != null else null
	if tree == null or tree.path(event.target_id) == null:
		return
	var shown: HeroWindow = _showing(event.source_id, HeroWindow.Page.TALENTS)
	if shown != null and moment.may_start(event):
		var banners: Array[PathBanner] = shown.talents.tree_view().banners
		# One win can rank several paths, each with its own event: every bar whose rank went up
		# sweeps from the share it showed, started before the window reads the hero once.
		for each: PathBanner in banners:
			var now: int = hero.ranks.rank(each.index, tree)
			if each.shown_rank() >= 0 and each.shown_rank() < now:
				each.rank_bar.sweep()
		shown.advance(0.0)
		moment.burst(banners[event.target_id].rank_label, event)
	var who: String = hero.def().display_name
	var named: String = tree.path(event.target_id).display_name
	var opens: Array[StringName] = opened_by(tree, event.target_id, event.amount)
	if not opens.is_empty():
		var names: Array[String] = []
		for id: StringName in opens:
			names.append(Content.ability(id).display_name)
		moment.announce(
			opens[0],
			"%s: %s rank %d" % [who, named, event.amount],
			"%s can be learned now" % " and ".join(PackedStringArray(names)),
			event
		)
	if event.amount >= tree.rank_xp.size():
		var path_nodes: Array[StringName] = tree.path(event.target_id).nodes
		moment.announce(
			path_nodes[path_nodes.size() - 1],
			"%s: %s at its top rank" % [who, named],
			"Every node of %s is open." % named,
			event
		)


## The nodes of path [param path] of [param tree] that rank [param rank] opens: those of the tier
## whose rank it is, in path order; none for a rank that opens no tier.
static func opened_by(tree: TalentTreeDef, path: int, rank: int) -> Array[StringName]:
	var found: Array[StringName] = []
	if rank <= 0 or tree.path(path) == null:
		return found
	for id: StringName in tree.path(path).nodes:
		if tree.rank_needed(id) == rank:
			found.append(id)
	return found


func _on_paragon(event: SimEvent, moment: UiMoment) -> void:
	var hero: Hero = _simulation.party.hero(event.source_id)
	var ids: Array[StringName] = Content.training_ids()
	if hero == null or event.target_id < 0 or event.target_id >= ids.size():
		return
	var shown: HeroWindow = _showing(event.source_id, HeroWindow.Page.TALENTS)
	var cells: int = shown.talents.paragon_cells.size() if shown != null else 0
	if event.target_id < cells and moment.may_start(event):
		shown.advance(0.0)  # the count up before it bursts
		moment.burst(shown.talents.paragon_cells[event.target_id].medallion, event)
	var rank: int = event.amount
	if rank > 0 and rank % PARAGON_BANNER_EVERY == 0:
		var def: TrainingDef = Content.training(ids[event.target_id])
		var headline: String = (
			"%s: %s %d, %s"
			% [hero.def().display_name, def.display_name, rank, ParagonCell.total_text(def, rank)]
		)
		moment.announce(def.id, headline, "%s for every point." % def.description, event)


func _on_microskill(event: SimEvent, moment: UiMoment) -> void:
	var hero: Hero = _simulation.party.hero(event.source_id)
	var ids: Array[StringName] = Content.microskill_ids()
	if hero == null or event.target_id < 0 or event.target_id >= ids.size():
		return
	var skill: MicroskillDef = Content.microskill(ids[event.target_id])
	var shown: HeroWindow = _showing(event.source_id, HeroWindow.Page.SKILLS)
	if shown != null and moment.may_start(event):
		shown.advance(0.0)
		for card: HeroSkillsTab.Card in shown.skills.cards:
			if card.skill == skill:
				moment.burst(card.slot, event)
	var headline: String = "%s learned %s" % [hero.def().display_name, skill.display_name]
	moment.announce(skill.id, headline, _sentence(skill.description), event)


## Hero [param hero_id]'s window when it is open on tab [param page], else null.
func _showing(hero_id: int, page: HeroWindow.Page) -> HeroWindow:
	var shown: HeroWindow = window_of(hero_id)
	if shown == null or not shown.is_open() or shown.page() != page:
		return null
	return shown


## The first sentence of [param text]: up to the first full stop followed by a space, or all of it.
static func first_sentence(text: String) -> String:
	var at: int = text.find(". ")
	return text if at < 0 else text.left(at + 1)


## [param text] as a sentence: its first letter capital, a full stop at its end.
static func _sentence(text: String) -> String:
	if text.is_empty():
		return ""
	var made: String = text.left(1).to_upper() + text.substr(1)
	return made if made.ends_with(".") else made + "."


## A hero window opened or closed: one never dragged takes the first free place as it opens.
func _on_open_changed(_window: UiWindow, hero_id: int) -> void:
	var shown: HeroWindow = _windows[hero_id]
	if shown.is_open():
		if not shown.placed:
			_take_place(hero_id)
		opened.emit(hero_id)
	else:
		_place_of.erase(hero_id)
	changed.emit()


## A hero window was dragged: it holds no place of the list any more.
func _on_moved(_window: UiWindow, hero_id: int) -> void:
	_place_of.erase(hero_id)


## The windows changed (one came to the front, or every place was reset): an open window never
## dragged that holds no place takes one.
func _on_windows_changed() -> void:
	for hero_id: int in _ids:
		var shown: HeroWindow = _windows[hero_id]
		if shown.is_open() and not shown.placed and not _place_of.has(hero_id):
			_take_place(hero_id)
	changed.emit()


## Puts hero [param hero_id]'s window at the first place no other open, undragged hero window holds.
func _take_place(hero_id: int) -> void:
	if _places.is_empty():
		return
	var held: Array[int] = []
	for other: int in _place_of:
		if other != hero_id and _windows[other].is_open():
			held.append(_place_of[other])
	var index: int = 0
	while held.has(index) and index < _places.size() - 1:
		index += 1
	_place_of[hero_id] = index
	var shown: HeroWindow = _windows[hero_id]
	shown.default_place = _places[index].round()
	shown.place_at(shown.default_place, Vector2(_ui.room()))
