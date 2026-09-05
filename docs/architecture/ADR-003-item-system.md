# ADR-003: 道具系统架构（完整目标态）

> 🔴 **当前目标已由 2026-08-30 标准取代：**本 ADR 的自动解锁、固定 1 能补充 / 升级、T1-only 抽取、通用升阶、使用免费与使用即清槽全部只作旧架构溯源。当前通用规则为：有空公开框时每回合一次手动免费真实背包三选一，选中结果公开并锁定本回合；每件道具每次使用支付自身 `0–4` 能费用并扣 1 耐久；T1/T2/T3 成品同池准入，不设通用升金。唯一当前入口见 [`2026-08-30-item-system-current-standard.md`](../superpowers/specs/2026-08-30-item-system-current-standard.md)，五维平衡见 [`2026-08-30-item-four-axis-balance-design.md`](../superpowers/specs/2026-08-30-item-four-axis-balance-design.md)。现有运行时尚未迁移，不得把下文旧 `ItemData` / 槽状态当成新实现说明。
>
> 🔶 **状态更新（2026-08-28·有序施放交互）**：采用“本地编排、最终整体提交”。按住左键拖出但未松手只作预览；在合法区域松手才视为释放、播放本地动画并追加有序步骤。最终确认后，BattleCore 原子校验并权威重放完整序列。下文 `pre_items` / `post_items` 与 `ANY 默认入 PRE` 是早期数据结构方案，不再是交互真相源；实施时应升级为能表达 `[道具, 动作, 道具]` 的统一步骤序列。详见 [`2026-08-28-item-sequence-interaction-design.md`](../superpowers/specs/2026-08-28-item-sequence-interaction-design.md)。
>
> ◻ **历史状态（2026-08-16·普通/稀有/传说连接件扩充）**：当时首发池为 **96 件（T1 31 / T2 39 / T3 26）**，审批全集池为 **145 件**，并曾使用 T2/T3 固定目录估值 4/6。该数值与池数量不是 2026-08-30 后的新设计真相。
>
> **持续效果与物理耐久分账**：跨回合效果继续登记到权威 `relics`，其中 `charges` / `turns` 是效果自己的次数或期限；物理道具实例另记 `max_durability` / `remaining_durability`。持续效果触发不重复扣物理耐久，只有权威道具使用事件扣 1。
>
> **本批特殊结算契约**：散契钟只移除双方仍在持续的道具状态，不回滚已结算数值且不清除英雄技能状态；均能斗在双方原行动完成能量收支后合并均分；清囊火盆在回合被动前烧掉双方仍可使用的道具并按所属方逐件返能；聚宝盆在回合经济清理后向一个空槽随机补入 T1；连环鼓依次结算两个不同公共行动，第二行动不允许切换或英雄技能。
>
> **2026-08-10 审计补充**：还魂丹每名英雄整局限用一次，并由统一致命 HP 减少闸口覆盖伤害、生命支付、失去生命与规则处决；天罗地网只撤销对手本回合首件合法道具，同时继续令其切换无效，选择期即时效果通过首件前快照与后续道具重放保持原子性。
>
> **2026-08-16 回合末登场补充**：候阵签在攻击、规则处决与遗物回合末效果完成后兑现。原出战英雄存活时走完整切换链并受切换封锁；原出战英雄已阵亡时直接完成预定死亡补位，不伪造切换触发。

> ◻ **历史状态（2026-07-03·经济重做=免入场税）**：当时 D5 经济状态机曾改为：
> **三格第 3/4/5 回合（显示）自动解锁（免费·无开格）**；格 1 自带随机 T1（后期玩家自选 T1/T2 携带·PvE）、格 2/3 解锁当回合 T1 池 3 选 1；
> **统一锁定规则** = 新道具（自带/抽/补/升级）出现当回合锁定（明牌电报）、下回合可用；**补充 1 能 / 升级统一 1 能（T1→2 与 T2→3 同价）**；抽卡池 = T1 only（T2/T3 只走升级线）。
> 动机：被动能量删除（2026-06-24）后道具费用被定价出局（搜索 AI 实测只刷小波、道具层沦为累赘）→ 刹车从能量改为时间锁。
> 同日后续：sim 实锤攒-only 下 AI 自对弈死龟锁（90%+ 打满回合上限）→ **被动 +1 能/回合已恢复（PASSIVE_ENERGY_GAIN=2·Eddy 决策 A）**，本文各处「PASSIVE=0/被动已删」注记已过时。
> 这些规则及下文 D5 三步电报/费率都仅作溯源；2026-08-30 目标规则见本文顶部新状态块，代码仍是迁移前现状。

> 🔶 **状态更新（2026-06-28）**：本 ADR 写于 2026-06-18，描述的是当时 91 件「完整目标态」。**当前首发已收敛为 61 件**（T1 20/T2 24/T3 17），**首发真相源 = `design/items-firstrelease.md`**（不再是 items.md）。下文 91 件方案作设计溯源保留。另：文中「被动 +1 能/回合」已废除（现 PASSIVE=0），大波维持 3 能。

