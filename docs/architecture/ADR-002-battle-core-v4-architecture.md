# ADR-002: Battle Core v4 架构（英雄重写）

> **✅ 实施状态（2026-05-25 更新）**：S1-S3 swap 已全部落地 —— v4 上移到 `src/battle/`、类名去 V4 后缀（`BattleCore`/`ActionDef`/`HeroSkill`）、`battle_engine.gd`→`battle_core.gd`、v3 旧核全删。下文"待实施/将/重写"等措辞为决策当时的计划态，现已完成；正文作决策溯源保留。真相源 = `src/battle/` + `tests/unit/battle/v4/`。
> **⚠ 英雄阵容**：本文英雄示例基于旧 34 阵容；大阿卡那(h13-h34)+星座(h35-h46)已弃（2026-06-19），槽位复用为暗生肖，现 24（h01–h24：12 生肖 + 12 暗生肖）。

| 字段 | 值 |
|------|-----|
| **Status** | ✅ Accepted（Eddy 审批 2026-05-25，Q1–Q5 已裁定） |
| **Date** | 2026-05-25 |
| **Author** | Eddy + Claude |
| **Supersedes** | ADR-001 §D4（"HeroSkill 迁移暂停"——重启条件已满足，见 Context） |
| **Related** | `hero-mechanics-hook-matrix.md`（⚠ 链接失效·该文件已删 / 不存在）、`tests/BEHAVIOR_NOTES.md`、`battlecore-risk-notes.md`、`design/heroes.md`、`design/heroes-schools.md` |

---

## Context

### 为什么是现在重写

ADR-001 §D4（2026-05-18）决定**暂停** HeroSkill 组件化迁移，明确**重启条件 = "英雄设计稳定（`design/heroes.md` 过渡版声明被撤销）"**。该条件现已满足：

- `design/heroes.md §1` 收录 **12 生肖**（h01-h12）。
- 新数值框架已定（HP 3-7 / 大波 3 能 / 切换 0 能占槽 / 初始 1 能），与现实现的旧数值不同。
- 13 生肖中多数被**推倒重做**（机制全换）。

### 现状（Current）与新设计的鸿沟

`src/battle/battle_core.gd`（727 行）实现的是**旧 13 英雄 v3 kit + 旧数值**：英雄逻辑 hardcoded 散落在 `resolve()` 6 个 phase（`hero_id==` / `passive_id==` 判断 + 8 个瞬态状态数组 + 每个专属动作一个 enum）。这套模式：

1. 在 13 英雄时已经半脏（ADR-001 自评 god class）。
2. 新设计需要它**完全没有的能力**（详见 `hero-mechanics-hook-matrix.md §4` — ⚠ 链接失效·该文件已删 / 不存在）：0.5 半血、随切换保留的状态、变身、延迟/转移伤害、替补参战、全场 AOE、无视防御处决、契约绑定。
3. 若照此模式硬塞 34→46 英雄 → 必然膨胀为不可维护的 god class。

### 已验证、必须保留的资产

重写**不是白纸重来**。下列经验证的东西必须带进 v4，否则会把已解决的 bug 再踩一遍：

- **同时独立结算模型**（`BEHAVIOR_NOTES` B-001/002/003，Eddy 已裁定为正式行为）：双方各自独立解算伤害、不抵消。
- 已解决的边界（B-004 resolve guard / B-005 / B-006 / B-007 winner 常量）。
- `battlecore-risk-notes` 的 6 条隐式规则（尤其 H2 攻击→防御→路由链、H5 shield 按 slot、H6 RNG 无注入）。
- 架构形态：纯 `RefCounted`、无 UI 依赖、`resolve()` 返回结构化 events、read-only views——这是**本地权威 headless 运行与可复现测试**的前提（ADR-001 D2/D3/D5）。

---

## Decisions

### D1：有原则的重写，不是迁移；保留/重写边界

**Decision**：保留并扩展核心骨架，**重写英雄层**。

| 保留（重用） | 重写 / 丢弃 |
|---|---|
| 同时独立结算模型（B-001/2/3） | 13 个英雄的具体实现 |
| `resolve()` 分相位 + 结构化 events + read-only views + 纯 RefCounted | 散落各 phase 的 `hero_id==` / `passive_id==` 硬编码调度 |
| EventFormatter 对外契约（ADR-001 D2/D3） | 旧 EXTRA_ACTION enum（每英雄一个动作）+ 8 个瞬态状态数组 |
| 已解决边界知识（B-004~007 + 6 隐式规则） | 旧数值（全换新框架，D10） |

