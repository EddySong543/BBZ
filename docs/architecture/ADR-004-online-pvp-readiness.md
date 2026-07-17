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
- **M2b-lite 大厅体验（✅ 2026-07-12）**：大厅 24 英雄选 3 + hello 阵容交换（房主净化伪造 id）+ 断线重连（加入同 IP=续战·断线暂停权威计时·双端提示）。
- **M2c 好友开房准备（✅ 2026-07-14·特意选不依赖公网选型的部分先做）**：①**局域网房间发现**：`src/net/lan_discovery.gd`（Beacon=UDP 信标广播 255.255.255.255+127.0.0.1 双投·Browser=收信标建房间表·信标只带公开信息「房名/端口/版本/是否有口令」·包体/表上限洪水防护）+ 大厅「附近的房间」列表点击即入（房主停 Browser 腾发现端口·同机双开可测）。②**房号短码**：`src/net/room_code.gd`（IPv4↔Crockford Base32 七字符+校验和="XXXX-XXXX"·容错大小写/连字符/易混字符·建房状态栏展示·加入框通吃 IP 或房号）。③**房间口令**：hello 加可选 `pass` 字段（≤16·validate_c2s 限型限长）·准入门内置 `net_session.poll_prestart`（大厅与探针共用同一实现）·**重连 hello 同过口令门**（防陌生人趁好友掉线抢唯一席位）。④**版本握手**：hello 加 `gv` 字段·不合回 `error{code=bad_version, detail=房主版本}`·信标带版本→列表预警。验证=GUT 30 脚本 376 用例（room_code/lan_discovery/协议扩展/口令门）+ `tools/lan_probe`（真 UDP 发现 + 真 ENet 三路准入：错口令拒/错版本拒/对口令开局）。**捎带修出两个现役潜伏坑**：(a) `is_link_ready()` 原来直调 `enet.poll()`=收到的业务包整批被丢（"吃包"·现役大厅靠帧序运气没炸）→ 传输层新增 `pump_only()`（只泵不取包）；(b) 拒绝后立踢与 error 包赛跑=对端收不到拒绝原因 → `KICK_GRACE_MS=300` 延迟踢兜底。
- **M2d BP 联机化·逻辑层（✅ 2026-07-17 打地基批·UI 接线待 BP 总风格定案=任务12）**：开局前置 BP 权威阶段——①协议扩展：hello 空 team=BP 流程报到（阵容由 BP 决出）·C2S 加 `bp_progress{n}`（已亮张数·服务器只转发数字不带内容=对手席盖牌演出的真信号源）与 `bp_confirm{picks}`·S2C 加 `bp_start{you,pool}/bp_progress/bp_reveal{picks×2 绝对视角}`。②`src/net/bp_room.gd`=权威房间（match_room 同款纯逻辑+send_cb·pick-only 同时盲选与本地 BP 同制·二道门=池内+队内禁重复·镜像合法·服务端权威计时超时随机代选·BP 期重连=补发 bp_start+对方进度·防洪令牌桶同参）。③`src/net/bp_client.gd`=客户端端（⚠不自己 poll——与 MatchClient 同传输抢包·由 net_session.pump_bp 统一收包按 kind 路由 feed）。④net_session：`start_bp/ensure_bp_client/pump_bp`（与 pump 互斥使用·bp_reveal 后房主拿 `bp.teams()` 换 HeroData 走 start_room=战斗照旧）。GUT=test_bp_room 8 例（双端揭晓一致/进度只转对方/非法提交全拒/超时代选/协议形状）。
- **M2e 匹配流程骨架（✅ 2026-07-17 打地基批·任务11「匹配画面」的逻辑层·画面/动画待 Eddy 方向）**：`src/net/matchmaker.gd`=快速匹配状态机（SEARCHING 扫信标窗口→有合格房「开放+版本一致」=CONNECTING 拨号→MATCHED(join)；没房=HOSTING 建房+信标等对端→MATCHED(host)；cancel/总超时/拨不通拉黑回搜全覆盖·发现端口被占降级直接建房）。browser/beacon/建房拨号全走可注入适配器（真实件=LanDiscovery+NetSession·GUT 假件零 socket=test_matchmaker 7 例）。⚠已知局限记录在案：双方同时开匹配且互没见信标=对称建房竞态（公网 backend 天然解决·LAN 版不另修）。MATCHED 后 session 所有权移交调用方接 hello/BP 流程。
- **M2f 审计修复批（✅ 2026-07-17·外部 agent 审计 5 条·4.5 条成立全修）**：①**同时结算归因偏置（战斗核公平性）**——施加段固定 p0→p1 序，先施加方触发后施加方护主换人后，后者 on-hit 回调按实时 `active_index` 归因给顶班天狗=先后手不对称；修=hit 生成时记 `src_slot`、`_apply_damage` 加 `attacker_slot` 尾参（-1=原语义·独立 hit 不受影响），回归测试=test_simultaneous_attribution（h20 印记归因+基线双例）。②**提交后经济逃逸**——已提交方仍可 draft/refill/pick 改真局 → 缓存动作预检失效静默部分应用；修=`_econ_gate`（提交即冻结经济·回 already_submitted）+ `_commit_and_resolve` 落局失败 push_error 可见化。③**快照私有信息泄漏**——全量快照广播含双方 draft/upg_draft 候选=「只发本人」的后门；修=`_snap_for(viewer)` 按接收者剥对方候选+info_distortion（全部 6 个快照出点统一走此口·本人侧原样=UI/重连零影响）。④**测试环境不可复现**——GUT 整目录被 .gitignore 忽略且无版本锁；修=GUT 9.6.0 入库（2.9MB/248 文件·测试框架随仓库走）。⑤**发布构建不可复现**——部分成立：export_presets.cfg 本机尚不存在（未到导出期）且含密钥不可入公开仓库；修=约定入档 pck-encryption-guide「导出配置可复现性」节（发布期建脱敏 example 模板入库·真文件持续忽略）。GUT 38 脚本 423 用例绿+net_probe PASS。
- **M2g 审计二轮（✅ 2026-07-17·外部审计第二批 6 条·5 条处置 1 条待拍板）**：①**死亡换人期重连恢复**——旧行为：DEATH_SWITCH 期没有 turn_begin 可跟且 match_client "snapshot" 分支不恢复相位 → 重连方 UI 干等服务器 20s 代选；修=snapshot 分支按房间 phase+pending_death_switch[you] 恢复（"death_switch"/"waiting"/"over"）+ battle_screen._net_pump 检测 client.phase 弹换人浮窗（_net_resume_death_switch·_net_busy 自守防双弹）；测试=test_match_room 重连相位用例。②**AI 深层剪枝合法性**——_shortlist「攒恒合法」假设早于 h17 锁招机制（锁定动作可执行时攒非法）·切换分支同样没过门 → 非法行稀释深层收益矩阵；修=攒/切换均过 can_afford（与顶层 legal_actions 同一收口·⚠AI 估值精度提升=下轮 sim 大轮基线可能微移）；测试=test_ai_shortlist_legality 3 例。③调试面收口补注：运行时双门已足（联机禁用+is_debug_build）·脚本本体剥离=导出过滤排除 src/ui/debug/**+tools/**（已入 pck 指南发布清单）。④README×2 测试计数过时已更（precise 数标日期以实跑为准）+docs/README 补 ADR-003/004 索引。⑤hd2d 原型引用已废 h30/h38=README 标注存档不可跑（原型隔离区不改代码）。⑥battle_screen 3042 行/143 函数拆分=**待 Eddy 拍板**（大手术·建议挂任务13 或联机 UI 接线批一并）。
- **M2b 服务端工程（剩余）**：进程托管（headless Godot 复用 sim 启动器骨架）+ 公网匹配服务 + 多房间 + 信息扭曲道具的视角假数据渲染（道具真立项时·快照私有字段过滤已在 M2f 落地）+ 公网方案（个人项目候选：Steam P2P / 轻量中转服·需 Eddy 选型·⚠公网化时 DTLS client_unsafe 须升级正经证书或平台通道）。
- **M3 反作弊面收口**：联机构建禁用 src/ui/debug；回合时限服务端计时；提交去重（turn 号幂等）。
- **M4 i18n 抽取（✅ 主体 2026-07-12）**：方案=**「原文即键」**（中文原文即翻译键；未注册翻译表时 `tr()` 原样返回=零行为变化，`.tscn` 文本零改动=Godot 自动翻译按原文查表，Eddy 编辑器所见仍是中文）。已做：①UI/story 代码显示点全量 `tr()` 包裹（字面量就地包·模板在拼接处包·数据文案在显示汇点包 `tr(变量)`·逻辑键不包）；②键表生成器 `tools/i18n_scan.gd`（可重复跑）→ `assets/i18n/strings_zh.csv` 389 键（含英雄 .tres/道具 catalog/levels.json/.tscn 文本·带出处 context 列）；③GUT 28 脚本 360 用例全绿。**剩余（激活翻译时做）**：填 en 列 → 去 context 列 → 移除 `assets/i18n/.gdignore` → project.godot 注册 translations（风险操作·届时批准）。**明示缓办**：src/expedition（占位内容等 F/G/H 重做）、debug 面板（release 剥离）、标题屏像素字形字（美术资产范畴）。
- **M5 账号/变现**：F2P 外观·绝不卖强度（Eddy 定·另立项）。

## Consequences

- 现在起新增引擎状态字段必须同步三处：`clone()`、`to_snapshot()/from_snapshot()`、快照测试 —— 已在两处函数头注释标明。
- 快照测试 + 边界守卫进入常绿基线（GUT 26 脚本 345 用例），任何破坏联机前提的改动会在本地就被测试拦下。
- 服务端选型钉死 headless Godot（与 sim 同栈），排除自研协议服务器/其他语言重写 —— 若未来推翻此选型需重开 ADR。
