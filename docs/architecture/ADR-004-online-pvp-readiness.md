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
| ~344 硬编码中文串 i18n | ✅ 主体已做（2026-07-12） | 「原文即键」tr() 包裹＋键表 389 键·见 Migration M4 |
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

- **M0（✅ 2026-07-12）**：序列化+确定性测试（批②）、UI 只读守卫（批③）、随机归属审计（批④=零工作量结论）。
- **M2a 对局协议栈（✅ 2026-07-12·联机线批A-D）**：`src/net/` 四件套——net_protocol（版本化+入包校验）/ match_room（权威房间：克隆预检提交·legal_actions 白名单·draft 权威门+私发·死亡换人相位·resync 快照）/ net_transport（Loopback+ENet 可靠 JSON 包）/ match_client（无 UI 协议端）。验证=GUT 9 用例（含两客户端经环回整局打穿·事件流双端逐位一致）+ tools/net_probe（真 ENet 127.0.0.1 混合传输 3 回合 PASS）。⚠ 权威门实录：begin_draft 本身不设防，服务端不把门=客户端可对未解锁槽强刷 rng——测试抓出后已在 match_room 收口。
- **M1 客户端驱动接线**：battle_screen 挂 match_client（本地局=room 进程内直连·远程局=ENet）+ 建房/加入 UI。改造面大（battle_screen ~2500 行），**下一批主菜**，先决条件全部备齐。
- **M1 客户端驱动接线（✅ 2026-07-12）**：快照镜像 lockstep（本地 battle=权威快照只读镜像·UI 读代码零改动）+ 加入方视角翻转（flip_snapshot/events/winner·双翻恒等锁定）+ net_session 接线盒 + 局域网大厅（建房/输 IP 加入）。E2E=tools/net_battle_probe（真 ENet 上真战斗屏以加入方打满回合）。
- **M3 安全收口（✅ 2026-07-12）**：①DTLS 传输加密（主机开房现生成自签证书·密钥不落盘·client_unsafe=加密不验身·fail-closed 不降级明文·⚠防不了主动 MITM=正经证书链等 M2b 专用服务器）②入包大小上限（服务器侧 8KB·JSON 炸弹防护）③服务端权威计时（TURN_TIME_STEPS+4s 宽限·超时代提交攒/代选替补·时钟可注入=GUT 锁定）④防洪令牌桶（突发 30·回填 10/s·超额静默丢）⑤调试面收口（release 剥离 + 联机局禁用）⑥PCK 加密=发布前手册 `docs/pck-encryption-guide.md`。
- **M2b 服务端工程（剩余）**：BP/选人联机化（现固定阵容）+ 断线重连 UI 接线（快照地基已备）+ 进程托管（headless Godot 复用 sim 启动器骨架）+ 大厅/匹配 + 多房间 + per-player 视图过滤（信息扭曲道具+快照私有字段）+ 公网方案（个人项目候选：Steam P2P / 轻量中转服·需 Eddy 选型）。
- **M3 反作弊面收口**：联机构建禁用 src/ui/debug；回合时限服务端计时；提交去重（turn 号幂等）。
- **M4 i18n 抽取（✅ 主体 2026-07-12）**：方案=**「原文即键」**（中文原文即翻译键；未注册翻译表时 `tr()` 原样返回=零行为变化，`.tscn` 文本零改动=Godot 自动翻译按原文查表，Eddy 编辑器所见仍是中文）。已做：①UI/story 代码显示点全量 `tr()` 包裹（字面量就地包·模板在拼接处包·数据文案在显示汇点包 `tr(变量)`·逻辑键不包）；②键表生成器 `tools/i18n_scan.gd`（可重复跑）→ `assets/i18n/strings_zh.csv` 389 键（含英雄 .tres/道具 catalog/levels.json/.tscn 文本·带出处 context 列）；③GUT 28 脚本 360 用例全绿。**剩余（激活翻译时做）**：填 en 列 → 去 context 列 → 移除 `assets/i18n/.gdignore` → project.godot 注册 translations（风险操作·届时批准）。**明示缓办**：src/expedition（占位内容等 F/G/H 重做）、debug 面板（release 剥离）、标题屏像素字形字（美术资产范畴）。
- **M5 账号/变现**：F2P 外观·绝不卖强度（Eddy 定·另立项）。

## Consequences

- 现在起新增引擎状态字段必须同步三处：`clone()`、`to_snapshot()/from_snapshot()`、快照测试 —— 已在两处函数头注释标明。
- 快照测试 + 边界守卫进入常绿基线（GUT 26 脚本 345 用例），任何破坏联机前提的改动会在本地就被测试拦下。
- 服务端选型钉死 headless Godot（与 sim 同栈），排除自研协议服务器/其他语言重写 —— 若未来推翻此选型需重开 ADR。