> **本 ADR = 道具系统的目标态架构**（Eddy 既定序列 B 能量经济 → **A 道具 ADR**（本文）→ 实装）。
> 范围由 Eddy 拍板 **= B「完整目标态一次到位」**：核心架构 + 完整经济状态机 + 全部新引擎能力详设 + 91 件落地映射。
> AI 道具策略 **= A「首版 AI 道具-blind」**，且 **AI 道具相关逻辑等本系统完整设计/实装后再加**（D9）。
> 设计真相源 = `design/items.md`（91 件清单 + §0 规范）+ `design/build-design-framework.md`（§2 骨架 / §4 汇率）。

| 字段 | 值 |
|------|-----|
| **Status** | ✅ Accepted（Eddy 审批 2026-06-18·Q1–Q5 全裁定） |
| **Date** | 2026-06-18 |
| **Author** | Eddy + Claude |
| **Supersedes** | `potion-system-concept`（旧药水设想，已被 §2 骨架取代） |
| **Related** | ADR-001（BattleCore 边界）、ADR-002（v4 架构·本 ADR 复用其管线/hook 范式）、`design/items.md`、`design/build-design-framework.md §2/§4`、memory `item-system-skeleton`/`item-design-catalog`/`defense-armor-absorption-model`/`synergy-master-theorem`/`energy-pool-is-team-global` |

---

## Context

### 为什么是现在

能量经济迁移（B）已完成，半能制 + 大波 3 能 + 被动能量已删（PASSIVE=0）——**能量作为「超模总闸门」的前提就绪**（§2 骨架：道具的获取/升级/refill 全吃能量）。道具是本作 build 深度的主体层（§3「浅而广」：6 元件里最多 3 个是道具）；91 件设计全集已定稿，进入实装前必须先锁架构。

### 现状（Current）与道具需求的鸿沟

`src/battle/battle_core.gd` 现状（v4 已实装）：
- **回合模型 = 每方一个动作**：`selected_action[player]`（单 int）+ `selected_target` + `_switch_to`，`resolve()` 走固定相位，**跨玩家同时独立结算**（B-001/2/3）。
- **无道具概念**：无道具数据、无道具栏状态、无序列编排。
- 能量 = 团队共享池 `energy[2]`，是唯一稀缺资源（[[energy-pool-is-team-global]]）。
- 防御 = 二元铁则（[[defense-armor-absorption-model]]）：力量=WHETHER 非 HOW MUCH；护甲=额外血量层（`shield[]`）；穿透三档（`Pen.NORMAL/PIERCE_DEF/PIERCE_BIGDEF/TRUE_DMG`）。

道具需要它**完全没有的能力**（详见 §0.1/§2）：
1. 一回合提交 = **有序序列** `[道具…, 动作, 道具…]`（道具**不占动作槽**、用时免费、用量不限）。
2. 道具**揭示前盲选提交**、对对手**公开**、**默认自动指向**。
3. 局内**经济状态机**：3 槽「开格→抽→可用」三步电报（各锁 1 回合）+ 局内 3 选 1 draft + 升级（1→2 花 1 能 / 2→3 花 2 能）+ refill（1 能）。
4. 一批**异类引擎能力**：自结算 DoT / 假·隐藏道具 / 条件改穿透·防御等级 / 读对手动作 / 元件层干扰 / 共鸣同回合配对 / 穿甲（无视护甲层）。

### 必须保留的不变量

- **同时独立结算**（B-001/2/3）：跨玩家无先后手、对攻不抵消、可同时死=平局。道具的「顺序」只作用于**己方回合内**（§D4），**绝不在两玩家间制造先后手**。
- **纯 RefCounted、无 UI 依赖、`resolve()` 返回结构化 events、可 seed RNG、可 `clone()`**（本地权威 headless 与可复现测试的前提，ADR-001/002 延续）。
- **二元防御铁则**（[[defense-armor-absorption-model]]）：道具的护甲/护甲 = 额外血量层（`shield`），**禁临时护甲吸收模型**；穿甲 = 无视护甲层但仍受「挡不挡」约束。
- **能量总闸门**：道具不引入新资源；获取/升级/refill 全从 `energy[]` 团队池支出。

---

## Decisions

### D1：道具 = 数据 Resource + 逻辑组件，镜像英雄 `HeroData`/`HeroSkill`

**Current**：英雄已是「`HeroData`（数据 .tres）+ `HeroSkill`（无状态逻辑组件，按 hero_id 注册）」二分（ADR-002 D2）。道具无任何对应物。

**Decision**：道具沿用同构二分。

