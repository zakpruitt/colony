# Base game: shape, look and feel

The lead's design for the first playable Colony, written for the 2026-11-16 overnight run. It turns
`plan.md` into concrete decisions the specs share. Everything here is first-pass and Zak's to change.

## The picture

An ant farm, seen from the side. The screen is a cross-section of dark earth with chambers and tunnels cut
through it. A small party of heroes walks the tunnels, fights what lives in each chamber, and climbs down
shafts to go deeper. You watch them the way you watch ants behind glass.

- **Resolution:** 640x360, scaled by whole numbers. One tile is 16 pixels, so the screen is 40 tiles wide and
  22.5 tall.
- **Sizes:** heroes 32x32, small monsters 24x24, large monsters 32x32, bosses 64x64, items and icons 16x16,
  tiles 16x16.
- **Palette:** one master palette of 32 colours (ENDESGA 32, a free palette, as the first pass). Every sprite,
  tile, effect and UI element uses only these colours.
- **Mood:** dark, warm earth; light comes from torches, spells and loot. Characters are simple and readable.
  The effort goes into what happens around them: hits, sparks, dust, glows, numbers, coins.

## The world

The labyrinth is endless downward. It is made of **levels**, one per depth, stacked like floors.

- A level is a horizontal band of earth 120 tiles wide and 16 tall, holding four to six **chambers** joined
  left to right by low **tunnels**. Every chamber on a level shares one flat floor; ceilings vary.
- One **shaft** leads down from each level to the next. Shafts alternate sides, so the party crosses most of
  a level to keep descending.
- A level's layout comes only from the seed and its depth. The same seed always gives the same labyrinth.
- Chambers have a kind: plain, a den (more monsters), or a vault (better rewards).

## The party

One to four heroes, each with a class. The first four:

| Class | Role | Fights by |
|---|---|---|
| Knight | Tank | Standing in front, high health and armour, modest damage |
| Rogue | Melee damage | Fast, hard hits, fragile |
| Mage | Ranged damage | Slow, heavy bolts from the back |
| Cleric | Healer | Healing whoever is most hurt; weak attack otherwise |

## A fight

Fights happen in a chamber, on its floor, as a line: heroes come in from one side, monsters hold the other.
Everyone picks a target, walks into range and attacks on a rhythm: a short wind-up, then the hit. Ranged
attacks and heals travel as projectiles. Monsters go for the nearest hero, which is why the Knight walks in
front. Nobody is controlled by the player.

## The loop

1. The party walks through the level, chamber by chamber.
2. Entering a chamber with monsters starts a fight. Winning gives XP and gold.
3. If the party is hurt after a fight, it rests where it stands until healed, then moves on.
4. At the shaft, the party descends if it is still above its target depth; at the target depth it turns round
   and farms the level, whose chambers refill over time.
5. If everyone dies, the party revives at the last stable depth (the deepest level it has survived on for ten
   minutes) and carries on from there. A wipe costs time, never progress.

## Feel

Every hit should be felt. The rules for effects:

- A hit shows three things at once: the target flashes white and recoils, a number pops out, and sparks fly.
- Big moments get more: a critical hit is larger, shakes the screen slightly and freezes the frame briefly.
- Death is a burst, never a fade: the monster pops into particles and its loot arcs out.
- Gold and XP are physical: coins bounce, then fly to the counter, which ticks up as each one lands.
- The world is never still: torches flicker, dust drifts, heroes breathe while idle.
- Everything animates in code from sprite parts (bob, swing, squash, recoil), so it stays on style.

## Code shape

The simulation (`sim/`) knows all of the above as numbers: levels as rectangles in tile coordinates, heroes
and monsters as positions along a floor, fights as ticks. It reports what happened as events. The game
(`game/`) draws the labyrinth from those rectangles, places sprites from those positions, and turns each
event into animation and effects. See `docs/architecture.md`.