**Migration Risks**：旧 13 英雄行为不保留——但它们本就在重做，这是有意替换，不是回归。
**Rationale**：迁移旧英雄逻辑 = 把要扔的东西搬进新家；散点模式正是要逃离的对象。但核心结算/事件/边界知识是中立资产，重写它们只会重新引入 bug。

---

### D2：英雄 = 组件文件 + 双接口（被动 hook + 主动技），组件**无状态**

**决策时现状**：仅 h05 是组件（当时为 `skills/chenlong.gd`；现行重设计实现为 `skills/h05_longyuji.gd`），其余 12 个 hardcoded；基类当时只有 1 个 hook。

**Decision**：
- 每个英雄 = `src/battle/skills/hXX_<name>.gd`，继承 `HeroSkill`，自带：
  - **被动 hook 覆盖**（按需 override，默认 no-op）；
  - **可选主动技声明 + execute**（见 D9）。
- **组件实例不持有可变游戏状态**——所有 per-hero 状态存在引擎的状态容器里（D5）。组件是纯逻辑（读写 battle 传入的状态）。
- 加 / 删 / 重做一个英雄 = 动一个文件。

**Migration Risks**：组件数从 1 → 34；但每个是小文件、互不耦合。
**Rationale**：
- 无状态组件 → 战斗状态全在可序列化容器里 → **快照 / 录像重放 / 存档**都只序列化容器，不碰组件实例。
- 每英雄隔离 → "后续好不好改"= 改一个文件，改动局部化。
- **本决议正式撤销 ADR-001 §D4 的"不预设 hook 列表"**：当时理由是"设计未稳，抽象会被稀释"；现设计已稳（34 定稿），按真实需求一次性设计 hook 集是恰当的（见 D6，hook 全部来自 `matrix §3`，无投机抽象）。

---

### D3：HP / 伤害用**整数半点**（×2 内部表示），支持 0.5 且确定性

**Current**：HP 是 `int`，无半血。
**新需求**：h18 / h24 / h30 / h31 需要 0.5 增量（`matrix §4①`）。

**Decision**：内部所有 HP / 伤害以**半点整数**存储（`1 HP = 2 半点`），显示层 ÷2。
- 死亡判定：`half_hp <= 0`。
- "减半"= 整数除 2（取整规则见 Open Question Q2）。

**Migration Risks**：所有读写 HP / 伤害的代码、测试、UI 显示要按半点改；这是 v4 一次性建好的底层，不在英雄铺设后再改。
**Rationale**：
- **确定性** > 浮点：半点整数没有跨平台浮点漂移风险，便于本地测试、录像与存档精确重放。
- 避开浮点等值比较 bug。
- 备选（float HP）见 Alternatives——因确定性被否。

---

### D4：伤害管线 —— 固定相位顺序（**承重决策**）

**Current**：伤害散在 `_calc_attack_raw` → `_apply_defense` → `_route_damage` + phase 3，英雄修正硬插其间。
**Decision**：单一 `apply_damage(target, raw, source, flags)`，**固定有序相位**，hook / 状态挂在相位上。**保留 B-001/2/3 同时独立结算**（双方攻击各自走一遍此管线）。

**A. 出伤（攻方声明时）**
1. 基础伤害（波=1 / 大波=2，新数值）
2. `modify_outgoing_damage` hook（攻方组件 + 自 buff）：怒目 / 渴血 / 天威 / 凶兽 / 啼晓 / 孤注(RNG×2) / 蓄势 / 恶魔契约 / 月相(造成 ×0.5、×2)

**B. 受伤（命中具体目标时）**
3. 易伤（燃烧 h32 +1）+ 月相(受到 ×0.5、×2，目标=月亮时)
4. **防御动作门**：大防挡全部 / 防挡波（除非 pierce_defense）
5. 平减（下限 0，可叠加）：三窟消层
6. 护甲吸收（除非 pierce_shield）
7. 转移 / 分担：星星 h30 把剩余实际伤对半分给替补星星
8. 延迟：节制 h27，>1 则本回合受 1、余入 pending
9. 落 HP（半点）

**C. 结算后（本回合全部伤害落完）**
10. **批量死亡判定**：收集所有 HP≤0
11. 死亡拦截 hook：蛇蜕重生（置 2HP）
12. 死亡触发（定序）：`on_kill`（渴血+1 / 死神回血 / 塔溢出）→ `on_death`（寅虎清零 / 恶魔解约）→ `on_ally_death`（恋人殉情 / 隐者叠加）
13. 连锁：溢出/殉情可致新死亡 → 重跑批量判定，带防无限连锁 guard（h29 溢出致死不再触发 splash）
14. 强制切换阵亡出战位

**特殊动作注入点**：
- 处决 h33：在 C 死亡判定前，对手出战 HP≤阈值 → 直接置 0（绕过 A/B）。
- AOE h34：对全场除己施 pierce 1 伤 → 汇入 C 批量判定。
- HP 平衡 h24：扶倾 = A 之前写 HP；清算 = C 死亡判定之后写 HP。

