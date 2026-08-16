# Windows 一键成就导入 TDD 证据

## 来源与用户旅程

需求来自本次对话中的实施计划，没有单独的计划文件。

- Windows 用户关闭游戏后双击一次，即可安全导入当前账号全部有效槽位。
- 用户可用 `-DryRun` 只读检查自动发现结果，即使游戏正在运行也不会写文件。
- 存档来源不唯一时停止；来源明确时保持槽位系列一致，不逐槽混用备份。
- 任一输入或暂存输出无效时不创建备份、不修改目标；写入中断时整批回滚。
- 有效导入快照可在启动或官方成就回调中吸收奖励 `IsAvailable()` 的新增正证据，但绝不删除已导入 ID。

## RED / GREEN 记录

| 阶段 | 命令 | 实际结果 | 证明 |
|---|---|---|---|
| 初始 RED | `node --test tests/one-click-import.test.js` | 0 通过、3 失败；均为启动器和 PowerShell 文件不存在 | 新测试确实覆盖待实现入口 |
| 来源选择 RED | 同上 | 1 通过、2 失败；另一命名格式的日期备份导致主存档误判，多属性注册表尚不安全 | 锁定主存档全局优先与 PowerShell StrictMode 边界 |
| Documents 回退 RED | 同上 | 2 通过、1 失败；缺少 `USERPROFILE\\Documents` 回退 | 锁定无 Known Folder 环境下的自动发现 |
| DryRun 守卫 RED | 同上 | 2 通过、1 失败；只读模式仍进入游戏/互斥守卫 | 锁定只读诊断不会因游戏运行而停止 |
| 安全审查修订 RED | 同上 | 0 通过、3 失败；入口仍转发参数、缺少权威上下文与安全边界、集成选择不符合新规则 | 锁定本轮审查修复确实由测试驱动 |
| 别名与启动器修订 RED | 同上 | 1 通过、2 失败；同前缀分隔符别名会覆盖，启动器仍依赖 PATH | 锁定同槽位哈希去重与固定系统 PowerShell 路径 |
| 本地来源修订 RED | 同上 | 1 通过、2 失败；生产脚本仍含云端/注册表发现，规范 Documents 目录无法按批次枚举 | 锁定仅本地来源、跨版本日期选择及不跨批次补槽 |
| 当前/日期竞争 RED | 同上 | 2 通过、1 失败；新增 PowerShell 5.1 竞争场景尚无通过标记 | 锁定当前文件 mtime 与日期批次的双向比较、精确并列及不混槽 |
| UInt32 小端序 RED | 同上 | 2 通过、1 失败；`82 02 00 00` 被 PowerShell 字节移位错误解码为 130，而非 642 | 锁定 642 项存档及 achievementId 284/641 不被截断 |
| 正证据刷新 RED | `node --test tests/achievement-import-contract.test.js` | 4 通过、3 失败；缺少单调刷新 API、启动刷新顺序和官方成就回调 | 锁定有效快照追加、重扫和持久化流程 |
| 正证据刷新 GREEN | 同上 | 7 通过、0 失败 | 启动批量刷新及 REPENTOGON 单项刷新契约通过 |
| 正证据审查 RED | 同上 | 5 通过、2 失败；启动刷新未排除共享标准奖励，callback 仍依赖奖励可用性 | 用真实 #8/#159 目录冲突锁定唯一键门禁与精确 ID 直录 |
| 正证据审查 GREEN | 同上 | 7 通过、0 失败 | 唯一标准奖励批量刷新和非标准奖励 callback 直录契约通过 |
| 全目录唯一键 RED | 同上 | 6 通过、1 失败；奖励键索引错误依赖快照范围 | 锁定唯一映射必须针对完整 catalog，而非当前快照子集 |
| 最终 GREEN | `node --test tests/one-click-import.test.js` | 3 通过、0 失败 | Windows PowerShell 5.1 临时夹具集成流程通过 |
| 全套 GREEN | `npm.cmd test` | 65 通过、0 失败 | 原有功能和新导入流程共同通过 |

按用户要求没有创建 TDD checkpoint commit；RED/GREEN 证据保存在本文档中。

