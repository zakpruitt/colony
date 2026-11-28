# Architecture

The rules every spec builds on. A spec may refine this document; it changes in the same pull request as the
code that makes it true.

## Two halves

```
 commands                       state + events
game/  ───────────────▶  sim/  ───────────────▶  game/
(input, UI)              (rules, pure)           (sprites, effects, UI)
```

**`sim/` is the game.** It holds every rule: movement, combat, loot, rest, depth. It is plain typed GDScript
(`RefCounted` classes and resources), with no scene tree, no engine clock and no global random state. It can be
created, stepped and inspected from a test with nothing else running.

**`game/` shows it and steers it.** Nodes read the sim's state and the events it reported since the last
frame, and draw them. The player's choices reach the sim as commands. Nothing in `game/` decides a rule, and
nothing in `sim/` knows it is being drawn.

`python tools/dev.py check` enforces the first half (the `boundary` step): a script under `sim/` that names
`Node`, `Engine`, `Time`, `OS`, `Input`, the scene tree, or a global random function fails the check.

## Two layers on screen (spec 058)

The picture is drawn in two layers, each in its own pixels.

- **The world** (the labyrinth, the party, the effects) is drawn at 640x360
  into `Main.world_viewport`, a `SubViewport` inside `Main.world_view` (a stretching
  `SubViewportContainer`, nearest filtering, snapped to pixels). The window shows it scaled by the largest
  whole number that fits (`UiRoot.world_scale()`). The HUD's `CanvasLayer` stays at `Main/HUD` but draws
  into that viewport (since spec 062 all it draws there is the world's own veil, the dark of a crossing:
  every other piece it makes is on the UI layer) (`custom_viewport`, set on `NOTIFICATION_SCENE_INSTANTIATED`: set any later, freeing
  `Main` makes the engine undo a connection that is already gone).
- **The UI layer** (`UiRoot`, `game/ui/ui_root.gd`, canvas layer 20) is drawn in *UI pixels*: the largest
  whole UI scale that still leaves at least 960x540 of room (`ui_scale()`, `room()`). 1280x720 gives a scale
  of 1 and 1280x720 of room, 1920x1080 a scale of 2 and 960x540. Everything on it hangs from `UiRoot.frame`,
  which carries the one theme (`UiTheme`); text there is `UiText`, the UI font.
- **Coordinates.** While a `UiRoot` is in the tree the window is in `CONTENT_SCALE_MODE_CANVAS_ITEMS` with
  a content size of 640x360: the root viewport still *thinks* in world pixels, so every input event and
  the world keep their 640x360 coordinates (tests push mouse events there), while drawing is at
  the window's size. The UI layer's transform is `ui_scale / world_scale`; `UiRoot.world_to_ui()` and
  `ui_to_world()` convert. Other scenes (the gallery, the showcase) keep the project's viewport mode.
- **The game's window** (spec 067, `WindowSettings`, `game/window_settings.gd`): a node `Main` holds
  (`Main.window_settings`, made by `WindowSettings.for_game`) only in a game someone plays: not headless,
  not run by a script (`-s`: the tests, the shot tool), not told `--window-default`. On a first run
  (`first_mode`) it maximizes the window if 1920x1080 fits inside a maximized window's frame (the usable
  height less the frame's, measured on the window as it opens), goes full screen if only the bare screen
  has that room (a 1920x1080 screen), else leaves the project's 1280x720 and writes nothing; `F11` is
  full screen and back; and the mode, with the windowed size and place, is kept in `user://colony.window`
  (its own file, not the save or the settings; written to a temporary file and renamed, as the save is)
  once a change has held for half a second (`observe`) or as the game closes (`flush`), and read at the
  next start (`decide`; a place off every screen is dropped, a size is cut down to the screen it lands
  on and raised to at least 640x360). Every decision is a plain function of a screen's size and the file; only with
  `WindowSettings.window` set is a real window read or changed, so a test names a file of its own and
  leaves `window` null. `UiRoot` refits on every change of the window's size, and a window held by the
  mouse stays in the hand through it (`UiRoot._held`).
- **Windows** (`UiWindow`, `UiWindows`): a title bar to drag by and a close button, any number open, a
  click raises one, `Esc` closes the front one, the title bar never leaves
  the room. Which are open, and the places of those the player dragged (`placed`), live in the settings
  file under `windows`, beside the sound setting, never in the save; an undragged window takes its default
  place for the current room, and a dragged one is moved wholly back in when the room shrinks. Windows
  saved open open as the game starts, under the away report if there is one (`UiWindows.open_waiting`). `UiButtonBar` holds a button
  per window, each with a `UiBadge` showing the window's `UiWindow.badge` count (the shop's affordable
  upgrades, the map's newly opened areas); a window with `on_bar` false (a hero window) has no button.
  A count is told, never polled: the content calls `WindowContent._show_badge(count)`, which emits
  `badge_changed(text)` only when the tag's text changes; its `UiWindow` takes the count and the bar
  refreshes its tags. The bar has no `_process`: `UiRoot.advance` runs the tags' pulse.
  Each button says what it opens (spec 068): the window's icon, its `UiWindow.short_name` (one word per
  window, given by its `WindowEntry`, the same in the help's key list, the goals, the notes
  and the tooltips: the shop, titled `Camp upgrades`, is `Camp`) and its key in a key cap
  (`UiButton.key_cap`). `UiButtonBar.fit_room` picks the first form that fits: icon, name and key side by
  side where that leaves `LEFT_ROOM` at the bar's left (1280x720); else each icon over its name with the
  key in a smaller cap at the button's top right corner (`UiButton.key_corner`; 960x540, where a hero
  window's default place and the ticker's longest line need `NARROW_LEFT_ROOM`); else the same without the
  keys (`shows_keys`; no room the game has now). A tag stands on the top left corner of its button's icon
  (`UiButtonBar.tag_place`), at most 2 pixels outside the button, because windows are drawn over the tags.
  `UiButton.icon_rect`, `name_rect` and `key_rect` say where a button draws each. A change to the bar's
  width or height moves what stands beside it: run specs 060 and 062's tests.
  A window refits when its content's minimum size changes. Help, the journal, the orders, the shop, the
  area map, the tally, the hero windows and the away report (`AwayWindow`, spec 062: not on the bar,
  centred, closed only by its button, `Esc` or its own 12 seconds) are windows. `UiTip` and `DefeatNote`
  treat a point on a window or the bar as nowhere (`UiWindows.covers`). A bar button's marker
  (`UiBadge`) is on the bar's own `Tags` layer, just above the bar and under every window (spec 062 R12).
- **Keys and the front window** (specs 059, 060): a window's keys act only while it is the front window
  of all (`UiWindows.front()`): 1 to 5 and B the shop's, 1 to 3 a hero window's on its Talents tab, Q and
  E a hero window's or the tally's tabs. Tab opens the next hero's window in front whatever is in front,
  Esc closes the front window (`UiWindows`), and a click anywhere on a window brings it to the front.
  `WindowKeys` (`game/ui/windows/window_keys.gd`, made by `UiRoot.setup`) hears them and asks
  `UiWindows.front()`; the `Hud` hears only its own (-, +, A, F3).
- **Window contents made by the HUD** (spec 059): `ShopWindow`, `AreaMapWindow` and `TallyWindow`
  (`game/ui/windows/`, all `WindowContent`) are made and advanced by `Hud.setup` as `hud.shop`,
  `hud.area_map` and `hud.tally`, so they hear the world's events from the start; their entries hand them
  to `UiRoot.setup`, which puts each in a window. `HelpPanel`, `JournalView` and `OrdersPanel` are
  made by their entries and advanced by `UiRoot.advance`; no content runs its own `_process`.
  They open and close through their window (`WindowContent.open`), so without a `UiRoot` (a HUD-only
  test) they never open: such a test adds one. `UiBar` is the UI layer's thin bar.
- **One list of windows, one table of keys** (spec 074). `WindowBook.entries()`
  (`game/ui/windows/window_book.gd`) lists the bar's windows in order, a `WindowEntry` each: its id,
  title, short name, key, the sentence its tooltip ends with, its icon part, its default place (a
  `place` callable: `WindowBook.top_left`, `top_right`, `under`, `between`) and `make_content`.
  `UiRoot` makes the windows from it (`UiRoot.entries`), the bar takes each button's name, key and
  tooltip from it, and `KeyBook` each window's help line. To add a window, add an entry there and a
  part to `window_icons.px`; nothing else changes (a test adds one with `WindowBook.add`). `KeyBook`
  (`game/ui/key_book.gd`) holds every other key in `ROWS`: its action, label, what it does and when it
  applies, with a window's row standing where its line goes in the help (an entry the table does not
  name goes at the end). `KeyBook.entries()` is the help's list, `KeyBook.pressed(event, key)` and
  `fresh_key(event)` the one test of a fresh press every piece of input code uses, and
  `KeyBook.label(action)` the letter a sentence writes ("Orders (O) sends it in"). To add a key, add a
  row and handle it where it acts, asking `KeyBook.pressed`.
- **The frame of the screen** (spec 061, `game/ui/frame/`): `PlacePanel` and `Countdown` at the top left,
  `Purse` (with the speed button) at the top right, `BossBarView` between them in a guardian fight, and a
  `HeroFrameView` per hero along the bottom. The `Hud` builds them under `Hud.screen_frame`, keeps making
  their texts (`status_text`, `_stable_parts`, `PlaceText`) and lays them out on a change; `UiRoot.setup`
  moves `screen_frame` onto the layer (`Hud.adopt_frame`, first child of `frame`, so windows draw over it)
  and `UiRoot._apply` sizes it to the room (`Hud.fit_frame`). A window under 1280x720 (whose UI room is
  under 960x540, as a headless test's 640x360 is) has the frame laid out at 960x540 and drawn scaled down
  by that fraction. `HudFrame.frames_line(room)` is the hero frames' true top in a room, and
  `UiRoot.frames_top()` the same in world pixels: the button bar, the hero windows and the ticker
  stand on it. Spec 062 adds the rest of what the HUD shows: `GoalsView` (rows of `GoalRow`) under the
  place panel, drawing what the `Goals` node decides; `StageList` at the right edge under the purse,
  drawing what `DepthLadder` (a plain `RefCounted` of risks, marks and the asked target) works out; the
  `Ticker` above the hero frames, clear of the button bar, showing `Journal.ticker_text()`; the
  `DefeatNoteView`, which `DefeatNote` fills and `Hud.lift_tip` puts over every window; and
  `CatchUpBar` on `UiRoot.frame`. Windows draw over the goals and the stage list as over the world. A `Hud` built alone in a test keeps the frame as its own child at a scale of 640/960, so its
  pieces' global rects stay in world pixels. Their tooltips are one `UiTip` (`Hud.frame_tip`) that follows
  the mouse itself (`follows_mouse`) and treats a point on a window as nowhere; `UiRoot.setup` lifts it to
  the last child of `frame` (`Hud.lift_tip`), so it draws over the button bar and every window. Each
  piece stops a click on it, so none reaches the world under it. Effects aim at the pieces' places on the screen
  (`UiFormat.on_screen`, through the canvas layer's transform, never a camera's): coins at the purse's coin, resource
  icons at their counts, and XP motes at their hero's frame (`CombatEffects.frame_screen_targets`; with no
  HUD, at the hero's chest as before). After a stall (`World.STALL_TICKS` at the game's speed) every
  piece snaps to the simulation's state.
