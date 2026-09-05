# h04「十方无次第」Implementation Plan

> ⚠️ **H03 交互为历史记录。**本计划中的 H04 自由选敌设计仍可溯源，但“H03 对攻先制 / 击杀断招”边界已退役；当前 H03 规则见 [`heroes.md`](../../../design/heroes.md) 与 [`2026-09-03-action-anchor-sequence-design.md`](../specs/2026-09-03-action-anchor-sequence-design.md)。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 h04 房日重做为 5 HP 的进攻英雄：其「波」和「大波」可指定任一存活敌方英雄，并完整退役旧版“敌方重复动作产能”。

**Architecture:** 在 `HeroSkill` 增加无状态的基础攻击自由选敌 hook；`BattleCore` 为双方各保存本回合基础攻击目标槽，并将该槽写入动作 hit，伤害管线据此结算目标英雄的防御、状态、护甲、受伤、命中与死亡。`legal_actions()` 为 AI 枚举每个存活敌方英雄；本地 UI 复用敌方头像框点选，中央出战位与两个替补位均可选。事件携带目标槽，中央角色只播放自身受击，替补受击反馈落到对应头像框。

**Tech Stack:** Godot 4、GDScript、GUT、Resource `.tres`、CSV i18n。

## Global Constraints

- 技能名固定为 `十方无次第`，h04 最大生命保持 `5`。
- 玩家可见说明固定为：`房日【兔】的「波」和「大波」可以指定任一敌方英雄。`
- 仅 h04 出战、存活、未沉默时开放自由目标；h04 在替补席不提供团队效果。
- 自由目标仅作用于基础「波 / 大波」；主动技、道具 hit、反击与其他英雄的基础攻击保持原目标规则。
- 未显式传目标的旧调用兼容为攻击敌方当前出战英雄；AI 合法集必须使用显式目标。
- 目标在提交后按英雄槽位锁定；敌方同拍切换不改变目标。若目标在动作 hit 前已阵亡，该 hit 落空，不自动改打别人。
- 对指定目标使用的防 / 大防仍按敌方本回合动作统一生效；破甲、护甲、毒、印记、易伤、on-hit 与死亡结算都落在实际目标槽。
- 替补受到致命伤时正常阵亡，但不触发出战位死亡换人；天狗护主与还魂等“出战将死”保护不替替补承伤。
- h03 对攻先制仍以双方出招英雄为断招判定对象；h04 即使瞄准替补，也不能绕开自身出招英雄被白额雷音击杀后的断招。
- 删除 `enemy_repeat_energy()` hook、h04 Phase 5.7 与 `repeat_energy` 现行引用；`_last_action` 仍供雪球等其他系统使用。
- 新增的攻击目标状态必须同步 `setup()`、`clone()`、快照 schema、`to_snapshot()`、`from_snapshot()` 与回合清理。
- 保留工作区内 h01、h02、h03、Scene/UI 及其他任务改动；只做精确小块补丁。
- 未经用户明确要求，不 commit、不 push。

---

### Task 1: 用失败测试锁定发布数据与目标结算契约

**Files:**
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`
- Modify: `tests/unit/battle/ai/test_battle_clone_ai.gd`
- Modify: `tests/unit/battle/v4/test_battle_snapshot.gd`

- [ ] **Step 1: 更新 h04 发布数据测试**

断言 HP5、技能名“十方无次第”、主定位“进攻”、说明文本与已批准文案完全一致。

- [ ] **Step 2: 替换旧重复产能测试**

新增行为测试：

- 「波」指定替补时只伤害该替补，敌方出战位不受伤。
- 「大波」指定替补时造成大波伤害；普通防挡不住，大防可以挡住。
- 指定目标在敌方同拍切换后仍按原槽位承伤。
- 指定替补死亡只处理该替补死亡，不设置出战死亡换人。
- 非 h04、替补席 h04、阵亡或越界目标不能显式定向。
- 无显式目标的兼容调用仍攻击敌方结算时出战位。
- 旧重复动作不再产生额外能量，也不再发出 `repeat_energy`。

- [ ] **Step 3: 锁定 AI、clone 与快照**

断言 h04 的「波 / 大波」各为每个存活敌方槽生成一个 `{action,target}` 合法选项；`apply_choice()` 传入目标后，clone 与 JSON 快照往返都保留选择，并能得到相同结算。

- [ ] **Step 4: 运行完整 GUT，确认旧实现上新测试失败**

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300
```

---

### Task 2: 实现通用基础攻击目标状态与 h04 技能