- **`ItemData`**（`class_name ItemData extends Resource`，数据源 `assets/data/items/*.tres`，一件一文件、editor 可直改）。字段：
  | 字段 | 类型 | 说明 |
  |---|---|---|
  | `item_id` | String | `t1_xxx` / `t2_xxx` / `t3_xxx`（tier 前缀 + 蛇形名） |
  | `item_name` | String | 展示名（奇幻调性，§0.5） |
  | `tier` | int | 1/2/3 |
  | `dimension` | String | 6 维之一（进攻/防御/能量/节奏/状态/干扰），draft 加权用 |
  | `role` | String | 元件角色（填隙/导出/泛连携/自成核/回路/共鸣/干扰），可空 |
  | `ev_half` | int | 设计 EV（半点），平衡核对/draft 偏置用 |
  | `target_mode` | int | 指向枚举（见 D6）：AUTO_ENEMY/AUTO_SELF/SPECIAL |
  | `sequence_tag` | int | 序列标签（见 D2）：PRE/POST/ANY |
  | `resonance` | bool | 是否带〔共鸣〕标记（§0.9 / D7-6） |
  | `upgrade_to` | String | 升级线下一级 item_id（劣质→普通→上等），无则空 |
  | `params` | Dictionary | 效果参数（伤害/治疗/层数/能量等半点数值），由 `ItemEffect` 读取 |
  | `skill_detail` / `picture` | String | 文案/画面（图鉴/道具栏展示） |

- **`ItemEffect`**（`@abstract class_name ItemEffect extends RefCounted`，每件 = `src/battle/items/<item_id>.gd`，**组件无状态**——所有运行时状态进 BattleCore 容器，同 ADR-002 §D2）。契约见 D4。
- **注册表** `_ITEM_EFFECT_SCRIPTS: { item_id → preload(script) }`（同 `_HERO_SKILL_SCRIPTS`），`setup()` 时按持有道具装配，带一次性静态校验（key 格式 + 子类校验）。
- **地板池加载**：`ItemData.create_floor_pool()` 扫 `assets/data/items/*.tres`（同 `HeroData.create_pool_heroes`）；养成特色件后续叠加（§2 池子模型）。

**Migration Risks**：新增两个类 + 一棵 `items/` 组件树（91 件最终各一文件，但增量实装、互不耦合）。
**Rationale**：与英雄系统范式一致 → 同样可序列化（快照/录像/存档只序列化容器）、editor 数据驱动、一件一文件改动局部化。无状态组件是可复现状态的硬需求。

---

### D2：回合模型 —— `selected_action` 扩成 `turn_plan`（经济 + 有序序列 + 单动作）

**Current**：`selected_action[player]: int` + `selected_target[player]` + `_switch_to[player]`，每方恰好一个动作。

**Decision**：每方提交一个 **`turn_plan`**（盲选、揭示前提交，§3A）：

```
turn_plan[player] = {
    economy_ops: Array,   # 经济操作（点亮槽/refill/升级），序列最前结算（§D4）
    pre_items:   Array,   # 动作【前】使用的道具（有序）：[{slot:int, target:int}, ...]
    action:      int,     # 唯一基础/主动/切换动作（仍占【动作槽】）
    action_target: int,   # 切换目标 / 特指目标
    post_items:  Array,   # 动作【后】使用的道具（有序）
}
```

- **道具不占动作槽**：`action` 字段始终恰好一个动作（攒/波/防/大波/大防/切换/主动）。道具在 `pre_items`/`post_items`，与动作正交。
- **序列 = 前/后两段有序列表**：设计里道具只标 `PRE`/`POST`/`ANY`（§0.1），单动作下「编排」的唯一自由度就是**在动作之前还是之后**；段内多件按玩家排列顺序结算（满足§D4「己方序列严格按编排顺序」——自身 buff/读自己动作结果的道具按序生效）。`ANY` 件默认入 `pre`（顺序无关，桶选择不影响结果）。
- **现有字段保留**：`selected_action`/`selected_target`/`_switch_to` 作为 `turn_plan.action` 的派生视图保留（UI/测试/AI 旧调用面不破），由 `turn_plan` 同步。
- 提供 `select_*` 的道具版入口：`use_item(player, slot, when, target)` / `commit_economy(player, op)`；旧 `select_action`/`select_switch`/`select_active` 写入 `turn_plan.action`。

**Migration Risks**：`clone()` / `legal_actions()` / `apply_choice()` / `resolve()` 都要认 `turn_plan`；AI 旧枚举只覆盖 `action`（D9 暂不搜道具，安全）。
**Rationale**：pre/post 两桶忠实于设计（前/后/无关三态），不引入无谓的任意深度交错；`action` 单字段保证「不占动作槽」是结构性的（动作永远恰好一个），而非靠约定。

---

### D3：结算管线接入 —— 己方序列结算 + 跨玩家同时独立（承重决策）

**Current**：`resolve()` 相位：Phase0 延迟伤害 → Phase2 扣能/攒/主动 → Phase2.5 切换 → Phase2.6 即时主动 → Phase3 出伤快照 → Phase4 施伤（同时） → Phase5 死亡 → Phase5.5 on_resolve_end → Phase6 cleanup。**Phase3/4 的「先快照后施加」是同时独立结算的实现**。

**Decision**：在现有相位骨架上插入道具相位，**严守不变量「己方序列顺序、跨玩家同时」**：

