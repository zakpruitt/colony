# 108 — "QUEST!" over whoever can do it

- **Status:** landed
- **Milestone:** M0
- **Depends on:** 076, 104, 107
- **Pull request:** [#108](https://github.com/zakpruitt/colony/pull/108)

Status is one of `draft`, `approved (YYYY-MM-DD)`, `provisional`, `in-progress`, `landed`.

## Intent

When the party reaches a quest it can do, the heroes who can do it say so. A quick orange "QUEST!" pops up over each of their heads, the way a game marks someone with something to do. The player sees at once that a quest was found and who will take it.

## Requirements

- **R1. "QUEST!" pops over every worker.**
  - On `QUEST_STARTED`, each id in `QuestWork.workers(run)` gets the word `QUEST!` over its head.
  - The word is in the palette's `orange`, with the ink outline that ability names use, at twice the pixel font's size.
  - It pops in: from 0.6 to 1.25 to 1.0 of its size over 0.15 s.
  - It holds for 0.9 s while drifting up 4 pixels, then blinks out the way `FxText` does, never with a fade.
  - Its whole life is about 1.2 s, so it is gone before the lead's `arrive` bubble (spec 107).
- **R2. It follows its hero.** The word stays over its hero's head as the hero walks to the work spot, as "Learned X" does (`QuestEffects._keep_over_hero`). Several workers each carry their own word.
- **R3. Gates too.** On `GATE_STARTED` the opener gets the same word. A gate is also something to do, and the player reads it the same way.
- **R4. Only when someone can.**
  - Nothing shows on `QUEST_MISSED`, whether walked past or a sprung hazard: nobody could do it.
  - Nothing shows for a gate that is sealed.
- **R5. Stale or skipped time shows nothing.**
  - The word starts only when `World.may_animate(event)` is true, and it goes through `World.fx` like every passing effect.
  - A word already showing when a catch-up starts goes with the pool's other passing effects.
- **R6. It does not crowd other words.** It takes a text slot over the hero (`FxText.slot`), so a "Learned X" or an ability name over the same hero at the same moment stacks above or below it rather than on top of it.
- **R7. The showcase shows it.** The existing quest rows show it with no new row. A watcher in the "TWO CLERICS MEND A WANDERER" row checks that both clerics got a word.

## Interfaces

```gdscript
# game/effects/quest_effects.gd
## The word over a hero who takes on a quest or a gate, and its colour.
const CALLOUT: String = "QUEST!"
const CALLOUT_COLOUR: StringName = &"orange"
## How many "QUEST!" words show now (for tests).
func callouts_shown() -> int
```

## Acceptance

One test per requirement, in `tests/acceptance/test_108_quest_callout.gd`. Write each test first and see it fail.

| Requirement | Test | What it shows |
|---|---|---|
| R1 | `test_r1_quest_pops_over_every_worker` | Two clerics meeting `hurt_wanderer` give two words, one over each, reading "QUEST!" in `orange` at 2x. The scale passes above 1.0 then settles at 1.0. Every word is gone by 1.4 s |
| R2 | `test_r2_it_follows_its_hero` | While a cleric walks 20 or more pixels to its spot, its word's x keeps within 2 pixels of the hero's |
| R3 | `test_r3_gates_too` | `GATE_STARTED` gives one word, over the opener |
| R4 | `test_r4_only_when_someone_can` | A walked-past quest, a sprung tripwire and a sealed gate give no word |
| R5 | `test_r5_stale_time_shows_nothing` | A `QUEST_STARTED` older than `ANIMATE_TICKS`, or one heard in a catch-up, gives no word |
| R6 | `test_r6_it_does_not_crowd` | A "Learned" word and "QUEST!" over one hero at once do not overlap |
| R7 | `test_r7_the_showcase_shows_it` | The two-clerics row sees two words |

For Zak's playtest, and the lane's shots (a `--count` sequence over a quest's start at 1280x720 and `--ui-room=960x540`, cropped and enlarged 3x): the word reads at a glance, feels punchy and not noisy, and sits clear of the hero's head and of the bubbles that follow.

## Out of scope

- A sound for it.
- An icon, or a "!" over the quest's prop.
- Marking quests seen from across the room before the party gets there.
- Changing chat bubbles, lines or the work poses.

## Paths

- `game/effects/quest_effects.gd`
- `game/effects/fx_text.gd` (only if the pop needs a scale curve it does not have)
- `game/dev/showcase_moments.gd` (R7's watcher)
- `tests/acceptance/test_108_quest_callout.gd` and its `.uid`
- `docs/architecture.md`, `docs/wiki/index.html`

## Open questions

None.