**Files:**
- Modify: `src/battle/hero_skill.gd`
- Move: `src/battle/skills/h04_jiaotu.gd` → `src/battle/skills/h04_wucidi.gd`
- Move: `src/battle/skills/h04_jiaotu.gd.uid` → `src/battle/skills/h04_wucidi.gd.uid`
- Modify: `src/battle/battle_core.gd`

- [ ] **Step 1: 增加无状态 hook**

```gdscript
func can_target_any_enemy_with_base_attack() -> bool:
	return false
```

h04 覆写为 `true`；删除旧 `enemy_repeat_energy()` hook。

- [ ] **Step 2: 新增本回合攻击目标状态**

增加 `_attack_target: Array[int] = [-1, -1]`，并同步 setup、clone、快照、恢复与回合清理。`select_action(player, action, target=-1)` 仅在出战技能允许且目标存活时接受显式目标；基础攻击未显式选目标时保留 `-1` 的“跟随当前出战位”兼容语义。

- [ ] **Step 3: 扩展合法动作与 choice 分派**

`legal_actions()` 对 h04 的「波 / 大波」逐个枚举敌方存活槽，其他基础动作仍为 `target=-1`；`apply_choice()` 把目标传给 `select_action()`。

- [ ] **Step 4: 将目标槽贯穿 hit 与伤害管线**

动作 hit 写入 `target_slot`；`_apply_resolve_hit()` 将其传给 `_apply_damage()`。显式槽合法且存活时以该槽结算完整伤害管线；目标已阵亡则发出带槽位的落空事件并返回 0。所有与目标有关的伤害/格挡/状态事件补充 `slot`。

- [ ] **Step 5: 删除旧 h04 结算阶段**

移除 Phase 5.7、`enemy_repeat_energy()` 与 h04 旧注释，但保留 `_last_action` 及其他调用者。

---

### Task 3: 接入本地 UI 与替补受击反馈

**Files:**
- Modify: `src/ui/battle_screen.gd`

- [ ] **Step 1: 泛化敌方目标选择态**

复用 `_enemy_target_pick`，记录当前是 h21 主动技还是 h04 基础攻击。h21 仍只允许点存活替补并显示“揪”；h04 允许点三个敌方头像框中的任一存活英雄并显示“攻”。切换到其他动作或离开选择阶段时完整清理。

- [ ] **Step 2: 本地提交携带攻击目标**

本地调用 `battle.select_action(PLAYER, selected_action, _enemy_target_pick)`。h04 未点目标时默认选择敌方当前出战位，避免提交不在合法集中。

- [ ] **Step 3: 让事件演出落到正确英雄**

`damage_taken`、格挡与死亡按 `slot` 区分。结算前出战槽的伤害继续走中央角色演出；替补伤害不再错误击打中央角色，而是让对应 `HeroFrame` 局部闪红、轻弹并显示伤害数字。死亡仍由事件与刷新后的头像状态表达。

---

### Task 4: 同步资源、i18n 与当前设计文档

**Files:**
- Modify: `assets/data/heroes/h04.tres`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `design/heroes.md`
- Modify: `design/heroes-redesign.md`
- Modify: `design/heroes-schools.md`
- Modify: `design/build-design-framework.md`
- Modify current-reference comments/docs discovered by global scan

- [ ] **Step 1: 更新发布资源**

```text
team_role = "进攻"
skill_description = "十方无次第"
skill_detail = "房日【兔】的「波」和「大波」可以指定任一敌方英雄。"
```

保留兼容字段 `dimension = "节奏"`，直到旧技术标签统一迁移。

- [ ] **Step 2: 更新玩家文案与设计依据**

统一记录 h04 的新定位、目标选择博弈、组合方式与明确边界；旧“玉魄乘隙/重复动作产能”只允许在标为历史废案的段落保留。

- [ ] **Step 3: 全局扫描旧现行引用**

```powershell
rg -n "玉魄乘隙|敌方重复动作|repeat_energy|enemy_repeat_energy|h04_jiaotu|灵跃藏锋" src tests design assets
```

---

### Task 5: 导入、完整验证与差异审计

- [ ] **Step 1: 运行 Godot 导入检查**

```powershell
& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 180
```

- [ ] **Step 2: 运行完整 GUT**

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300
```

- [ ] **Step 3: 检查差异与遗留**

```powershell
$Repo = 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization'
git -c safe.directory=$Repo -C $Repo diff --check
git -c safe.directory=$Repo -C $Repo status --short
```

确认只精确改动本任务相关小块，不提交、不推送。
