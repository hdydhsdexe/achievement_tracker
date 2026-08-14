# Achievement Tracker / 成就条件追踪器

适用于 **The Binding of Isaac: Repentance / Repentance+** 的局内成就条件追踪器。

## 功能

- HUD 持续显示成就的具体完成条件，而非仅显示成就名称。
- `F3` 打开居中安全区域内的奖励可视化目标菜单：方向键选择，`Tab` 筛选奖励类型，`Enter`/`Space` 切换追踪，最多同时追踪三个目标。
- `F3` 会依次排列当前角色（多人时为任一玩家）、本局可通过安卡、碎安卡、犹大的影子、拉撒路的破布、寻人启事或遥控器转换后完成、以及仅限其他角色的目标；潜在转换目标以琥珀色 `~` 标记，其他角色目标灰显，两者都仍可选择追踪。
- 菜单直接显示游戏内道具、饰品和卡牌图标，并为角色、区域、挑战、机制和其他奖励提供类型图标。
- `F4` 显示或隐藏 HUD。
- 支持中文和英文，新安装默认使用中文。
- 设置和当前局限制条件按以撒存档槽持久保存。
- 为 Boss Rush、Hush、Zip! 提供时间提醒。
- 检测 It's the Key 的心、硬币和炸弹拾取限制。
- 可选适配 Mod Config Menu Pure，可调整语言、字体大小、HUD 位置和追踪目标。

## 中文字体

Mod 使用由 LanaPixel 生成的自带中文位图字体，只包含当前界面和成就条件实际使用的字形。中文显示不依赖 EID、中文补丁或游戏语言资源包，因此同时适配《忏悔》和《忏悔+》。字体资源遵循 SIL Open Font License 1.1，许可证位于 `resources/font/LANAPIXEL_OFL.txt`。

## 安装

将本目录放入 `The Binding of Isaac Rebirth/mods/achievement_tracker`，在 Mods 菜单启用后开始一局游戏。

## 已知限制

原版 Lua API 无法可靠读取所有原版成就或角色完成标记，因此缺少证据的目标显示为“未确认”。安装 REPENTOGON 后，F3 菜单会在单人游戏中暂停并覆盖暂停页；多人游戏和原版单人游戏保持实时运行并显示提示。原版环境若已打开暂停页，需要先关闭暂停页再按 `F3`，避免两个全屏界面重叠。

## 开发

- `npm.cmd test`：运行零依赖合约测试。
- `tools/generate_font.py`：从 Lua 中文文本重新生成精简字体；可通过 `--name` 指定独立输出名，新增中文文案后应重新运行。
- `tools/generate_reward_type_icons.py`：重新生成非标准奖励的五格像素图集。
