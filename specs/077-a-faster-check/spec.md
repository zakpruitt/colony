# 077 — A faster check that holds the standards

- **Status:** landed (provisional)
- **Milestone:** M8 (cleanup)
- **Depends on:** 071
- **Pull request:** [#77](https://github.com/zakpruitt/colony/pull/77)

## Intent

The full check takes fifteen to twenty minutes in CI and every change waits on it twice; and several of
the project's standards are held only by a reviewer noticing. This spec splits the tests across parallel
jobs, takes needless Godot starts out of the check, and makes the `harness` step enforce the standards a
text scan can enforce, so the next specs are quicker to land and harder to get wrong.

## Requirements

- **R1. Tests run in shards.** `python tools/dev.py test --shard=I/N` runs the I-th of N parts of the test
  scripts. Every test script is in exactly one shard for a given N, the split is the same on every machine,
  and `--shard` works together with `--only`. Without `--shard` everything runs as today.
- **R2. CI runs the shards side by side.** The `Check` workflow runs the tests as four parallel jobs and
  the other steps as a fifth; a pull request is green only when all five are. Each job prints its test
  count. A push that only edits `specs/` still runs nothing.
- **R3. The project is imported once per check.** One `check` run imports the project once, however many
  steps need it, and a step run alone still imports for itself.
- **R4. The `art` step starts no Godot.** The tool tests that run `dev.py sim` (in `test_sim_command.py`,
  `test_016_…`, `test_036_…`, `test_049_…`, `test_051_…`) and the two that take shots move to a step of
  their own, `tools`, placed after `compile`. `art` keeps the sprite, font and sound tests and lints.
- **R5. `harness` holds the comment rule.** It fails on a comment in `sim/`, `game/`, `tools/` or
  `tests/colony_test.gd` that names a spec or requirement number or tells history (the phrases the two
  existing GUT tests look for), joining wrapped comment lines first. Those two GUT tests
  (`test_069`'s `test_r2_…` and `test_070`'s `test_r3_…`) are deleted: one check, in one place. Today's
  tree passes.
- **R6. `harness` holds the attribution rule.** It fails when a commit in `origin/dev..HEAD` has a
  `Co-Authored-By` line, a "Generated with" line or a `claude.ai/code/session` link, naming the commit.
  With no `origin/dev` to compare with (a shallow CI checkout), it checks `HEAD` alone.
- **R7. `harness` warns before a lint cap bites.** It prints, without failing, every `.gd` file within 15
  lines of gdlint's 1000 and every class within one of its 20 public methods.
- **R8. The check says what it ran on.** `check` and `test` print the commit's short hash and whether the
  tree has uncommitted changes before the first step.
- **R9. The harness is true to it.** `CLAUDE.md`'s command table and step list, `docs/standards.md`, the
  `implement-spec` and `godot-headless-test` skills and the wiki's stated durations match.

## Interfaces

```
python tools/dev.py test [--only=<part>] [--shard=I/N]
python tools/dev.py check [--only=<steps>]      # steps: format, boundary, harness, art, compile, tools, tests, data, boot
```

How scripts are dealt into shards is the lane's choice (by name is enough; a tracked list of slow scripts
to spread them is allowed). Report the four shards' times from CI.

## Acceptance

In `tools/tests/test_077_a_faster_check.py`:

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_every_script_is_in_one_shard` | for N of 1, 3 and 4 the shards' scripts are disjoint and together are every `test_*.gd` |
| R1 | `test_r1_a_bad_shard_is_refused` | `0/4`, `5/4` and `x` exit non-zero with a message |
| R3 | `test_r3_a_check_imports_once` | counts the import calls of a `check` run with Godot's runner stubbed out |
| R4 | `test_r4_art_starts_no_godot` | the `art` step, run with the Godot runner stubbed to fail, passes |
| R5 | `test_r5_a_spec_number_in_a_comment_fails` | a temp tree with `# as spec 12 says`, one wrapped over two lines, and `# since the old way`; and a clean one that passes |
| R6 | `test_r6_an_attribution_line_fails` | a temp repository with one clean commit and one carrying each forbidden line |
| R7 | `test_r7_a_file_near_the_cap_is_named` | a 990-line file is named in the output and the step still passes |

R2 is shown by the pull request's own five green jobs; R8 and R9 by the reviewer.

## Out of scope

- Making any test faster or changing what it asserts (a later spec). Caching `.godot/` between CI runs.
- Any change under `sim/`, `game/` or `tests/` other than deleting the two lint tests named in R5.

## Paths

- `tools/` (not `tools/art.py` or `tools/sfx.py`), `.github/workflows/check.yml`
- `tests/acceptance/test_069_sim_tidy.gd`, `tests/acceptance/test_070_game_tidy.gd` (R5's two deletions)
- `CLAUDE.md`, `docs/standards.md`, `docs/wiki/index.html`, `.claude/skills/`

## Open questions