| 相位 | 内容 | 同时性处理 |
|---|---|---|
| **E 经济** 🆕 | 双方 `economy_ops`（点亮/refill/升级）扣能 + 置 lock timer | 各扣各能，无交互 |
| **0 延迟伤害** | 现有 `pending_damage` 落地 | 不变 |
| **S 前置自结算** 🆕 | 双方各按 `pre_items` 顺序施加**自身向**效果（治疗/护甲/护甲/能量/自 buff/置「本击+X」修正器/置条件 intent）+ 施加**对敌 debuff**（易伤/破防降级/预埋毒/元件层干扰） | 对敌 debuff 只改对手状态、不读对手并发伤害 → 双方先后施加结果对称、无先后手 |
| **A 动作** | 现有 Phase2/2.5/2.6（扣动作能/攒/主动/切换） | 不变 |
| **D 同时独立伤害** 🆕扩 | 计算双方完整伤害列表（pre 伤害件 → 动作攻击 → post 伤害件，按序）对快照算好，再一起施加；独立道具伤害走伤害／护甲管线，但不算命中 | 沿用 Phase3/4 先快照后施加 → 跨玩家不见彼此 HP 变化；可同时死=平局 |
| **P 后置自结算** 🆕 | 双方 `post_items` 的**自身向**效果（如「动作后回血」读己方动作结果） | 各管各 |
| **5 死亡** / **5.5 on_resolve_end** | 现有 | 不变 |
| **6 cleanup** 🆕扩 | 现有 status tick + 被动能量 +1 + turn++ **加** 道具栏 lock tick / DoT tick（D7-1）/ 信息扭曲过期（D7-2） | 不变 |

- **命中边界**（**D1·2026-08-13 取代旧决策**）：只有基础「波／大波」穿过防御门才算命中；护甲吸收仍算命中。主动技、追击、反击与独立道具伤害只复用伤害／护甲／还魂管线，不引爆毒素、不触发英雄命中技能。
- **额外触发边界**：双生咒符、聚鼎三花等只重复英雄命中技能；附在攻击上的道具效果每次攻击最多结算一次。
- **道具的毒 = 巳蛇引爆毒**（**D2 决策**）：道具施的毒进 `statuses["poison"]`，与英雄毒同一种、任意攻击引爆。
- **道具自身向效果复用**：`_heal`（含燃烧禁回血）/ `shield`（护甲=额外血量层）/ `_gain_energy`（过英雄能量加成）/ `statuses` 容器。

**Migration Risks**：相位插入顺序错 → 「动作前 +攻 ≠ 动作后追伤」、易伤/破防预埋时机、同时性都会错。需 Eddy 签字（Open Q1）。一回合可产出**多个 hit**（动作 + 多个伤害件）→ events 流变长、UI 飘字要支持多段。
**Rationale**：把道具效果挂相位（而非散插），与 ADR-002 D4 同理是可组合性的根治；复用 `_apply_damage`/`_heal`/`shield`/`statuses` 让 D1/D2 与二元铁则**零额外成本**落地。

---

### D4：`ItemEffect` 契约（hook 集，按 91 件真实需求定）

**Decision**：`ItemEffect` 基类提供以下方法，全部空默认、子类按需 override（同 `HeroSkill` 风格）。`player/slot` = 使用者出战位；`battle` = 引擎；`target` = 指向（D6 解析后）。数值半点。

**核心施放**：
- `on_use_pre(battle, player, slot, target)` —— 动作【前】施放（S 相位）：自 buff / 对敌 debuff / 置「本击+X」修正器 / 置条件 intent。
- `on_use_post(battle, player, slot, target)` —— 动作【后】施放（P 相位）：读己方动作结果的自身向效果。
- `outgoing_hits(battle, player, slot, target) -> Array` —— 本件产生的**伤害 hit**列表（D 相位汇入 hit-list）：`[{damage, kind, pen, ...}]`。命中类道具在此声明（生锈的飞镖/赌徒的硬币/闪电/毒刺…）。

**修正器（per-turn，挂状态容器）**：
- `modify_action_outgoing(dmg, action, battle, player, slot) -> int` —— 「本击 +X」类（先手/赌徒的硬币/血祭…）对动作攻击的加成。引擎在 `_calc_outgoing` 后叠加道具层。
- `override_action_pen(base_pen, action, battle, player, slot) -> int` —— 条件改穿透（破盾咒/魔法箭/巨人的铁锤；读对手动作见 D7-4）。
- `modify_self_defense(def_action, battle, player, slot) -> int` —— 临时升级己方防御等级（魔法气泡：防→可挡大波一次）。

**条件/读取**：
- `requires(battle, player, slot) -> bool` —— 使用前置（如绝境的魔咒 HP≤2；引擎已查能量/槽状态，子类补额外条件）。
- 读对手动作：effect 内直接读 `battle.turn_plan[1-player].action`（结算期对手动作已知，D7-4）。

**指向/共鸣元信息**（亦可由 `ItemData` 声明，effect 覆盖）：
- `target_mode()` / `is_resonance()` / `resonance_pair_kind()`。

**Migration Risks**：契约一次定形，后续按件落地。比英雄 hook 多一层「pre/post/hit/修正器」分工，但每类职责清晰。
**Rationale**：设计已稳（91 件清单），按真实需求一次性定 hook 集是正收益（同 ADR-002 D6）；`outgoing_hits` + 修正器分离让「追伤件」与「buff 件」走不同路径，对应§D4「动作前+攻 ≠ 动作后追伤」。

---

### D5：经济状态机（3 槽·开格→抽→可用电报·局内 3 选 1 draft·升级·refill）

