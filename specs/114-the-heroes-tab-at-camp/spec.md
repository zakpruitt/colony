# 114 — The Heroes tab at camp: recruit and choose the four

- **Status:** approved (2026-11-27)
- **Milestone:** M9
- **Depends on:** 063, 065, 068, 112, 113
- **Pull request:** —

## Intent

Specs 112 and 113 let the colony hold more heroes than the four who go down and make the screen
follow a change. This spec gives the player the place to do it: a Heroes tab in the Camp window,
where the four going down and the heroes at camp stand side by side, a swap is two clicks, a
benched hero's window opens from its card, and every hero whose artifact was found waits there with
its request. It goes in the Camp window, not a new window on the bar: the bar is boxed in at
317 UI pixels wide at 960x540 (spec 068) and has no room for another button, and recruiting is done
at camp.

## Requirements

- **R1. The Camp window has two tabs.**
  - The Camp window (`ShopWindow`, its id `shop` and its key `U` unchanged) gains a row of two tabs,
    `Upgrades` and `Heroes`, as the tally has its row. Its title becomes `Camp`.
  - The Upgrades tab is today's window: cards, pips, prices, Auto-buy, flashes, bursts and banners
    as specs 065 and 017 have them.
  - `Q` and `E` change tab while the Camp window is in front. `1` to `5` and `B` act only while the
    Upgrades tab is open. The window opens on the tab it last showed.
  - The tag on the bar's Camp button counts the upgrades the party can pay for plus the classes it
    can recruit now (`Roster.can_recruit`).
- **R2. The four and the bench.**
  - The Heroes tab has two groups, `Going down` (the four, in formation order) and `At Camp` (the
    benched heroes, by id).
  - Each hero is a card: its picture (`HeroClassDef.look()`), class, level, and the title spec 109
    gives it. A card at camp adds `At Camp`. Pointing at a card shows a tooltip with its level, its
    unspent talent points and its path ranks.
  - A click on a card's picture opens that hero's window (`HeroWindows.open_hero`).
  - With no hero at camp, the group says `No one at camp. Recruit below.`
- **R3. Swapping is two clicks.**
  - Each card has a `Swap` button. A click on one lights that card. A click on a `Swap` in the other
    group then asks for the swap (`roster.swap`), and the light goes. A click on the lit card's own
    button, a click on a card in the same group, or `Esc` drops the choice and asks for nothing.
  - While a card is lit, a line under the groups says `Choose who the Ranger replaces` (or, from a
    card going down, `Choose who replaces the Knight`).
  - A swap waiting (`roster.waiting()`) marks both cards `After this fight` until it is made or
    dropped.
  - Once it is made, both cards move to their new groups within the frame it is heard in.
- **R4. Recruiting.**
  - Under the groups, `Waiting at camp` lists every class waiting (`roster.waiting_at_camp()`), in
    that order, one card each.
  - A waiting card shows the class's picture, its name, the artifact that was found (its
    `artifact_picture`, or the shared placeholder, and `artifact_name`), the level it would arrive at
    (`roster.recruit_level()`), and its request in the hero's words: `Bring 300 gold and 40 Glowcaps`
    (or `Bring 300 gold`), the resource with its icon. Its `Recruit` button is enabled only when
    `roster.can_recruit` holds; otherwise its tooltip says what is short (`Needs 120 more gold`,
    `Needs 15 more Glowcaps`).
  - Under them, while `roster.still_hidden()` is above 0, one line:
    `3 more heroes are out there. Their artifacts lie in caches down the side paths.` (`1 more hero
    is out there. Its artifact lies …` for one). No hidden class is named.
  - With no one waiting and none hidden, the section says `Every class has joined the colony.`
  - The shared placeholder artifact picture is one 16x16 picture with the id `artifact`, in a new
    sheet `assets/sprites/ui/pictures_artifacts.px` listed in `UiIcon.SHEETS`: master palette, more
    than 40 opaque pixels, baked and linted, as spec 063 R1 and spec 109 R1 ask of a picture. Each
    class spec may add its own artifact's picture to that sheet.
- **R5. Moments.**
  - For a recent `ARTIFACT_FOUND`, a banner shows the artifact's picture with `Found a Ranger's
    Whistle` and under it `A Ranger waits at Camp`.
  - For a recent `HERO_RECRUITED`, the new hero's card bursts (spec 063's `UiMoment.burst`) and a
    banner shows its picture with `The Ranger joins the colony`.
  - For a recent `HERO_FIELDED`, both cards burst; no banner.
  - A stale event, or one heard while catching up, moves the cards with no burst and no banner.
- **R6. Fits.**
  - At 960x540 and 1280x720, with the added class and the four, no text is cut or overlaps.
  - The window is never taller than the room. The Heroes tab scrolls inside it when it must, as the
    hero window's tabs do.
  - The button bar does not change (spec 068).
- **R7. Keys, help, wiki and showcase.**
  - `KeyBook.ROWS`: `B` and `1-5` apply on `Upgrades tab`, and `Q E` change tab in `Hero window,
    Tally or Camp`. No key is added.
  - Help says, in a line, that new heroes are recruited in the Camp window's Heroes tab, and that
    the four in `Going down` are the ones who fight.
  - The wiki gains a "The colony and recruiting" section: artifacts found in caches, the request,
    the arrival level, the bench, swapping; and its "Not built yet" line loses the roster. The entries for specs 112, 113
    and 114 are added.
  - The showcase gains a moment that opens the Camp window on its Heroes tab.
- **R8. Nothing lost.** Buying, auto-buy, the cards' flashes, bursts and banners, and the tag work as
  before on the Upgrades tab. The tests of specs 017, 022, 059, 065, 068 and 074 that cover the Camp
  window pass, amended only where they read its title, measure its height or name the key rows'
  words (each amendment listed in the pull request, with what still guards it).

## Interfaces

```gdscript
# game/ui/windows/shop_window.gd
enum Page { UPGRADES, HEROES }
const TITLE: String = "Camp"
var tab_buttons: Array[UiButton] = []
var heroes: RosterTab
func page() -> Page
func set_page(which: Page) -> void