## 测试保证

| 保证 | 类型 | 证据 |
|---|---|---|
| 根目录 `.cmd` 正确处理空格路径、使用固定参数并保留退出码 | 合约 | `tests/one-click-import.test.js` |
| 仅扫描三个明确的 Documents 本地目录；生产代码不访问注册表、用户云端目录或远端文件 | 合约、PowerShell 集成 | 静态断言及更新更晚的云端形状夹具 |
| 各目录、版本、日期/当前命名形成独立集合；最新集合不使用旧日期填补缺失槽位 | PowerShell 集成 | 临时目录夹具 |
| 备份日期按 `YYYYMMDD`、当前集合按最大 LastWriteTimeUtc 比较；最新并列时仅接受内容相同的镜像 | PowerShell 集成 | 临时目录夹具 |
| 当前集合较新和日期集合较新时均选择正确赢家且不跨集合补槽；精确同刻相同内容稳定去重、不同内容停止 | PowerShell 5.1 集成 | 四组直接竞争夹具 |
| 同日期、同槽位的命名别名仅在哈希相同时稳定去重，内容不同时停止 | PowerShell 集成 | 临时目录夹具 |
| PowerShell 5.1 使用有界 `BitConverter.ToUInt32` 读取 SAVE09R 小端字段，642 项快照保留 achievementId 284 和 641 | PowerShell 集成 | 直接字节向量及完整二进制夹具 |
| 启动刷新仅接受可解析且只映射一个 achievementId 的标准奖励键；共享 `collectible:20` 的 #8/#159 均不会借同一 `IsAvailable()` 污染快照 | 合约、真实目录夹具 | `tests/achievement-import-contract.test.js` |
| 官方成就 callback 将有效、范围内且目录存在的精确 ID 直接作为单调正证据，不依赖 `IsAvailable`，支持 character/area 等非标准奖励 | 合约 | `tests/achievement-import-contract.test.js` |
| 两条刷新路径均只在变化时重建去重升序数组并清缓存；启动由原有结尾 save 持久化，callback 变化后重扫并保存 | 合约 | `tests/achievement-import-contract.test.js` |
| `-DryRun` 不创建目标目录、备份或文件 | PowerShell 集成、实机只读 | 临时夹具及真实发现命令 |
| schema v4 合并保留设置、追踪目标和观察记录，输出 UTF-8 无 BOM | PowerShell 集成 | 临时目录夹具 |
| 损坏二进制、超限输入、非法 UTF-8、损坏 JSON 和超限暂存输出在写前停止 | PowerShell 集成 | 临时目录夹具 |
| 备份强制创建，原子替换中断时恢复旧文件并删除批次中新文件，所有临时文件均被清理 | PowerShell 集成 | 故障注入夹具 |
| 游戏运行与并发互斥在写模式下停止导入，游戏原始存档哈希不变 | PowerShell 集成 | 进程/互斥及 SHA-256 断言 |
| 目标在准备后被外部修改时于备份前停止；目标链中的重解析点被拒绝 | PowerShell 集成 | TOCTOU 注入与 Junction 夹具 |

## 覆盖率与已知边界

- `npm.cmd run test:coverage`：65 项测试通过；被 Node 覆盖率工具检测的浏览器解析器为 92.45% 行、89.87% 分支、100% 函数。PowerShell 不被 Node 覆盖率插桩，其关键路径由 Windows PowerShell 5.1 集成夹具执行。
- 实机 `one-click-import.ps1 -DryRun`：发现 `Repentance+ / Local backup / 20260815`，三槽 `achievementCount` 均为 642，已解锁数分别为 284/637/637；6 个源/目标文件哈希均未变化。
- 自动发现仅比较受支持的本地集合；同一最新时刻存在内容不同的集合时，使用网页导入器手动选择。
- 当前开发环境没有 Lua 运行时；Lua 刷新行为由 Node 合约检查和真实目录冲突夹具覆盖，REPENTOGON callback 的游戏内触发仍属于手工验收边界。
- 实现面向 Windows Repentance/Repentance+，未在非 Windows PowerShell 上提供自动写入支持。