- **A small HUD, and a screen that sits still** (spec 075). The `Hud` is the frame of the screen: it
  makes, lays out and advances its pieces and the shop, the map and the tally, and has at most 15
  public methods. What others shared from it lives apart: `UiFormat` (`game/ui/ui_format.gd`:
  `group_thousands`, `short_count`, `clock`, `on_screen`) and `HudFrame` (`game/hud/hud_frame.gd`: the
  frame's sizes, `frames_line`, `STATE_WORDS` and the frame's tooltips). Nothing finds the `Hud` by
  its parent or looks it up: `Goals`, `Journal`, `AreaMapWindow` and `DefeatNote` are handed the
  pieces they reach in `setup` (the map asks for a target with its own `target_asked`). Each frame a
  view works out the values it shows and words, lays out or redraws only when they changed
  (`ShownValues`, `game/ui/shown_values.gd`); a label's text goes through `WindowText.set_text` and
  its colour through `WindowText.set_colour`, which set only a change and count it in
  `WindowText.changes` (spec 075's test watches an idle screen with it). A closed shop, map, tally or
  hero window words nothing and is brought up to date as it opens; a hero window refreshes only the
  tab showing, and its Stats tab builds the hero's `Combatant` only when a stat's inputs change.
  Spec 080 gives the frame's panels one base type, `FramePiece` (`game/ui/frame/frame_piece.gd`:
  `advance(delta)`, `catch_up()`, `add_tips(tips)`): `PlacePanel`, `Countdown`, `Purse`,
  `BossBarView`, `Ticker`, `GoalsView` and `StageList`, in `Hud.pieces`, added with `Hud.add_piece`
  (on the frame, in the list, tipped) and placed in `Hud._lay_out_frame`; `Hud` advances them every
  frame, catches them up after a stall and tips them once by walking the list. `HeroFrameView` is
  not one. An idle frame does no work: `Hud` lays the frame out only when the room changes or a
  piece's size or visibility does (`Hud.layouts` counts), words the status line and the road to
  stable only when what they are made from changes (`Hud.worded`), `Goals` reads the goals again
  only then (`Goals.built` counts the goals made) and an open Talents tab words itself and reads
  its nodes' states only then (`HeroTalentsTab.worded`, `TalentTreeView.states_read`). "What they
  are made from" is the simulation's tick, which moves with everything the simulation does, and
  the few values a command or a test changes between ticks. One owner advances each thing that
  moves: `Hud.advance` refreshes its `CrossingVeil` last, and `UiRoot.advance` runs its `UiMoment`
  after the bar and then the `Milestones` `Main` gives it (`UiRoot.milestones`), so a banner they
  queue drops in on the next frame; none has a `_process` of its own.
