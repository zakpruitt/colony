# 057 — Lively moves: heroes that leap, spin and cast

- **Status:** provisional (direction from Zak 2026-11-18; text not yet read by him)
- **Milestone:** M6
- **Depends on:** 007, 008, 010, 048, 050, 051, 056

## Intent

Zak, after reading what the trees do: "I would really like there to be more animations and more movement
from the characters during their moves. I want them to feel really active and fun, jumping around (when
appropriate), or when casting spells having animations for them. Nothing too in depth, but we want to
strike a charming but interesting art style." Today every ability is the same small lunge with a name
over it. After this spec each ability has a move of its own that the body performs, spells are things you
can see fly and land, and ordinary fighting has more bounce. It stays cheap: a small set of moves made in
code from the parts the characters already have, no drawn frames.

## Requirements

- **R1. Every ability has a move.** Each of the 44 abilities names one move from a small set (about ten to
  fourteen), as data on the ability. The set must at least hold: a **leap** (jump in an arc and come down
  on the blow), a **spin** (the body turns round with the weapon out), a **dash** (a quick streak to the
  target and back), a **heavy swing** (a long draw back, a big follow-through), a **throw**, a **brace**
  (crouch behind the shield), a **shout** (rear back, puff up), a **cast** (staff or arm raised, the body
  lifts a little off the floor, then a thrust as it lands), a **channel** (arms up, held, for the big
  spells), a **prayer** (head bowed, then arms raised) and a **flourish** for a passive that fires (a
  short hop or flick that does not interrupt what the hero is doing). The data check fails on an ability
  with no move or an unknown one. Which ability gets which move is the lane's choice by what the
  ability's description says (Whirlwind spins, Meteor channels, Backstab dashes, Shield Bash leaps or
  swings heavy, Prayer prays); the pull request lists all 44.
- **R2. The body really moves.** A move is seen in the sprite itself: over its length the sprite's
  position, turn or its parts' angles leave their resting values by an amount a test can measure (a leap
  rises at least 8 pixels; a spin turns the body through a full turn or flips its facing and back; a dash
  travels at least 12 pixels; a cast lifts at least 3). Moves use squash and stretch (the body a little
  shorter and wider on landing, taller in the air) so they read as lively, not as sliding.
- **R3. A move keeps the fight true.** A move is view only. It starts on the ability's start event and its
  blow, spell or heal lands on screen on the tick the simulation says, whatever the move's length; the
  recovery after may run on, at most 0.4 s. When the move ends the sprite is exactly where the simulation
  has it, at rest. A move never leaves the chamber's floor band or the screen, and in a guardian fight
  spec 048's rule holds: no hero is drawn over the guardian's body at the end of a move, and a leap or
  dash comes down in front of its target, not on it.
- **R4. Spells are seen.** Each kind of spell effect has its own small visual, made of palette squares and
  the existing particles: a fireball that flies with a flame trail and bursts; a meteor that falls from
  above the screen onto its target; a shard of ice that flies straight and shatters; a frost burst that
  spreads along the floor; falling flakes over the enemies for a blizzard; a jagged spark that jumps from
  enemy to enemy; a column of light on whoever is healed or blessed by a prayer; a short beam or flash
  from above for a smite or holy fire; knives that fly out in a fan. Fire reads orange, frost pale blue,
  holy pale gold, shadow violet. Each is gone within a second of landing.
- **R5. Ordinary fighting has more bounce.** With no ability at all: a melee strike has a clear draw
  back, a step in and a settle; a ranged hero's shot has a small recoil; a hero who lands a killing blow
  or a crit does a small hop; when a fight is won each living hero does a short cheer (a hop or a raised
  weapon, not all at the same instant); a monster's strike gets the same draw back and step. None of this
  changes how long anything takes.
- **R6. Interrupted cleanly.** A stun, a death, the end of the fight, a wipe, a stage or area change in
  the middle of a move ends the move at once: the sprite is at its simulated place and pose in that same
  frame, with nothing left in the air and no spell visual left behind.