**Decision**：每方 3 个道具槽，引擎持有状态机（§2 骨架 + §D3 道具锁）。

- **槽状态** `item_slots[player][i]`：
  ```
  { state, item_id, tier, ready_on_turn, draft_options }
  state ∈ { LOCKED(未点亮), OPENING(本回合点亮·锁), EMPTY(已开格待抽),
            DRAFTING(本回合抽·锁), READY(可用), SPENT(已用待 refill),
            UPGRADING(本回合升级·锁) }
  ```
- **电报（§D3·所有槽走「开格 → 抽道具 → 可用」三步，每步各 1 回合·从属框架表）**：
  - **开局自带件①**：回合 1 开格(带入道具·锁) → 回合 2 抽出道具①(锁) → **回合 3 可用**（最快路径）。
  - **中途新槽②③**：同三步；槽② 最早第 3 回合开、槽③ 最早第 4 回合开 → 全开最快第 6 回合。
  - 升级已持有道具同样锁 1 回合。`ready_on_turn` 记可用回合。
  - **卯兔例外**：道具锁 −1 回合（破电报，见 `heroes-redesign.md`）。
- **能量闸门**（全从团队池 `energy[]`）：点亮新槽 1 能 / refill 1 能 / 升级 1→2 花 1 能、2→3 花 2 能（升级锁 1 回合）。在 **E 相位**最前扣（§D4）。
- **局内 3 选 1 draft**：抽道具/refill/点亮时，引擎用 **seed RNG**（ADR-002 D7）从（地板池 + 玩家收藏）加权生成 3 个 `draft_options`；玩家选 1（`economy_op = {kind:DRAFT, slot, chosen_index}`）。引擎校验所选 index 合法，防止非法输入。
- **开局带 1**：`setup()` 入参带玩家预选的 1 件（唯一轻构筑动作，§D3）；slot① 仍走三步电报 → `ready_on_turn = 3`（从属框架 §D3 表，Q2 已裁）。
- **升级**：`economy_op = {kind:UPGRADE, slot}` → 若 `ItemData.upgrade_to` 非空且能量够 → 置 `UPGRADING` + `ready_on_turn`，到期换 `item_id`/`tier`。
- **遗物（T3·充能制）**：充能计数进 `statuses` 或槽内字段（如「3 充后碎」）；遗物=永久被动只允许 T3（§2 骨架）。

**Migration Risks**：状态机是新子系统，UI 要可视化槽状态/锁/draft 弹窗；`clone()` 要深拷槽状态 + draft_options。draft 必须 seed 确定，保证测试与回放可复现。
**Rationale**：能量在「大波/大防/点亮(广度)/升级(深度)/refill」间四向分配 = 全局机会成本中枢（§2），是道具不超模的结构性闸门；电报制让「公开道具」产生 yomi 预判窗、杜绝突袭抽取即爆发。

---

### D6：目标指向规则（默认自动 + 特指）

**Decision**（§0.1 / §D5=A）：
- `target_mode = AUTO_ENEMY`：伤害/debuff → 敌方出战。
- `target_mode = AUTO_SELF`：甲/盾/治疗/能量/自 buff → 己方出战。
- `target_mode = SPECIAL`：个案特指（纸扎人立替身、北辰式后排、全体 AOE 等），由 effect + `action_target` 解析。
- 自动指向在 `use_item` 时解析为具体 `target`，effect 收到已解析目标。

**Rationale**：默认自动降操作量；特指开个案口子，不污染通用路径。

---

### D7：七类新引擎能力（详设）

> 每类标注「机制 / 落点 / 复用还是新增」。对应件清单见 `items.md` 各 § 末「引擎可行性待核」。

**7-1 自结算 DoT**（毒蘑菇/妖火）
- 机制：施加后**每回合末 −0.5 HP·不依赖命中**（区别于「引爆毒」需命中）；妖火附带该回合禁回血。
- 落点：新状态 `statuses["dot"] = {amount_half, turns, blocks_heal}`；在 **Phase 6 cleanup**（或 Phase 0）tick 扣血——**不走 `_apply_damage`、不触发 on-hit**（自结算、无攻击者）。解毒药水/妖火清 `dot`。
- 新增（现有 `burn` 只加易伤+禁回血、不自扣血）。

**7-2 假·隐藏道具**（幻影/迷雾/隐身斗篷）
- 机制：操纵**己方道具栏对对手的公开视图**——幻影 +1 假件、迷雾藏 1 件、隐身斗篷全藏；**持续到你下次用道具**。
- 落点：新状态 `info_distortion[player] = {fake_count, hidden_slots, until_next_item:true}`；纯信息层（无战斗数值），但**必须进可序列化状态**（录像/存档）。公开视图 = `public_inventory_view(viewer, owner)` 应用扭曲。下次该玩家用任意道具时清除。
- 新增（信息层结构本作独有）。

