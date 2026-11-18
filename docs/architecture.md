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

- **The world** (the labyrinth, the party, the effects) and, for now, **the old HUD** are drawn at 640x360
  into `Main.world_viewport`, a `SubViewport` inside `Main.world_view` (a stretching
  `SubViewportContainer`, nearest filtering, snapped to pixels). The window shows it scaled by the largest
  whole number that fits (`UiRoot.world_scale()`). The HUD's `CanvasLayer` stays at `Main/HUD` but draws
  into that viewport (`custom_viewport`, set on `NOTIFICATION_SCENE_INSTANTIATED`: set any later, freeing
  `Main` makes the engine undo a connection that is already gone).
- **The UI layer** (`UiRoot`, `game/ui/ui_root.gd`, canvas layer 20) is drawn in *UI pixels*: the largest
  whole UI scale that still leaves at least 960x540 of room (`ui_scale()`, `room()`). 1280x720 gives a scale
  of 1 and 1280x720 of room, 1920x1080 a scale of 2 and 960x540. Everything on it hangs from `UiRoot.frame`,
  which carries the one theme (`UiTheme`); text there is `UiText`, the UI font.
- **Coordinates.** While a `UiRoot` is in the tree the window is in `CONTENT_SCALE_MODE_CANVAS_ITEMS` with
  a content size of 640x360: the root viewport still *thinks* in world pixels, so every input event, the
  world and the old HUD keep their 640x360 coordinates (tests push mouse events there), while drawing is at
  the window's size. The UI layer's transform is `ui_scale / world_scale`; `UiRoot.world_to_ui()` and
  `ui_to_world()` convert. Other scenes (the gallery, the showcase) keep the project's viewport mode.
- **Windows** (`UiWindow`, `UiWindows`): a title bar to drag by and a close button, any number open, a
  click raises one, `Esc` closes the front one (before any old HUD panel sees it), the title bar never leaves
  the room. Which are open, and the places of those the player dragged (`placed`), live in the settings
  file under `windows`, beside the sound setting, never in the save; an undragged window takes its default
  place for the current room, and a dragged one is moved wholly back in when the room shrinks. Windows
  saved open wait until the away report has gone (`UiWindows.open_waiting`). `UiButtonBar` holds a button
  per window, each with a `UiBadge` showing the window's `UiWindow.badge` count (the shop's affordable
  upgrades, the map's newly opened areas); a window with `on_bar` false (a hero window) has no button.
  A window refits when its content's minimum size changes. Help, the journal, the orders, the shop, the
  area map, the tally and the hero windows are windows; no old panel opens over them any more (the away
  report, the goals and the rest of the old HUD move over in specs 061 and 062). `HudTooltip` and
  `DefeatNote` treat a point on a window or the bar as nowhere (`UiWindows.covers`).
- **Keys and the front window** (specs 059, 060): a window's keys act only while it is the front window
  of all (`UiWindows.front()`): 1 to 5 and B the shop's, 1 to 3 a hero window's on its Talents tab, Q and
  E a hero window's or the tally's tabs. Tab opens the next hero's window in front whatever is in front,
  Esc closes the front window (`UiWindows`), and a click anywhere on a window brings it to the front.
  The `Hud` hears the keys and asks `UiWindows.front()` (`Hud._in_front`).
- **Window contents made by the HUD** (spec 059): `ShopWindow`, `AreaMapWindow` and `TallyWindow`
  (`game/ui/windows/`, all `WindowContent`) are made by `Hud.setup` as `hud.shop`, `hud.area_map` and
  `hud.tally`, so they hear the world's events from the start, and `UiRoot.setup` puts each in a window.
  They open and close through their window (`WindowContent.open`), so without a `UiRoot` (a HUD-only
  test) they never open: such a test adds one. `UiBar` is the UI layer's thin bar.
- **The frame of the screen** (spec 061, `game/ui/frame/`): `PlacePanel` and `Countdown` at the top left,
  `Purse` (with the speed button) at the top right, `BossBarView` between them in a guardian fight, and a
  `HeroFrameView` per hero along the bottom. The `Hud` builds them under `Hud.screen_frame`, keeps making
  their texts (`status_text`, `_stable_parts`, `PlaceText`) and lays them out each frame; `UiRoot.setup`
  moves `screen_frame` onto the layer (`Hud.adopt_frame`, first child of `frame`, so windows draw over it)
  and `UiRoot._apply` sizes it to the room (`Hud.fit_frame`). A `Hud` built alone in a test keeps it as its
  own child at a scale of 640/960, so its pieces' global rects stay in world pixels. Their tooltips are
  one `UiTip` (`Hud.frame_tip`) that follows the mouse itself (`follows_mouse`: the labels take no mouse)
  and treats a point on a window as nowhere. Effects aim at the pieces' places on the screen
  (`Hud.on_screen`, through the canvas layer's transform, never a camera's): coins at the purse's coin, resource
  icons at their counts, and XP motes at their hero's frame (`CombatEffects.frame_screen_targets`; with no
  HUD, at the hero's chest as before). After a stall (`World.STALL_TICKS` at the game's speed) every
  piece snaps to the simulation's state.
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
  node's picture is its ability's `AbilityDef.picture` (one of `AbilityDef.PICTURES`, a view hint the
  data check validates and the state hash leaves out), drawn from `assets/sprites/ui/talent_icons.png`.

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

