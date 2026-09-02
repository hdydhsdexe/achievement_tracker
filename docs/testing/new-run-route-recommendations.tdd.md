# 新局路线推荐与 V 键快捷追踪：TDD 证据

## RED

- 先新增 `tests/route-recommendations.test.js`，覆盖兼容路线模板、候选门槛、角色优先与评分、逻辑追踪位、续局恢复、HUD/F3、`V` 键优先级和路线冲突。
- 命令：`node --test tests/route-recommendations.test.js`
- 结果：0/9 通过；失败均来自尚不存在的路线模块、状态字段和界面/快捷键接口。
- RED 检查点：`09ad880 test: define new-run route recommendation behavior`

## GREEN

- 新增稳定的新局路线规划器，并按强烈推荐、推荐、普通数量，总目标数、最早目录位置和固定路线顺序评分。
- 路线在追踪器中只占一个逻辑槽位，但成员会展开给 HUD、失败警告和完成检测；`activeRun` 保存推荐、已追踪路线及初始房提示状态，存储 schema 保持 v10。
- HUD 合并路线成员、进度和去重步骤；F3 增加路线分类和虚拟路线行，并保护路线成员；`V` 按场景机会、推荐路线、兼容普通目标的顺序工作。
- 新文案所需的 11/22/33px 字库已重新生成。

## 验证

- `npm.cmd test`：157/157 通过。
- `npm.cmd run test:coverage`：157/157 通过。
- JavaScript 工具覆盖率：行 95.02%，分支 84.41%，函数 90.63%。
- `git diff --check`：通过。

游戏内仍应进行一次人工冒烟测试，重点确认正常/困难/贪婪新局、初始房离开前后的 `V` 键、续局恢复、F3 鼠标/键盘切换，以及窄分辨率下的路线分页。
