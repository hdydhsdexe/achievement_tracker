# Achievement Tracker

An in-run achievement goal tracker for **The Binding of Isaac: Repentance**.

## Current MVP

- Select up to three goals from an in-run menu (`F3`).
- Toggle the HUD with `F4`.
- Persist tracked goals per Isaac save slot.
- Receive deadline reminders for Boss Rush, Hush, and Zip!.
- Receive a warning when the run no longer qualifies for It's the Key.
- Browse 18 initial timed, route, completion, counter, and streak goals.
- Configure goals through Mod Config Menu Pure when it is installed; it remains optional.

## Installation

Place this directory under `The Binding of Isaac Rebirth/mods/achievement_tracker`, enable it in the Mods menu, then start a run. The base mod has no required dependencies.

## Important limitations

The vanilla Repentance Lua API cannot reliably inspect every vanilla achievement or completion mark. Goals without an observable vanilla callback are guidance-only in this MVP. Automatic filtering of already-unlocked achievements is planned as an optional REPENTOGON/Repentance+ integration.

The default game font may not contain Chinese glyphs, so the shipped default is English even though the catalog contains Chinese localization data.

## Development

Run `npm.cmd test` on Windows. Node is used only for contract tests and is not required by the game.
