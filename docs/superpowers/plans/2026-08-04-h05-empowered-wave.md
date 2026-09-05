# h05「龙御极」强化波 Implementation Plan

**Goal:** 将 h05 重做为团队可选的「波」强化：亢金在队时，我方可为本次「波」额外支付 1 能，使伤害增加 1 点；旧「破绽」机制完整退役。

**Architecture:** 保留 `ActionDef.Action.ATTACK` 作为唯一「波」动作，在 `BattleCore` 增加逐方布尔选择态 `empowered_wave`。合法动作枚举把普通波与强化波作为两个 choice 暴露；玩家 UI 与 AI 传递同一个 `empowered_wave` 标记。结算时额外扣 2 半能并给该次波增加 2 半点伤害，不改变动作类型与穿透等级；h02 若把这次波升级为大波，则在大波伤害上继续叠加 1 点。

**Tech Stack:** Godot 4、GDScript、GUT、`.tres` 英雄资源、CSV i18n。

## Global Constraints

- 玩家短文案固定为：`亢金【龙】在队时，我方的「波」可以额外消耗1点能量，使伤害增加1点。`
- 强化是主动选择，不自动扣能；普通波始终保留。
- 强化波总费用 2 能、总伤害 2 点，仍是「波」，所以普通「防」可以完整挡下。
- 只强化基础「波」；大波、主动技、道具伤害、反击和持续伤害不适用。
- 强化波与 h02 的波升级、h04 的攻击目标、h16 的疾风及攻击道具复用原有路径。
- 保留工作树中 h09-h11、Scene、Boot 与 UI 等其他任务改动。

## Task 1: 先锁定新行为测试

**Files:**
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`
- Modify: `tests/unit/battle/ai/test_battle_clone_ai.gd`
- Modify: `tests/unit/battle/v4/test_battle_snapshot.gd`

- [x] 普通波与强化波同时进入合法 choice；不足 2 能时只有普通波。
- [x] 强化波额外扣 1 能、加 1 伤，仍被普通防挡住。
- [x] 替补 h05 同样授权；无 h05、大波或错误标记提交均拒绝。
- [x] h02 升级与 h05 强化同时生效；h04 目标和 h16 双段不丢选择态。
- [x] clone、快照与 JSON 往返保留已提交的强化波。

## Task 2: 实现统一选择与结算

**Files:**
- Modify: `src/battle/hero_skill.gd`
- Modify: `src/battle/battle_core.gd`
- Move: `src/battle/skills/h05_pozhan.gd` → `src/battle/skills/h05_longyuji.gd`
- Move: `src/battle/skills/h05_pozhan.gd.uid` → `src/battle/skills/h05_longyuji.gd.uid`
- Modify: `src/battle/ai/battle_ai.gd`
- Modify: `src/battle/ai/battle_eval.gd`

- [x] 用无状态技能能力 `enables_empowered_wave()` 标记 h05。
- [x] 增加 `has_empowered_wave`、`can_empower_wave`、`select_empowered_wave` 与 choice 成本门。
- [x] 选择态同步 setup、clone、快照、resolve 清理。
- [x] Phase 2 额外扣费；hit 生成时额外加伤，动作身份和穿透保持不变。
- [x] 删除 `opening` 状态消费、被挡钩子及 AI 资产权重。

## Task 3: 接通玩家 UI 与本地提交

**Files:**
- Modify: `src/ui/battle_screen.gd`
- 旧同步分支已废弃；当前只保留本地 BattleCore 逻辑。

- [x] 仿照「疾风」建立 `龙御极 +1能` 开关，仅选中波且付得起时可启用。
- [x] 本地提交、重置和超时均正确清理或传递选择。

## Task 4: 同步玩家数据与当前设计文档

**Files:**
- Modify: `assets/data/heroes/h05.tres`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `design/heroes.md`
- Modify: `design/heroes-redesign.md`
- Modify: `design/heroes-schools.md`
- Modify: `design/copy-style-guide.md`
- Modify: `docs/architecture/battlecore-risk-notes.md`

- [x] 所有当前真相源改为强化波机制。
- [x] 删除当前术语与架构中的 h05「破绽」说明；旧实施计划保留为历史记录。
- [x] 更新受旧 h05 combo 事件影响的暗英雄测试。

## Task 5: 验证与 h08 审视

- [x] 运行 `& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 180`（exit 0）。
- [x] 运行 `& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300`：h05 及战斗核心相关测试通过；全套 584/590，剩余 5 个远征 UI 失败与 1 个 Scene2 层级失败来自工作树中的其他任务。
- [x] 运行真实 BattleScreen 截图探针，确认默认含 h05 队伍显示 `龙御极 +1能` 开关且不遮挡既有 UI。
- [x] 全局扫描 `h05_pozhan|opening_applied|opening_used|亢金.*破绽|龙.*破绽`，只允许历史计划命中。
- [x] 基于 h08 当前代码、边界测试和资源曲线分析强度来源；只提出建议，不改 h08。