**7-3 条件改穿透 / 防御等级**（破盾咒/魔法气泡/闪电/魔法箭/酸液瓶/腐朽咒/巨人的铁锤）
- 机制：① 改己方攻击穿透档（魔法箭：波→穿防；巨人的铁锤：大波→穿大防；破盾咒：若对手「防」则穿防）② 升己方防御等级（魔法气泡：防→可挡大波一次）③ 降对手防御等级（酸液瓶：大防→防→无 1 回合；腐朽咒：下次防/大防失效）。
- 落点：① 经 `override_action_pen`（D4）改 `out_pen`，复用现有 `Pen` 档 + 防御门。② 经 `modify_self_defense` 改 `eff_def`。③ **复用现有 `broken_armor` 机制**（`_apply_damage` Stage B4 已有：`broken_armor>0` 时大防→防、防→无）——酸液瓶/腐朽咒 = 给对手置 `broken_armor`。
- 大半复用（穿透档 + broken_armor 已存在），少量新增（条件读对手动作见 7-4）。

**7-4 读对手动作**（铜钱/后手/香蕉皮/分神的铃铛/省力咒/破盾咒/魔法气泡）
- 机制：效果依赖对手本回合所选动作（盲选时是赌、结算时已知）。如后手「若对手攻击 → +1.0 甲」、香蕉皮「对手攻击 −0.5 伤」、铜钱「对手攻击→+0.5 甲 否则 +0.5 能」。
- 落点：effect 在结算相位读 `battle.turn_plan[1-player].action`（双方动作此时都已 commit）。无需新基建——结算期对手动作已知。
- 复用（仅放开 effect 读对手 `turn_plan`）。

**7-5 元件层干扰**（封魔锁/封印术/贪婪的诅咒/定身符/迷魂药/窃贼的魔爪/驱逐令）
- 机制：干扰对手**道具栏/动作栏/信息**（本作独有结构）：封道具槽 / 禁 1 基础动作 / 费能动作 +1 能 / 禁切换 / 隐藏操作栏(迷魂) / 偷道具 / 强制切换(驱逐)。
- 落点：盲选+同时 → 这些是**预判**（§3A）。结算时：
  - 禁动作/禁切换 → 复用现有 `is_action_disabled` 框架（封印术/定身符 = 道具驱动版 `disabled_group`）。对手若 commit 了被禁动作 → **该动作直接无效**（不执行·无效果·不转攒·能量不扣，Q3 裁定）。
  - 封道具槽（封魔锁）→ 置对手该槽 `LOCKED` 本回合（counterplay：下回合自解）。**Edge case（Q3）**：对手本回合**正要用**被封的道具 → 该次使用取消、**对方道具保留不消耗**；你的封槽件照常消耗。
  - 费能 +1（贪婪）→ 结算 `_get_cost` 对对手费能动作加价。
  - 强制切换（驱逐）→ 结算期改对手 active（偏 PvE）。
  - 隐藏操作栏/偷道具（迷魂/窃贼）→ 重口、偏 PvE（§3D）。
- 部分复用（禁动作链已有），部分新增（封槽/费能加价/强制切换）。当前只保留带可反制出口的候选；无解版本不进入远征。

**7-6 共鸣同回合配对**（双生星/回响的咒/应和的钟，§0.9）
- 机制：〔共鸣〕件单出=弱/无；同回合与另一〔共鸣〕件（道具+道具）或指定动作（道具+动作）一起打出 → 触发强效果。
- 落点：结算前扫该玩家 `turn_plan` 的 pre/post_items + action，判定共鸣是否成立（`is_resonance` 件计数 / `resonance_pair_kind` 与 action 匹配），置 per-turn flag 供 effect 读。
- 新增（配对判定），但只是 `turn_plan` 内扫描，无跨玩家复杂度。

**7-7 穿甲**（索魂咒，#4）
- 机制：无视对手**护甲层**（`shield`，额外血量层），直击本体血量；**仍受「挡不挡」约束**（防御门挡住=归零）——区别于穿防（破「防动作」）与真伤（无视一切）。
- 落点：新标记 `pierce_armor`（hit 上的 bool 或 `Pen` 旁路）；`_apply_damage` **Stage B6 护甲吸收**在 `pierce_armor` 时跳过，但 Stage B4 防御门照常。
- 新增（现 `shield` 旁路只绑 `TRUE_DMG`，需拆出独立 `pierce_armor`）。**遵二元铁则**：穿甲≠吸收，是「跳过额外血量层」。

**附：软版同气连枝**（同心结，#5）= 持 ≥2 同维度道具 → 各 +0.25（封顶）。落点：effect 在施放时读 `item_slots[player]` 数同维度件，非新 hook（库存查询）。

---

### D8：公开信息 + 序列化 / clone

**Decision**：
- **道具公开**（§2）：`public_inventory_view(viewer, owner)` 暴露对手槽内容（state/item_id/tier/lock），经 D7-2 信息扭曲过滤。UI 据此画对手道具栏 + 锁电报。
- **`clone()` 扩展**：深拷 `turn_plan` / `item_slots`（含 `draft_options`）/ `info_distortion`；`ItemEffect` **无状态**→`clone()` 重建实例（同 `_build_skills`，§D2 锁死零共享）。
- **确定性**：draft 3 选 1 用 seed RNG（D5）；道具数值半点整数（无浮点漂移）。本地权威引擎统一校验经济操作 / 道具使用（槽状态合法、能量够、draft index 合法）。

