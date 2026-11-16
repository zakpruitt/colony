# Project Colony — plan.md

Code name: **Project Colony**. A 2D idle/AFK game built in Godot, developed agentically with Claude Code. It is a desktop app you leave running and tab away from while you do other things.

## Vision

An ant-colony-style idle RPG. A party of heroes lives in an infinite, procedurally generated labyrinth. They explore, fight monsters, loot and rest **on their own**. The player is the manager: recruit, gear, spec and point the party in a direction, then leave them to farm. Check-ins are short and rewarding: spend XP on talents, spend gold at the shop, adjust the party, tab out again.

Design pillars:

- **Built to be left running.** Leaving the game alone is how it's meant to be played, not something it punishes. Progress never goes backwards.
- **The skill is in building the party, not in fast reactions.** The challenge is making a party that can survive on its own.
- **Flavour over power.** Rarity and exclusivity give you stories and something to show off, not a must-have meta.
- **A rich, lively little world.** Simple sprites but a lot of character in the art, items and effects.

## Art direction

- 2D pixel art, side-on view, inspired by Noita.
- Simple, readable character sprites; the extra effort goes into items, spell and hit effects, particles and juice.
- No full per-pixel physics simulation.
- Assets should be easy for an agent to make: sprite sheets, tilemaps and palettes that can be generated or changed in code where possible.

## Core loop (v1)

1. The party moves through the labyrinth on its own, fighting whatever it meets.
2. Kills give XP, gold and item drops.
3. When resources run low, the party rests on a cycle and then carries on.
4. The player checks in: spends XP on per-character talents, buys or equips gear, changes the party setup and picks a target depth.
5. Repeat for as long as you like.

## Death and the "last stable depth" rule

- No permadeath. A wipe never wipes out progress.
- The game tracks the **last stable depth**: the deepest area where the party survived for a set time (start with about 10 minutes, and make it tunable).
- On a wipe, the party revives and falls back to the last stable depth, then carries on farming there automatically.
- A wipe costs efficiency, not progress. The player's goal is to build a party that can farm deeper indefinitely.

## Party and classes

- Heroes are recruited with a set class, then specialised through talents.
- v1 classes: a small classic set, for example Tank, Healer, Melee DPS and Ranged/Caster DPS.
- Party balance matters: a party with no healer should struggle at depth.
- Item drops are randomised from the start, with standardised base types and random rolls.
- Later: rare recruitable classes (for example a Witch Doctor) found by chance. These are flavourful and different, **never** best-in-slot or required.

## The labyrinth

- Infinite procedural generation that keeps generating as the party explores.
- Difficulty scales with depth. Tiers are loose for now and will be tuned through play.
- The player sets a target depth or direction; the party decides how to get there.

## Technical requirements (from day one)

- **The simulation keeps running when the window is unfocused or minimised.** Use a fixed-step simulation tick that doesn't depend on rendering, and lower the rendering cost when the window is in the background.
- **Offline catch-up**: if the machine sleeps or the game is closed, work out the time missed when it comes back and simulate or estimate the progress made.
- Separate the simulation from the visuals so the game logic can run headless and be tested.
- Save the game automatically and often. Saves must be safe against crashes.
- Use a data-driven design: classes, talents, items and monsters are defined in data files, so agents can add content without touching engine code.
- Use deterministic seeds for generating the labyrinth, to make debugging easier.

## v1 scope (in)

- One labyrinth with endless procedural depth.
- A small party (1 to 4 heroes) with the classic classes.
- Autonomous movement, targeting and combat AI.
- Rest cycles.
- XP, levels and a simple talent tree per class.
- Gold, randomised loot and a basic shop.
- Death fallback using the last stable depth rule.
- Background ticking and offline catch-up.
- Pixel-art sprites, effects and a clean management UI.

## Later phases (out of v1)

- **Phase 2: Home base.** A camp the party returns to for resting, trading and upgrades.
- **Phase 3: Recruiting and rarity.** Rare classes and special encounters.
- **Phase 4: Economy automation.** Heroes buy, sell and gather resources on their own, with Factorio-style logistics. Each hero picks one WoW-style profession (for example herbalism, mining or alchemy) that feeds the economy.
- **Phase 5: Social.** Compare progress with friends (leaderboards or shared stats).
- Extra support for when the window is minimised, such as notifications or a summary of what happened while you were away.

## Agentic workflow notes

