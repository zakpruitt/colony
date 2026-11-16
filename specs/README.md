# Specs

Colony is built from specs. A spec says what a piece of the game must do and how we will know it does; an
implementer lane builds exactly that.

## Board

| # | Spec | Milestone | Status | Depends on |
|---|---|---|---|---|
| — | Harness bootstrap (not a spec: built by the lead), [#1](https://github.com/zakpruitt/colony/pull/1) | M0 | landed | — |
| 001 | [Simulation clock and background ticking](001-sim-clock/spec.md) | M0 | draft | — |

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
2. **Approve.** Zak approves; the lead sets the status and commits it to `main`.
3. **Interfaces first.** If other lanes will depend on what this spec adds, the lead lands the signatures as
   stubs before spawning anyone.
4. **Build.** The lead spawns an `implementer` agent in a worktree with the spec path. It works on branch
   `spec/NNN-slug` (`implement-spec` skill) until `python tools/dev.py check` passes, then opens a pull request.
5. **Review.** CI runs the same check. A `reviewer` agent reads the spec and the diff. The lane fixes findings.
6. **Land.** The lead reads it last, squash-merges when CI is green, and marks the spec `landed` (`land-lane`).

Two specs in progress at once never list the same path.

## When a spec is wrong

The lane stops and reports the question. A change to behaviour goes back to Zak; a clarification the lead can
make alone is committed to the spec on `main` and the lane rebases.

## Autonomous mode

Only when no approved spec is waiting **and** Zak has said to keep working. In this order:

1. **Standing-approved work**, landed as usual: bugs against landed specs, missing tests for landed
   requirements, flaky or slow checks, docs that have drifted from the code.
2. **Drafting** the next specs from the milestone list, ready for Zak to read.
3. **Provisional specs.** The lead marks its own draft `provisional` and runs it through a lane, but the pull
   request is a draft labelled `provisional` and is not merged until Zak approves the spec. Work that depends
   on it stacks on its branch. Zak reviews the spec and the running result together.

Never without Zak: merging provisional work, changing a design pillar, approving art, passing a milestone.