**Rationale**：道具公开 + 锁电报是 yomi 的信息基础；序列化/确定性是测试、回放和存档的共同需求，与英雄系统同标准。

---

### D9：AI 集成（首版道具-blind，完整设计/实装后再加）

**Current**：`battle_ai.gd` minimax 枚举 ~7 基础动作 + 终局贴现。

**Decision**（Eddy 选 A + 「等完整设计/实装后再加」）：
- **首版 AI 道具-blind**：`legal_actions`/`apply_choice` 对 AI 只暴露 `turn_plan.action`（基础动作），道具/经济当 no-op；AI 不点亮槽、不用道具、不 draft（或走最简「不开槽」默认）。
- 道具系统**完整设计 + 实装跑通后**再加 AI 道具逻辑，届时分级推进：①启发式（贪心用增益件、走经济）②minimax 增广「动作 × 道具子集 × 顺序」+ 剪枝（昂贵，需专门 ADR/工作）。
- 影响面隔离：道具走独立的 `turn_plan` 字段，AI 只读 `action` → **道具系统不破坏现有 AI 与 70/70 测试**。

**Rationale**：道具价值=yomi 博弈，本就靠人对人验证；首版道具-blind 最省、零回归风险；待手感稳再投 AI 搜索成本。

---

### D10：测试策略

**Decision**（同 ADR-002 D11 风格 + [[current-behavior-lock-policy]]）：
- **不破现有**：道具走新 `turn_plan` 字段，现有 70/70 battle 测试（无道具）应全绿不变——回归基线。
- **新测试分层**：① 经济状态机（电报 3 步锁/能量扣费/升级/refill/draft 校验）② 序列结算（pre/post 顺序、动作前+攻 vs 动作后追伤、跨玩家同时不串）③ 只有「波／大波」命中引爆毒素／触发英雄技能，独立道具伤害不触发，护甲吸收仍触发 ④ 七类新能力各 2-3 case ⑤ 半点/seed draft 可复现/clone 零共享。
- 先写测试锁行为，再铺件（coding-standards 验证驱动）。

---

### D11：实装分期（目标态完整，但落地按机制类推进）

**Decision**：架构一次建好（D1-D8），**件按机制类增量铺**——91 件不一次写完，按「复用现有 → 新能力」排序，每类配测试。映射见 D12。AI 道具逻辑最后加（D9）。

---

### D12：91 件 → 机制/能力映射（实装排序）

> 用途 = 实装工程清单：每件归到「复用现有 / 新增能力」，定铺设顺序。逐件数值/文案见 `items.md`（真相源）。

| 机制类 | 代表件 | 落地方式 | 引擎成本 |
|---|---|---|---|
| 直伤 / 本击+X / 追伤 | 生锈的飞镖·先手·锋利的飞镖 | `outgoing_hits` / `modify_action_outgoing` | **复用**（_apply_damage） |
| 治疗 / 净化 | 生命药水线·解毒药水·治愈光环·续命香 | `_heal` + 清 dot/poison | **复用** |
| 护甲 / 护甲 / 反弹 | 护甲线·带刺的护甲·应和的钟 | `shield`（额外血量层）+ `on_block` 式反弹 | **复用**（二元铁则） |
| 能量 / 经济导出 | 法力药水线·魔力源泉·汲魔符·火球术·天雷 | `_gain_energy` / 弃能 | **复用** |
| 引爆毒（命中） | 毒刺·毒药瓶·炼毒的大锅 | `statuses["poison"]`（D2） | **复用** |
| 英雄命中技能额外触发 | 双生咒符·聚鼎三花 | 只增加英雄技能触发次数；道具附效每次攻击最多一次 | **复用** |
| 自结算 DoT | 毒蘑菇·妖火·轮回的毒咒(PvE) | **7-1** `statuses["dot"]` | 🆕 |
| 假·隐藏道具 | 幻影·迷雾·隐身斗篷 | **7-2** `info_distortion` | 🆕 |
| 条件穿透 / 防御等级 | 破盾咒·魔法气泡·闪电·魔法箭·酸液瓶·巨人的铁锤 | **7-3**（穿透档 + broken_armor 复用 + modify_self_defense 新） | 半🆕 |
| 读对手动作 | 铜钱·后手·香蕉皮·分神的铃铛·省力咒 | **7-4** 读 `turn_plan[opp].action` | 复用 |
| 元件层干扰 | 封魔锁·封印术·贪婪的诅咒·定身符·迷魂药·窃贼的魔爪·驱逐令 | **7-5**（禁动作链复用 + 封槽/费能/强制切换新） | 半🆕 |
| 共鸣 | 双生星·回响的咒·应和的钟 | **7-6** turn_plan 扫描配对 | 🆕 |
| 穿甲 | 索魂咒 | **7-7** `pierce_armor` 旁路 shield | 🆕 |
| 同气连枝（软） | 同心结 | 库存查询（D7 附） | 复用 |
| 切换节奏 | 风之靴·替身草人·冲锋号角·筋斗云 | on_use + 切换钩 / 免动作槽切换 | 半🆕 |
| 随机 / wildcard | 锦囊·命运的骰子·恶魔的赌约·魔法宝箱 | seed RNG（赌自己为主） | 复用 |
| 自成核 / 遗物（充能） | 禁咒·绝境的魔咒·狂暴药水·石像鬼·贪财的小精灵 | 条件/代价/充能计数 | 半🆕 |

