# Achievement Tracker / 成就条件追踪器

适用于 **The Binding of Isaac: Repentance / Repentance+** 的局内成就条件追踪器。

当前版本：**v0.8.5**。

## 功能

- HUD 持续显示成就的具体完成条件，而非仅显示成就名称。
- 当玩家遇到可立即推进或完成特定成就的场景时，HUD 底部会显示以“尝试”开头的动作提示；`F3` 会将对应成就排列在正在追踪的目标之后、其他可完成目标之前。场景判断覆盖特殊 Boss、房间实体、可用道具/卡牌/胶囊、拾取限制、胜利跑圈、限时暗室、累计体型/Gulp/蓝苍蝇以及 Home 的妈妈箱等三批机会。
- 角色通关标记类目标会按当前楼层拆成“当前步骤 + 下一步”，逐层列出本层可进入的具体普通/支线楼层，覆盖 Mom's Heart、Isaac、Satan、Boss Rush、???、羔羊、超级撒但、究极贪婪、死寂、精神错乱、Mother 和祸兽路线；最后入口标黄，错过路线标红，R Key 或合法替代方式可使路线重新恢复。
- 路线提示会检查所有玩家当前持有或房间中实际出现的关键道具、卡牌和饰品，仅在能帮助当前步骤时显示对应替代方案。Mother 路线会跟踪镜像世界、两块菜刀碎片、陵墓肉门和尸宫；祸兽路线会跟踪奇怪门、爸爸的便条、回溯与家。追踪堕化角色解锁时会改用专用回溯路线，并在发现多余饰品后持续提醒将其留在头目房或宝箱房，以便回溯时取得红钥匙碎片。
- `F3` 打开居中安全区域内的奖励可视化目标菜单：方向键或长按连续选择，鼠标悬停选择并可左键切换追踪，`Tab` 在全部、道具、饰品、卡牌、人物、怪物、地点、挑战、掉落物、机器与场景、机制和其他奖励间循环筛选，`Enter`/`Space` 也可切换追踪，最多同时追踪三个目标。取消追踪时目标会留在当前位置，直到菜单因重新打开、搜索、筛选或状态变化而刷新。
- 在 F3 菜单按 `/` 可用英文、数字或缩写进行模糊搜索；搜索覆盖中英文成就名称、解锁奖励、完成条件、地点、所需角色/道具、奖励类型和编号，并可与 `Tab` 分类组合使用。
- `F3` 会优先排列正在追踪的目标，再依次排列当前角色（多人时为任一玩家）、本局可通过安卡、碎安卡、犹大的影子、拉撒路的破布、寻人启事或遥控器转换后完成、仅限其他角色、当前模式不可完成、以及已完成的目标。五种状态分别使用绿色对勾、天蓝目标、琥珀转换箭头、紫色人物和珊瑚红叉号表示；金色星标独立表示正在追踪，深色选中框和 `>` 独立表示当前光标，因此无需只凭颜色判断。
- 菜单直接显示游戏内道具、饰品、卡牌图标和原版人物肖像，并为区域、挑战、机制和其他奖励提供类型图标。
- `F4` 显示或隐藏 HUD。
- 支持中文和英文，新安装默认使用中文。
- 设置和当前局限制条件按以撒存档槽持久保存。
- 已知角色通关标记按角色和难度长期保存。安装 REPENTOGON 时会只读同步游戏原生标记；否则根据本 Mod 实际见证的 Boss 击杀、Boss Rush 完成及已导入的解锁成就积累肯定证据，未知标记不会被当作未完成。
- 为部分原版 API 无法直接读取的累计目标保存保守的本局或长期进度证据；续局会恢复有效状态，并避免把未知进度误报为已完成。
- 成就 #326“冲！”会在玩家于 20 分钟内抵达原版暗室时显示剩余时间；若同时满足 #327“这就是钥匙”的禁拾取条件，HUD 会合并提示，而 `F3` 仍分别前移两个成就。
- 可选适配 Mod Config Menu Pure，可独立调整 HUD 与 F3 的原生 11/22/33px 字号上限、HUD 0–8px 行间距、HUD 位置和追踪目标。

## 中文字体

Mod 使用由 LanaPixel 生成的自带中文位图字体；LanaPixel 缺少的字符会在生成时由 Source Han Sans SC 补齐。HUD 与 F3 共用以 LanaPixel 11px 设计栅格为基准的原生 11/22/33px 字库并全部按 1:1 绘制；22/33px 的 LanaPixel 主字形是 11px 二值硬边字形的精确 2×/3× 最近邻放大，中文后备字形则保留灰阶抗锯齿以避免断笔。所选字号是上限：F3 面板会先增高、再加宽并在必要时降档；HUD 会先降档，最低档仍不足时自动左移或分页，两者都不会覆盖保存的选择和位置。字库只包含当前界面和成就条件实际使用的字形，生成器会拒绝任何两套源字体都无法显示的字符。中文显示不依赖 EID、中文补丁或游戏语言资源包，因此同时适配《忏悔》和《忏悔+》。两套字体均遵循 SIL Open Font License 1.1，许可证分别位于 `resources/font/LANAPIXEL_OFL.txt` 和 `resources/font/OFL.txt`。

## 安装

