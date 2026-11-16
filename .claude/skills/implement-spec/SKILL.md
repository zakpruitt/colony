---
name: implement-spec
description: The procedure an implementer lane follows to build one approved Colony spec, from reading it to opening the pull request. Use when you have been given a spec path (specs/NNN-slug/spec.md) to implement, or when resuming a lane after review findings.
---

# Implementing a spec

You are in your own git worktree. Other lanes are working in theirs at the same time.

## 1. Set up

1. Read `CLAUDE.md`, `docs/architecture.md`, then the spec, start to finish.
2. Check the spec's status is `approved` or `provisional`. If it is `draft`, stop and report.
3. `git switch -c spec/NNN-slug` from the current `main` (a `provisional` spec that depends on another
   provisional one branches from that spec's branch; the lead will say so).
4. `python tools/dev.py import`: a new worktree has no import cache, and nothing runs without one.
5. `python tools/dev.py check` should pass before you change anything. If it does not, report that instead of
   building on it.

## 2. Read the spec as a contract

- List the requirements. For each, find its row in **Acceptance**.
- Read **Interfaces**: those signatures are exact. Other lanes are coding against them.
- Read **Out of scope** and **Paths**. Work outside either is not yours, however close it looks.
- If two parts disagree, a requirement cannot be tested as written, or the work cannot fit inside Paths: stop
  and report the question, with what you found. Do not pick an interpretation and build on it.

## 3. Tests first

Write `tests/acceptance/test_NNN_slug.gd` with one test per requirement, named as the spec names it. Run
`python tools/dev.py test --only=test_NNN` and see each one fail for the right reason (the behaviour is
missing, not a typo). Then write the code. The `godot-headless-test` skill covers how to write these so they
prove something.

Add unit tests under `tests/unit/` for logic the acceptance tests only reach indirectly.

## 4. Build

- Rules go in `sim/`, drawing and input in `game/`, content in `data/`. `docs/architecture.md` says why.
- Type everything. A warning is a compile error here.
- Run `python tools/dev.py check --only=format,boundary,compile,tests` often; it takes seconds.
- Commit in logical steps with Conventional Commit messages (`feat(sim): …`), each one passing the check.
  Include the `.uid` file of every script you add. No attribution lines.

## 5. Finish

1. `python tools/dev.py format`, then the full `python tools/dev.py check`. It must end `check: PASS`.
2. Re-read the spec against your diff (`git diff main...HEAD`): every requirement met, nothing extra, nothing
   outside Paths.
3. If you learned something a future lane would trip over, add it to the relevant skill or `CLAUDE.md` as a
   separate `docs(harness): …` commit.
4. `git fetch origin && git rebase origin/main`, run the check again, then `git push -u origin spec/NNN-slug`.
5. Open the pull request with `gh pr create`. Title: `feat(<area>): <what the spec delivers>`. Body: a link to
   the spec, then a table of requirement → test, then anything the reviewer should know. For a `provisional`
   spec add `--draft --label provisional`.
6. Report to the lead: the pull request URL, the requirement → test table, the check's last line, open doubts.

## After review

The lead sends findings back. Fix what must change, push to the same branch, and answer each finding in your
report: fixed (which commit), or not changed and why.