**实装顺序建议**：复用类（直伤/治疗/护甲/能量/毒/on-hit）先 → 验证经济状态机 + 序列结算端到端 → 再铺半🆕/🆕 类。

---

## Consequences

**解锁**：道具 build 深度层（§3 浅而广的主体）；yomi 博弈加变量层；连携/导出/共鸣/元件层干扰（本作独有玩法）；远征掉落养成的内容钩子。
**成本**：一次性建 `turn_plan` 模型 + 经济状态机 + 七类新能力 + 道具组件树（91 件增量）；UI 要画道具栏/锁电报/draft 弹窗/多段飘字；AI 道具逻辑后补。
**不变**：纯 RefCounted、无 UI 依赖、结构化 events、同时独立结算、二元防御铁则、能量团队池、可 seed/clone（ADR-001/002 延续）。

---

## Alternatives Considered

| 决策 | 备选 | 拒绝理由 |
|---|---|---|
| D1 | 道具效果硬编码进 resolve()（如旧 v3 英雄） | 正是 ADR-002 要逃离的 god class；91 件必膨胀 |
| D2 | 任意深度交错序列 `[i,a,i,i,a...]` | 设计只有前/后/无关 + 单动作，pre/post 两桶已完整，任意交错是过度工程 |
| D3 | 道具完全绕开统一伤害管线 | 重复护甲、受伤与还魂逻辑；独立道具伤害应复用这些底层结算，但明确不进入命中分支 |
| D5 | 道具不吃能量（旧药水设想 3 瓶不碰能量） | 失去「能量=超模总闸门」，道具必超模（§2 已弃，[[potion-system-concept]]） |
| D7-7 | 穿甲复用 `TRUE_DMG` | 真伤无视防御门，违设计（穿甲仍受挡不挡约束）；须独立 `pierce_armor` |
| D9 | 首版 AI 即搜道具空间 | 分支爆炸、昂贵；道具价值是人对人 yomi，先验证手感 |

---

## ✅ Resolved Questions（2026-06-18 Eddy 裁定·全部已答）

| # | 问题 | 裁定 |
|---|---|---|
| **Q1** | D3 相位插入顺序（E→S→A→D→P）+ 对敌 debuff 在 S 相位双方对称施加 | ✅ **同意** |
| **Q2** | 开局自带第 1 件道具的可用时机 | ✅ **从属框架 §D3 表 = 回合 3 可用**（走「开格→抽→可用」三步电报；Eddy 撤回口头「回合 2」、以框架为准） |
| **Q3** | 元件层干扰（7-5）被禁动作的盲选冲突 | ✅ **被禁动作直接无效**（不执行·无效果·不转攒·能量不扣）。**Edge case**：你用封道具槽件、对手正要用被封的道具 → 对方该次使用取消、**道具保留不消耗**；你的封槽件照常消耗 |
| **Q4** | 共鸣「道具+动作」配对，动作被禁后是否成立 | ✅ **不成立**（配合的动作没打出，共鸣不触发，只剩单出弱效果） |
| **Q5** | 局内 3 选 1 draft 选项来源 | ✅ **引擎 seed 生成 + 玩家选 index**（引擎校验防伪造） |


---

## 实装顺序（批准后）

1. **底层**：`ItemData` + `ItemEffect` + 注册表 + 地板池加载（D1）。
2. **回合模型**：`turn_plan` + `use_item`/`commit_economy` 入口 + `clone()`/`legal_actions`/`apply_choice` 适配（D2，AI 仍只读 action）。
3. **结算相位**：E/S/D/P 相位插入 + 道具走 `_apply_damage`/`_heal`/`shield` 复用（D3）+ 其测试（先验证现有 70/70 不破）。
4. **经济状态机**：3 槽电报 + 能量扣费 + 升级 + refill + seed draft（D5）+ 测试。
5. **复用类道具铺设**（直伤/治疗/护甲/能量/毒/on-hit·D12）→ 端到端可玩切片（无 UI 也可 headless 验证）。
6. **七类新能力**（D7）逐类落地 + 测试。
7. **UI**：道具栏 + 锁电报 + draft 弹窗 + 多段飘字（独立 UI 任务）。
8. **AI 道具逻辑**（D9，最后）。

---

## 修订历史

| 日期 | 修订 | 作者 |
|------|------|------|
| 2026-06-18 | 初版 Proposed（范围 B 完整目标态 + AI 道具-blind·A 决议） | Eddy + Claude |
| 2026-06-18 | Q1/Q5 裁定（相位顺序同意 / draft seed+index）；D5 道具锁加卯兔例外 | Eddy + Claude |
| 2026-06-18 | Q3/Q4 裁定（被禁动作无效 + 封道具 edge case / 共鸣不触发）；Q2 改判（从属框架 §D3 = 回合 3 可用）→ **Accepted** | Eddy + Claude |
