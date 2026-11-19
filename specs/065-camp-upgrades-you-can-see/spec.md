# 065 — Camp upgrades you can see

- **Status:** provisional (direction from Zak 2026-11-18; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 017, 045, 052, 059, 063
- **Pull request:** —

## Intent

Zak wants the camp upgrades, like the talents, to have "graphics / icons", to make it "clear what
you're getting rather than some text" and to "feel like bigger accomplishments". Today the shop is rows
of sentences with a thin bar. This spec makes each upgrade a card with its picture, its ranks as pips
you fill, what you have now beside what the next rank gives, and a moment when you buy.

## Requirements

- **R1. A card per upgrade.** Each upgrade is a card: its picture in a large `UiIcon` (spec 063) with
  the rank as its count, its name in bold with its number key, and one buy button with the whole price
  (gold, and the resource with its icon from the rank that costs it). The icon is ready when the party
  can pay, locked when it cannot, owned in gold for good at the top rank, where the button reads `Max`.
- **R2. What you get, as numbers.** Each card shows what the upgrade gives now and what the next rank
  will give, side by side with an arrow, the gain in green: `Damage and healing  +15%  >  +20%`. At
  rank 0 the left side reads `+0%`; at the top rank only the total shows, with `Mastered`.
- **R3. Ranks as pips.** Under the name, one pip per rank, filled for each bought, with every fifth
  pip larger; they fit the card at the top rank count in the data (20 today) without wrapping.
- **R4. What is missing.** While the party cannot pay, the card says what is missing in words, as
  spec 059 R2 rules (`Needs 12 more clay, from The Claypits`). Pointing at a card shows a card tooltip
  (spec 063 R3) with the picture, the next rank's prices and where its resource comes from, as spec 052
  R5 rules.
- **R5. Buying is a moment.** When the player buys a rank (button or key) and the event is recent: the
  icon bursts (spec 063 R4), the new pip fills with a flash, and the numbers of R2 step to their new
  values. A purchase by auto-buy fills its pip with the flash and no burst.
- **R6. Milestones.** Every fifth rank, whoever bought it, gets a banner (spec 063 R5) with the
  upgrade's picture: `Sharp Blades, rank 5` over `+25% damage and healing`. The top rank's banner reads
  `Sharp Blades mastered`. A stale purchase, or one heard while catching up, gets neither burst nor
  banner.
- **R7. The foot and the keys.** The Auto-buy switch with its sentence, keys `1` to `5` and `B` on the
  front window, and the bar button's count of upgrades the party can pay for all work as today.
- **R8. Nothing lost.** Every command the shop sent is sent with the same effect, and every fact it
  showed is still shown. The tests of specs 017, 045, 052 and 059 that cover the shop pass, amended only
  where they name a node or a pixel position (list each amendment and what still guards the behaviour).
- **R9. True in a crowded frame.** After a frame of 300 ticks holding purchases by the player and by
  auto-buy, every card shows the end state: rank, pips, numbers, price, what is missing.
- **R10. Fits both rooms.** At 960x540 and 1280x720, with the longest names and dearest prices in the
  data, no text is cut or overlaps, the window is never taller than the room, and at their default
  places the shop still overlaps neither the map nor the tally nor the hero frames' line (spec 059 R8).
- **R11. Help, wiki and showcase.** True to it; the showcase's shop moment shows a rank being bought
  and a fifth rank's banner.

## Interfaces

Built on specs 058, 059 and 063, unchanged; if one needs a new function, add it and say so. The window
keeps its id and its key. What an upgrade gives is read from `UpgradeDef` (`description`, `per_rank`);
if a short name for the stat is needed for R2's line, it is a new view hint on `UpgradeDef`
(`gives: String`, checked by `validate()`, read by no rule). Nothing else under `sim/` changes.

## Acceptance

In `tests/acceptance/test_065_camp_upgrades_you_can_see.gd`, one test per requirement named
`test_rN_…`, each written before its code and seen to fail, driven by real clicks and keys, checking the
simulation after each command. R5 and R6 check the player's purchase, auto-buy's, and a stale one. A
reviewer will break the code under each.

**To look at, and for Zak:** the shop fresh, mid-game with a card the party cannot pay, and with an
upgrade mastered, at both rooms; three frames of a purchase; a fifth rank's banner; a card tooltip.
Describe every shot. Can you tell what each upgrade does and how far along it is without reading a
sentence?

## Out of scope

- The pictures and the slot, card, burst and banner themselves (spec 063). Talents (spec 064).
- New upgrades, prices or rules. Renaming the shop. The map and the tally.

## Paths

- `game/ui/windows/` (the shop's files only), `game/ui/` (additions to shared classes only)
- `game/main.gd`, `game/dev/showcase.gd`, `game/hud/` (help text)
- `sim/defs/upgrade_def.gd`, `data/upgrades/` (the `gives` hint only)
- `tests/`
- `docs/architecture.md`, `docs/style-bible.md`, `docs/wiki/index.html`

## Open questions

None.
