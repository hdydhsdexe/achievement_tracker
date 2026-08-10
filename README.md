# Achievement Tracker / 成就条件追踪器

适用于 **The Binding of Isaac: Repentance / Repentance+** 的局内成就条件追踪器。

## 功能

- HUD 持续显示成就的具体完成条件，而非仅显示成就名称。
- `F3` 打开局内目标选择菜单，最多同时追踪三个目标。
- `F4` 显示或隐藏 HUD。
- 支持中文和英文，新安装默认使用中文。
- 设置和当前局限制条件按以撒存档槽持久保存。
- 为 Boss Rush、Hush、Zip! 提供时间提醒。
- 检测 It's the Key 的心、硬币和炸弹拾取限制。
- 可选适配 Mod Config Menu Pure，可调整语言、字体大小、HUD 位置和追踪目标。

## 中文字体

Mod 默认使用由 LanaPixel 生成的精简中文位图字体，并保留 Noto Sans SC 字体作为加载失败时的后备；两者都只包含当前界面和成就条件实际使用的字形。中文显示不依赖 EID、中文补丁或游戏语言资源包，因此同时适配《忏悔》和《忏悔+》。字体资源遵循 SIL Open Font License 1.1，许可证分别位于 `resources/font/LANAPIXEL_OFL.txt` 和 `resources/font/OFL.txt`。

## 安装

将本目录放入 `The Binding of Isaac Rebirth/mods/achievement_tracker`，在 Mods 菜单启用后开始一局游戏。

## 已知限制

原版 Lua API 无法可靠读取所有原版成就或角色完成标记。当前部分目标只提供路线指引；自动排除已完成成就仍需要 Repentance+ 或 REPENTOGON 提供的接口。

## 开发

- `npm.cmd test`：运行零依赖合约测试。
- `tools/generate_font.py`：从 Lua 中文文本重新生成精简字体；可通过 `--name` 指定独立输出名，新增中文文案后应重新运行。