- **Hero windows** (spec 060, `game/ui/windows/`): `HeroWindows`, made by `UiRoot.setup` and handed to the
  `Hud`, owns one `HeroWindow` per hero, registered as `hero_0` to `hero_3` by the hero's place in the
  party. All four are as tall as the tallest needs, so lines line up across them. Places go by what is
  open: an undragged window takes, as it opens, the first free one of `HeroWindows._places` (left
  column, right column, then a cascade at 1280x720; a cascade at 960x540, where the windows are made
  short enough that two clear the frames' line, the cascade clears the bar (`UiButtonBar.rect_in`) and
  the tabs' content scrolls in `HeroWindow.scroll`, the Talents tab's `top_row` standing above it).
  A window lays itself out by hand in 13-pixel lines (`WindowText`),
  sorts its chrome at once (`settle`), refreshes only while open (`advance`, called every frame) and snaps
  its bars as it opens. The tabs are `HeroStatsTab`, `HeroTalentsTab` (with `TalentTreeView`,
  `TalentNode`, `ParagonCell`) and `HeroSkillsTab`; they send the same commands the old sheet did. A
  node's picture is its ability's own (spec 063, below). Spec 064 draws the tree as a tree: each
  `TalentNode` is a large `UiIcon` with its name under it; `TalentTreeView` lays the three paths (spec
  109) side by side, each a column of four tier rows under a `PathBanner`, and draws the lines and
  arrowheads itself
  (`joins()`, `arrows()`), lit in the path's colour (`PathColours`, a view table by class and path; a
  path's name is tinted in it wherever the window says it, by a `WordTint` drawn over the label). A
  node's words are on its card (`UiTip.attach_card`) and in the `NextStrip` at the tree's foot; the
  paragon medallions sit under that, past the first view (`HeroTalentsTab.base_height()` leaves them
  out, so two windows on Talents still sit side by side at 1280x720). `HeroWindows.setup` is handed the
  world and connects its own `_on_sim_event`, which turns a recent `TALENT_TAKEN`, `PARAGON_SPENT` or
  `MICROSKILL_LEARNED` into a burst and a banner through `UiMoment`. Spec 111 makes each path a panel
  (`TalentTreeView.panels()`, drawn by the view behind its column): its `PathBanner` carries the rank
  (`rank_label`) and a `RankBar` (a `UiBar` in the path's colour, its shade from `PathColours.shade`)
  showing the XP into the rank of its span. `RankStanding` (`game/ui/windows/`) is the one place that
  works a path's rank, XP into it and span out of the tree's table, and the rank a node is short of
  (`short_of`); the bar, its tooltip, the strip (`6 of 28 XP to rank 4`, one wording everywhere) and
  the node states all read it. A `PATH_RANKED` the moment may start bursts the rank and calls
  `RankBar.sweep()` (fill to the end, start again from empty) on every banner whose shown rank is
  below the hero's, before the window reads the hero once: one win ranking three paths sends three
  events, and each bar sweeps from its own old share. A rank that opens a tier, or the top rank, also
  gets a banner (`HeroWindows.opened_by`). A capstone (`TalentNode.is_end()`: bold name, `END_RING`
  ring) taken calls `TalentTreeView.sweep(path)`, which lights the path's lines tier by tier, instead
  of `light`. A node its rank holds shut carries a `RankTag` (a padlock and the rank's number in a
  small pill inside the slot's bottom right, drawn by the tag itself so nothing hangs past it) and its
  line is in `PathColours.dim()`. `HeroTalentsTab.standing` lists everything a node waits for, one per
  line, in order (the node above, the rank, a point); the strip falls back to the first node held shut
  only by its rank. The journal writes a tier-opening or top rank and a capstone learned.
- **Pictures and the moment** (spec 063, `game/ui/`): every ability, upgrade, paragon stat and microskill
  has a 16x16 picture, a part named for its id in one of `assets/sprites/ui/pictures_<group>.png`;
  `UiIcon.picture(id)` finds it, and no rule or data field names it. `UiIcon` is the framed slot (owned,
  ready, locked, closed; square or cut; a count; lit under the mouse; `clicked`), its pulse run by its
  owner's `advance`. `UiTip.attach_card` gives a control a card (`UiTip.Card`: picture, title, kind, body,
  stand) in place of a plain tip; a later `attach` replaces it, and a freed control is forgotten. `UiMoment` (`UiRoot.moment`, made by `UiRoot.setup` after the windows, so
  over them and under the tips and the defeat note) marks a gain: `burst(control)` pops the control by its
  `scale` about its middle (nothing in the layout moves; a container's sort resets its children's scale,
  so the moment puts the pop back on the container's `sort_children`) under a flash and a ring of sparks
  it draws itself; `announce(...)` queues a banner (at most three wait; the newest win) that shows from its
  next `advance` under the top band, no wider than the room between the middle and its `keep_clear`
  controls (`Main` gives it the goals and the stage list), its line two lines at most. `Main` gives it the world and the sound player: both take an optional `SimEvent`
  and start nothing for one that is not recent or while the world catches up, and a catch-up drops what
  waits and what runs. Which gains get one is for specs 064 and 065. `PictureSpecimen`
  (`game/ui/picture_specimen.tscn`) shows every picture in every state.
- **Chat bubbles** (spec 105, `game/ui/speech_bubbles.gd`, `speech_bubble.gd`): a line a character
  says goes through `World.say(speaker, text, seconds)` (a listener uses `World.say_for(event, …)`,
  which asks `may_animate`). The speaker is a hero or monster id (the bubble sits on the top of its
  sprite at rest, `SpriteBounds.body_rect`, and goes when the world frees that sprite) or a
  `Callable` returning a point in the world. `UiRoot.setup` makes `UiRoot.bubbles` right after the
  frame of the screen, so it draws over that and under the bar, every window, the moment and the tips,
  and takes no mouse; `Main` hands it to `World.bubbles` (null in a world with no UI layer: `say`
  does nothing). `World.sync` moves it on last, after the camera: each bubble's point goes through
  the world's canvas transform to the 640x360 screen and `UiRoot.world_to_ui` to the layer, the panel
  slid sideways to stay in the room while the tail (a child control) keeps under the speaker, and a
  later bubble lifted clear of an earlier one. A speaker has one bubble; at most 8 nodes, reused, the
  oldest first. A line is measured and wrapped once (160 UI pixels, 3 lines) and the panel drawn
  again only then: a frame only moves nodes. A bubble pops in by its `scale` and blinks out, as
  `FxText` does. A catch-up and a change of stage or area clear them all.
- **Shop cards** (spec 065): each `ShopRow` is a card: a large `UiIcon` (the rank as its count),
  `ShopPips`, and what the upgrade gives now and next, its stat named by `UpgradeDef.gives` (a view
  hint no rule reads). The simulation's `UPGRADE_BOUGHT` does not say who bought, so `ShopWindow`
  remembers each ask of the player's with its tick: a purchase heard on the tick after its ask is the
  player's (it bursts through `Main`'s `ShopWindow.moment`), any other auto-buy's. Only a fresh purchase
  flashes, bursts or announces; every fifth rank and the top one get a banner. `UiTip.card_for` reads
  the card a control was given.
- **Milestones** (spec 066, `game/ui/frame/milestones.gd`): `Main` makes a `Milestones` node that hears
  the world's `sim_event` and marks the run's biggest events through `UiMoment`: a guardian slain
  gets a banner with the guardian's sprite (`Milestones.guardian_picture`, every part of its sheet
  drawn into one texture cut to what is drawn; `UiMoment.announce_picture` takes a `Texture2D` where
  `announce` takes a picture id, and shows it at a whole multiple of its size, `picture_size`, the
  banner growing to hold a sprite larger than the 48 pixel place), held until the next `advance` so that the areas opened on the same tick go
  on it rather than on a banner of their own; a level bursts the hero's frame and steps its level
  number up (`HeroFrameView.step_level`), a talent point pulses its tag (`pulse_tag`), a stage
  further than the safe one it knows bursts and steps `Safe N` (`PlacePanel.step_safe`, run on by
  `PlacePanel.run_step` from `Milestones.advance`, before the world syncs; the HUD gives it no time). All ask `UiMoment.may_start` first
  and are cleared when the world catches up (the hero frames by the HUD's own snap on a stall). Each
  of these events has its own sound, so every burst and banner here passes `quiet` (the last
  argument of `burst` and `announce_picture`) and the moment plays none.

## Time

The sim advances only when something calls its step function, one fixed tick at a time. It never asks what
time it is.

The driver in `game/` measures real elapsed time (not rendered frames) and steps the sim as many ticks as have
passed. That one design gives three things the game needs:

- **Background running:** the tick count depends on the clock, so a throttled or hidden window loses no time.
- **Offline catch-up:** time missed while closed or asleep is more ticks to step (or to estimate, past a cap).
- **Fast tests:** a test steps ten minutes of play in a loop, with no waiting.

**Game speed (spec 032).** At 2x or 4x (`Main.set_speed`, never saved) the driver also steps `speed - 1` extra
ticks per tick of real time, but only while the frame's `step_budget_usec` lasts; extra ticks that do not fit
are dropped, never kept. The real-time ticks, backlog, catch-up and saving are exactly as at 1x. The world
multiplies its recent and stall windows by the speed and eases sprites and bolts in game time.

## Randomness

Every roll comes from a `SimRng` (`sim/sim_rng.gd`), a seeded stream whose position can be saved. Systems take
their own stream with `fork("label")`, so adding a roll to loot never changes what combat rolls. The same seed
and the same commands give the same run; a test asserts it.

## Content

Classes, talents, items, monsters and gates are custom resource classes with typed `@export` fields, stored as text
`.tres` files under `data/`. Adding content means adding a file, not code. Each content class extends
`ContentDef` (`sim/defs/content_def.gd`), which declares `key()` (what `Content` finds the definition by: its
`id`, or a talent tree's `class_id`, one tree a class) and `validate() -> PackedStringArray` (one line per
problem). `ContentDef` has no exported field: each class keeps its own `id` and `display_name`. The `data`
step of the check loads every resource under `data/`, validates each `ContentDef` and fails on any problem.

`Content` (`sim/defs/content.gd`) loads them, once, from one table, `Content.KINDS`: a row per kind with
its folder under `data/`, its definition class and how its ids are listed (`BY_ID`, `BY_ORDER` by the
definitions' `order` then id, `BY_AREA` for resources); each definition is listed under its `key()`. Each
`…_ids()` getter returns the same read-only array every call: a caller that wants to change the list
copies it (`.duplicate()`) first.

**Adding a kind of content:** make its class under `sim/defs/` (extending `ContentDef`: typed `@export`
fields, an `id`, `key()` and `validate()`), its folder under `data/`, a value in `Content.Kind` and its row
at the same place in `Content.KINDS` (a kind ordered by another comes after it), and its getters (`thing(id)` and
`thing_ids()`, each one line over `_find` and `_ids_of`). `test_072_content_table` fails until every folder
under `data/` has exactly one row.

## Saving

The save is the party's *progress*, not the exact moment (spec 014). `Simulation.to_save()` returns plain
values: a format version, the seed, the tick, the gold, each hero's class, level and XP, and the expedition's
last stable depth, deepest depth, target depth and auto-push, the rank of each camp upgrade (spec 016), the auto-buy switch (spec 022)
each hero's talents and paragon points (spec 051), the party's orders (spec 035), and the resources it holds
and the guardians it has beaten (spec 052), the bench and the artifacts found (spec 112).
Positions, a fight in progress, chamber timers and
random streams are not saved: `Simulation.from_save(data)` makes a new simulation from the seed and stands the
party up the way revival does (`Arrival.from_save`), alive and full at the arrival point of its last
stable depth, with every chamber freshly populated. The shape of the stages is not saved either: it is
what the caller plays (`from_save(data, shape)`, flat unless told; "Winding stages", below), so a save
of any version loads on either with the same progress.

- **Refused, not guessed at.** `Simulation.save_problems(data)` lists every problem, one line naming the field;
  `from_save` returns `null` if there is any. JSON makes whole numbers floats, so a whole float is read as an
  int; a float past 2^53 is refused, so seeds must stay within ±2^53 to survive a save. Those whole-number
  checks, and a dictionary of counts by known id, are `SaveChecks` (`sim/save_checks.gd`), which every part
  of the save (`Simulation`, `AreaSave`, `ResourceSave`, `TalentSave`, `RosterSave`) shares.
- **Versions.** `SAVE_VERSION` is 12. Loading goes through `Simulation.upgrade_save`, which brings older data
  forward one step at a time; a new format adds a step there and raises the version. Version 1 to 2 adds
  `upgrades` (a dictionary of upgrade id to rank) with every rank 0. A rank that is negative, above the
  upgrade's maximum or for an unknown upgrade is refused by name; unknown extra top-level keys are tolerated.
  Version 2 to 3 adds `auto_buy` (true or false), off; any other value is refused by name. Version 3 to 4 adds
  `training` to each saved hero (a dictionary of training id to rank) with every rank 0; a rank that is
  negative, above the training's maximum or for an unknown training is refused by name
  (`heroes[1].training.power`). Version 4 to 5 adds `pace` (`cautious`, `steady` or `bold`) and
  `guardian_order` (`challenge` or `hold`) at `steady` and `challenge`; any other value is refused by name.
  Version 5 to 6 (spec 049, `AreaSave`) adds `area` (the first area), `areas` (empty) and `open_areas`: the
  first area, and each later one whose way in (the guardian stages of the areas before it, added up: 5, 10,
  15) the save's `deepest_depth` went beyond. `last_stable_depth`, `deepest_depth` and `target_depth` are the
  stages of the area the party is in; `areas` holds every other area it has been in as
  `{"safe": s, "furthest": f}`. An unknown or closed `area`, an unknown id in `open_areas` or `areas`, and a
  stage below 1 or a safe stage beyond the furthest are refused by name (`areas.claypits.safe`).
  Version 6 to 7 (spec 051, `TalentSave`) drops each hero's `training`, adds the gold spec 029 charged for
  its ranks (the old prices `TalentSave` keeps) to the party's, and gives it `talents` (empty) and `paragon`
  (empty): every talent and paragon point its level earned is unspent. A version 6 rank that cannot be read is
  kept, and refused by name (`heroes[1].training`). A version 7 hero's `talents` must be a legal order of its
  class's tree no longer than its level earns (`heroes[2].talents[4]`, `heroes[1].talents`), and its
  `paragon` (stat id to points) known stats with whole points no more than its level earns
  (`heroes[2].paragon.luck`, `heroes[2].paragon`).
  Version 7 to 8 (spec 052, `ResourceSave`) adds `resources` (resource id to count) empty, and
  `guardians_beaten` (area ids): each area an open area is opened by, and each whose furthest stage (the
  party's `deepest_depth` for the area it is in, `areas.<id>.furthest` for another) is past its guardian stage.
  Upgrade ranks stay. A count that is not a whole number of at least 0 or names an unknown resource, and an
  unknown area in `guardians_beaten`, are refused by name (`resources.clay`, `guardians_beaten[1]`).
- **The side path order (spec 096).** A third order, `Expedition.side_paths` (`EXPLORE`, the default, or
  `PRESS_ON`), set through `Simulation.set_side_paths` and reported as `ORDER_CHANGED` with order
  `PartyOrders.SIDE_PATHS`. Under Press on `SidePathWalk.travel` turns onto no side path and reports no
  `GATE_SEALED`; a party already on one finishes it. All three orders reach the expedition through
  `Expedition.command_order(which, value)`; the values asked for, their applying on the next tick and their
  part of the state hash are `PendingOrders` (`sim/expedition/pending_orders.gd`). The order has a hash
  part of its own, there only while it is Press on, so a run that never gives it hashes as it did. Save
  version 9 adds `side_paths` (`"explore"` or `"press_on"`); a version 8 save loads at Explore.
  Version 9 to 10 (spec 109, `TalentSave.upgrade_9_to_10`): the trees became three paths of five, so
  every hero gets its talents back (`talents` and `used` empty) and keeps its paragon points.
  Version 10 to 11 (spec 110, `TalentSave.upgrade_10_to_11`): paths rank by use, so every hero gets its
  talents back again and its `paths` (its XP in each of its three paths, in path order) start at
  `[0, 0, 0]`. `paths` that is missing, not a list of three or holds anything but whole numbers of 0 or
  more is refused by name (`heroes[2].paths`), as is a node held whose tier needs a higher rank than its
  path's saved XP gives (`heroes[0].talents[3]`).
  Version 11 to 12 (spec 112, `RosterSave.upgrade_11_to_12`) adds `bench` (empty) and `artifacts`
  (none). `RosterSave` writes, reads and checks `heroes` too: `heroes` holds the four going down in
  formation order, `bench` the benched in id order, each hero saved alike, and `artifacts` the class ids
  found in `Content.hero_class_ids()` order. Ids are not saved: on loading the heroes going down take 1, 2
  ... and the bench the next ids. Refused by name: `bench` missing or not a list, a benched hero with any
  problem a hero going down would have (`bench[0].level`), more than four in `heroes`, a second hero of a
  class anywhere (`bench[1].class`), `artifacts` missing or not a list, an id in it that is not a class, a
  starting class or twice (`artifacts[1]`), and a hero of a new class whose artifact is not in it.
- **Orders (spec 035).** `Expedition.pace` and `Expedition.guardian_order`, set through
  `Simulation.set_pace` and `set_guardian_order`, apply on the next step with an `ORDER_CHANGED` event. The
  pace picks the share of health below which a hero makes the party rest (`PartyOrders.rest_below`); under
  Hold the party's walking goal stops short of a living guardian's chamber (`PartyOrders.short_of`), it turns
  there and hunts on that level, and `Expedition.is_holding` says so. At their defaults the orders add nothing
  to the state hash. `EncounterRoll` holds the expedition's encounter roll, guardian lookup and fighters' hash
  parts, kept apart so `expedition.gd` stays under gdlint's 1000 lines. Spec 078 holds that file to 900
  lines: what a chamber holds on a visit (always empty, a guardian's, its quest and its monsters)
  is `ChamberRules`, and where the heroes stand and the anchor walks is `PartyPlaces`, both read-only
  under `sim/expedition/`. `PartyPlaces` asks the stage's course (below) for every place:
  `PartyPlaces.anchor(run)` is the anchor's feet in world tiles, `world_facing(run)` the way the party
  faces in the world, `of` a hero's feet (in line behind the anchor along the course) and `walk_goal`
  the distance the anchor walks toward.
- **Talents and paragon (spec 051).** See "Talent trees and paragon" below. `Simulation.take_talent`,
  `spend_paragon` and `reset_talents` apply on the next step, like `buy_upgrade`. A hero with no node and no
  paragon point spent adds nothing to the state hash.
- **Auto-buy (spec 022).** `Simulation.set_auto_buy` applies on the next step. While on, the step buys the
  cheapest affordable upgrade on each tick that starts a whole `AUTO_BUY_SECONDS`, through the same path as
  `buy_upgrade`, so nothing about its timing needs saving. Off, it adds nothing to the state hash.
- **Files belong to `game/`.** `SaveStore` (`game/save/save_store.gd`) is given its path (default
  `user://colony.save`). It writes JSON to `<path>.tmp` and renames it into place, keeping the previous save as
  `<path>.bak`; reading falls back to the backup, then to an empty dictionary, if a file is missing or damaged.
- **Time away (spec 019).** `Main` adds a `saved_at` key (real seconds since 1970) beside the simulation's
  fields when it writes; the simulation ignores it. On starting with a stamped save, `Main.time_away` gives
  the real time since, clamped to 0 to 8 hours; from 60 s up, an `AwayReplay` (`game/save/`) steps the loaded
  simulation for that game time in 10 ms slices per frame, draining and counting events into an `AwayReport`,
  while a `CatchUpBar` (on the UI layer) shows. The driver, world, effects and HUD are made only when it ends (`caught_up`), so
  nothing from the time away is drawn, and an `AwayWindow` reports it (`AwayStory` words the rows). No save is written during a replay, so
  quitting part way loses nothing. Tests set `away_seconds_override`; a run with no `save_store` never replays.
  Watching changes nothing (spec 023): the expedition's reads (`monsters_in`, `is_populated`,
  `quest_in`, `working_quest`, `worker_id`, `work_progress`, `hero_position`, `chamber`,
  `guardian_of`, `hash_parts`) never change the state hash, so a watched game and
  the same game run headless stay hash-equal. A chamber's record is made only when the party fights there;
  a read works out the visit the chamber is on and takes its monsters from a roll cache outside the hash.
  Monster ids come from where the monster waits (`Expedition.monster_id`: depth, chamber, visit and place in
  the encounter), not from the order anything was asked for.

## The course

Spec 088. Every `LabyrinthLevel` has a `course`, a `StageCourse` (`sim/labyrinth/stage_course.gd`): the
line a party walks through that stage, built with `begin` and `line_to` from straight runs (level along
a floor, or straight up a ladder), each run in a chamber or in none. A place on it is a **distance**
from its first point. The course knows its two ends (`start`, `end`), where a party from the stage
before arrives (`entry`) and where the way on leaves (`exit`), and answers every question about place:
`point_at` (feet in world tiles), `heading_at` (1 right, -1 left, 0 on a ladder), `on_ladder`,
`chamber_at`, `stretch_of` (the first and last distance inside a chamber) and `distance_in` (the
distance of a world column on a chamber's floor). Feet at column c stand on the tile from c to c + 1:
where two level runs meet, the point belongs to the run on its right, and where a ladder meets a floor,
to the floor.

`Expedition.x` is the party's distance along the course of its stage, and `Expedition.facing` the way
it travels along it (1 toward `end`, -1 toward `start`), not a direction in the world. The expedition's
scripts (`sim/expedition/`) take every place from the course and from a chamber's own rectangle
(`LabyrinthChamber.floor_columns`, `floor_row`): a party revived, loaded or arriving stands at `entry`
facing `exit` (`Arrival`); sent on it walks to `exit`, sent back to `entry`, and at its target from one
end to the other; the guardian's chamber is the one `exit` is in, and the chambers `entry` and `exit`
are in are otherwise always empty (`ChamberRules`); under Hold it turns one tile of course short of the
guardian's chamber's stretch. A fight stays in world columns on its chamber's floor row: the heroes
enter from the side the course brought them (`PartyPlaces.world_facing`), and after a win the anchor is
at `distance_in` of the front hero's column.

On the levels `Labyrinth` makes, the course is the floor row and the distance is the world column, from
the first chamber's first floor column to the last chamber's last, with `exit` the middle of the shaft
down and `entry` the middle of the shaft from above (at depth 1, the middle of the START chamber); a
climb between stages keeps `x`, the shaft being one column through both. `LabyrinthLevel.floor_y`,
`tunnels`, `shaft_down`, `shaft_chamber()` and `Labyrinth.shaft_column()` describe only that shape and
are read by `game/` alone: nothing under `sim/expedition/` names them. The world (`game/world/`) reads
no column from `Expedition.x` and no screen direction from `Expedition.facing` ("The party on a winding
stage", below), and the showcase, when it cuts the party to a place, writes a course distance and the
way along the course (`ShowcaseMoments._stand_before`: so far before a room's `stretch_of`, going on).

## Winding stages

Spec 089. A `Labyrinth` has a `shape`, given when it is made: `FLAT` or `WINDING`.
`Simulation.new(seed, shape)` passes it on, `Simulation.from_save(data, shape)` too, and every area's
labyrinth has the first one's (`AreaTravel.labyrinth`).

**The game plays winding stages** (spec 092). `Main.STAGE_SHAPE` is `WINDING`, and `Main` gives it to
both: a new game, a loaded save and so the replay of time away (`AwayReplay` steps the simulation
`Main` loaded) are winding in every area, and the showcase, which runs a `Main`, is too. `FLAT` is only
the default of `Labyrinth.new`, `Simulation.new` and `Simulation.from_save`, kept for the tests that
make their own simulation and for `python tools/dev.py sim` without `--winding`; nothing a player sees
is flat. The view draws a winding stage ("A winding stage on screen", below) and everything in the
world stands in its own room on one ("The party on a winding stage").

A winding stage is made by `WindingStage` (`sim/labyrinth/winding_stage.gd`) from the level's own
stream alone, so it lines up with no other stage. It lies in a band `Labyrinth.band_height()` (32) rows
tall, `LabyrinthLevel.band`, with three floor rows 10 apart. Its route is two or three **runs**, each a
row of 2 to 5 rooms and the tunnels between them on a floor of its own (7 to 10 rooms in all, on
neighbouring floors, going down in some stages and up in others). The first run is walked one way, the
next the other way, and a ladder stands in the columns the last room of a run shares with the first
room of the next, two tiles inside both rooms' walls and far along the room it leaves.
`LabyrinthLevel.chambers` is in route order, `tunnels` too (one for each pair of neighbours on a
floor), `ladders` holds each ladder from the row under the upper room's floor to the lower room's floor
row (so it runs down through the lower room, the one overlap among `open_rects()`), `floor_y` is the
first room's floor and `shaft_down` has no area. The kinds are rolled as a flat level's: the first and
last rooms are plain (stage 1's first is the START), at most one vault.

The course starts at 0 at the far wall of the first room and runs through every room, tunnel and
ladder to the far wall of the last; `entry` and `exit` are doors 2 to 5 tiles inside those walls. So
the first room is the one a party arrives in and the last the one the way on leaves from, which a
guardian holds on its stages. From `entry` to `exit` is a little over twice a flat stage's walk.

**Changing stage** (`StageCrossing`, `sim/expedition/`). Flat stages are joined by a shaft: the party
climbs its rows and keeps its `x`. Winding stages are joined by doors (`StageCrossing.by_door`): the
party is CLIMBING for as long as `Labyrinth.LEVEL_HEIGHT` rows take (the climb's rows are counted,
`LEVEL_HEIGHT` a stage, not measured between the floors), then stands at the next stage's `entry`
facing its `exit`, or, going back, at the stage before's `exit` facing its `entry`.
`ClimbProgress.share` runs from 0 to 1 over it. For the first half every hero is where it left from, in
line behind the anchor, and from half way where it lands (`StageCrossing.feet`); a party that falls on
the way lies where it left from. Hold turns a party on its way back to a living guardian
(`StageCrossing.turn_back`): it is then leaving the stage before by its `exit`, as far along as it had
come.

`Expedition.monster_id` leaves room for 8 chambers a stage, so a winding stage's rooms 8 and 9 share
ids with rooms 0 and 1 of the next stage. No two of those are in one fight, and the world shows one
stage at a time, forgetting a stage's monsters as it leaves; the span has not been widened.

## Side paths and caches

A winding level has up to three **side paths** (`LabyrinthLevel.side_paths`, `SidePath` in
`sim/labyrinth/`), fitted after its main route by `SidePathLayout.fit` from a stream of their own
(`side/<depth>`), so the route, its rooms and its course are what they are without them. Each leaves a
room that is neither the first nor the last, one a room: by its own ladder to a cache room on a
neighbouring floor, or along the room's floor to a wall nothing joins and through its own tunnel. A
level where none fits has none (none has been seen with fewer than one). The cache room is a
`LabyrinthChamber` of kind `CACHE` with index -1: it is not in `chambers`, holds no monsters and no side
quest. `side_rects()` and `side_ladders()` are what a view cuts out of the earth and draws beside the
route's own.

| Field | Is |
|---|---|
| `gate` | The id of its `GateDef` (`data/gates/`): the microskill that opens it and the seconds it takes |
| `at` | Where it leaves, as a distance along the main course |
| `course` | Its own `StageCourse`, from 0 at `at` to the cache room's far wall |
| `gate_at` | Where the gate stands on that course: 0 at a ladder, the tunnel's mouth otherwise, at least 2 tiles from the route's ladders and doorways |
| `room`, `tunnel`, `ladder` | The cache room and the one of the two that joins it (the other has no area) |

**Walking one** (`SidePathWalk`, held by the `Expedition`; the questions anyone may ask are
`SidePathRules`). Travelling on the main course, a party that reaches `at` with the cache full and a
living hero with the gate's microskill turns off: `Expedition.side_path` is the path's place in the
level's list (else -1), `x` is a distance along the path's course and `PartyPlaces.course(run)` is that
course, so everything that places heroes goes on working. A party not moving along the course this
tick reaches nothing; and the room a path leaves comes first: reached before that room is entered and
clear of monsters, the path waits, and the party walks back to `at` once it is. It walks to `gate_at`, is WORKING for the
gate's seconds (`GATE_STARTED`, then `GATE_OPENED`; `working_quest()` is empty), walks to the far wall,
opens the cache as its anchor steps onto the cache room's floor (`CACHE_OPENED`, then `GOLD_GAINED`,
`XP_GAINED` for each living hero and `RESOURCE_GAINED`, then perhaps `ARTIFACT_FOUND`: "The roster",
below), walks back and stands at `at` again facing
the way it was going. `chamber()` is the cache room while the anchor is in it and null on the rest of
the path. With nobody able the party walks on and `GATE_SEALED` is told once for that gate until the
party next arrives on the stage. An opened cache is passed for `SidePathRules.REFILL_SECONDS`; a wipe or
a change of stage does not fill it, a journey to the area does. A target asked for on a side path waits
until the party is back on the main course. Nothing of this is saved: a loaded party stands on a main
course with every cache full, and the state hash gains a part only once a party has turned onto a side
path.

**On screen.** `LabyrinthView` cuts `side_rects()` out of the earth with the route's rectangles
(`is_open`, `open_rects_near`) and draws `side_ladders()` as it draws the route's; `World` gives a
hero's `LadderRoute` both lists, so a hero climbs a side ladder in its column; `AmbienceClearings`
keeps props off a side ladder's columns and the column by a side tunnel's mouth.

**Gates and caches on screen** (spec 094). `SideProps` (`game/world/side_props.gd`, a child of `World`
beside `QuestProps`) gives every side path of a built stage two sprites, found by id as a quest's
prop is (`assets/sprites/props/<gate id>.png`, `cache.png`), each sheet with a `closed` and an `open`
part: the gate at `course.point_at(gate_at)` and the strongbox at the middle of the cache room's floor.
What they show is read from the state on every scan, never kept from events: a cache is closed while
`SidePathRules.is_full`, and a gate is open while its cache is empty or the party is on that path past
`gate_at` (a `GATE_OPENED` heard covers the tick it stands on it), so a stall or the time away leaves
them true. `QuestProps` works a gate as it works a prop (`SideProps.worked_spot`: the worker beside it
on the side the heroes behind it are, the bar, the name); `PropGlints` is the one glint both use, on a
quest's prop and on a full cache out of the light. The gains of the tick a cache opens leave from it
(`SideProps.gains_from`, asked by `CombatEffects` and `ResourceEffects`); `QuestEffects` bursts its
sparks under the quest budget and raises `Needs a <microskill>` from a sealed gate; `SoundPlayer` plays
`gate_open` and `cache_open`. A closed gate under the mouse shows `GateTip`, drawn in the world over
the gate (the world polls its own viewport's mouse: `WorldView` passes no mouse events in), worded by
`GateTip.who_line`. The ambience dresses each cache room with one torch and a plain room's props, held
apart in `AmbienceLevel.cache_torches` and `cache_props` (a cache room is no chamber of the route, so
it has no index for `props_in`). The target arrow hides while `Expedition.side_path >= 0`.

**In words** (spec 095). `SidePathWords` (`game/hud/`) holds every sentence about a side path: a gate's
and a microskill's name come from their definitions, and `SENTENCES` has one row per gate for what its
opener did, what the status reads while it is worked and whether its name is counted (rubble takes no
"a" and no "s"; a gate with no row is "opened", and counted). `CacheReader` turns the events that follow
`CACHE_OPENED` on its tick into one `Pay`, complete at the `RESOURCE_GAINED` that ends them; the
`Journal` writes its line then, and `SidePathTally` (`Tally.side_paths`) adds it to the area the events
are in. `AwayReplay` counts `CACHE_OPENED` and `GATE_SEALED` by gate into the `AwayReport`. `Goals`
keeps the gates heard sealed since the party arrived on its stage (cleared on `DEPTH_CHANGED`,
`AREA_CHANGED` and `PARTY_REVIVED`, as the simulation tells them anew then) and its microskill goal
prefers a skill that opens one. `Hud.status_text` reads `Expedition.side_path` for the status.

## Pace by depth

Spec 036. How long things take on a level depends on its depth, in `DepthTiming` (`sim/expedition/`), so a new
game is busy and the deep game keeps its slow pace. A depth is stable after
`DepthTiming.stable_seconds_at(depth)`: 60 s at depth 1, growing by the same factor each level to 600 s at
depth 10 and every depth below. `Expedition.stable_seconds` reads that curve at the party's depth; a value set
by hand (a test, the `sim` tool) holds flat at every depth. A cleared chamber refills after
`DepthTiming.respawn_seconds_at(depth)`: 5 s at depth 1, rising evenly to `Expedition.RESPAWN_SECONDS` (90 s)
at depth 10; a beaten guardian's chamber still waits `GUARDIAN_RESPAWN_SECONDS`. Each `ChamberState` knows its
depth for that. Reaching level n takes `(n - 1) * (25n - 30)` XP (`Hero.xp_for_level`): 20 for level 2, 380
for level 5, a few percent under the old `25 * (n - 1) * n` for late levels. `python tools/dev.py sim
--timeline` prints the game time of each first (level 2 and 5 of every hero, depth 2 and 5, the first
affordable upgrade, the first guardian met and beaten), which is how the opening is measured.

## Areas

Spec 049. The labyrinth is a set of areas (`AreaDef`, `data/areas/`), each with its own monsters (and the
stage each first appears at), its guardian and its guardian stage, a base level, and the area whose guardian
opens it. Inside an area the party moves through stages exactly as it moved through depths, and the code
keeps the old names: `Expedition.depth`, `target_depth`, `last_stable_depth` and `deepest_depth` are stages
of the area the party is in. A stage's level is `base level + stage - 1` (`Expedition.level_at`): monsters
are made at that level (`Combatant.from_monster`, growing from `MonsterDef.base_level`, which kept the
numbers of the old `min_depth`), and `QuestDef.reward_at` reads it. The timers to become safe and to refill
a chamber (`DepthTiming`) go by the stage number instead, so every area's first stage is safe in a minute.
A chamber holds only
its area's monsters that have appeared by its stage (`EncounterRoll`), and the guardian stands at its stage
and every `GUARDIAN_EVERY` stages after.

Each area has its own `Labyrinth`: the first area's is the seed's own, every other's is forked under
`area/<id>/`, as are its encounter and quest rolls. `AreaTravel` (owned by the expedition, read as
`Expedition.travel`) keeps the open areas, every other area's safe and furthest stage, each area's labyrinth
and a journey. `Simulation.set_destination(area, stage)` asks for one, and is ignored if the area is not open
then. Once the party is out of any fight or quest and standing, it leaves (`JOURNEYING`; a rest it
leaves ends with `REST_ENDED`). The journey is a rest: the heroes heal as `AreaTravel.JOURNEY_SECONDS` of
resting would, and the fallen stand. That long after it left, it arrives at the start of the stage asked for
or the area's safe stage if that is nearer, with the stage asked for as its target (or a target chosen on the
way), every chamber fresh, and `AREA_CHANGED` then `DEPTH_CHANGED`. A destination asked for on the way turns
it there and starts the journey again. While it is on its way, `Expedition.area` names the destination and
`Expedition.place` the area it is leaving, whose labyrinth it still stands in. Beating an area's guardian at
its guardian stage for the first time opens the areas it opens, each with `AREA_OPENED`.
`Simulation.labyrinth` is the labyrinth of the area the party stands in. Monster ids do not name the area, so
the view changes area when it reaches `AREA_CHANGED` among the events, never from the live state ahead of
them: the world shows the new labyrinth then, and the journal and tally keep the area the events are in
from that event, as the defeat note does. The screen names a place as an area and a stage (`PlaceText`,
`Mossy Hollow 3`).

## Resources

Spec 052. Each area names one resource (`AreaDef.resource`, a `ResourceDef` under `data/resources/`; its
icon is its part of `assets/sprites/ui/resource_icons.px`). `ResourceDrops` (`sim/expedition/`) gives it:
a monster killed drops some with `DROP_CHANCE` by its size (small 0.3, large 0.8, a guardian always), as much
as `ResourceDrops.amount_at(size, stage)` (1, 2 or 6 on stage 1, a quarter more each stage on), and a quest
finished pays a large monster's drop. Each kill's roll is its own stream,
`fork("<area label>resource/<monster id>")`, so a drop takes nothing from any other roll and leaves nothing to
save. `Party.resource(id)` holds the counts; `RESOURCE_GAINED` reports a drop (the source, the resource's
position in `Content.resource_ids()`, the amount). Each `UpgradeDef` names a resource: from
`resource_from_rank` (3) on, a rank also costs `resource_cost_at(rank)`, and `Upgrades.can_pay` is the one rule
the buy, auto-buy, the shop and its marker share. With no resource held and no guardian beaten the state hash is
what it was, so the recorded hashes changed only where they now include resources.
`AreaTravel.guardians_beaten` keeps the areas whose guardian has been beaten at least once
(`Simulation.is_guardian_beaten`); the area map reads it. On screen, the `Purse` (spec 061) shows
the counts and `ResourceEffects` (made by `CombatEffects`) sends a drop's icons rising from the monster to it.

## Talent trees and paragon

Spec 051, made three paths of five by spec 109. Each class has a `TalentTreeDef` (`data/talents/`, one per
class, `Content.talent_tree`) holding three `SkillPathDef`s (a name, a summary and five ability ids),
every node an `AbilityDef` under `data/abilities/`. A path's nodes sit in tiers `TalentTreeDef.TIERS`
(1, 2, 2, 3, 4): tier 2 needs tier 1, tier 3 either tier-2 node, tier 4 tier 3 (`needs`).
`open_nodes(taken)` is the whole rule of order and nothing closes a path; `order_problem` checks a saved
list against it, and `main_path` names the path a hero holds most of (a tie to the earlier).

A `Hero` keeps the nodes it took, in order, and the paragon points it put into each `TrainingDef.Stat`;
neither unspent count is stored: `TalentRules.talent_points_at(level)` (one at every even level, up to
`Hero.TALENT_POINTS`, 15) and `paragon_points_at(level)` (one a level after 30) less what was spent.
`Hero.combatant()` hands the fighter its nodes' abilities in `TalentTreeDef.fight_order` (highest tier
first, then path order, then left before right). Of its ready actions with a target, a fighter uses the
one ready the longest; a tie goes to the one it used least recently (`Hero.used`, the hero's order of use,
which every combatant of the hero shares and the battle moves an action to the end of; saved as `used`),
then to that order (`BattleAbilities.choose`). After an action its next swing is a plain strike
(`Combatant.swung_since_action`). `Hero.combatant()` also multiplies its damage and
healing, maximum health and attack speed by `1 + points * TrainingDef.per_rank` (3%) of Power, Toughness and
Quickness, after the camp upgrades. A node taken mid-fight waits for the next fight; a paragon point spent
mid-fight changes the fighter at once, as spec 029's training did. A fresh start (`reset_talents`) costs
`Simulation.reset_price(hero)`, a price per level times the hero's level, is refused while
`Expedition.battle` is set, and leaves paragon points alone. Events: `TALENT_POINT_GAINED` (from `Expedition._give_xp`, beside the
`LEVEL_UP` that earned it), `TALENT_TAKEN` (with `ability_id`), `PARAGON_SPENT`, `TALENTS_RESET`. Auto-buy
never spends a point. When the expedition's 90-second limit ends a fight, it calls `Battle.end()` first, so
every status ends with its event and no monster goes back to its chamber carrying one.
R14: fights last seconds, so every talent action has `ready_at_start` (`TalentTreeDef.validate` refuses one
that has not) and waits only for its condition; `AbilityDef.Condition.OTHER_ALLY_BELOW` is `ALLY_BELOW`
without the fighter itself (Bulwark). A second tree for a class is refused by its `validate()`, and
`Content` keeps the first.
`TalentSpender` (`tools/godot/`) is the headless run's way of spending (`dev.py sim --spend-talents`): for
each point, the first node it can take on the path asked for (0 by default), tier by tier, then the first
it can take on any path, passing over nodes a path's rank holds shut, and every paragon point into Power.

**Path ranks (spec 110).** A path ranks up by use. `Hero.ranks` (`PathRanks`, `sim/party/`) keeps a hero's
XP in each of its three paths; its rank is how many of the tree's `rank_xp` totals that XP has reached
(`TalentTreeDef.rank_at`), so a rank never goes down, and a fresh start keeps it. A node can be taken
only once its path's rank is at least `tier_ranks[tier - 1]` (`TalentTreeDef.rank_needed`, asked by
`Hero.can_take`); a node held stays held. When the heroes win a fight, `Expedition._end_battle` calls
`PathTraining.after_win` (`sim/expedition/`): every hero, fallen or not, gains in each path the nodes it
holds there plus the uses of that path's abilities in the fight, each ability counted at most
`uses_counted` times. A use is an `ABILITY_USED` with the fighter as source, strike boosts included;
`Battle.record_use` sends it and counts it in `Combatant.uses` (cleared by `reset_abilities`). Each rank
passed is a `PATH_RANKED` (source the hero, target the path's index, amount the new rank), in rank order.
A lost fight, or one ended at the 90-second limit, gives nothing. `Party.hash_parts` adds a hero's path
XP only while `ranks.any()`, so a run that spends nothing hashes as it did. The tab shows ranks
as spec 111 lays them out (Hero windows, above). An `AbilityEffect` with
`damage_from_healing` deals its multiplier times the fighter's healing power (the Sunpriest's holy damage).

## The roster

The colony may hold more heroes than the four who go down (spec 112). `Party.heroes` is still exactly the
four going down, in formation order (by `HeroClassDef.Role`, then id), and every system that reads it is
unchanged; `Party.bench` holds the rest in id order, `Party.roster()` is both, and `Party.hero(id)` finds
either. A benched hero earns no XP or path XP, does no quest and opens no gate, but takes talent and
paragon commands as one going down does. The colony holds one hero of each class, since every sentence
names a hero by its class.

- **Artifacts.** A class not in `Party.STARTING_CLASSES` names its artifact (`artifact_name`,
  `artifact_picture`), its chance per cache (`artifact_chance`) and its request (`recruit_gold`, and
  optionally `recruit_resource_count` of `recruit_resource`); `looks_like` names a class it is drawn as
  until it has its own pictures (`HeroClassDef.look()`). `ArtifactFinds.on_cache` (`sim/expedition/`),
  called once by `SidePathWalk._pay` after the cache's events, forks a stream for that cache alone
  (`artifact/<area>/<stage>/<side path>/<tick>`), draws one number and walks the classes not yet found
  in `Content.hero_class_ids()` order adding up their chances: the first whose total passes it is found
  (`Party.artifacts`, `ARTIFACT_FOUND`: source the opener, target the class's place). With no class left
  to find nothing is forked, so no roll, hash or baseline changes while the data has none.
- **Commands.** `Simulation.roster` (`Roster`, `sim/party/roster.gd`), applied in `Simulation.step` after
  the talent commands. `recruit(class_id)` pays the request on the next step for a class that waits at camp
  (`is_waiting`: found, and none of it in the colony); the hero joins the bench at the level of the
  lowest going down with that level's XP, every point unspent, every path at 0 (`HERO_RECRUITED`: source
  the new id, one more than the largest, target the class's place, amount the gold). `swap(bench_id,
  field_id)` waits (`waiting()`, not saved) for a step that begins with the party resting at camp,
  then each swap still true is made: the newcomer stands at full health and the four are sorted again
  (`HERO_FIELDED`: source in, target out). Bad ids do nothing.
- **Hash.** `Party.hash_parts` adds the bench and the artifacts only while either holds something.

## Zones on screen

Spec 054. The simulation still stacks an area's stages as bands of one labyrinth and climbs a shaft between
them; the view shows one stage at a time and never shows the climb. `LabyrinthView.zoned` (set by `World`)
builds only the stage on screen, fills the shafts back with earth, draws a stone doorway where each shaft met
the floor (the way on at `shaft_column(stage)`, the way back at `shaft_column(stage - 1)`) and looks after
the area (`LabyrinthView.area`, `ZoneLook`: one of the four looks by the area's place in the list, each stage
a little darker; the ambience reads it through `zone_look()`). `ZoneCrossing` (a child of `World`) turns the
simulation's own clock into the crossing: the share of the climb done (`ClimbProgress`, a read-only helper
in `sim/expedition/`, added by this spec because `Expedition` is at gdlint's public-method limit), the
journey's `arrive_tick` and the revival tick. The screen is dark from a quarter of the climb to three
quarters, and the world switches to the next stage under it at half (`ZoneCrossing.stage_shown`); the
heroes fade into the doorway as they reach it and stand at the far doorway when the screen opens. Because it
is read from the state, a crowded frame at any speed shows the right stage. The HUD's `CrossingVeil`, drawn
under the rest of the HUD, paints the dark and the title.

## A winding stage on screen

Spec 090. The zoned view cuts a winding stage out whole. Everything that asked for
`Labyrinth.LEVEL_HEIGHT` asks the labyrinth's `band_height()` instead, so a stage is 32 rows for a
winding labyrinth and 16 for a flat one, whose picture has not changed: `LabyrinthView.set_focus` takes
the stage from the focus row over it, the level's node holds that many rows and `SURROUND_ROWS` of
earth above and below, and the ambience's open map, exposure map and buried details cover them.

- **Open space** is every chamber, tunnel and ladder of the level (`open_rects_near`), and nothing of
  its neighbours: a winding stage that is built stands alone, so `is_open` and `visuals_at` answer
  earth for the rows drawn round it, whatever the stage above or below holds there.
- **A room is cut to a shape** (spec 100). `RoomShape` (`game/world/room_shape.gd`) is one room as
  drawn: a ceiling row of its own over each column of the rectangle, everything under it open, so some
  tiles of the rectangle are earth and some above it are open. It is drawing only: the simulation's
  room is still `LabyrinthChamber.rect`, the floor is whole, and nothing in `sim/` knows. The shape
  comes from the labyrinth's seed, the stage and the room (`SimRng.fork`), cut by the numbers of the
  area's `RoomCut`, one row of `ZoneLook.CUTS` (reach, step, run width, lean, round corners, raised
  middle, turn, ledge): a new manner is a row there. Three things hold whatever the cut: `STANDING_ROWS` (4) rows
  over the whole floor are open, as tall as the tallest sheet that stands on one (the 64-pixel
  bosses) and a row over a tunnel's mouth and a doorway; a ladder's columns are open for the
  rectangle's height; and nothing opens outside the room's columns, more than `MOST_ROWS` (8) over
  the floor, or beside another place the rectangle does not touch. `StageShapes`
  (`LabyrinthView.shapes(depth)`, null for a flat or un-zoned view, which draw their boxes) holds a
  stage's shapes and its open tiles. **Ask `LabyrinthView.is_open` for the truth of a tile**:
  `open_rects_near` answers a room with its shape's `bounds()`, which holds earth too. Whatever hangs
  from a ceiling asks the shape for its column's (`AmbienceLevel._ceiling_px`); what stands on a floor
  needs nothing, the lowest four rows being open.
- **Ladders** are drawn in each of `LabyrinthLevel.ladders` with the tiles an un-zoned shaft has, the
  top piece standing on the upper room's floor row.
- **Doorways** (`doorways(depth)`) stand where the course leaves (`exit`) and, from stage 2 on, where
  it arrives (`entry`), each centred on `course.point_at` and on the floor of the room that is in. A
  flat stage's stay where its shafts were.
- **The ambience** dresses each chamber on its own floor and ceiling (`AmbienceLevel`), keeping clear
  the columns `AmbienceClearings` gives for that chamber: on a winding stage the ladders that meet that
  room and the doorways in it, on a flat one the two shafts' columns as before. What a room holds by its
  kind (campfire, webs, chest) is `AmbienceRoomProps`'; everything else it is dressed with (spec 101) is
  a row of `AmbienceDecor.TABLE`, one entry per area, stood by `AmbienceDresser` where its rectangle
  meets nothing `AmbienceClearings.standing` names (ladders, doorways, tunnel mouths, gates, the cache,
  a quest prop's place), no torch flame, no other prop and no earth. Decorations are drawing only, give
  no light (but for the area's glowing kinds, under `MAX_GLOW_LIGHTS`) and are rolled from the level's
  seed and the room alone. `AmbienceOpenMap` holds
  the band's open tiles and how much lamplight reaches each. A level's motes are capped by its height
  (`MAX_MOTES` for 16 rows).
- **A room is dark until the party has stood in it** (spec 097). `AmbienceRooms`
  (`game/ambience/ambience_rooms.gd`, `Ambience.rooms`) is the view's memory of the rooms lit on the
  stage shown, a route room by its index and a cache room by `CACHE` plus its side path's place;
  nothing in `sim/` or the save knows of it. `World.sync` ends by calling
  `Ambience.follow_party(expedition, shown stage, arrived, quiet)`, and the memory follows where the
  party is, never events: a room the anchor steps into (`AmbienceRooms.room_of`:
  `Expedition.chamber()`, or the room of the doorway while the party changes stage) lights, its
  torches catching `CATCH_GAP` apart from the nearest to the party, each with a flare
  (`AmbienceLight.swell`), the room's other lamps with the torch nearest them. An arrival (the
  world's first picture, a change of stage or area, a revival heard; the memory also sees for itself
  another stage or another labyrinth) clears the memory and lights the room the party stands in
  whole, with no flare. A sync that catches up on a stall is quiet: what was lit stays lit, the room
  the party stands in now is lit whole with no flare, and the rooms it passed unseen stay dark. A lamp of an unlit room has
  `AmbienceProp.lit` false: `AmbienceLevel` draws a torch's `unlit` part and no flame, throws no
  embers from it, and its light is not in `Ambience.lights()`. That list is one array, filled again
  only when `AmbienceRooms.changes` moves, and it is what `AmbienceDarkness` is handed; a frame in
  which nothing catches or flares does nothing for any of this. An `Ambience` never told of a party
  (the demo, a view in a test) has every room lit. Glints are `PropGlints`' own and do not look at
  the rooms.
- **What the party has not seen is black** (spec 099). `AmbienceSeen`
  (`game/ambience/ambience_seen.gd`, `Ambience.seen`) is a second memory beside the rooms', fed by
  `follow_party` from the lit rooms and the level's rectangles only (a room's is the bounds of
  its drawn shape, `RoomShape.bounds()`, or `LabyrinthChamber.rect` with no shape; tunnels,
  ladders, side paths; never which tiles are open): a place is seen if it is a lit room,
  a tunnel or ladder that touches one (`grow(1)` meets its rectangle), or earth within
  `AmbienceSeen.REACH` tiles of those. It keeps one map, a pixel a tile, of how near each tile is
  to something seen; `AmbienceDarkness`'s third rectangle, the Veil (`veil.gdshader`, z `VEIL_Z`,
  over each level's glow), reads it blended between tiles and cut into the darkness's steps, and
  draws black over the rest, but for where the party's own light reaches. `Ambience.light_at` and
  `brightness_at` answer with the veil (`AmbienceMood.unveiled`), and `Ambience.hides(point)` is
  true where the world is drawn black. A room entered comes out over `SHOW_SECONDS`; a lit room
  the party is not in that holds monsters again is forgotten. `AmbienceRooms` never copies the
  refill rule: as the party leaves a room, and as a stall starts or ends, it asks
  `ChamberRules.refill_tick` (read-only) and asks `Expedition.is_populated` only once that tick
  has passed. A forgotten room's torches go out `GUTTER_GAP` apart and the black
  closes over it in `HIDE_SECONDS`; an arrival or a sync that catches up settles all of it at once.
  The map is one `ImageTexture`, remade only in a frame in which a place fades. What shows in the
  black is drawn at `AmbienceDarkness.HINTS_Z`, over the veil and under the effects: `PropGlints`
  and `UnseenEyes` (`game/world/unseen_eyes.gd`, `World.eyes`), a blinking pair from
  `ambience/eyes.px` at the head of each waiting monster standing where `hides` is true (the
  larger pair for the stage's guardian), redrawn only when a pair comes, goes or blinks.
  `SideProps` shows no `GateTip` for a gate where `hides` is true. A flat labyrinth, an un-zoned
  view and an `Ambience` never told of a party have no veil.
- **The camera** has `WorldCamera.rows`, the world rows its view stays inside (`Vector2.ZERO`: no
  limit). `World` sets it when the stage shown changes, from `WorldCamera.rows_of`: a winding stage's
  band and 4 rows of earth either side, nothing for a flat stage. Inside it the camera follows its
  target up and down as it does sideways.

Tests of the game start `Main` (`ColonyTest.make_main()`), which is winding; a test that wants a
winding simulation or view of its own makes one with `ColonyTest.winding_simulation()` and
`zoned_view()`.

## The party on a winding stage

Spec 091. Nothing in `game/world/` stands on "the level's floor" or reads the party's place as a
column: every place is asked of a room's own rectangle or of the stage's course, so the same code
shows a flat stage (where the answers are what they always were) and a winding one.

- **Places** (`WorldPlaces`, `game/world/world_places.gd`): the feet pixel of a place in tiles, a
  room's floor line, the floor a fight is on (`Expedition.chamber()`'s) and where and facing which
  way the party will be revived (`course.point_at(entry)`, the course's heading there). Waiting
  monsters, fighters, quest props (two-thirds across their room's floor, spec 106) and the revival's camera use
  them; the fallen lie where their sprites fell.
- **Heroes** go where `Expedition.hero_position` says. On a stage with ladders a hero on its feet
  is moved by `LadderRoute` (`game/world/ladder_route.gd`): along its floor, and from one floor to
  another only in the column of the ladder between them, so one that trails round a corner or runs
  to a fight from a ladder never crosses the earth. On a ladder it is drawn walking. Monsters, the
  fallen and every sprite of a flat stage move by its one-floor step (`LadderRoute.step`).
- **Facing** on screen is `PartyPlaces.world_facing`: a new sprite, a hero with no one to face,
  the side a hero steps to off a guardian, the side the worker stands by a prop, the camera's look
  ahead. In a room the course walks from right to left the party faces left.
- **The crossing.** While the party changes stage every hero heads for the anchor
  (`PartyPlaces.anchor`): the doorway at `exit` (or `entry`, going back) for the first half, the
  doorway it arrives by for the second, as `StageCrossing` has it; on a flat stage the shaft's
  column on the floor of the stage shown. A hero fades by its distance from that point.
- **The arrow** (`TargetMarker.heading()`) points the way the party travels next along the course
  toward the doorway it leaves by: it looks `AHEAD` (half a tile) along the course, so at the head
  of a ladder it points down (or up) and at its foot along the floor. On the doorway's own floor
  it points at the doorway from where the party is drawn, as on a flat stage. `side()` is its
  sideways part, 0 while it points along a ladder.
- **The camera** follows the leader's sprite up and down inside `WorldCamera.rows` and looks ahead
  the way the party faces in the world. A revival on another stage cuts as the stage shown
  changes, so it lands inside the new stage's rows.

## A camp when they rest

Spec 102, view only. `CampView` (`game/world/camp_view.gd`, `World.camp`) is a child of `World`
beside `QuestProps`, under the characters: four sprites made once (the `campfire` sheet's logs and
flames, a `bedroll` at each end of the line) and reused for every rest. While the expedition is
RESTING it lays the camp out from where the simulation has the heroes as the rest begins: the fire at
the middle of the line on the front hero's floor, each hero there kept at least `CAMP_CLEARANCE` from it,
moved at most `CAMP_REACH` (12 px) and facing it; a hero off that floor stays put, faces it and stands
(`goal_for`, chained by `World._follow` between `QuestStage.goal_for` and `FallenParty.goal_for`;
`facing_of`, read by `World._act`). `World.camp.animate` runs in `sync` before the heroes are placed.
A `REST_STARTED` that `may_animate` allows sets the camp up over `CAMP_SETUP`; a rest found any other
way is whole at once, and `World._act` snaps a hero's sit (`CharacterSprite.snap_sit`) on a frame that
snaps every sprite. Packing takes `CAMP_PACK`; the puffs are `&"combat"` particles in `World.fx`. While
the fire burns `Ambience.set_camp_light` keeps one more light in `Ambience.lights()`.

- **Sitting** is a layer of `CharacterSprite`'s pose (`sitting`, eased over `SIT_TIME`, `shown_sit()`):
  the rig shorter and lower about the feet, the head bowed, the weapon laid down behind. `World._act`
  sits a hero that stands at its camp place.
- **The fallen of a won fight** lie on while the party rests (`FallenParty.animate` counts RESTING as
  down). When the simulation has one alive again, `World._settle_heroes` calls
  `FallenParty.rise_at_camp`, the same rise as a revive in a fight, which emits `rose_at_camp`; seen late
  (`_snap_all`) it is let go upright at once (`FallenParty.let_go`).
- **One revival effect**: `LoopBeats.revival_effect(hero_id)` (two columns of light and
  `REVIVAL_SPARKS` rising sparks at the hero's feet) for `rose_at_camp`, a `REVIVED` and each hero of a
  `PARTY_REVIVED`, each only for an event `may_animate` allows.

## The quest's stage

Spec 106, view only. A quest's prop stands on its room's floor two-thirds of the way across it, the
way the stage's course runs through the room, at least 2 tiles from the walls of its shape (the
middle of a floor under 6 tiles): `QuestProps.spot_in(view, depth, chamber)`, a static that
`AmbienceClearings.standing` asks too, so no decoration stands on a prop or its dressing.

- **Looks** (`QuestLooks`, `game/world/quest_looks.gd`): each prop sheet has three looks, each with
  every state's part (`<look>_<state>`: `iron_open`, `pilgrim_walk_1`), all on one bottom-centre
  pivot. A chamber's look, tint (a palette swap done by a shared `ShaderMaterial` on `COLOR`),
  mirroring (never the door's: its hinge goes on the nearer wall's side) and 1 to 3 pieces of
  dressing (`quest_dressing.png`, clear of every work spot) come from a `RandomNumberGenerator`
  seeded from the area, the stage and the chamber, never the simulation's stream.
- **The stage** (`QuestStage`, `game/world/quest_stage.gd`, `World.quest_stage`, a `RefCounted`
  the world makes): while the party works a quest, `update` (called in `sync` before the heroes
  move) reads `QuestWork.workers`: the lead `WORK_GAP` short of the prop on the side the party came
  from, the second as far past it, a third and fourth `BEHIND` (7) pixels further out, each facing
  it; every other living hero stays where the simulation has it and `World._act` sits it
  (`CharacterSprite.sitting`) facing the prop once it has stopped. `goal_for` is chained by
  `World._follow` inside `CampView.goal_for`. A gate keeps its one opener (`QuestProps.goal_for`).
- **Props** (`QuestProps`): each worker works at its spot in its quest's pose (spec 107, below),
  offset by `SWING_OFFSET` a rank; the bar stands over the prop (a gate's opener still swings, with
  the microskill's name over its bar). A stone being read shows `rune_1` to `rune_4` over
  its `dim` part, one more each quarter of the work. On `QUEST_DONE` (heard on `World.sim_event`;
  a scan earlier in the same sync keeps what it takes away until `animate`) the prop takes its
  done part and moves to its own table: `prop()` and `prop_count()` are waiting props only,
  `part_of` and `is_done` read both. A done prop stays until its room holds something again or
  the world shows another stage; a mended wanderer stands `STAND_SECONDS`, walks back the way the
  party came at a hero's pace and goes once out of its room. A `QUEST_DONE` `may_animate` refuses,
  or one heard while catching up, is done at once, and its wanderer gone. Nothing of it is saved.

## The quest's story

Spec 107, view only. `QuestStory` (`game/world/quest_story.gd`, `QuestProps.story`, which makes
it, asks `pose` for each worker, and calls `advance` once a frame and `catch_up` when the world
catches up) plays each quest as a short story.

- **Poses**: a quest's `work_move` names a looping work pose of `CharacterMoves` (`LOOPS`:
  `kneel_work`, `push`, `read`, `tend`, one cycle a `SWING_SECONDS`), played in the main slot until
  stopped or replaced, with no vertical shift of its own (the feet stay on the floor line); each
  new cycle (`CharacterMoves.cycles`) is a stroke, and `QuestProps` emits `worked` for it. A worker
  still walking plays none. From three quarters of a wanderer's work each cleric at it prays once,
  and the heal light (`SpellEffects.light_column_at(fx, feet, rng)`, the same a healed hero shows)
  stands on the wanderer as the prayer's blow falls; heal sparkles rise over it while tended.
- **Lines** are data: `QuestDef.lines`, each a `QuestLine` (beat, speaker, class or any, text of at
  most 48 characters), checked by `QuestDef.validate`. They are said through `World.say_for` at the
  beats: the wanderer's plea at `QUEST_STARTED` (and once on a `QUEST_MISSED` walked past), the
  lead's arrival line as it first reaches its spot, the workers' in turn at a third and two
  thirds of `work_progress()`, one sitting hero's at a half, the lead's at `QUEST_DONE` and the
  wanderer's thanks 0.4 s later. The beats driven by progress are said for a fresh `SimEvent`
  stamped with the current tick; at speed 4 or more only the plea, done and thanks are. A line
  for the speaker's class is chosen before one for anyone, at random by a `RandomNumberGenerator`
  seeded from the chamber and the tick. The wanderer speaks through one kept `Callable`
  (`QuestStory.subject()`, over `QuestProps.head_of`). Who works is told by the lead's first line:
  no name stands over a quest's bar.
- **Payoffs** (`QuestEffects`, beside its words and burst): coins (`FxCoin`) out of an opened chest
  to its opener, a stone's runes flaring with an XP mote (`FxMote`) to each living hero, a snip
  spark where a wire was, dust at a stuck door's foot at each shove, all in `World.fx`'s quest
  budget.
- **The callout** (`QuestEffects`, spec 108): on `QUEST_STARTED` each of `QuestWork.workers`, and
  on `GATE_STARTED` the opener, gets `QuestEffects.CALLOUT` in `CALLOUT_COLOUR`, outlined, at 2x,
  under the pool's `quest_callout` budget. It pops by its scale (`FxText.grow_*`: 0.6, 1.25, 1 over
  0.15 s), holds 0.9 s drifting 4 pixels and blinks out, gone before the lead's `arrive` line. It
  follows its hero's feet (`_keep_over_hero`) and keeps clear (`_stack`, giving it an
  `FxText.slot` over what it clears) of the words and ability names over its hero and of every older
  callout: placed STACK_GAP over them when it starts, and moved up over one that overlaps it later
  (a rising name). Never over a younger callout, and a frame moves it only on a real overlap, not
  inside the gap, or two words a rounded pixel apart (a "Learned" stacked over it, two workers
  bobbing as they walk) would leapfrog up the screen. What each callout keeps clear of is kept in
  `QuestEffects._crowds` and worked out again only when the count of quest words, names or callouts
  changes: a frame compares boxes and allocates nothing. A "Learned" starts over every callout.
- **Late events**: nothing starts for an event `may_animate` refuses; a catch-up stops the poses,
  drops what waits to be told and marks the beats the work is past as told.

## Quests and microskills

Spec 025. A microskill (`MicroskillDef`, `data/microskills/`) is a minor passive: each `HeroClassDef` lists
the ones it learns and the level of each, and a hero has one from that level on (`Hero.microskills()`), so
nothing about them is saved. A quest (`QuestDef`, `data/quests/`) is what a plain chamber holds
in place of monsters on a visit, with chance `ChamberRules.QUEST_SHARE`, rolled like the monsters from the
seed, depth, chamber and visit only (`fork("sidequest/d/c/v")`). Reaching one, every living hero with its
microskill (`Party.heroes_with_microskill`, ascending id) works on it while the expedition is `WORKING`.
The lowest id is the lead: `Expedition.worker_id()`, the source of the quest's events and its gold, and the
one the view moves until it shows the others. `QuestWork.workers(run)` reads them all, lead first (only the
opener at a gate), and they are in the state hash. The work takes `QuestWork.work_ticks(def, n)`: one
worker's `work_seconds`, divided by `1 + HELPER_SHARE * (n - 1)`; that function is the one place a later
upgrade shortens it. The reward does not depend on how many worked, and work in progress is not saved. The
reward is `QuestDef.reward_at(depth)`, a number of average kills of that depth, and the chamber is cleared
like a fought one. With nobody able the party walks on: a quest stays for a later pass (its `ChamberState`
remembers the miss so it is reported once per visit), a hazard springs, hurts every living hero (never below
1) and is cleared. Events: `MICROSKILL_LEARNED`, `QUEST_STARTED`, `QUEST_DONE`, `QUEST_MISSED`,
with the usual gold, XP and hit events beside them.

A quest and a gate (spec 093) are both a job a microskill does: `QuestDef` and `GateDef` extend `JobDef`
(`sim/defs/job_def.gd`), which holds the id, names, microskill and `work_seconds` and checks them against
each kind's own `work_range()` (8 to 18 seconds for a quest, 3 to 6 for a gate, which one hero opens
alone, `Party.hero_with_microskill`). A quest adds its reward and hazard.

## Abilities in combat

Spec 050. An `AbilityDef` (`data/abilities/`, its `AbilityEffect`s embedded as sub-resources) is an action
or a passive; `Combatant.abilities` lists a fighter's: a hero's talents (spec 051), none for monsters.
`Battle` keeps the movement and the strike; the new rules live beside it, stateless, in `BattleAbilities`
(which action is ready and at whom, what sets passives off, what each effect does) and `BattleStatuses`
(putting a status on, its work each second, its end), with the per-fight state on the `Combatant`
(`statuses`, `action_ready_tick`, `spent`, `strikes`, `pending_action`, `chasing`), cleared by
`Combatant.reset_abilities` when a battle starts.

- **Actions** replace an ordinary strike when off cooldown, their condition holds and their aim finds
  someone; the fighter walks into the action's reach as for a strike and keeps that target until the
  action starts (`chasing`). A condition of an enemy within some tiles never makes it walk. The cooldown
  runs from when it lands. A stunned fighter does nothing and loses its wind-up. A healer with an ally
  below the healing threshold uses no action aimed at an enemy: it heals first.
- **Within a tick heroes act before monsters**, each side in its order, so a hero's stun bites a tick
  sooner than a monster's would: the stunned monster loses the very tick it is stunned on.
- **Passives** answer to triggers. Landing a hit or a crit and being hit come only from ordinary strikes
  and actions; kills, allies' deaths and falling below a share answer any damage, a passive's or a
  status's too, so passives can set off passives, and `BattleAbilities.MAX_CHAIN` bounds how deep. A
  passive that would land on nobody (its target already dead, say) is not used and reports nothing. A
  passive on a strike may multiply that strike instead of adding a hit (`AbilityEffect.on_strike`); its
  life steal is a share of the whole strike, and a strike that misses sets nothing off.
- **Nothing lands on the dead** but a revive: the receivers of an effect are worked out once, and one
  that an earlier receiver's passive killed is passed over. An **untouchable** fighter takes nothing
  hostile from an enemy, and enemies aim at someone else while anyone else on its side stands
  (`Battle.best_enemy`). `Battle.end()` ends every status with its event; the battle calls it as it ends,
  and so does the expedition's time limit (spec 051).
- **Nothing on the tick builds a list** (spec 078). `Battle.fighters()` is the one list of both
  sides, made as the battle is; the passives and statuses walk it. A target is chosen in one pass
  (`Battle.nearest_enemy`, `best_enemy`: the first in its side's order on a tie), a healer's hurt
  ally is asked for once a tick, and `BattleAbilities.ready_target` says whom one action would
  aim at. How deep passives are setting off passives travels with the call (`chain`, through
  `Battle.deal`, `BattleAbilities.fire` and `use`), so nothing holds it between calls.
- **All damage** goes through `Battle.deal`: a shield absorbs first (a `MISSED` event, flagged), then the
  `HIT` with its true source, then the passives. Ability damage and healing carry no roll and never crit;
  ordinary strikes roll as before, multiplied by mighty or weakened and marked. Statuses in points (shield,
  burning, bleeding, chilled, mending) are a multiple of the fighter's damage or healing, or of the
  receiver's maximum health, fixed when they are put on; one worth nothing is not put on. Putting a status
  on again moves its end and keeps the stronger amount, but not its once-a-second clock.
- **Summons (spec 115).** An `AbilityEffect` that does `SUMMON` (it lands on `SELF`) carries a
  `SummonDef` (`sim/defs/summon_def.gd`, a sub-resource: health, damage and healing as shares of the
  summoner's, its own armor, crit, timing, range, move speed, `ahead`, lifetime and ability ids), a
  `count` and a `summon_cap`. The rules are `BattleSummons` (`sim/combat/battle_summons.gd`): each
  summon is `Combatant.from_summon` (its `owner_id` the summoner, `ends_tick` when its time is up),
  pushed `ahead` tiles toward the enemy inside the room, and put in `Battle.summons` with
  `Battle.add_summon`; its fight-start passives answer its coming, and `SUMMONED` reports it (source
  the summoner, target the summon, amount the lifetime in ticks). `Battle.heroes` stays the party's
  fighters; `allies_of` and `enemies_of` give the heroes' side as heroes then summons, and
  `fighters()` heroes, summons, monsters: lists made anew only as a summon comes or goes, so a walk of
  one is never changed under it, and the act loop walks the list as the tick began, so a summon acts
  from the next tick. A summon is a target like any hero (nearest, weakest, furthest, an area effect,
  a taunt), but a healer's hurt ally, a `WEAKEST_ALLY` aim, an ally-below condition and a revive pick
  heroes only. A summon keeps no place in the heroes' line: spacing, the reach over shoulders, a
  taunt's reach and the places heroes take count heroes only (`Battle._line_of`). One with a move
  speed of 0 never walks: it strikes what is in its range or waits; one with no damage share never
  strikes and acts only through its abilities, with no swing between them (an aura). Ids
  run from `Battle.FIRST_SUMMON_ID` (50) to `LAST_SUMMON_ID` (99) in turn (`Battle.next_summon_id`),
  skipping one held; a summoner's summons of one id over its cap replace its oldest, and past fifty at
  once the oldest in the fight goes. A summon ends (`BattleSummons.end_summon`, `SUMMON_ENDED`, source
  the summon, target its summoner, amount `BattleSummons.Ended`) when its time is up, when it falls,
  when it is replaced and when the fight ends (`Battle.end`). Its end is never a death: no `DIED`, no
  kill or ally's death passive, no revive; its own statuses end with it, and of those it put on
  anyone the ones that work each second from it (burning, bleeding, chilled, mending), while the
  rest keep their time; no status is put on from it once it has gone (one felled mid-action), a
  shot it fired or one at it lands on nobody, and it leaves every list and `combatant()`. A summon
  is always on the heroes' side, and its fight-start passives answer its coming. The heroes
  lose when every hero has fallen, whatever summons stand. A monster a summon kills rewards the party
  as a hero's kill does; the summon's own hits, heals and statuses carry its id, and its own ability
  uses are on its own `Combatant.uses`, so they give its summoner no path XP.
- **Nothing changes without abilities.** Every new roll (a passive's chance, a nimble dodge) happens only
  when an ability or a status asks for it, and every multiplier is exactly 1 without one, so the recorded
  hashes stand. Events: `ABILITY_STARTED`, `ABILITY_USED`, `STATUS_BEGAN`, `STATUS_ENDED`, `MISSED`,
  `REVIVED`, with `SimEvent.ability_id` and `SimEvent.status`.

## Moves and spells on screen

Spec 057. Every `AbilityDef` names a `move`, one of `AbilityDef.MOVES` (the data check refuses any
other); it is a view hint that no rule reads and the state hash leaves out.

- **`CharacterMoves`** (`game/entities/character_moves.gd`, one `_pose_<move>` function each) works out a
  move's offsets from time alone: a shift, a turn and a scale for the rig, and turns for the parts.
  `CharacterSprite.play_move(move, lead, room, pace)` starts one, or ends every move with `&""`; the
  sprite adds the offsets on top of its own pose and clamps the arm and weapon so layers that add up never
  swing through the floor. The blow falls at `lead` (the wind-up left, in real seconds), then a recovery
  of at most 0.4 s. A move with a lead plays in the main slot; one with none (a passive's flourish, a hop on
  a kill or crit, a cheer) plays in an overlay slot over it without interrupting it.
- **`FightMoves`** (`game/world/fight_moves.gd`), held by the `World`, reads the events `_show` draws:
  `ABILITY_STARTED` starts the move (only for a fresh event, never while catching up), `ABILITY_USED`
  brings its blow forward to that frame (`CharacterMoves.land`, by a tick at most:
  `brought_forward` says how far) so it falls on the simulation's tick, and
  stuns, deaths, the end of a fight, a wipe and a change of stage or area end moves at once. `room` keeps a
  leap or dash in front of its target (the gap less both sprites' reach). A stall (`World.catching_up`)
  ends every move. An action heard only as it lands moves nothing, and a sprite held by a stun starts
  no move (it would play late).
- **`CombatEffects`** (`game/effects/combat_effects.gd`) shows the blows: numbers, sparks, bursts,
  coins, motes, bolt trails, a guardian's burst. Where a number starts, so its path clears every
  number showing, is `NumberPlace`'s; the beats of the loop (a level up, resting z's, the WIPED and
  stable banners, a revival's light, a guardian's coming and fall) are `LoopBeats`', which it makes
  and advances and which hears its own events.
- **`SpellEffects`** (`game/effects/spell_effects.gd`), made and advanced by `CombatEffects`, maps an
  ability to a kind of spell (`KINDS`) drawn from palette particles in one colour family each: a flight
  (fireball, meteor, ice shard) leaves on `ABILITY_STARTED` and arrives as the wind-up ends; the rest
  burst on `ABILITY_USED`. Flakes, flames, light, beams, shadow and a spark's jumps show only on the
  fighters the same tick's `HIT`, `HEALED`, `REVIVED` and `STATUS_BEGAN` events credit to the spell,
  read through `AbilityEffects`' `AbilityCredit`. It clears everything on an interrupt or while the
  world catches up.
- **One pool, one gate, one guardian record** (spec 076). Every passing effect (texts, particles, coins,
  motes, rings, resource icons) is added to the `World`'s `FxPool` (`World.fx`, `game/effects/fx_pool.gd`)
  under a budget name; the pool parents it to `World.effects_layer`, advances it each frame (every
  pooled node is an `FxNode`, whose `advance(delta) -> bool` returns false when it is finished) and
  frees it, tidying its lists in place. Four budgets are capped:
  combat 300, ability 150, spell 120, quest 120 (`FxPool.CAPS`); a guardian's death may pass combat's
  by its allowance. What a node follows or flies to is a callable on it (`FxText.follow`,
  `FxCoin.target`, ...), and arrivals are its signals. Every view that starts a move, effect, sound or
  flash for an event asks `World.may_animate(event)` (recent, and the world not catching up); only code
  that clears what is running reads `World.catching_up()`. Catching up means a stall only: a sync
  after more than `World.STALL_TICKS` ticks (times the speed) since the last. The world's first sync
  and a move to another stage or area snap every sprite into place, but are not a catch-up, so what
  they bring (an arrival's goal, a level up) still shows. Every listener connects its own
  `_on_sim_event` in its own setup. `World.guardians` (`GuardianRecord`) knows which fighters are
  guardians, updated from events, for the sounds and the combat effects alike.
- An ordinary strike's draw back and step are stronger (`BODY_WINDUP_SHIFT`, `BODY_STRIKE_SHIFT`) and a
  ranged shot recoils; none of it changes a tick.
- **Summons on screen** (spec 116). `SummonSprites` (`game/world/summon_sprites.gd`), made by the
  `World` (`World.summons`) and advanced in each `sync` after the events, gives each summon standing in
  the fight a `CharacterSprite` among the characters through `World.add_summon` and takes it away with
  `World.remove_summon`; from then on the world acts it out as any fighter (wind-ups, shots, hits, moves,
  status marks), its place the simulation's on the fight's floor (`SummonSprites.goal_of`), eased and
  walking as a monster's. Its sheet is `CharacterSprite.for_summon(id)`:
  `assets/sprites/summons/<id>.png`, else `placeholder.png`, found once per id. A `SUMMONED` that
  `may_animate` makes it at once with a puff (an `FxParticle` `PUFF` in `World.fx`, budget `combat`);
  a summon heard late, or standing with no word of its coming, is given its sprite by `advance` with no
  puff, and one already ended is never shown. A `SUMMON_ENDED`, for any reason, is no death: the sprite
  fades over `FADE_SECONDS` (0.3) with a puff and goes, or goes at once when stale; wind-ups at it end
  (`World._lose_aim`, `FightMoves`). It knows whose each summon is and its name (`owner_of`, `name_of`,
  `colour_of`: the summoner's class bar colour), from `SUMMONED` and the battle: `AbilityEffects`
  colours a summon's names and damage numbers as its summoner, and the `Tally` counts a summon's damage
  and healing to its summoner, by ability as one line under the summon's name (`Tally.note_summon`;
  a tally made mid-fight is told of those standing), and leaves what a summon takes off Taken. The hero
  frames, hero windows and goals are the party's and never show one.

## Conventions

- One class per file, `class_name` in PascalCase, file in snake_case, a `##` doc comment on the class and on
  every public method.
- Signals for things that happened, methods for things to do. The sim does not use signals; it returns events.
- Scenes stay small and are composed in code or by instancing; logic lives in scripts, not in the editor.
- Tuning numbers live in data or in named constants with a comment saying what the number does.