**Migration Risks**：相位顺序错 → 减免/护甲/转移/延迟叠加结果错。需 Eddy 签字确认顺序（Open Question Q1）。
**Rationale**：30+ 英雄的可组合性全靠这条固定管线；hook 挂相位而非散插，是 god class 的根治。

---

### D5：每槽位状态容器（随切换保留），引擎统一 tick 时长

**Decision**：`statuses[player][slot]` = 一组 StatusEffect（`{id, magnitude, duration, source}`）+ 结构化字段。承载：
- 自身状态：毒素(h06) / 剑气(h10) / 脆弱(h20) / 变身 form
- 他人施加的 debuff：燃烧(h32) / 沉默(h15) / 易伤
- 绑定：挚爱(h19) / 契约(h28) 存 `link[player]`

引擎在 `on_turn_start` 统一递减 duration、结算 pending 伤害(h27)。组件读写容器，**自身不存状态**（D2）。

**Migration Risks**：需定义 StatusEffect 数据形状 + 哪些随切换保留 / 哪些下场清。
**Rationale**：统一容器 → 可序列化（快照/录像/存档）；"benched 仍保留的状态"（燃烧/窟/蓄势）有处可存；沉默(h15)只需在容器置 flag，引擎触发被动 hook 前检查跳过。

---

### D6：Hook 集（一次性按真实需求定，不投机）

**Decision**：`HeroSkill` 基类提供以下 hook，全部 no-op 默认，全部来自 `matrix §3`（无"未来可能需要"的投机 hook）：

被动 hook：
`on_setup` · `modify_outgoing_damage` · `modify_incoming_damage` · `on_ally_take_damage`(后排参战) · `on_kill` · `on_death` · `on_ally_death` · `on_before_death` · `on_switch_in` · `on_switch_out` · `on_enemy_switch_out` · `on_resolve_end` · `on_turn_start`

作用域规则：多数 hook 只对**出战英雄**触发；明确的**团队级 hook**（`on_ally_take_damage` 后排分担 h30、契约扣血 h28）对**含替补的全 3 槽**扫描。

**Migration Risks**：13 个 hook 比当前 1 个多——但每个落地由对应英雄驱动（增量实现），ADR 只是把目标集一次性写明，让管线设计为其留位。
**Rationale**：设计已稳，预先定形是正收益（ADR-001 D4 的反向条件成立）。

---

### D7：可 seed 的 RNG 注入（修 H6）

**Current**：`randi_range` 直调，无法重放。
**Decision**：BattleCore 持有 `RandomNumberGenerator`（构造/ setup 时传入 seed）；所有技能与道具随机分支统一走它。
**Rationale**：本地结算一致性 + 测试确定性 + 录像重放。seed 由战斗会话入口统一确定。

---

### D8：批量死亡判定 + 死亡触发定序（修多目标连锁）

**Current**：phase 5 逐 player 检查出战位死亡，无多目标 / 替补死亡概念。
**Decision**：见 D4 相位 C。死亡判定收集全场 HP≤0、统一拦截重生、按 `on_kill→on_death→on_ally_death` 定序触发、连锁带防无限 guard。
**Rationale**：h34 AOE / h29 溢出是首批多目标连锁死亡场景，必须有确定的触发顺序，否则不同执行入口会产生不一致。

---

### D9：通用主动技框架（费用 / cap / execute + 三个动作经济例外）

**Decision**：主动技英雄的组件声明 `ActiveAbilitySpec{action_id, cost, per_game_cap, occupies_slot, target_type}` + `can_use()` + `execute(battle, player, slot)`。引擎统一处理：
- **每局 cap N**（h01/07/12/13/14/15/16/24/26/32/33 共用；h17/20/34 无 cap）
- **动作槽例外**：千里快哉风 h07（0 能不占槽，方案 C 英雄级唯一例外）
- **动作复制**：梅开二度 h14（下一动作 ×2）
- **动作锁定**：保留基建（原 h17 使用；2026-08-06 重设计后暂无英雄施加者）
- **结算时机选择**：天平归衡 h24（玩家选 扶倾/清算 注入点）——元机制，特殊处理

**Rationale**：主动技的 cap / 扣能 / 可用性是横切样板，统一比每英雄重写省且一致。

---

### D10：新数值框架常量

**Decision**（数据驱动，常量集中，禁硬编码散落）：
- 英雄 HP：3–7（逐英雄存 `.tres`，见 `matrix` 各 HP）
- 大波：3 能（曾短暂改为 2、现已改回 3）
- 切换：0 能、占动作槽（h07 唯一例外）
- 初始能量：1
- （回合上限 / 节奏待 GDD 复核）

