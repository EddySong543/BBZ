# ADR-001: BattleCore 职责边界与解耦原则

> **⚠️ 历史决策（v3 时代）**：本文描述的 v3 BattleCore 已被 v4 重写取代（2026-05-25，见 ADR-002）。§D4「HeroSkill 迁移暂停」已被 ADR-002 撤销并完成重启；边界原则 D2/D3/D5 由 v4 延续。正文作历史保留，当前真相源 = `src/battle/`。
> **⚠ 英雄阵容**：本文英雄示例基于旧 34 阵容；大阿卡那(h13-h34)+星座(h35-h46)已弃（2026-06-19），槽位复用为暗生肖，现 24（h01–h24：12 生肖 + 12 暗生肖）。

| 字段 | 值 |
|------|-----|
| **Status** | ✅ Accepted |
| **Date** | 2026-05-18 |
| **Author** | Eddy + Claude |
| **Supersedes** | — |
| **Related** | `battlecore-risk-notes.md`、`tests/BEHAVIOR_NOTES.md` |

---

## Context

### 项目当前形态

`src/battle/battle_core.gd` 自项目起步即承担战斗系统全部职责，已增长至 **673 行**：

- 14 个 Action 枚举（6 基础 + 8 英雄专属）
- 6 phase 的 `resolve()` 流程
- 12 个英雄被动 / 主动技能 hardcoded if 分支（仅 h05 已迁移至独立组件）
- 8 个 transient state 数组
- UI 直读 `battle.shield[][]`、`battle.hero_hp[][]`、`battle.energy[]` 等私有字段

### 近期已落地的解耦

| 改动 | 来源 | Commit |
|------|------|--------|
| HeroData 数据化（13 个英雄迁出代码到 `.tres`） | P0-1 | `e96219b` |
| events 结构化（30 处 `events.append(中文)` → `{id, params}`） | P0-2 | `3ee65b7` |
| HeroSkill 评估窗口结论：暂停迁移 | P0-3 | （本 ADR） |

### 沉淀这份 ADR 的动机

P0-1 / P0-2 / P0-3 是密集做出的架构级决策，但之前散落在 commit message / memory / risk-notes。本 ADR **第一次**把 BattleCore 的对外契约边界总览固化下来，作为未来 P1+ 任务（UI 拆分、联网、i18n）的参照锚。

---

## Decisions

### D1: HeroData 必须以 `.tres` 资源形态存在

**Current**: 13 个英雄分别存于 `assets/data/heroes/h01.tres ~ h13.tres`。`HeroData.create_pool_heroes()` 通过 `DirAccess` 扫描目录加载。

**Decision**:
- 禁止在 `.gd` 代码内 hardcoded 英雄字典（`_hero_defs()` 已删除）
- 新增英雄 = 新建一个 `.tres` 文件，**不需要改任何代码**
- 英雄数值 / 描述 / sprite 路径在 Godot Inspector 直接编辑

**Migration Risks**: 无（已完成）。

**Rationale**: 满足 CLAUDE.md `coding-standards.md` "游性数值禁止硬编码" 条款；同时让美术 / 策划可以无代码协作。

---

### D2: BattleCore 对外输出结构化事件，禁止任何中文显示文本

**Current**: `resolve()` 返回 `last_result.events: Array[Dictionary]`，每条事件形如 `{id="damage_taken", player=0, amount=3}`。

**Decision**:
- BattleCore 业务逻辑代码内**零**玩家可见中文字符串
- 唯一例外：`get_action_name()` 返回的动作名（`"波" / "大波" / "防"` 等）暂时残留于 `BASE_ACTION_DEF` / `EXTRA_ACTION_DEF`，留待下一轮单独治理
- 注释、`push_warning` 调试信息不受此规则约束

**Migration Risks**: 无（已完成 P0-2）。残留动作名是已知技术债，记录在 `battlecore-risk-notes` 待办区。

**Rationale**:
- 解锁 i18n（远期 P2-8）：翻译只需替换 EventFormatter
- 解锁联网（远期 P3）：客户端直接读结构化事件做特效 / 飘字，不必反向 parse 字符串
- 解锁测试稳定性：测试断言 `events[0].id`，不再受文案改动影响

---

### D3: EventFormatter 是 BattleCore 对外契约的一部分

**Current**: `src/battle/event_formatter.gd` 同目录 with battle_core；UI 端通过 `EventFormatter.format(ev)` 调用。

**Decision**:
- EventFormatter **属于战斗模块的对外契约**，不属于 UI 模块
- 物理位置：`src/battle/event_formatter.gd`（不放 `src/ui/`）
- UI 端只读 events 数组 + 调 formatter，不自行解读 event_id
- i18n 时整体替换本文件，BattleCore / 测试 / UI 均无需改动

**Migration Risks**: 无（已完成 P0-2）。

**Rationale**: 文案翻译的"对接点"必须有单一物理位置；放在 UI 层会诱导多个 UI 文件各自做 event_id 解读，造成翻译漂移。

---

### D4: HeroSkill 组件化暂停

**当时现状**:
- 已迁移：**1 个**（当时的 h05 辰龙；现行重设计实现位于 `src/battle/skills/h05_longyuji.gd`）
- 未迁移：**12 个**（h01~h04, h06~h13），继续走 battle_core hardcoded 分支
- 当时 HeroSkill 基类只有 1 个 hook：`on_attack_calc`

**Decision**:
- **暂停** HeroSkill 迁移；h05 保留为孤例
- 12 个未迁英雄维持现状，新加技能允许直接写在 battle_core
- **重启条件**：英雄设计稳定（design/heroes.md 的"过渡版本"声明被撤销）后重新评估

