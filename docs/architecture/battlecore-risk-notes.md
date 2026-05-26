# BattleCore 风险笔记

> **短文档**。仅记录最关键的隐式规则与未来重构原则。
> 详细背景：`tests/BEHAVIOR_NOTES.md`、`tests/unit/battle/*.gd`。
>
> **⚠️ v3 历史（2026-05-25）**：本文 §1-§4 的行号/函数名（`_apply_defense`/`_calc_attack_raw`/`_route_damage`/百兽 kit 等）指向**已删除的 v3 `battle_core.gd`**，不对应当前 v4 代码。H6 RNG 风险已由 ADR-002 D7（seed 注入）解决，HeroSkill 迁移（§3/§4）已重启并完成。当前真相源 = v4 `src/battle/battle_core.gd` + `tests/unit/battle/v4/`。正文作历史保留。

---

## 1. 最危险的隐式规则（6 条）

| # | 规则 | 位置 | 主要风险场景 |
|---|------|------|-------------|
| H1 | `resolve()` 6 phase 顺序固定，phase 间通过私有 state 通信 | `battle_core.gd:258-486` | 技能组件化时 hook 必须落在正确的 phase |
| H2 | `_calc_attack_raw` → `_apply_defense` → `_route_damage` 必须依次调用（中间 `_raw_dmg_to[p]` 被设置供反戈读取） | `battle_core.gd:566-595` | 拆函数会破坏反戈反弹链 |
| H3 | `selected_target` 索引到 shuffle 后的 `clone_order` | `battle_core.gd:209,517` | UI 显示位置必须与 `clone_order` 同步；shuffle 不 deterministic |
| H4 | `selected_action[p]` 在 phase 1 被 `YU_ZHE`（愚者）改值 | `battle_core.gd:278-283` | UI 拿不到玩家原始选择；网络同步要小心 |
| H5 | `shield[p][slot]` 按 slot 索引而非 active hero | `battle_core.gd:391,400` | 切换后 shield 在新 slot 上才生效；无 `current_shield(p)` getter |
| H6 | `randi_range` 直接调用，无 RNG 注入 | `battle_core.gd:89,280,348,522` | 联网/录像无法重放 |

---

## 2. 最易被误改的行为（5 条）

| # | 行为 | 误改风险 | 保护方式 |
|---|------|---------|---------|
| 1 | ATTACK × ATTACK 双方各受 1 伤（B-001） | 第一眼像 bug，会被"修"成抵消 | `# LOCKED-FOR-REFACTOR` + `BEHAVIOR_NOTES.md` |
| 2 | `_calc_attack_raw` 内 hardcoded 被动列表（chenlong/xugou） | 加新被动时忘加到这里 | **HeroSkill 迁移**（本文 §3） |
| 3 | `select_switch_target` 内 h07/h09 字面量分支 | 拆英雄技能时漏迁移 | 未来 `on_switch_in/out` hooks |
| 4 | `turn_number += 1` 在 `resolve()` 末尾，司晨用 `(turn_number+1) % 3` | 递增时机改了，司晨周期偏移 1 | docstring 锁定时机 |
| 5 | `events: Array[String]` 是 UI 唯一事件源 | 字符串改动会让 UI / 测试同时炸 | `last_result` 字段尽量稳定，新增字段不删旧字段 |

---

## 3. HeroSkill 小步迁移原则

> ⏸ **2026-05-18 状态更新**：迁移已**暂停**。详见 `ADR-001 §D4`。
> 本节原则保留作为"重启迁移时"的参照，**当前不执行**。
> 重启条件：英雄设计稳定（`design/heroes.md` "过渡版本"声明被撤销）。

### 设计原则

- **极简基类**：`HeroSkill` 只放当前迁移需要的 hook，**禁止**预设完整 hook 列表
- **新旧共存**：迁移过的英雄走 hook；未迁移的英雄走原 if 分支；不强求一次性纯化
- **一次迁一个**：每个英雄独立 commit；跑完测试再下一个
- **测试跟进**：迁移哪个英雄就为它补 2-3 个核心 case 测试，不预先全覆盖
- **不为架构而架构**：抽象让阅读成本升高 → 不保留

### 当前 hook 表

| hook | 触发位置 | 已迁移英雄 |
|------|---------|-----------|
| `on_attack_calc(raw_dmg, action, battle, player, energy_before) -> int` | `_calc_attack_raw` 内 | h05 龙威（首批） |

### 何时该加新 hook

**仅当**某个英雄当前用 hardcoded if 分支、且**即将**被迁移时加新 hook。
不为"未来可能需要"加。

---

## 4. 评估窗口

### 原计划

完成 h05 迁移后停下评估：
- 开发体验是否真的改善？
- BattleCore 是否更容易维护？
- 当前抽象是否过重？

通过则继续 h10/h12；不通过则回滚或调整方案。

### ✅ 评估结论（2026-05-18）

**结论：暂停**（不回滚 h05，不继续迁移其他英雄）。详见 `ADR-001 §D4`。

**评估时观察到的事实**：

| 维度 | 数据 |
|------|------|
| h05 迁移净成本 | 新增框架 ~56 行（基类 + 注册 + 调用）/ 节省 battle_core ~2 行 → 短期亏本 |
| 候选英雄 hook 复用率 | 0 / 12 — 候选英雄（h07/h10/h11/h12）**没有**任何一个能"零新 hook"复用 `on_attack_calc` |
| 候选英雄 hook 类型多样性 | h11 需新 `on_shield_calc`；h12 需新 `on_damage_taken`；h10 需新 `on_action_modify`；h07 需新 `on_switch_in/out` 双 hook |
| 设计稳定性 | `design/heroes.md` 明示 h06~h13 大概率重新设计 |

**结论的逻辑链**：抽象成本只有抽完 4~5 个稳定英雄才回本；当前候选英雄既需要持续扩张 hook 表、又大概率被设计变更稀释 → 现在继续投入是负收益。
