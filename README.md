# Achievement Tracker / 成就条件追踪器

适用于 **The Binding of Isaac: Repentance / Repentance+** 的局内成就条件追踪器。

## 功能

- HUD 持续显示成就的具体完成条件，而非仅显示成就名称。
- 角色通关标记类目标会按当前楼层拆成“当前步骤 + 下一步”，覆盖 Mom's Heart、Isaac、Satan、Boss Rush、???、羔羊、超级撒但、究极贪婪、死寂、精神错乱、Mother 和祸兽路线；最后入口标黄，错过路线标红，R Key 或合法替代方式可使路线重新恢复。
- 路线提示会检查所有玩家当前持有或房间中实际出现的关键道具、卡牌和饰品，仅在能帮助当前步骤时显示对应替代方案。Mother 路线会跟踪镜像世界、两块菜刀碎片、陵墓肉门和尸宫；祸兽路线会跟踪奇怪门、爸爸的便条、回溯与家。
- `F3` 打开居中安全区域内的奖励可视化目标菜单：方向键选择，`Tab` 筛选奖励类型，`Enter`/`Space` 切换追踪，最多同时追踪三个目标。
- 在 F3 菜单按 `/` 可用英文、数字或缩写进行模糊搜索；搜索覆盖中英文成就名称、解锁奖励、完成条件、地点、所需角色/道具、奖励类型和编号，并可与 `Tab` 分类组合使用。
- `F3` 会依次排列当前角色（多人时为任一玩家）、本局可通过安卡、碎安卡、犹大的影子、拉撒路的破布、寻人启事或遥控器转换后完成、以及仅限其他角色的目标；潜在转换目标以琥珀色 `~` 标记，其他角色目标灰显，两者都仍可选择追踪。
- 菜单直接显示游戏内道具、饰品、卡牌图标和原版人物肖像，并为区域、挑战、机制和其他奖励提供类型图标。
- `F4` 显示或隐藏 HUD。
- 支持中文和英文，新安装默认使用中文。
- 设置和当前局限制条件按以撒存档槽持久保存。
- 已知角色通关标记按角色和难度长期保存。安装 REPENTOGON 时会只读同步游戏原生标记；否则根据本 Mod 实际见证的 Boss 击杀、Boss Rush 完成及已导入的解锁成就积累肯定证据，未知标记不会被当作未完成。
- 为成就 #326 Zip! 提供时间提醒。
- 检测 It's the Key 的心、硬币和炸弹拾取限制。
- 可选适配 Mod Config Menu Pure，可调整语言、字体大小、HUD 位置和追踪目标。

## 中文字体

Mod 使用由 LanaPixel 生成的自带中文位图字体，只包含当前界面和成就条件实际使用的字形。中文显示不依赖 EID、中文补丁或游戏语言资源包，因此同时适配《忏悔》和《忏悔+》。字体资源遵循 SIL Open Font License 1.1，许可证位于 `resources/font/LANAPIXEL_OFL.txt`。

## 安装

将本目录放入 `The Binding of Isaac Rebirth/mods/achievement_tracker`，在 Mods 菜单启用后开始一局游戏。

## 从游戏存档导入准确成就状态

普通 Mod 没有读取任意本地文件的权限。Windows 用户完全关闭游戏后，双击 Mod 根目录的 `一键导入成就.cmd` 即可。脚本不需要管理员权限、Node.js、REPENTOGON 或网络，只读取当前用户 Documents 下的本地备份，并一次处理最新批次中实际存在的全部槽位。

脚本识别 Repentance 的 `%Documents%\My Games\Binding of Isaac\Repentance\YYYYMMDD.rep_persistentgamedataN.dat`、Repentance+ 的 `%Documents%\My Games\Binding of Isaac Repentance+\save_backups\YYYYMMDD.rep+persistentgamedataN.dat`，并兼容旧版 Repentance 平铺目录 `%Documents%\My Games\Binding of Isaac Repentance`。各目录、版本和日期分别构成一个不可拆分的存档集合；日期批次按 `YYYYMMDD`、无日期当前文件按最后写入时间选择全局唯一最新集合，不会用旧批次补齐缺失槽位。最新时间并列且内容不同会安全停止，内容相同的镜像则稳定去重。自动流程不会扫描 Steam 注册表、`userdata` 或 Cloud `remote`。

所有游戏存档和现有 Mod JSON 会先整批验证。旧 `saveN.dat` 自动备份至 `The Binding of Isaac Rebirth/data/achievement_tracker/backups/<时间戳>`，随后原子替换对应槽位；缺失槽位保持不变，失败时自动回滚。脚本不会修改游戏原始存档。可在 PowerShell 中运行 `tools/save_importer/one-click-import.ps1 -DryRun`，只查看预计来源、槽位和解锁数量，即使游戏正在运行也不会写文件。

需要手动选择文件、跨环境操作或排查自动发现问题时，可双击 `tools/save_importer/index.html` 使用原有本地网页导入器。它支持 Documents 中的 `persistentgamedataN.dat`、Steam Cloud 中的 `rep_persistentgamedataN.dat` / `rep+persistentgamedataN.dat` 以及日期前缀备份；选择对应的现有 Mod `saveN.dat` 后下载合并文件，再复制回 `data/achievement_tracker`。所有解析均在本机完成，不会上传文件。

导入结果以离线快照为基础。安装 REPENTOGON 时，Mod 会在官方成就解锁回调后把精确 `achievementId` 追加到当前槽位的 `saveN.dat`；原版环境会在下一局开始时使用奖励 `IsAvailable()` 做保守补录，但只接受在目录中唯一对应一个成就的物品、饰品或卡牌奖励，且绝不删除快照中的既有成就。角色、区域、功能以及共享同一奖励等无法可靠反推的成就，仍需关闭游戏并再次双击启动器刷新。若要恢复，关闭游戏后将最近备份目录中的 `saveN.dat` 复制回 `data/achievement_tracker`。导入器当前支持带 `ISAACNGSAVE09R  ` 文件头的 Repentance / Repentance+ 存档。

## 已知限制

未导入存档快照时，原版 Lua API 仍无法可靠读取所有原版成就或角色完成标记，因此缺少证据的目标显示为“未确认”。搜索输入仅支持英文字母、数字和空格，但无论界面语言为何都会检索中英文资料。安装 REPENTOGON 后，F3 菜单会在单人游戏中暂停并覆盖暂停页；多人游戏和原版单人游戏保持实时运行并显示提示。原版环境若已打开暂停页，需要先关闭暂停页再按 `F3`，避免两个全屏界面重叠。

组合通关标记在无 REPENTOGON 的旧存档中只能显示 Mod 安装后观测到或可由已解锁成就肯定推断的部分；追踪器不会猜测缺失标记。路线替代提示只覆盖正常可操作方式，不提示特殊种子、越界房间或漏洞技巧。

## 开发

- `npm.cmd test`：运行零依赖合约测试。
- `一键导入成就.cmd`：Windows 一键发现、备份并导入全部有效存档槽。
- `tools/save_importer/index.html`：离线解析游戏存档并生成 Achievement Tracker 导入文件。
- `tools/generate_font.py`：从 Lua 中文文本重新生成精简字体；可通过 `--name` 指定独立输出名，新增中文文案后应重新运行。
- `tools/generate_reward_type_icons.py`：重新生成非标准奖励的五格像素图集。
