# The world: who the colony is

Decided with Zak on 2026-11-16, after he played the first draft. This note sets the premise that names,
content and later art are written against. It changes no code by itself.

## Premise

A colony of **little folk with pointy ears** lives at the mouth of an endless labyrinth and digs its home
deeper. The party is the colony's expedition. The world is high fantasy in the bright, chunky, good-humoured
way of World of Warcraft: swords, spells, loot and bosses, all familiar. What makes it Colony's own is that
everyone in it is small, and the party does more down there than fight.

- **Tone:** light. Not dark fantasy, not grim. A wipe is the party being chased home, not a tragedy.
- **Unique yet familiar:** classes are ones everybody knows (knight, rogue, mage, cleric, and later beast
  master, tinkerer, bard and so on), sometimes themed to their size: a beast master commands small animals,
  a knight's shield might be a bottle top. The theme is a seasoning, not a rule for every class.
- **The colony grows.** The camp at the surface is meant to become a warren-town that visibly grows with
  what the party brings back. (Not built; camp upgrades are its first seed.)

## What the party does

The party should feel alive and the world interesting even though the player is mostly away. That does not
mean simulating daily life. It means the party keeps meeting different challenges and answering them with
its members' skills, in ways the player can optimise for.

- **Fights stay the most common thing** a chamber holds.
- **Quests** are everything else: a locked chest, a tripwire, a stuck door, a rune stone, a hurt
  wanderer, and more later. They are small things the party comes across, not gathering.
- **Microskills open them.** A microskill is a minor passive a hero has (Lockpicker, Trapspotter, Strongarm,
  Runereader, Mender). If someone in the party has the one a quest asks for, the party can do it;
  if nobody does, the party walks past, or the hazard catches them. Heroes pick microskills up as they level.
- **Professions are a different thing** (crafting or gathering trades), not designed yet. Microskills are
  not professions.
- **The player tunes the party.** Which microskills the party has decides which quests pay off.

## Ease first

Zak's priority after the first playtest: the game must be easy to read and easy to manage. At a glance the
player should know what the party is doing and why, and each hero should have a clear place to be looked at,
upgraded and managed.

## What this means for work in progress

- **Art is placeholder.** Zak will make characters himself and the world's look will be agreed with him. New
  specs reuse existing sprites or add the plainest prop, and say so.
- **Names move toward the premise** as specs touch them; nothing is renamed for its own sake.
- **Order:** readability and a sheet for each hero; quests and microskills with the four existing
  heroes; per-hero upgrades; then choosing who goes down (a roster); then new classes, starting with the one
  Zak wants to draw.

## Areas and skill trees (decided with Zak on 2026-11-17, after he played the demo)

Zak's words: the game should not feel like "you just are ever-going down", there should be "difference and
intentionality of where you go to farm and spelunk", and every hero should have a "very interesting yet
simple" skill tree.

### Areas, not one descent

- **A map of areas.** The labyrinth is several areas (Mossy Hollow, the Claypits, the Old Crypt, Ember
  Deep, more later). Each has its own monsters, its own guardian and its own resource.
- **Stages.** An area is a run of stages that get harder. Going from one stage to the next is walking on
  into a new zone, not climbing down. The player picks the area and how far in the party farms.
- **Opening areas.** Beating an area's guardian opens the next area. Earlier areas stay worth visiting for
  their resource.
- **Resources pay for the camp.** Camp upgrades cost gold and a resource from one area, so what the player
  wants to build decides where the party goes. Gear and professions are later ideas, not designed.

### Skill trees

- **Every node is something the hero does.** A new action, or a passive with a visible effect. Never a
  plain damage or health increase.
- **Three skill paths of five (spec 109).** Each class has three named paths (a knight's are Guardian,
  Berserker and Warlord), each a small tree of five nodes in four tiers: one node, two side by side, one,
  then a capstone. A node opens once a node above it in its path is taken. Nothing locks: a hero may
  learn from every path and, in time, holds all fifteen nodes. Its title names the path it holds most of.
- **Points come from levels.** One talent point at every even level up to 30: fifteen, the whole tree.
- **Paragon after that.** From level 31 each level gives a paragon point to put in Power, Quickness or
  Toughness. Plain stat gains live only there. Gold training (spec 029) is removed.
- **Ranks by use (spec 110).** A path will grow stronger the more its abilities are used, through path
  ranks that gate its deeper tiers.

## The UI and how fights move (decided with Zak on 2026-11-18)

Zak asked for two things after reading what the trees do.

- **Livelier fights.** "More animations and more movement from the characters during their moves ...
  jumping around (when appropriate), or when casting spells having animations for them. Nothing too in
  depth, but we want to strike a charming but interesting art style." Spec 057: a move for every
  ability, made in code, and a visual for every kind of spell.
- **A UI overhaul.** "The font is hard to read, although thematic ... and I want the UI to be sort of
  like WoW where you can have multiple screens open individually at once and compare or put side by side
  or layer ... getting the UI to be friendly and nice will be paramount." He chose three things: the UI
  is drawn on a layer sharper than the 640x360 world; the font is a clean pixel font made for reading,
  not a smooth one; windows can be moved, layered and remember their places, without resizing or locking
  in the first version. Specs 058 to 061.
