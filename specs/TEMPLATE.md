# NNN — Title

- **Status:** draft
- **Milestone:** M0
- **Depends on:** none
- **Pull request:** —

Status is one of `draft`, `approved (YYYY-MM-DD)`, `provisional`, `in-progress`, `landed`.

## Intent

Two or three sentences. What does the player, or the next spec, get from this that they do not have today?

## Requirements

Each one is a behaviour someone could observe, not a way of building it.

- **R1.** …
- **R2.** …

## Interfaces

What this spec adds to or changes in the code other work relies on: classes, method signatures, events,
commands, resource fields. Signatures are exact; bodies are the lane's business.

```gdscript
```

## Acceptance

One test per requirement, in `tests/acceptance/test_NNN_slug.gd`, named for it.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_…` | … |

Anything that cannot be tested headless (how it looks or feels) is listed here for Zak's playtest instead.

## Out of scope

What the lane must not build, even if it seems close.

## Paths

The only files and folders the lane may create or change.

- `sim/…`
- `tests/acceptance/test_NNN_slug.gd`

## Open questions

Must be empty before approval.
