# Achievement Tracker / 成就条件追踪器

适用于 **The Binding of Isaac: Repentance / Repentance+** 的局内成就条件追踪器。

## 功能

- HUD 持续显示成就的具体完成条件，而非仅显示成就名称。
- `F3` 打开居中安全区域内的奖励可视化目标菜单：方向键选择，`Tab` 筛选奖励类型，`Enter`/`Space` 切换追踪，最多同时追踪三个目标。
- 在 F3 菜单按 `/` 可用英文、数字或缩写进行模糊搜索；搜索覆盖中英文成就名称、解锁奖励、完成条件、地点、所需角色/道具、奖励类型和编号，并可与 `Tab` 分类组合使用。
- `F3` 会依次排列当前角色（多人时为任一玩家）、本局可通过安卡、碎安卡、犹大的影子、拉撒路的破布、寻人启事或遥控器转换后完成、以及仅限其他角色的目标；潜在转换目标以琥珀色 `~` 标记，其他角色目标灰显，两者都仍可选择追踪。
- 菜单直接显示游戏内道具、饰品、卡牌图标和原版人物肖像，并为区域、挑战、机制和其他奖励提供类型图标。
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

## 从游戏存档导入准确成就状态

普通 Mod 没有读取任意本地文件的权限。本项目提供纯前端导入器，在浏览器本地解析游戏的 `persistentgamedata*.dat`，再生成 Achievement Tracker 自己的 `saveN.dat`；文件不会上传，游戏原始存档也不会被修改。

1. 完全关闭游戏，并备份 `The Binding of Isaac Rebirth/data/achievement_tracker/saveN.dat`。
2. 双击打开 `tools/save_importer/index.html`。
3. 选择要导入的游戏存档。关闭 Steam Cloud 时通常位于：
   - `%USERPROFILE%\Documents\My Games\Binding of Isaac Repentance`
   - `%USERPROFILE%\Documents\My Games\Binding of Isaac Repentance+`
4. 使用 Steam Cloud 时，选择 Steam `userdata/<Steam ID>/250900/remote` 中的 `rep_persistentgamedataN.dat`（Repentance）或 `rep+persistentgamedataN.dat`（Repentance+）；也可以选择带日期前缀的备份文件。
5. 为保留语言、HUD 位置和追踪目标，选择对应槽位现有的 `data/achievement_tracker/saveN.dat`。首次使用时可以不选，导入器会创建最小的新文件。
6. 下载合并后的 `saveN.dat`，确认 `N` 与游戏存档槽一致，再复制到 `The Binding of Isaac Rebirth/data/achievement_tracker` 覆盖同名文件。
7. 重新启动游戏。导入快照中的 `achievementId` 状态优先于奖励可用性和旧观察记录。

导入是离线快照：本局中新解锁不会自动写入快照。需要刷新时，关闭游戏并重新执行以上流程。导入器当前支持带 `ISAACNGSAVE09R  ` 文件头的 Repentance / Repentance+ 存档。

## 已知限制

未导入存档快照时，原版 Lua API 仍无法可靠读取所有原版成就或角色完成标记，因此缺少证据的目标显示为“未确认”。搜索输入仅支持英文字母、数字和空格，但无论界面语言为何都会检索中英文资料。安装 REPENTOGON 后，F3 菜单会在单人游戏中暂停并覆盖暂停页；多人游戏和原版单人游戏保持实时运行并显示提示。原版环境若已打开暂停页，需要先关闭暂停页再按 `F3`，避免两个全屏界面重叠。

## 开发

- `npm.cmd test`：运行零依赖合约测试。
- `tools/save_importer/index.html`：离线解析游戏存档并生成 Achievement Tracker 导入文件。
- `tools/generate_font.py`：从 Lua 中文文本重新生成精简字体；可通过 `--name` 指定独立输出名，新增中文文案后应重新运行。
- `tools/generate_reward_type_icons.py`：重新生成非标准奖励的五格像素图集。
