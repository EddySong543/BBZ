# BattleCore 行为差异清单

本文件记录 **`src/battle/battle_core.gd` 当前实现** 与
**`design/gdd/game-concept.md` / `design/heroes.md` 设计文档** 之间的不一致点。

---

## 用法 / 协作约定

| 阶段 | 处理方式 |
|------|---------|
| **Phase 1（测试编写）** | 测试**一律锁定代码当前行为**。所有 `# CURRENT-BEHAVIOR` 测试断言对应一个本文档条目。绝不"先改代码再写测试"。 |
| **Phase 1 末** | 由 Eddy 逐条裁决 → 修代码 / 改设计文档 / 接受为正式行为。 |
| **Phase 2 (ADR)** | 已裁决条目的最终结论写入 `docs/architecture/ADR-001-battlecore-responsibility.md` 附录。 |
| **Phase 3 (重构)** | 重构后若条目状态为 "修代码"，则测试断言同步翻转，并把该条目移到下方"已解决"区。 |

---

## 条目模板

```markdown
### B-NNN 标题（一句话）

- **Status**：Undecided / Design Authority (代码需修) / Current Behavior Authority (设计需更) / Accepted as Canonical / Resolved (Code Fixed) / Resolved (Design Updated)
- **Impact**：低 / 中 / 高
- **位置**：`battle_core.gd:行号 函数名`
- **Design Intent**：`design/.../xxx.md §章节`，原文："..."
- **Current Behavior**：`battle_core.gd:行号` 当前实际表现 ...
- **测试**：`tests/.../test_xxx.gd::test_yyy`（含 `# CURRENT-BEHAVIOR (B-NNN)` 注释）
- **可能原因**：作者笔误？设计变更未同步？刻意调整？
```

### Status 字段含义

| 值 | 含义 | 谁能改 |
|----|------|--------|
| `Undecided` | 新发现差异，等待 Eddy 裁决 | 默认值 |
| `Design Authority` | Eddy 裁决"代码错了"，按设计为准。等待代码修改 | Eddy |
| `Current Behavior Authority` | Eddy 裁决"设计过时"，按代码为准。等待 GDD 更新 | Eddy |
| `Accepted as Canonical` | Eddy 裁决"两者都对，按当前代码就是正式行为"。可关闭测试的 LOCKED-FOR-REFACTOR 警示 | Eddy |
| `Resolved (Code Fixed)` | 代码已按设计修复，测试断言已翻转 | 重构者，需 Eddy 确认 |
| `Resolved (Design Updated)` | GDD 已更新为符合代码行为 | 设计文档维护者，需 Eddy 确认 |

---

## 已识别差异（待裁决）

### B-001 ATTACK × ATTACK 不抵消，双方各受 1 伤

- **Status**：Undecided
- **Impact**：高
- **位置**：`battle_core.gd:578 _apply_defense`
- **Design Intent**：`design/gdd/game-concept.md §3.2 同时出手结算矩阵` 与 `§5 边界情况` 第 1 条，原文：
  > "双方同时出『波』 → 互相抵消，双方均不受伤害，各自消耗 1 能量"
- **Current Behavior**：`_apply_defense(dmg, atk=ATTACK, def=ATTACK)` 没有命中 BIG_DEFEND 分支、也不满足 `def == DEFEND and atk == ATTACK`，直接 `return dmg` → 双方都被 `_route_damage` 加到对方 hp_dmg。结果是双方都受 1 伤（hp -1），能量都 -1。
- **测试**：`tests/unit/battle/test_base_actions.gd::test_attack_vs_attack_both_take_1_damage`
- **可能原因**：早期实现遗漏，或在英雄技能（如 h05 龙威）调试中临时改的；与 `events` 输出文本（"P1/P2 命中"）一致，说明是有意走双向解算，但未对齐设计文档。

---

### B-002 BIG_ATTACK × BIG_ATTACK 不抵消，双方各受 2 伤

- **Status**：Undecided
- **Impact**：中
- **位置**：`battle_core.gd:578 _apply_defense`（与 B-001 同一处）
- **Design Intent**：`§3.2`、`§5 边界情况` 第 2 条：
  > "双方同时出『大波』 → 互相抵消，双方均不受伤害，各自消耗 3 能量"
- **Current Behavior**：双方各受 2 伤、各 -3 能。
- **测试**：`test_base_actions.gd::test_big_attack_vs_big_attack_both_take_2_damage`
- **可能原因**：与 B-001 同根

---

### B-003 ATTACK vs BIG_ATTACK 双向都解算

- **Status**：Undecided
- **Impact**：高
- **位置**：`battle_core.gd:323-335 resolve()` Phase 2 + `_apply_defense`
- **Design Intent**：`§3.2` 与 `§5` 第 3 条：
  > "波 vs 大波 → 大波方对波方造成 1 点伤害，波方消耗 1 能量，大波方消耗 3 能量"

  含义：**仅大波方造成伤害**（波方的波被大波"压制"，不造成伤害；大波方的大波也只造成 1 伤而非满 2 伤）。
- **Current Behavior**：双方独立解算 — 波方受 2 伤（大波满伤）、大波方受 1 伤（波满伤）。与设计的双重不一致：(a) 没有"压制"逻辑；(b) 大波伤害未削减。
- **测试**：
  - `test_base_actions.gd::test_attack_vs_big_attack_both_take_damage`
  - `test_base_actions.gd::test_big_attack_vs_attack_both_take_damage`
- **可能原因**：与 B-001/B-002 同根 — `_apply_defense` 只处理"防御类"动作，没处理"攻击类压制"

---

### B-004 `select_action` 拒绝后 `selected_action=-1` 会让 `resolve()` 崩溃

- **Status**：Undecided
- **Impact**：低（UI 当前兜底）/ 高（网络/AI 接入后）
- **位置**：`battle_core.gd:202 select_action` + `resolve()` Phase 1 cost lookup
- **Design Intent**：`§5 边界情况`："能量不足时选择消耗动作 → 动作不可选择（按钮置灰）"。设计假设 UI 会阻止这种状态进入 resolve()
- **Current Behavior**：BattleCore 自身没有防御 — 若 `selected_action[p] = -1`，`resolve()` Phase 1 会调 `_get_action_cost(p, -1)` → 查 `BASE_ACTION_DEF[-1]` → KeyError 崩溃
- **测试**：`test_energy_cost.gd::test_select_action_rejects_unaffordable_action`（仅测 select_action 拒绝；不直接触发崩溃以避免污染 GUT 输出）
- **可能原因**：BattleCore 信任调用方（UI）；缺少 defensive precondition

---

### B-005 `_get_action_cost(BAI_SHOU)` 未 clamp 到 `BAI_SHOU_DAMAGE_CAP`

- **Status**：Undecided
- **Impact**：低（当前无调用方读取，UI 不基于此值显示）；中（未来 AI / 网络 / UI 显示真实成本时会偏离）
- **位置**：`battle_core.gd:137 _get_action_cost` vs `battle_core.gd:294 resolve()` Phase 1 内 `spent = clampi(energy[p], 1, BAI_SHOU_DAMAGE_CAP)`
- **Design Intent**：`design/heroes.md` h03 寅虎："**百兽**（消耗全部能量(上限6)），造成等量次数的1点伤害"
- **Current Behavior**：两处 cost 计算不一致：
  - `_get_action_cost(p, BAI_SHOU)` = `maxi(energy[p], 1)` → 能量 10 时返回 10
  - `resolve()` 内 `spent` = `clampi(energy[p], 1, 6)` → 能量 10 时实际花费 6
- **测试**：`test_energy_cost.gd::test_baishou_cost_uses_max_of_energy_and_one`
- **可能原因**：作者修改 cap 时只改了 resolve() 一处，未同步 `_get_action_cost`

---

### B-006 `setup()` 未重置三个 transient 标志数组

- **Status**：Undecided
- **Impact**：低（BattleCore 实例每场新建，且 resolve() 开头会重置这三个数组）；中（若调用方复用 BattleCore 跨多场战斗、且未走 resolve() 路径）
- **位置**：`battle_core.gd:72-113 setup()` 未涉及 `_baishou_spent`、`_jiaotu_immune`、`_shetui_active`
- **Design Intent**：N/A（私有实现细节，无对应设计文档）
- **Current Behavior**：
  - `_baishou_spent`、`_jiaotu_immune`、`_shetui_active` 三个数组在 `setup()` 调用后保留上次 `resolve()` 末态
  - 这三个数组在 `resolve()` Phase 1 开头被重置为 `[0, 0]` / `[false, false]` / `[false, false]`
  - 所以游戏中每次 resolve 前是脏的、resolve 后立即被清，无可见影响
- **测试**：`test_setup_reset.gd::test_setup_does_not_reset_baishou_jiaotu_shetui_transient_flags`
- **可能原因**：作者把这三个视为 resolve() 内部 transient，未意识 `setup()` 也应该清

---

### B-007 双方同回合全灭时 `winner = 0`，语义与 winner=1/2 不平行

- **Status**：Undecided
- **Impact**：低（events 文本会写明"平局"）；中（任何读 winner 字段判定输赢的代码必须特判 0）
- **位置**：`battle_core.gd:438-447 resolve()` Phase 4 game_over_check
- **Design Intent**：`design/gdd/game-concept.md §5`："双方同时击杀对方最后英雄 → 平局"
- **Current Behavior**：
  - P1 胜：`winner = 1`
  - P2 胜：`winner = 2`
  - 平局：`winner = 0`
  - 但 `setup()` 把 winner 初始化为 -1。winner 取值 {-1, 0, 1, 2}，其中 0 既不是初值也不是"P1/P2 编号 + 1"的延续 — **语义模糊**
- **测试**：`test_death_and_winner.gd::test_draw_when_both_sides_die_same_turn`
- **可能原因**：作者用 0 表示平局，但未加 `const DRAW := 0` 或类似常量提示读者

---

## 已解决（重构后回填）

_（空）_

---

## 索引（按位置）

| 文件行 | 函数 | 条目 |
|--------|------|------|
| `battle_core.gd:578` | `_apply_defense` | B-001 / B-002 / B-003 |
| `battle_core.gd:202` | `select_action` | B-004 |
| `battle_core.gd:137` | `_get_action_cost` (BAI_SHOU 分支) | B-005 |
| `battle_core.gd:72-113` | `setup` | B-006 |
| `battle_core.gd:438-447` | `resolve` Phase 4 | B-007 |