**Migration Risks**：与旧数值不兼容，旧测试作废（D11）。

---

### D11：测试策略

**Decision**：
- 旧 GUT 测试锁的是旧英雄 / 旧数值 → 重写后**大半退役**（移入归档或删除，由 Eddy 定）。这不违反 `current-behavior-lock-policy`——锁的就是要替换的行为。
- 新核按 `coding-standards` 先写测试：① 基础动作同时结算矩阵（移植 B-001/2/3 为新数值版）② 伤害管线各相位（减免/护甲/转移/延迟/穿透叠加）③ 每个英雄 2-3 个核心 case ④ 半点 HP / RNG 可复现 / 批量死亡定序。
- `BEHAVIOR_NOTES` 的 B-001~007 结论作为**新核设计输入**保留引用。

---

## Consequences

**解锁**：每英雄一个文件、改动局部化；无状态组件 + 半点整数 + seed RNG → 本地可复现 / 录像 / 存档具备前提；可组合伤害管线支撑英雄机制多样性。
**成本**：一次性建底层（半点 HP / 状态容器 / 管线 / hook 集 / 死亡定序）工作量集中在前期；旧测试退役要重写。
**不变**：纯 RefCounted、无 UI 依赖、结构化 events、EventFormatter 契约（ADR-001 D2/D3/D5 延续）。

---

## Alternatives Considered

| 决策 | 备选 | 拒绝理由 |
|------|------|---------|
| D1 | 迁移旧英雄到组件 | 旧英雄在重做，迁移是白费；且不解决新机制缺基建 |
| D1 | 整个 battle_core 白纸重写 | 会重新引入 B-001~007 已解决的 bug、丢失边界知识 |
| D2 | 组件持有自身状态（有状态组件） | 难序列化 → 阻碍快照 / 存档；改用无状态 + 容器 |
| D3 | float HP | 跨平台浮点漂移威胁 BattleCore 权威确定性；半点整数无此问题 |
| D4 | 各英雄自行散插伤害修正（沿用旧法） | 正是 god class 根因；叠加顺序不可控 |
| D6 | 沿用 ADR-001 D4"按需逐个加 hook，不预设" | 该决议前提是"设计未稳"，现已稳定，预先定形是正收益 |

---

## ✅ Resolved Questions（2026-05-25 Eddy 裁定）

| # | 问题 | 裁定 |
|---|------|------|
| **Q1** | 伤害管线相位顺序（D4） | ✅ **同意**——顺序按逻辑走（转移→护甲→延迟→落 HP）。 |
| **Q2** | 半血取整（D3） | ✅ **半点整数、不取整**：所有伤害是 0.5 的倍数，0.5 = 最小伤害，0.5 真实存在。内部 1 HP = 2 半点。 |
| **Q3** | 旧 GUT 测试退役 | ✅ **Claude 自定**——移 `tests/_archive/` 或删除皆可。 |
| **Q4** | h27 延迟伤害 | ✅ **a 不再平滑**（欠账下回合全额落）+ **b 仍落地**（节制切到替补，欠账照砸）。 |
| **Q5** | h29 溢出连锁 | ✅ **否**——溢出只触发一次，被溢出炸死的替补不再产生新溢出（防无限连锁）。 |
| **Q5b** | h29 溢出分摊（Eddy 补充 edge case） | ✅ 溢出**平均分摊**给当时存活的对手替补，落 0.5 档；除不尽时各向下取整到 0.5、余量（0.5 单位）给靠前替补，**总溢出守恒、确定可复现**。 |

---

## 实装顺序（批准后）

1. **底层基建**（一次建好）：半点 HP / StatusEffect 容器 / 伤害管线相位 / HeroSkill hook 集 / seed RNG / 批量死亡定序 / 主动技框架。
2. **基础动作 + 数值**（新框架）+ 其测试（B-001/2/3 新数值版）。
3. **MVP 切片**：挑覆盖各机制类的 8–12 英雄（建议含：自 buff 被动 / 主动扣能 / 团队层 / 状态附加 / 变身 / 半血 / 替补参战 各 1），逐个建组件 + 测试。
4. **试玩切片** → 回答"好不好玩" + 清 playtest 旗标。
5. **批量铺其余英雄**（此时每个 = 一个 hook 组件文件，便宜）。

---

## 修订历史

| 日期 | 修订 | 作者 |
|------|------|------|
| 2026-05-25 | 初版 Proposed（B 阶段第 1 步产出） | Eddy + Claude |
| 2026-05-25 | Accepted — Q1–Q5 + Q5b 裁定，进 Step 2 实装 | Eddy |
