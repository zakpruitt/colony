---
name: land-lane
description: For the lead session - spawn an implementer lane for an approved Colony spec, review its pull request, merge it and update the board. Use when a spec has just been approved, when a lane reports back, when CI or the reviewer has findings, or when deciding whether a pull request can merge.
---

# Running a lane, from spawn to landed

## Spawn

1. The spec is `approved` (or `provisional`, in autonomous mode) on `dev`, and `dev` is pushed.
2. No spec `in-progress` shares a path with it. If lanes will meet at an interface, land its stub first.
3. Set the spec `in-progress` on the board and commit.
4. Spawn the `implementer` agent with `isolation: worktree`. Never more than three agents running at once. The brief is the spec path and, for a provisional
   spec that depends on another, the branch to start from. Do not restate the requirements: the spec is the
   brief, and a paraphrase is a second, conflicting one. Independent specs spawn together in one message.

## When the lane reports

1. Read the report, then verify it rather than trust it: `gh pr checks <n>` for CI, `gh pr diff <n>` for what
   actually changed.
2. Spawn the `reviewer` agent with the spec path and the pull request number only.
3. Send must-fix findings back to the same lane (SendMessage, so it keeps its context). Repeat until the
   reviewer has none and CI is green.
4. Read the diff yourself last. You are checking what neither of them is placed to see: does this fit where the
   next specs are going, and is the interface one you want to keep?

## Merge

- Approved spec, CI green, no must-fix findings: `gh pr merge <n> --squash --delete-branch` into `dev`. One
  feature is one squashed commit.
- Provisional spec: merge to `dev` the same way only while Zak has authorised an autonomous run (see
  `specs/README.md`); otherwise leave the pull request open for him. Never merge anything to `main`: Zak
  promotes `dev` after a playtest.
- After merging: set the spec `landed` with the pull request link, update the board, commit to `dev`. If the
  lane's pull request changed a skill or `CLAUDE.md`, mention it to Zak: harness changes are his to see.

## When it goes wrong

- **The lane asks a spec question.** `write-spec` skill, "When a lane says the spec is wrong".
- **CI fails but the lane's local check passed.** The difference is the bug: Linux against Windows (path case,
  line endings), or something untracked on the lane's disk. Fix the cause, never the check.
- **Two pull requests conflict.** The Paths lists overlapped, which is a spec mistake. Land one, have the other
  lane rebase, and fix whichever spec was wrong.
- **A lane is stuck or going in circles.** Stop it, read what it did, and decide whether the spec, the harness
  or the brief was at fault before spawning another.
