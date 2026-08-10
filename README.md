# Achievement Tracker

一个用于 **The Binding of Isaac: Repentance** 的局内成就条件追踪器。

## Current MVP

- HUD 持续显示成就的具体完成条件，而不是只显示成就名称。
- 支持中文与英文；新安装默认使用中文，并使用游戏内置 CJK 字体。
- Select up to three goals from an in-run menu (`F3`).
- Toggle the HUD with `F4`.
- Persist tracked goals per Isaac save slot.
- Receive deadline reminders for Boss Rush, Hush, and Zip!.
- Receive a warning when the run no longer qualifies for It's the Key.
- Browse 18 initial timed, route, completion, counter, and streak goals.
- 安装 Mod Config Menu Pure 后，可调整语言、字体大小、HUD 横向/纵向位置、显示状态和追踪目标；该 Mod 仍为可选依赖。

## Installation

Place this directory under `The Binding of Isaac Rebirth/mods/achievement_tracker`, enable it in the Mods menu, then start a run. The base mod has no required dependencies.

## Important limitations

The vanilla Repentance Lua API cannot reliably inspect every vanilla achievement or completion mark. Goals without an observable vanilla callback are guidance-only in this MVP. Automatic filtering of already-unlocked achievements is planned as an optional REPENTOGON/Repentance+ integration.

中文通过游戏自带的 `font/lanapixel.fnt` Unicode 字体渲染，无需附带或下载第三方字体。

## Development

Run `npm.cmd test` on Windows. Node is used only for contract tests and is not required by the game.