**Migration Risks**:
- battle_core.gd 会继续膨胀（每加一个新被动 +5~15 行 if 分支）
- 两套机制并存（hook + hardcoded）增加阅读成本，但 hook 实例数量极少（仅 h05），可控

**Rationale**:
- P0-3 评估窗口（2026-05-18）发现 h11~h13 中的多数候选英雄需要新 hook 类型（`on_shield_calc` / `on_damage_taken` / `on_action_modify` / `on_switch_in_out`），抽象会快速膨胀
- 同时 `design/heroes.md` 明示 h06~h13 部分英雄将被重新设计
- 现在投入 hook 抽象，结果会被设计变更稀释
- 抽 h05 的客观账：56 行框架投入换 2 行 battle_core 节省，短期亏本；只有抽完 4~5 个稳定英雄才能回本

**Supersedes**: `battlecore-risk-notes.md §3` 中的"一次迁一个"原则（保留作为重启后参照，但当前不执行）。

---

### D5: 依赖方向严格单向 — UI → BattleCore

**Current**:
- ✅ BattleCore 不依赖任何 UI 类型 / scene 节点
- ❌ UI（`battle_screen.gd`）**直读** BattleCore 私有字段：
  - `battle.shield[player][slot]`
  - `battle.hero_hp[player][slot]`、`battle.hero_max_hp[][]`
  - `battle.energy[player]`
  - `battle.clone_count[player]`、`battle.clone_hp[][]`、`battle.clone_order[][]`
  - `battle.pending_death_switch[player]`

**Decision**:
- 依赖方向: `UI` → `BattleCore`（严格单向）
- BattleCore 不得 import / instantiate / call 任何 UI 类型或节点
- BattleCore 不得依赖具体 scene 树结构
- **目标方向**（Target）：UI 通过公开 getter 或 read-only view 访问战斗状态，停止直读私有数组
- **当前 Partial 状态**：UI 直读私有数组**临时允许**，但属于已知架构债

**Migration Risks**:
- 现在强制 UI 走 getter 会牵动 `battle_screen.gd` 929 行同时改 → 大改动
- 与 P1-5（battle_screen 拆分）天然耦合，应一并处理
- 在 P1-5 完成前，新加 UI 代码**应优先使用 getter**（如已有 `active_hero(p)`、`current_hp(p)`、`get_living_reserves(p)` 等），不要新增直读私有字段

**Rationale**:
- 联网（P3）要求 BattleCore 可以在服务端独立运行，不能依赖 UI
- 单向依赖让 BattleCore 的单元测试不需要 mock 任何 UI
- Partial 状态是务实选择 —— 完全严格会推迟 P1-5

---

## Consequences

### 解锁的事

- **i18n（P2-8）**：D2 + D3 让翻译聚焦于 EventFormatter 一个文件；HeroData.skill_description 等 i18n key 化也具备前提
- **联网（P3）**：D2 + D3 + D5 让 BattleCore 可在服务端独立运行；结构化事件可直接做协议
- **新英雄无代码协作**：D1 让美术 / 策划在 Inspector 直改 `.tres`
- **战斗逻辑测试稳定**：D2 让测试断言 event_id 而非字符串

### 受限的事

- D4 → battle_core.gd 在英雄设计稳定前会继续膨胀
- D5 Partial → P1-5（battle_screen 拆分）必然会触碰大量直读字段，无法回避大改动
- 残留动作名（D2 例外）需要再来一轮"actions id 化"才能彻底完成 i18n 准备

### 不变的事

- BattleCore 仍是 god class，本 ADR **不**要求立即拆分
- HeroSkill / 测试体系 / risk-notes 等其他治理产物保持现状

---

## Alternatives Considered

| 决策 | 备选 | 拒绝理由 |
|------|------|---------|
| D1 | 保留 `_hero_defs()` 作为 fallback | 留 fallback = "两个真相源"，违反数据化初衷 |
| D2 | events 同时存 dict 和 string（兼容期） | UI 只 1 处读、测试 0 处断言字符串 → 没有兼容期成本 |
| D3 | EventFormatter 放 UI 层 | 多 UI 文件各自解读 event_id 会造成翻译漂移 |
| D4 | 继续逐个迁移 HeroSkill | P0-3 评估窗口否决 — 英雄设计未稳，投入会被稀释 |
| D4 | 把 h05 也回滚塞回 battle_core | 数据不足支持回滚；保留孤例作为未来重启时的参考实现 |
| D5 | 现在就强制 UI 不直读私有字段 | 风险过高，与 P1-5 重叠，推迟会更安全 |

---

## 引用文档

- `tests/BEHAVIOR_NOTES.md` — BattleCore 行为差异清单（7 条已 Resolved）
- `docs/architecture/battlecore-risk-notes.md` — 6 大隐式规则 + HeroSkill 迁移原则（§3 §4 已根据本 ADR D4 加状态注）
- `design/gdd/game-concept.md`、`design/heroes.md` — 设计意图源
- Memory:
  - `phase-lightweight-personal-project` — 项目运营原则
  - `adr-style-current-vs-target` — ADR 写作风格
  - `current-behavior-lock-policy` — 测试锁定原则

---

## 修订历史

| 日期 | 修订 | 作者 |
|------|------|------|
| 2026-05-18 | 初版（P0-1 / P0-2 / P0-3 决议沉淀） | Eddy + Claude |
| 2026-07-31 | 标明 h05 条目为决策时历史现状，并补充现行脚本索引 | Codex |
