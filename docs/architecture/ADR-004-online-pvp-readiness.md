# ADR-004: 联机 PvP 准备——权威模型、就绪现状与迁移路线

| 字段 | 值 |
|------|-----|
| **Status** | ✅ Accepted（准备阶段·联机主工程未启动） |
| **Date** | 2026-07-12 |
| **Author** | Eddy + Claude |
| **Supersedes** | — |
| **Related** | ADR-002（v4 引擎架构）、`.claude/rules/network-code.md`、体检清单 `production/session-state/audit-2026-07-02.md`「联机改造记账」 |

> 本文遵循三层分离：**Current Behavior**（现状·已验证）/ **Target**（目标架构）/ **Migration**（迁移路线）。
> 方向依据：目标 = 联机 1v1 PvP·服务器权威·先本地验证好玩再联机（Eddy 定·2026-05）。

---

## Context

游戏形态 = **双方同时盲选动作 → 引擎一次性结算**的回合制。这个形态对联机极其友好：

- 没有实时输入流，**每回合每方只提交一次 {动作, 道具集}** —— 无需客户端预测/回滚那一整套（network-code.md 的预测条款适用于实时游戏，本作可豁免）；
- 回合有硬时限（10/15/20s 阶梯），超时兜底「攒」已是引擎语义 —— 天然的服务器 tick 边界；
- 引擎已确定性（seed 注入 + clone 逐位一致由 GUT/AI 异步契约测试锁定），**服务端 = headless Godot 跑同一份 BattleCore** —— sim 管线（tools/sim）三年跑百万拍，就是服务端可行性的既成证明。

## Current Behavior（2026-07-12 审计·各项均有代码/测试背书）

体检「联机改造记账」（2026-07-02）三项，两项已被后续工作化解：

| 项 | 状态 | 依据 |
|---|---|---|
| draft 选项须服务器生成 | ✅ 已在引擎侧 | `begin_draft`/`begin_upgrade_draft`/`_weighted_draft_pick` 全在 BattleCore，随机走 core.rng；UI 只展示+提交选择 |
| 死亡换人/draft await 内联改异步边界 | ✅ 引擎侧已异步 | `resolve()` 不阻塞：死亡换人=`pending_death_switch` 旗标+`force_switch_prompt` 事件，UI 事后 `execute_death_switch`；draft=begin/pick 两段式。await 只存在于 UI 收集本地输入，联机语义=「服务器要输入→客户端弹窗→回传」，结构已就位 |
| ~344 硬编码中文串 i18n | ⏳ 未做 | 独立机械批·见 Migration M4 |
| （新增）UI 只读边界 | ✅ 已锁 | 唯一直写点=src/ui/debug 调试面（A2 拆出·联机禁用）；`tests/unit/ui/test_ui_readonly_boundary.gd` 守卫常绿 |
| （新增）战局序列化 | ✅ 已落地 | `BattleCore.to_snapshot()/from_snapshot()`（版本化·JSON 安全·rng 64 位走字符串）；`test_battle_snapshot.gd` 锁「恢复局续打逐位一致」 |
| （新增）动画事件流化 | ✅ 已完成 | A3a/A3b：战斗演出全部由 `events` 派生，不 diff 引擎状态 —— 客户端只收事件流即可重放演出 |
| 随机性归属 | ✅ 引擎独占 | 游戏随机全在 core.rng（seed 注入式·服务器换发 seed 即权威）；UI 层随机全是纯视觉（粒子相位/星空 seed）；AI 侧 rng 属驾驶员（联机时被真人替换） |

## Target（目标架构）

```text
[客户端 A] ──提交 {turn, action, items, draft_pick, switch_pick}──▶
                                                    [服务端 = headless Godot + BattleCore]
[客户端 B] ──提交──▶                                   权威 resolve → 广播 {events, 公开状态}
      ◀──events 流（客户端重放演出）+ 各自私有视图──┘
```

- **权威**：服务端持有唯一 BattleCore；客户端提交意图，服务端校验合法性（`legal_actions`/`can_afford` 已是现成校验面）后代入 `select_action`/`use_slot`/`pick_draft`。**绝不信任客户端**（network-code.md §1）。
- **消息**：全部版本化（快照已带 `SNAPSHOT_VERSION`，对局消息沿用同规矩）；字段范围校验入包即做。
- **重连/观战**：`to_snapshot()` → 传输 → `from_snapshot()`，随机流逐位续打（已测）。
- **私有信息**：3 选 1 选项、信息扭曲（幻影/迷雾）只发给所属方 —— 需要 per-player 视图过滤器（见 M2；体检 D 组「per-player 可见性视图提前实现=不做」维持，届时再做）。
- **匹配/大厅**：主菜单匹配流程已是假匹配演出，接真实匹配服务时 UI 结构不变。

## Migration（迁移路线·按依赖排序）

- **M0（已完成·本 ADR 落地时）**：序列化+确定性测试（批②）、UI 只读守卫（批③）、随机归属审计（批④=零工作量结论）。
- **M1 本地驱动抽象**：battle_screen 与 BattleCore 之间抽 `MatchDriver` 接口（本地实现=直连 core+AI；远程实现=网络代理）。改造面大（battle_screen ~2500 行），**等联机立项再做**，先决条件已备齐（命令面收敛+事件流化）。
- **M2 服务端工程**：headless Godot 对局进程（复用 sim 启动器骨架）+ 房间/匹配 + per-player 视图过滤 + 断线重连（快照）。
- **M3 反作弊面收口**：联机构建禁用 src/ui/debug；回合时限服务端计时；提交去重（turn 号幂等）。
- **M4 i18n 抽取**：~344 中文串 → 键表（独立机械批·与联机并行可做）。
- **M5 账号/变现**：F2P 外观·绝不卖强度（Eddy 定·另立项）。

## Consequences

- 现在起新增引擎状态字段必须同步三处：`clone()`、`to_snapshot()/from_snapshot()`、快照测试 —— 已在两处函数头注释标明。
- 快照测试 + 边界守卫进入常绿基线（GUT 26 脚本 345 用例），任何破坏联机前提的改动会在本地就被测试拦下。
- 服务端选型钉死 headless Godot（与 sim 同栈），排除自研协议服务器/其他语言重写 —— 若未来推翻此选型需重开 ADR。