- Build in small, testable milestones; every milestone should run and be playable. Scaffold the project for agents from day one: a clear folder layout (data, assets, sim, UI), CLAUDE.md with the project rules, command-line scripts for build, test, asset lint and running the simulation headless, so every agent loop (generate, check, fix) has a command to call.
- Add headless simulation tests (for example "a party at depth X survives N minutes") so agents can check balance changes.
- Create skills or docs for: adding a class, adding an item, adding a monster, and generating sprites.

## Asset pipeline and style consistency

Every asset must look like it belongs to the same game. "On style" is enforced by rules and automated checks, not left to taste.

**Style bible (locked before any production assets):**

- One fixed colour palette (one small master palette, for example 32 colours). Every asset uses only these colours.
- Fixed sprite sizes per category (for example heroes 32×32, small monsters 24×24, bosses 64×64, items 16×16).
- Outline rules (colour, thickness, inside or outside), one light direction, shading style.
- Animation standards: frame counts and timing per action (idle, walk, attack, hit, death), and a consistent pivot point and baseline.
- A reference sheet of approved sprites that grows as assets are approved.

**Creation workflow:**

1. **Brief.** Zak provides a concept (AI concept art or a description). This is a brief, not something to trace.
2. **Generate.** Use a dedicated pixel-art generator that outputs true pixel grids and accepts a style reference (for example PixelLab or Retro Diffusion), locked to the reference sheet. For simple or tiny sprites, the agent can draw them directly in code from a pixel grid. Budget: an existing paid tool at roughly $10–20 is fine for now; a custom generation flow can come later.
3. **Normalise.** A script snaps the image to the grid, forces it onto the palette, fixes the size and pivot, and applies the outline rule.
4. **Lint (automated, blocking).** Reject any asset with off-palette colours, the wrong size, a missing outline, or stray semi-transparent pixels.
5. **Agent style review.** The agent compares the new asset next to the reference sheet and flags anything that doesn't match.
6. **Human approval.** Zak signs off on new assets. Approved assets join the reference sheet.
7. **Implement.** Import into Godot from data definitions, not hand-wired scenes.

**Animation approach:**

- Default: part-based animation. Sprites are split into parts (head, body, arms, weapon), and Godot animates them in code: bob, swing, squash and stretch, recoil, flashes. This is agent-friendly and stays on style automatically.
- Hand-drawn or generated frame-by-frame animation only for signature moments (special attacks, rare classes, bosses), and it goes through the same lint and review.
- Effects (hits, spells, particles) use the same palette and are built in code wherever possible.

**Agent workflow requirements:**

- Skills or docs for: creating a sprite, animating a sprite, adding an enemy end to end, adding an item, and running the asset lint.
- The asset lint runs in CI or a pre-commit hook, so off-style assets can't land.
- Every asset records its source (prompt, generator, settings) so it can be regenerated consistently.

## Skills, agents and the self-improving loop

Most of this project is repeatable work, so skills and specialised agents are made from the start, not added later.

**Starter skills (each one a step-by-step procedure with the commands to run and checks to pass):**

- create-sprite, animate-sprite, add-enemy (end to end), add-item, add-class, add-talent, run-asset-lint, run-balance-sim.

**Specialised agents (subagents):**

| Agent | Job | Must pass before done |
| --- | --- | --- |
| Asset builder | Brief → generate → normalise → lint → implement | Asset lint + style review |
| Style reviewer | Compares new assets with the reference sheet | Writes approve or reject with reasons |
| Content designer | Writes class, item, monster and talent data | Data schema validation |
| Balance tester | Runs headless simulations at different depths | Survival and income targets |
| Code reviewer | Reviews gameplay and engine changes | Tests + project rules |

**The self-improving loop:**

1. Every task runs through its skill: do the work, run the checks, fix, and repeat until they pass.
2. When a task hits a new problem or finds a better way, the agent writes the lesson back into the skill (or CLAUDE.md) before finishing.
3. Repeated manual steps become new skills or scripts.
4. Zak reviews skill changes like code changes, so the harness gets better with every task instead of making the same mistakes again.

## Suggested v1 milestones

1. Milestone 0 first: style bible, palette, reference sheet, asset lint and the creation skills. Then the Godot project skeleton, a simulation tick that runs in the background, and the save system.
2. Procedural labyrinth generation and rendering.
3. One hero with autonomous movement and combat against basic monsters.
4. XP, gold, loot and the death fallback rule.
5. A full party with four classes, talents, and the shop UI.
6. Offline catch-up, then polish: effects, juice and balancing.
