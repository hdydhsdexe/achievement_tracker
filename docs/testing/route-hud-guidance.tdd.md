# 简化路线 HUD 与离层提醒：TDD 证据

## RED

- 先新增 `tests/route-hud-guidance.test.js`，覆盖 Tab 简洁/完整切换、始终可见的提醒、普通/虚空活板门识别、结构化离层事项、超级撒但钥匙提示和中英文控制文案。
- 命令：`node --test tests/route-hud-guidance.test.js`
- 结果：0/7 通过；七项失败均来自计划中的行为尚未实现。
- RED 检查点：`2271bb6 test: specify compact route HUD guidance`

## GREEN

- 路线 HUD 默认只显示去重后的本层操作；按住 `Tab` 时展开路线名称、成员、总进度和下一步。未追踪的新局推荐仍显示 `V` 提示。
- 普通下层活板门与虚空入口分别识别。Mother 菜刀碎片、宝箱层/暗室照片、祸兽入口、Boss Rush 和 Hush/Delirium 限时入口均使用结构化状态生成黄色离层提醒。
- 已追踪路线含未完成超级撒但目标时，天使房按地上碎片、存活天使、可炸雕像三个阶段提示；献祭房只说明第 9/11 次奖励。完整钥匙或可靠开门方案会使提示静默。
- 指引只存在于实时路线合并结果中，未增加 `activeRun` 字段，也未提升存储 schema。
- 三档 11/22/33px 字库已按当前中英文 Lua 文案重新生成。

## 验证结果

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 新行为契约 | `node --test tests/route-hud-guidance.test.js` | 7/7 PASS |
| 字体与窄分辨率布局 | `node --test tests/route-hud-guidance.test.js tests/text-layout.test.js tests/font-assets.test.js` | 16/16 PASS |
| 完整回归 | `npm.cmd test` | 164/164 PASS |
| 覆盖率 | `npm.cmd run test:coverage` | 行 95.02%，分支 84.41%，函数 90.63% |
| 补丁格式 | `git diff --check` | PASS |

游戏内仍建议人工冒烟确认一次：按住/松开 `Tab` 的即时切换、普通活板门旁的多条离层提醒、天使雕像三个阶段、献祭房提示，以及 F3 打开时 HUD 隐藏且 `Tab` 继续只切换分类。

## 增量：实时简短操作

### RED

- 新增“头目未击败时只显示击败头目”“出口出现后报告主线/支线可用性”“只灰显不可用出口”三项契约。
- 命令：`node --test tests/route-hud-guidance.test.js`
- 结果：原有 7 项通过，新增 3 项失败；失败原因分别为尚无实时简短操作、头目房完成状态与支线出口检测。
- RED 检查点：`a85f485 test: specify live compact route actions`

### GREEN

- 普通楼层在头目完成前只显示“击败本层头目”；完成后根据当前房间实际生成的普通活板门与支线入口分别显示短操作。
- 支线入口通过门的目标房间索引识别，不从本地化文本推断；没有实际出现的出口使用 HUD 淡色，而可用出口继续使用当前路线状态色。
- 特殊后期出口继续使用既有结构化指引，避免把光柱、肉门等不同出口错误当作普通活板门。

### 增量验证

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 新行为契约 | `node --test tests/route-hud-guidance.test.js` | 10/10 PASS |
| 完整回归 | `npm.cmd test` | 167/167 PASS |
| 覆盖率 | `npm.cmd run test:coverage` | 行 95.02%，分支 84.41%，函数 90.63% |
| 补丁格式 | `git diff --check` | PASS（仅 Git 的 LF/CRLF 转换提示） |

游戏内仍建议人工冒烟确认一次：在地下室、洞穴和深牢的头目房分别观察头目击败前、普通出口出现、支线入口出现三种状态，以及 XL 层需要清理两个头目房的情况。
