# Specs

Colony is built from specs. A spec says what a piece of the game must do and how we will know it does; an
implementer lane builds exactly that.

## Board

| # | Spec | Milestone | Status | Depends on |
|---|---|---|---|---|
| — | Harness bootstrap (not a spec: built by the lead), [#1](https://github.com/zakpruitt/colony/pull/1) | M0 | landed | — |
| 001 | [Simulation clock and background ticking](001-sim-clock/spec.md) | M0 | in-progress | — |

### Planned for the 2026-11-16 overnight run

Written and spawned by the lead as each wave's dependencies land; numbers and scope may shift.

| Wave | Spec | Depends on |
|---|---|---|
| A | 002 Art foundation: master palette, code-drawn sprites, palette lint, first style bible | — |
| A | 003 Labyrinth generation: endless seeded chambers and tunnels by depth (sim) | — |
| A | 004 Combat core: heroes, monsters, stats, fights in a chamber, sim events (sim + data) | 001 |
| B | 005 Expedition loop: travel, encounters by depth, XP, gold, rest, wipe and fallback (sim) | 003, 004 |
| B | 006 Labyrinth view: draw the cross-section, camera, light | 002, 003 |
| B | 007 Entity view: hero and monster sprites, part-based animation | 002, 004 |
| C | 008 Combat effects: hit flashes, damage numbers, particles, shake, death bursts, loot pickups | 007 |
| C | 009 HUD: party frames, XP, gold, depth | 005 |
| C | 010 Ambient life: torches, dust, glow, background detail | 006 |
| D | Balance and polish passes, then saves if the night allows | all |

Milestones follow `docs/design/plan.md`: **M0** harness, style bible, skeleton, background tick, saves ·
**M1** labyrinth · **M2** one hero, movement and combat · **M3** XP, gold, loot, death fallback ·
**M4** full party, talents, shop · **M5** offline catch-up and polish. Each ends with Zak's playtest.

## Who does what

| Who | Does | Never does |
|---|---|---|
| Zak | Design, approves specs, approves art, playtests milestones | |
| Lead session | Writes specs with Zak, owns architecture and interfaces, spawns lanes, final review, merges | Implements a feature spec itself |
| Implementer lane (Opus 5.5) | Builds one approved spec in its own worktree, opens the pull request | Edits the spec, leaves its Paths, merges |
| Reviewer (fresh agent) | Compares the spec with the diff | Reads the implementer's account of the work |

## Life of a spec

1. **Draft.** The lead and Zak write `specs/NNN-slug/spec.md` from `TEMPLATE.md` (`write-spec` skill).
2. **Approve.** Zak approves; the lead sets the status and commits it to `dev`.
3. **Interfaces first.** If other lanes will depend on what this spec adds, the lead lands the signatures as
   stubs before spawning anyone.
4. **Build.** The lead spawns an `implementer` agent in a worktree with the spec path. It works on branch
   `spec/NNN-slug` (`implement-spec` skill) until `python tools/dev.py check` passes, then opens a pull request.
5. **Review.** CI runs the same check. A `reviewer` agent reads the spec and the diff. The lane fixes findings.
6. **Land.** The lead reads it last, squash-merges into `dev` when CI is green (one feature, one commit), and
   marks the spec `landed` (`land-lane`).
7. **Promote.** After a playtest Zak promotes `dev` to `main`. Nothing else merges to `main`.

At most three agents run at once.

Two specs in progress at once never list the same path.

## When a spec is wrong

The lane stops and reports the question. A change to behaviour goes back to Zak; a clarification the lead can
make alone is committed to the spec on `dev` and the lane rebases.

## Autonomous mode

Only when no approved spec is waiting **and** Zak has said to keep working. In this order:

1. **Standing-approved work**, landed as usual: bugs against landed specs, missing tests for landed
   requirements, flaky or slow checks, docs that have drifted from the code.
2. **Drafting** the next specs from the milestone list, ready for Zak to read.
3. **Provisional specs.** The lead marks its own draft `provisional` and runs it through a lane. If Zak has
   authorised the run to land work (see below), it is squash-merged into `dev` once verified; otherwise the pull
   request waits for him. Zak reviews the specs and the running result together when he is back.

Never without Zak: anything reaching `main`, changing a design pillar, final approval of art, passing a
milestone, spending money on outside tools.

### Authorised runs

- **2026-11-16, overnight.** Zak approved 001 and asked the lead to design and build the base game on its own:
  look, feel and effects first, the endless dungeon, and a party killing monsters for XP and gold. The lead
  writes the specs, one Opus lane per spec, at most three at a time, each verified and squash-merged into `dev`
  through a pull request. Art made in this run is first-pass and code-drawn, for Zak to react to.
