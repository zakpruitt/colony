---
name: implement-spec
description: The procedure an implementer lane follows to build one approved Colony spec, from reading it to opening the pull request. Use when you have been given a spec path (specs/NNN-slug/spec.md) to implement, or when resuming a lane after review findings.
---

# Implementing a spec

You are in your own git worktree. Other lanes are working in theirs at the same time.

## 1. Set up

1. Read `CLAUDE.md`, `docs/architecture.md`, then the spec, start to finish.
2. Check the spec's status is `approved` or `provisional`. If it is `draft`, stop and report.
3. `git fetch origin && git switch -c spec/NNN-slug origin/dev`. All spec work branches from `dev` and is
   merged back into `dev`; `main` only moves when Zak promotes a playtested `dev`.
4. `python tools/dev.py import`: a new worktree has no import cache, and nothing runs without one.
   If the spec changes how the game looks, also read "Looking at the game" in `CLAUDE.md`.
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

A test that names a class which does not exist yet fails with a parse error, not for the right reason. First
write each **Interfaces** file as a stub (the exact signatures, bodies that return `0`, `""` or do nothing),
run `python tools/dev.py import` so Godot sees the new `class_name`s, then run the tests: they now fail on
their assertions.

Add unit tests under `tests/unit/` for logic the acceptance tests only reach indirectly.

## 4. Build

- Rules go in `sim/`, drawing and input in `game/`, content in `data/`. `docs/architecture.md` says why.
- Type everything. A warning is a compile error here.
- Run `python tools/dev.py check --only=format,boundary,compile,tests` often; it takes seconds.
- `gdlint` allows 100 characters per line. A doc comment copied word for word from the spec's **Interfaces**
  can be longer; rewrap it (the signatures stay exact, the comment's line breaks do not matter).
- Generating many files (abilities, trees) or editing with a Python script is fine, but on Windows Python
  writes CRLF unless you open the file with `newline='\n'`; do so, or the diff turns every line.
- Removing a feature other specs built on (spec 051 removed gold training) breaks tests far from your
  code: run the whole suite early, not just your own test, and list each amended test in the pull request.
- Commit in logical steps with Conventional Commit messages (`feat(sim): …`), each one passing the check.
  Include the `.uid` file of every script you add. No attribution lines.

## 5. Finish

1. `python tools/dev.py format`, then the full `python tools/dev.py check`. It must end `check: PASS`.
2. Re-read the spec against your diff (`git diff origin/dev...HEAD`): every requirement met, nothing extra, nothing
   outside Paths.
3. If you learned something a future lane would trip over, add it to the relevant skill or `CLAUDE.md` as a
   separate `docs(harness): …` commit.
4. `git fetch origin && git rebase origin/dev`, run the check again, then `git push -u origin spec/NNN-slug`.
5. Open the pull request with `gh pr create --base dev`. Title: `feat(<area>): <what the spec delivers>` (it
   becomes the one squashed commit for the feature). Body: a link to the spec, then a table of requirement →
   test, then anything the reviewer should know. No attribution lines.
6. Report to the lead: the pull request URL, the requirement → test table, the check's last line, open doubts.

## After review

The lead sends findings back. Fix what must change, push to the same branch, and answer each finding in your
report: fixed (which commit), or not changed and why.
