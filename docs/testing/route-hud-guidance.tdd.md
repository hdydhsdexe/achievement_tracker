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
