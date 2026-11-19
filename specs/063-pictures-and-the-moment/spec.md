# 063 — A picture for everything you gain, and the moment you gain it

- **Status:** provisional (direction from Zak 2026-11-18; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 017, 028, 051, 055, 058, 059, 060, 062
- **Pull request:** —

## Intent

Zak, after playing the overhauled UI: talent trees should be "similarly set up to WoW with a clear
diversion and graphics / icons for each skill / talent node", "the same goes for camp upgrades, paragon,
etc.", so that it is "clear what you're getting rather than some text" and gains "feel like bigger
accomplishments". This spec makes the parts every such screen needs: an own picture for each thing a
player can gain, a framed slot that shows one, a tooltip card with the picture in it, and the moment that
marks a gain. Specs 064 (talents and paragon) and 065 (camp upgrades) lay the screens out with them.

Zak asked for these pictures, so they are an exception to the rule of few new assets; they are still
placeholders he may redraw.

## Requirements

- **R1. Its own picture.** Every ability in a talent tree (44 today), every upgrade (5), every paragon
  stat (3) and every microskill (5) has a picture of its own, 16x16 in the master palette, that shows
  what the thing is or does (a ball of fire for Fireball, a shield with a crack for Last Stand, a fat
  coin purse for Fat Purse). No two are the same picture, and no two abilities of one class can be
  mistaken for each other at a glance. A picture is found by the thing's id. A test fails when any of
  those ids has no picture, so new content cannot ship without one.
- **R2. The slot.** `UiIcon` shows one picture at twice its size (32 UI pixels) in a bevelled frame, or
  at its own size in a small frame. It has four states that differ in more than colour: **owned** (full
  colour, gold frame), **ready** (full colour, yellow frame that pulses gently), **locked** (the picture
  dimmed, plain frame) and **closed** (the picture dark and barely there, a small padlock at the
  corner). A frame is square or has cut corners (064 uses the shape for actions and passives). It can
  carry a short count at its bottom right (`3`, `12/20`) in the equal-width digits, brightens under the
  mouse, and reports a left click.
- **R3. The card.** A tooltip can be a card: the picture, a bold title, a grey line under it (what kind
  of thing it is), the wrapped body, and a last line in a colour of the caller's choice that says how it
  stands (`Click to learn`, `Needs 12 more clay`). Plain tooltips are unchanged. Cards stay above every
  window, as spec 062 R12 rules for tooltips.
- **R4. The burst.** `UiMoment.burst(control)` marks a gain on a control: its frame flashes white, a
  ring of sparks spreads from it and the control pops to 1.3 times its size and settles, all within
  0.6 s, drawn in code above the windows. It moves nothing in the layout.
- **R5. The banner.** `UiMoment.announce(...)` drops a banner in at the top middle of the screen, under
  the boss bar's place: the picture at three times its size, a headline in bold and one line under it,
  with a sound. It stays 2.5 s, or until clicked. Banners wait their turn; at most three wait, and a
  newer one replaces the oldest waiting. It never covers the hero frames, the place panel or the purse
  at either room, and the note after a defeat is drawn over it.
- **R6. Only for what just happened.** Neither a burst nor a banner starts for an event that is not
  recent or while the world is catching up (`World.is_recent`, `World.catching_up`), and those waiting
  are dropped when a catch-up starts. A frame of 300 ticks holding ten gains shows at most the three
  newest banners.
- **R7. The present screens show the pictures.** Until specs 064 and 065 lay them out afresh, the
  talent nodes, the paragon cells, the skill cards and the shop's rows show the new pictures in their
  present layouts. The eight shared pictures of spec 060 (`talent_icons`, `AbilityDef.picture` and
  `AbilityDef.PICTURES`) are removed.
- **R8. Two sounds.** A small gain and a grand gain each have a sound (`.sfx` recipes), passing the
  sound lint; the burst plays the small one, the banner the grand one, neither more than once in
  0.15 s.
- **R9. A sheet to look at.** A specimen scene shows every picture with its name under it, grouped by
  class, upgrades, paragon and skills, in all four states, and one burst and one banner; the gallery
  command's kind of shot shows it whole.
- **R10. Fits both rooms.** At 960x540 and 1280x720 the banner and a card with the longest title and
  body in the data are wholly on screen with no text cut.

## Interfaces

```gdscript
class_name UiIcon extends Control
enum State { OWNED, READY, LOCKED, CLOSED }
enum Shape { SQUARE, CUT }
signal clicked
func _init(picture_id: StringName, large: bool = true, shape: Shape = Shape.SQUARE) -> void
static func picture(picture_id: StringName) -> Texture2D   # null when there is none
static func has_picture(picture_id: StringName) -> bool
func show_state(state: State) -> void
func state() -> State
func set_count(text: String) -> void
func advance(delta: float) -> void

# UiTip, added beside attach():
func attach_card(control: Control, card: Callable) -> void   # card.call() -> UiTip.Card
class Card: var picture_id: StringName; var title: String; var kind: String; var body: String
            var stand: String; var stand_colour: StringName

class_name UiMoment extends Control   # one, on UiRoot above the windows: Main.ui.moment
func burst(control: Control) -> void
func announce(picture_id: StringName, headline: String, line: String) -> void
func waiting() -> int
func shown_headline() -> String
```

Picture ids are the content ids (`&"fireball"`, `&"fat_purse"`, `&"power"`, `&"lockpicker"`); if two
kinds of content ever share an id, say so and stop. Sheets go under `assets/sprites/ui/`. Nothing a rule
reads changes under `sim/`: only the `picture` hint goes.

## Acceptance

In `tests/acceptance/test_063_pictures_and_the_moment.gd`, one test per requirement named `test_rN_…`,
each written before its code and seen to fail. R1 reads every id from `Content` and also checks that no
two pictures have the same pixels. R6 drives real events through a `Main`, stale and recent. A reviewer
will break the code under each.

**To look at, and for Zak:** the specimen whole and enlarged 3x by class; a card over a talent node; a
burst in three frames; a banner at both rooms; the hero window's Talents tab and the shop with the new
pictures. Describe every shot. Can you tell what each picture is without its name?

## Out of scope

- New layouts for the talent tree, paragon, skills (spec 064) and the shop (spec 065).
- Deciding which gains get a burst or a banner (064, 065). New rules, abilities or upgrades.
- Pictures for monsters, areas or resources.

## Paths

- `assets/sprites/ui/`, `assets/audio/`
- `game/ui/`, `game/audio/`, `game/art/`, `game/main.gd`
- `sim/defs/ability_def.gd`, `data/abilities/` (removing the `picture` field only)
- `tests/`, `tools/` (only if the art or sound lint needs to know the new sheets)
- `docs/architecture.md`, `docs/style-bible.md`, `docs/wiki/index.html`, `CLAUDE.md`

## Open questions

None.
