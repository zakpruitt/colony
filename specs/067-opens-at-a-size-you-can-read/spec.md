# 067 — Opens at a size you can read

- **Status:** landed (provisional: not yet reviewed by Zak) (direction from Zak 2026-11-19; text not yet read by him)
- **Milestone:** M7
- **Depends on:** 030, 058
- **Pull request:** [#67](https://github.com/zakpruitt/colony/pull/67)

## Intent

Zak's first complaint about the UI was that it is hard to read. Spec 058 draws the UI at twice the size
in a 1920x1080 window, but the game still opens in a 1280x720 window, where everything is at its
smallest. This spec makes the game open at the size where it reads best on the player's screen, and
remember what the player chose instead.

## Requirements

- **R1. Opens large.** On first run the window opens maximized on the screen it starts on, when a
  maximized window there has room for the UI's smallest room at twice the size (1920x1080 inside the
  window's frame). On a screen that has that room only without a frame (a 1920x1080 screen) it opens in
  full screen. On a smaller screen it opens as it does today, and that first run writes no settings
  file: a later start on a larger screen is still a first run.
- **R2. Full screen.** `F11` switches between full screen (borderless, on the current screen) and the
  window as it was; the help lists it.
- **R3. Remembered.** The window's mode (windowed, maximized, full screen), and its size and place when
  windowed, are saved when they change and restored on the next start, in a settings file of their own
  under `user://`, not in the save. A remembered place that is off every screen now is ignored, and
  a remembered size larger than the screen it lands on is cut down to it.
- **R4. The UI follows.** After any change of the window's size the UI layer picks its scale and room
  as spec 058 rules, windows stay inside the room, and nothing is cut; changing size mid-drag or with
  windows open breaks nothing.
- **R5. Tools are unchanged.** Headless runs, `tools/dev.py shot` (1280x720, and `--ui-room`) and the
  tests open no maximized window and read or write no settings file unless a test names one of its own.
- **R6. Wiki** says how the game opens and what `F11` does.

## Interfaces

A small `WindowSettings` class under `game/` that loads, applies and saves; `Main` uses it only when
not headless and not told otherwise by a command-line flag (`--window-default`, which `dev.py shot`
passes). Nothing under `sim/` changes.

## Acceptance

In `tests/acceptance/test_067_opens_at_a_size_you_can_read.gd`, one test per requirement named
`test_rN_…`, each written before its code and seen to fail. What cannot be driven headless (the real
window's mode) is tested through `WindowSettings`' decisions given a screen size and a saved file, and
the lane says plainly which lines only a real window exercises and how it ran them by hand (a windowed
run through `dev.py`, closed by its timeout). Tests that write the file use a per-process name.

**To look at, and for Zak:** a shot of the game as it now opens on this machine, and after `F11`.

## Out of scope

- A settings screen. A UI scale the player picks. Rebinding keys. Remembering which screen.

## Paths

- `game/main.gd`, `game/window_settings.gd`, `game/ui/ui_root.gd`, `game/hud/help_panel.gd`
- `project.godot`, `tools/dev.py`, `tools/tests/`
- `tests/`
- `docs/architecture.md`, `docs/wiki/index.html`, `CLAUDE.md`

## Open questions

None.