- **R7. True in a crowded frame.** A frame that holds many ticks (4x, a hitch, a whole fight) starts no
  moves for events already past, leaves every sprite at rest where the simulation has it, and leaves no
  spell visual. At 4x a move is shortened to fit, and still shows.
- **R8. Still readable.** In a fight with four heroes with full trees and five monsters, moves and spell
  visuals do not hide a hero's health frame or the boss bar for more than a moment, ability names (spec
  056) still show, and the particle limit of spec 010 holds.
- **R9. In the showcase and the cast demo.** The showcase's four class moments show each class's moves,
  and the cast demo (`character_demo.tscn`) plays every move in the set on one hero, labelled, in a loop.

## Interfaces

- `AbilityDef` (`sim/defs/ability_def.gd`) gains `@export var move: StringName`, checked by `validate()`
  against the set. It is a view hint: no rule reads it, the state hash does not include it, and the
  recorded-hash tests pass unchanged. The set of move names lives in one place the data check and the
  view both read.
- `game/entities/character_sprite.gd` (610 lines) gains one entry point to play a named move for a given
  length and to end it at once; the moves themselves go in a new file beside it
  (`game/entities/character_moves.gd`), so adding a move is adding one function or one table row there.
- Spell visuals go in a new file under `game/effects/` (`spell_effects.gd`), made and advanced by
  `CombatEffects` as `AbilityEffects` is; `combat_effects.gd` (969 lines) and `ability_effects.gd` gain
  only the few lines that call it. Anything that stays on screen follows CLAUDE.md's rule for
  `World.effects_layer`.
- No new sprite sheets for the moves. A spell visual may add small pieces (8x8 or less) from the master
  palette, following the style bible.

## Acceptance

In `tests/acceptance/test_057_lively_moves.gd`, one test per requirement named `test_rN_…`, each seen to
fail first. A reviewer will empty the drawing code and expect these to fail.

| Requirement | What the test shows |
|---|---|
| R1 | Every ability file names a move from the set; an ability with none fails `validate()` |
| R2 | For every move in the set, played on a real sprite frame by frame: the measured rise, turn, travel or lift, and that the body's scale leaves 1 and returns |
| R3 | In real fights for both paths of every tree: the blow's damage number appears on the simulation's tick; the sprite is at its simulated place and at rest when the move ends; no hero's rectangle overlaps the guardian's at a move's end |
| R4 | For each spell kind, begun by a real ability's events: its visual exists in flight, has its colour family, and is gone a second after landing |
| R5 | The draw back and step of an ordinary strike measured; the hop on a kill; the cheers after a won fight start on different frames; a fight's length in ticks is unchanged |
| R6 | A stun, a death, the fight's end, a wipe and a stage change each delivered mid-move: the same frame's pose and place, and no visual left |
| R7 | 300 ticks holding a whole fight before one frame; and a move at 4x measured |
| R8 | Rectangles measured frame by frame in the busy fight; the particle count |
| R9 | (`test_showcase`, and the demo's list holds every move) |

**To look at, and for Zak:** for each class, a sequence (`--count`) of its moment in the showcase and of
the cast demo, cropped and enlarged 3x, so each move's arc can be followed frame to frame. Describe every
sequence. Say which moves read best and which are weakest, and whether anything looks like sliding rather
than moving. Is it charming, and can you still tell what is going on?

## Out of scope

- Any rule or timing under `sim/` (only the `move` field and its check). New abilities. Monsters with
  abilities.
- Drawn animation frames, new character art, new sounds (existing ones may be reused).
- Moves for walking, resting or side quests.

## Paths

- `sim/defs/ability_def.gd`, `data/abilities/`
- `game/entities/`, `game/effects/`, `game/world/`, `game/dev/showcase.gd`
- `assets/` (small spell pieces only)
- `tests/acceptance/test_057_lively_moves.gd`, `tests/unit/`, older tests where a pose they assert
  changes (say which)
- `docs/style-bible.md`, `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None.