# game/ui/windows/roster_tab.gd (new): what tests read
class_name RosterTab
extends VBoxContainer
var field_cards: Array[RosterCard] = []      # formation order
var bench_cards: Array[RosterCard] = []      # id order
var recruit_cards: Array[RosterCard] = []    # roster.waiting_at_camp() order
var hidden_line: Label
var choosing_line: Label
## The hero id of the lit card, or -1.
func chosen() -> int
```

`RosterCard` (new) is the lane's to shape. `ShopWindow` has 7 public methods today; it stays well
under gdlint's 20.

## Acceptance

In `tests/acceptance/test_114_the_heroes_tab_at_camp.gd`, one test per requirement named
`test_rN_…`, each written before its code and seen to fail. Every test is driven by real clicks,
keys and mouse motion, and checks the simulation after each command. The class to recruit comes from
`ColonyTest.add_recruit_class()` (spec 112).

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_two_tabs` | Q and E change tab; 1 and B buy and switch only on Upgrades; the tab remembered; the tag counts a recruitable class |
| R2 | `test_r2_the_four_and_the_bench` | The cards in their groups and order, their words and tooltip; a picture click opens the hero's window; the empty bench line |
| R3 | `test_r3_two_clicks` | A swap by two clicks reaches the simulation; each way of dropping a choice asks nothing; the line; `After this fight` during a fight, gone when made |
| R4 | `test_r4_recruiting` | Before a find, only the hidden line; after it, the card's artifact, request and arrival level; the button off with its tooltip when short, on and working when not; the last line once all have joined; the placeholder picture is found by `UiIcon` |
| R5 | `test_r5_moments` | A banner for a recent find, burst and banner for a recent recruit, bursts for a swap, nothing for stale ones |
| R6 | `test_r6_fits` | Rectangles at 960x540 and 1280x720: nothing cut or overlapping, the window inside the room, the bar's size unchanged |
| R7 | `test_r7_keys_help_wiki_showcase` | The key rows' words, the help line, the showcase moment's watcher |
| R8 | the amended suite | Every listed test passes |

**To look at, and for Zak:** the Heroes tab fresh (four going down, the hidden line), the find's banner,
with a hero waiting and short of gold, after a recruit (the burst and banner), mid-choice, and
with a swap waiting; at 1280x720 and `--ui-room=960x540`, from a throwaway scene under `.shots/` that
adds the class. Crop and enlarge small parts 3x, and describe every shot. Is the swap obvious without
reading help?

## Out of scope

- Any rule, chance, price or save change (spec 112). A new class, or a class's own artifact picture.
- A new window or button on the bar, new keys, dragging cards to swap.
- Dismissing a hero, naming one, comparing two heroes inside the tab (their windows do that).

## Paths

- `game/ui/windows/shop_window.gd`, `game/ui/windows/roster_tab.gd` and
  `game/ui/windows/roster_card.gd` (new, with their `.uid`s), `game/ui/windows/window_book.gd` (the
  Camp entry's tooltip), `game/ui/windows/help_panel.gd`, `game/ui/key_book.gd`
- `game/ui/windows/hero_windows.gd` (only to hand `open_hero` to the tab), `game/hud/hud.gd` (only
  where it makes the Camp window; it gains no public method, being at its cap of 15), `game/main.gd`
  or `game/ui/ui_root.gd` (only if the tab must be given the hero windows there)
- `game/ui/ui_icon.gd` (the new sheet in `SHEETS` only), `assets/sprites/ui/pictures_artifacts.px`
  and its baked `.png` and `.json`
- `game/dev/showcase.gd`, `game/dev/showcase_moments.gd`
- `tests/acceptance/test_114_the_heroes_tab_at_camp.gd` and its `.uid`,
  `tests/acceptance/test_017_upgrade_shop.gd`, `test_022_auto_buy.gd`,
  `test_059_shop_map_and_tally_windows.gd`, `test_065_camp_upgrades_you_can_see.gd`,
  `test_068_a_button_bar_that_says_what_it_opens.gd`, `test_074_one_list_of_windows_and_keys.gd`,
  `test_030_help_and_hints.gd` (all for the amendments R8 allows)
- `docs/wiki/index.html`, `docs/architecture.md` (the Camp window's tabs)

## Open questions

None.
