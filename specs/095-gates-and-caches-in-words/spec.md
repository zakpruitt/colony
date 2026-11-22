# 095 — Gates and caches in words

- **Status:** in-progress (provisional)
- **Milestone:** M9 (the dungeon overhaul)
- **Depends on:** 093
- **Pull request:** —

## Intent

The party now opens gates and caches (spec 093) and the world shows it (spec 094), but a player who was
tabbed away, as the game means them to be, learns nothing of it: the journal, the ticker, the tally and the
away report do not know side paths exist. This spec tells it in words, so that coming back to the game says
what the detours brought home and which gates still wait for a skill the party lacks.

## Requirements

- **R1. The journal and the ticker tell of gates and caches.** A gate opened: `<Hero> <did it>` by the
  gate (`The Rogue picked a lock`, `The Knight cleared the rubble`, `The Mage read a rune seal`,
  `The Rogue found a hidden crack`). A cache opened: one line with what it paid, `Cache: +120 gold, +9
  clay, 40 XP each`. A gate nobody could open: `A rune seal: needs a Runereader`, once for each
  `GATE_SEALED`. Each line names its area and stage where its neighbours do.
- **R2. The tally counts them.** The tally window counts, for the session and by area as it counts what it
  counts today: gates opened, caches opened, and the gold, the resource and the XP that came from caches.
- **R3. The away report tells of them.** Time away counts caches opened and what they paid in the report's
  own totals, with a row `Caches opened: N` when N is above 0, and a row naming the kind of gate passed
  most often for want of a skill (`Passed 6 rune seals: needs a Runereader`) when there was one.
- **R4. A goal points at a gate the party cannot open.** When the party has passed a gate for want of a
  skill on the stage it is on, and a hero of the party will learn that skill, the microskill goal names
  it: `Mage learns Runereader at level 4: opens rune seals`. It is the same goal row the goals show
  today, not a new one.
- **R5. The status says what the halt is.** While a gate is worked the status line reads by the gate
  (`Picking a lock`, `Clearing rubble`, `Reading a rune seal`, `Searching a crack`) where it reads
  `Working` today, and on a side path otherwise `Exploring a side path`.
- **R6. The words come from the data.** Every gate's and microskill's name in these lines is its
  definition's `display_name`; a gate added as data later needs only its sentence in one table.
- **R7. Nothing is worded on a frame.** These lines are made when their event arrives, and an idle screen
  words nothing new (spec 075's idle test passes untouched).

## Interfaces

None that other work relies on. The table of each gate's sentence lives with the journal's other words.

## Acceptance

In `tests/acceptance/test_095_gates_and_caches_in_words.gd` (extends `ColonyTest`):

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_the_journal_tells_each_gate_and_cache` | the four gate lines, the cache line's three amounts equal to the events', the sealed line once; the ticker shows the newest |
| R2 | `test_r2_the_tally_counts_side_paths` | counts and sums after three caches in two areas equal the events' |
| R3 | `test_r3_the_away_report_tells_of_caches_and_sealed_gates` | an hour away with a party that opens some and passes others: both rows, and neither with a party that meets none |
| R4 | `test_r4_the_goal_names_the_gate_a_skill_would_open` | the row's words after a sealed gate; unchanged with no such gate; unchanged when no hero learns it |
| R5 | `test_r5_the_status_names_the_gate` | the status through a whole side trip for two kinds of gate |
| R6 | `test_r6_a_new_gate_needs_only_its_line` | a gate definition added in the test is told with its own name |

R7 is spec 075's test.

## Out of scope

- Anything under `game/world/`, `game/effects/`, `game/audio/`, `game/dev/`, `assets/`: spec 094.
- Anything in `sim/` or `data/`. A new window, a new frame piece, a map of the stage.

## Paths

- `game/hud/` (the journal, the tally, the goals), `game/ui/` (the tally window, the away window's story),
  `game/save/` (the away replay and report)
- `tests/acceptance/test_095_gates_and_caches_in_words.gd` (new), `tests/support/`
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None. (093 landed as #93: `SidePath` has `at`, `course`, `gate_at`, `room`, `tunnel`, `ladder`; `Expedition.side_path`; `SidePathRules.is_full` and `opener`; the events `GATE_STARTED`, `GATE_OPENED`, `GATE_SEALED`, `CACHE_OPENED` as its Interfaces give them.)