Classes, talents, items and monsters are custom `Resource` classes with typed `@export` fields, stored as text
`.tres` files under `data/`. Adding content means adding a file, not code. Each content class defines
`validate() -> PackedStringArray` (one line per problem); the `data` step of the check loads every resource
and fails on any problem.

## Saving

The save is the party's *progress*, not the exact moment (spec 014). `Simulation.to_save()` returns plain
values: a format version, the seed, the tick, the gold, each hero's class, level and XP, and the expedition's
last stable depth, deepest depth, target depth and auto-push, the rank of each camp upgrade (spec 016), the auto-buy switch (spec 022)
each hero's talents and paragon points (spec 051), the party's orders (spec 035), and the resources it holds
and the guardians it has beaten (spec 052).
Positions, a fight in progress, chamber timers and
random streams are not saved: `Simulation.from_save(data)` makes a new simulation from the seed and stands the
party up the way revival does (`Arrival.from_save`), alive and full at the arrival point of its last
stable depth, with every chamber freshly populated.

- **Refused, not guessed at.** `Simulation.save_problems(data)` lists every problem, one line naming the field;
  `from_save` returns `null` if there is any. JSON makes whole numbers floats, so a whole float is read as an
  int; a float past 2^53 is refused, so seeds must stay within ±2^53 to survive a save.
- **Versions.** `SAVE_VERSION` is 8. Loading goes through `Simulation.upgrade_save`, which brings older data
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
  its ranks (`TalentSave.OLD_TRAINING_PRICES`) to the party's, and gives it `talents` (empty) and `paragon`
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
- **Orders (spec 035).** `Expedition.pace` and `Expedition.guardian_order`, set through
  `Simulation.set_pace` and `set_guardian_order`, apply on the next step with an `ORDER_CHANGED` event. The
  pace picks the share of health below which a hero makes the party rest (`PartyOrders.rest_below`); under
  Hold the party's walking goal stops short of a living guardian's chamber (`PartyOrders.short_of`), it turns
  there and hunts on that level, and `Expedition.is_holding` says so. At their defaults the orders add nothing
  to the state hash. `EncounterRoll` holds the expedition's encounter roll, guardian lookup and fighters' hash
  parts, kept apart so `expedition.gd` stays under gdlint's 1000 lines.
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
  while a `CatchUpBar` shows. The driver, world, effects and HUD are made only when it ends (`caught_up`), so
  nothing from the time away is drawn, and an `AwayPanel` reports it. No save is written during a replay, so
  quitting part way loses nothing. Tests set `away_seconds_override`; a run with no `save_store` never replays.
  Watching changes nothing (spec 023): the expedition's reads (`monsters_in`, `is_populated`,
  `side_quest_in`, `working_quest`, `worker_id`, `work_progress`, `hero_position`, `chamber`,
  `guardian_of`, `hash_parts`) never change the state hash, so a watched game and
  the same game run headless stay hash-equal. A chamber's record is made only when the party fights there;
  a read works out the visit the chamber is on and takes its monsters from a roll cache outside the hash.
  Monster ids come from where the monster waits (`Expedition.monster_id`: depth, chamber, visit and place in
  the encounter), not from the order anything was asked for.

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
numbers of the old `min_depth`), and `SideQuestDef.reward_at` reads it. The timers to become safe and to refill
a chamber (`DepthTiming`) go by the stage number instead, so every area's first stage is safe in a minute.
A chamber holds only
its area's monsters that have appeared by its stage (`EncounterRoll`), and the guardian stands at its stage
and every `GUARDIAN_EVERY` stages after.

