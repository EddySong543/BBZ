# BattleCore 风险笔记

> **短文档**。仅记录最关键的隐式规则与未来重构原则。
> 详细背景：`tests/BEHAVIOR_NOTES.md`、`tests/unit/battle/*.gd`。

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

完成 h05 迁移后停下评估：
- 开发体验是否真的改善？
- BattleCore 是否更容易维护？
- 当前抽象是否过重？

通过则继续 h10/h12；不通过则回滚或调整方案。