将本目录放入 `The Binding of Isaac Rebirth/mods/achievement_tracker_3788047099`，在 Mods 菜单启用后开始一局游戏。

## 从游戏存档导入准确成就状态

普通 Mod 没有读取任意本地文件的权限。Windows 用户完全关闭游戏后，双击 Mod 根目录的 `一键导入成就.cmd` 即可。脚本不需要管理员权限、Node.js、REPENTOGON 或网络，只读取当前用户 Documents 下的本地备份，并一次处理最新批次中实际存在的全部槽位。

脚本识别 Repentance 的 `%Documents%\My Games\Binding of Isaac\Repentance\YYYYMMDD.rep_persistentgamedataN.dat`、Repentance+ 的 `%Documents%\My Games\Binding of Isaac Repentance+\save_backups\YYYYMMDD.rep+persistentgamedataN.dat`，并兼容旧版 Repentance 平铺目录 `%Documents%\My Games\Binding of Isaac Repentance`。各目录、版本和日期分别构成一个不可拆分的存档集合；日期批次按 `YYYYMMDD`、无日期当前文件按最后写入时间选择全局唯一最新集合，不会用旧批次补齐缺失槽位。最新时间并列且内容不同会安全停止，内容相同的镜像则稳定去重。自动流程不会扫描 Steam 注册表、`userdata` 或 Cloud `remote`。

所有游戏存档和现有 Mod JSON 会先整批验证。旧 `saveN.dat` 自动备份至 `The Binding of Isaac Rebirth/data/achievement_tracker/backups/<时间戳>`，随后原子替换对应槽位；缺失槽位保持不变，失败时自动回滚。脚本不会修改游戏原始存档。可在 PowerShell 中运行 `tools/save_importer/one-click-import.ps1 -DryRun`，只查看预计来源、槽位和解锁数量，即使游戏正在运行也不会写文件。

需要手动选择文件、跨环境操作或排查自动发现问题时，可双击 `tools/save_importer/index.html` 使用原有本地网页导入器。它支持 Documents 中的 `persistentgamedataN.dat`、Steam Cloud 中的 `rep_persistentgamedataN.dat` / `rep+persistentgamedataN.dat` 以及日期前缀备份；选择对应的现有 Mod `saveN.dat` 后下载合并文件，再复制回 `data/achievement_tracker`。所有解析均在本机完成，不会上传文件。

导入结果以离线快照为基础。安装 REPENTOGON 时，Mod 会在官方成就解锁回调后把精确 `achievementId` 追加到当前槽位的 `saveN.dat`；原版环境会在下一局开始时使用奖励 `IsAvailable()` 做保守补录，但只接受在目录中唯一对应一个成就的物品、饰品或卡牌奖励，且绝不删除快照中的既有成就。角色、区域、功能以及共享同一奖励等无法可靠反推的成就，仍需关闭游戏并再次双击启动器刷新。若要恢复，关闭游戏后将最近备份目录中的 `saveN.dat` 复制回 `data/achievement_tracker`。导入器当前支持带 `ISAACNGSAVE09R  ` 文件头的 Repentance / Repentance+ 存档。

## 已知限制

未导入存档快照时，原版 Lua API 仍无法可靠读取所有原版成就或角色完成标记，因此缺少证据的目标显示为“未确认”。搜索输入仅支持英文字母、数字和空格，但无论界面语言为何都会检索中英文资料。安装 REPENTOGON 后，F3 菜单会在单人游戏中暂停并覆盖暂停页；多人游戏和原版单人游戏保持实时运行并显示提示。原版环境若已打开暂停页，需要先关闭暂停页再按 `F3`，避免两个全屏界面重叠。

组合通关标记在无 REPENTOGON 的旧存档中只能显示 Mod 安装后观测到或可由已解锁成就肯定推断的部分；追踪器不会猜测缺失标记。路线替代提示只覆盖正常可操作方式，不提示特殊种子、越界房间或漏洞技巧。

HUD/F3 原生字库只能避免字形纹理自身的分数缩放；游戏的全局 Filter、显卡缩放或显示器后处理仍可能使最终画面变软，本 Mod 不会覆盖用户的全局 Filter 设置。

## 开发

- `npm.cmd test`：运行零依赖合约测试。
- `一键导入成就.cmd`：Windows 一键发现、备份并导入全部有效存档槽。
- `tools/save_importer/index.html`：离线解析游戏存档并生成 Achievement Tracker 导入文件。
- `tools/generate_font.py`：从 Lua 文本重新生成精简字体，并输出每个后备字形的来源清单。先运行 `npm.cmd install`；HUD 与 F3 的共享字库使用 `--pixel-base-size 11`，并依次用 `--size 11/22/33` 与 `--fallback-size 10/20/30` 生成三档资源。新增文案后应重新生成并运行测试。
- `tools/generate_reward_type_icons.py`：重新生成非标准奖励的五格像素图集。
- `tools/generate_status_icons.py`：重新生成 F3 的五种状态符号和选中框像素资源。
- 堕化角色路线的游戏内回归应覆盖：正确/错误及多人角色、饰品跨房间提醒、头目房/宝箱房放置与拾回、续局、回溯对应楼层取碎片、持有红钥匙直接到家，以及中英文窄分辨率 HUD。