Each area has its own `Labyrinth`: the first area's is the seed's own, every other's is forked under
`area/<id>/`, as are its encounter and side-quest rolls. `AreaTravel` (owned by the expedition, read as
`Expedition.travel`) keeps the open areas, every other area's safe and furthest stage, each area's labyrinth
and a journey. `Simulation.set_destination(area, stage)` asks for one, and is ignored if the area is not open
then. Once the party is out of any fight or side quest and standing, it leaves (`JOURNEYING`; a rest it
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
as `ResourceDrops.amount_at(size, stage)` (1, 2 or 6 on stage 1, a quarter more each stage on), and a side quest
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

Spec 051. Each class has a `TalentTreeDef` (`data/talents/`, one per class, `Content.talent_tree`): a trunk of
three ability ids and two named paths of four, every node an `AbilityDef` under `data/abilities/`.
`TalentTreeDef.next_nodes(taken)` is the whole rule of order: the next trunk node, then the first node of
either path, then the next node of the path begun; `order_problem` checks a saved list against it.

A `Hero` keeps the nodes it took, in order, and the paragon points it put into each `TrainingDef.Stat`;
neither unspent count is stored: `TalentRules.talent_points_at(level)` (one at every even level, up to
`Hero.TALENT_POINTS`, 7) and `paragon_points_at(level)` (one a level after 14) less what was spent.
`Hero.combatant()` hands the fighter its nodes' abilities, the newest first (a fighter tries its actions in that order), and multiplies its damage and
healing, maximum health and attack speed by `1 + points * TrainingDef.per_rank` (3%) of Power, Toughness and
Quickness, after the camp upgrades. A node taken mid-fight waits for the next fight; a paragon point spent
mid-fight changes the fighter at once, as spec 029's training did. A fresh start (`reset_talents`) costs
`Simulation.RESET_GOLD_PER_LEVEL` (100) times the hero's level, is refused while `Expedition.battle` is set,
and leaves paragon points alone. Events: `TALENT_POINT_GAINED` (from `Expedition._give_xp`, beside the
`LEVEL_UP` that earned it), `TALENT_TAKEN` (with `ability_id`), `PARAGON_SPENT`, `TALENTS_RESET`. Auto-buy
never spends a point. When the expedition's 90-second limit ends a fight, it calls `Battle.end()` first, so
every status ends with its event and no monster goes back to its chamber carrying one.
R14: fights last seconds, so every talent action has `ready_at_start` (`TalentTreeDef.validate` refuses one
that has not) and waits only for its condition; `AbilityDef.Condition.OTHER_ALLY_BELOW` is `ALLY_BELOW`
without the fighter itself (Bulwark). A second tree for a class is refused by its `validate()`, and
`Content` keeps the first.
`TalentSpender` (`tools/godot/`) is the headless run's way of spending (`dev.py sim --spend-talents`): the
trunk, then the first path, and every paragon point into Power.

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

## Side quests and microskills

Spec 025. A microskill (`MicroskillDef`, `data/microskills/`) is a minor passive: each `HeroClassDef` lists
the ones it learns and the level of each, and a hero has one from that level on (`Hero.microskills()`), so
nothing about them is saved. A side quest (`SideQuestDef`, `data/sidequests/`) is what a plain chamber holds
in place of monsters on a visit, with chance `Expedition.SIDE_QUEST_SHARE`, rolled like the monsters from the
seed, depth, chamber and visit only (`fork("sidequest/d/c/v")`). Reaching one, the living hero with its
microskill (lowest id first, `Party.hero_with_microskill`) does it while the expedition is `WORKING`; the
reward is `SideQuestDef.reward_at(depth)`, a number of average kills of that depth, and the chamber is cleared
like a fought one. With nobody able the party walks on: a quest stays for a later pass (its `ChamberState`
remembers the miss so it is reported once per visit), a hazard springs, hurts every living hero (never below
1) and is cleared. Events: `MICROSKILL_LEARNED`, `SIDE_QUEST_STARTED`, `SIDE_QUEST_DONE`, `SIDE_QUEST_MISSED`,
with the usual gold, XP and hit events beside them.

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
  (`Battle.aimable`). `Battle.end()` ends every status with its event; the battle calls it as it ends,
  and so does the expedition's time limit (spec 051).
- **All damage** goes through `Battle.deal`: a shield absorbs first (a `MISSED` event, flagged), then the
  `HIT` with its true source, then the passives. Ability damage and healing carry no roll and never crit;
  ordinary strikes roll as before, multiplied by mighty or weakened and marked. Statuses in points (shield,
  burning, bleeding, chilled, mending) are a multiple of the fighter's damage or healing, or of the
  receiver's maximum health, fixed when they are put on; one worth nothing is not put on. Putting a status
  on again moves its end and keeps the stronger amount, but not its once-a-second clock.
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
- **`SpellEffects`** (`game/effects/spell_effects.gd`), made and advanced by `CombatEffects`, maps an
  ability to a kind of spell (`KINDS`) drawn from palette particles in one colour family each: a flight
  (fireball, meteor, ice shard) leaves on `ABILITY_STARTED` and arrives as the wind-up ends; the rest
  burst on `ABILITY_USED`. Flakes, flames, light, beams, shadow and a spark's jumps show only on the
  fighters the same tick's `HIT`, `HEALED`, `REVIVED` and `STATUS_BEGAN` events credit to the spell,
  read through `AbilityEffects`' `AbilityCredit`. It keeps its own particle cap, as `AbilityEffects` does, and clears everything
  on an interrupt or while the world catches up.
- An ordinary strike's draw back and step are stronger (`BODY_WINDUP_SHIFT`, `BODY_STRIKE_SHIFT`) and a
  ranged shot recoils; none of it changes a tick.

## Conventions

- One class per file, `class_name` in PascalCase, file in snake_case, a `##` doc comment on the class and on
  every public method.
- Signals for things that happened, methods for things to do. The sim does not use signals; it returns events.
- Scenes stay small and are composed in code or by instancing; logic lives in scripts, not in the editor.
- Tuning numbers live in data or in named constants with a comment saying what the number does.
