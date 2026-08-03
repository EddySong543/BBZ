# h05 / h07 Skill Name Update Implementation Plan

> **For agentic workers:** Execute this plan inline and preserve all unrelated working-tree changes.

**Goal:** 将 h05 技能名统一为「龙御极」，将 h07 技能名统一为「千里自在风」，不改变任何技能机制、数值或玩家文案效果。

**Architecture:** 英雄 `.tres` 是玩家可见名称真相源；技能脚本、BattleCore、UI、测试及设计文档中的名称只作同步引用。h07 技能脚本文件同时按新名称改为 `h07_qianlizizaifeng.gd`，保留原 Godot UID，避免资源身份变化。

**Tech Stack:** Godot 4.x、GDScript、GUT、Markdown、CSV

## Global Constraints

- 只改技能名称及由名称派生的文件名、测试名和注释。
- 不改变 h05「攻击被成功防御后施加破绽」的机制。
- 不改变 h07「涉及星日的切换不占动作，并在登场时造成 0.5 冲撞伤害」的机制。
- 保留工作区内所有无关改动。
- 用户未要求 commit 或 push，本计划不执行 Git 提交。

---

### Task 1: 更新英雄真相源与运行时代码引用

**Files:**
- Modify: `assets/data/heroes/h05.tres`
- Modify: `assets/data/heroes/h07.tres`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `src/battle/battle_core.gd`
- Modify: `src/battle/hero_skill.gd`
- Modify: `src/battle/skills/h05_pozhan.gd`
- Move current h07 skill script to: `src/battle/skills/h07_qianlizizaifeng.gd`
- Move its UID sidecar to: `src/battle/skills/h07_qianlizizaifeng.gd.uid`
- Modify: `src/ui/battle_screen.gd`

**Interfaces:**
- Consumes: `HeroData.skill_description`、BattleCore 的 h07 preload 映射、HeroSkill 免费切换 hook。
- Produces: 运行时统一显示「龙御极」与「千里自在风」，h07 preload 指向新脚本路径。

- [x] **Step 1: 精确替换玩家可见名称**

将 h05 `skill_description` 改为 `"龙御极"`，将 h07 `skill_description` 改为 `"千里自在风"`，并同步 CSV。

- [x] **Step 2: 重命名 h07 技能脚本并更新 preload**

移动 `.gd` 与 `.gd.uid`，保留 UID 文件内容不变；将 BattleCore preload 更新为：

```gdscript
"h07": preload("res://src/battle/skills/h07_qianlizizaifeng.gd"),
```

- [x] **Step 3: 同步代码注释**

将运行时代码中仅用于说明的旧技能名全部替换为新名称，不改函数签名、常量与结算顺序。

### Task 2: 更新设计文档与测试名称

**Files:**
- Modify: `design/gdd/game-concept.md`
- Modify: `design/heroes.md`
- Modify: `design/heroes-redesign.md`
- Modify: `design/naming-bank.md`
- Modify: `docs/architecture/ADR-002-battle-core-v4-architecture.md`
- Modify: `docs/architecture/battlecore-risk-notes.md`
- Move/update the previous h05 naming plan to: `docs/superpowers/plans/2026-07-31-h05-longyuji.md`
- Modify: `tests/unit/battle/v4/test_hero_team_role.gd`
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`

**Interfaces:**
- Consumes: 已批准的新名称与现行 h05 / h07 机制。
- Produces: 文档、断言、测试函数名和测试说明均不再残留旧名称。

- [x] **Step 1: 同步现行设计文档**

所有现行标题、表格、命名解释及架构注释使用「龙御极」和「千里自在风」。h05 命名解释改为：“龙”点明龙相；“御极”取登临极位之意，表现亢金生来居于龙相之顶，其攻势即使被完整防御，仍会在守势中留下后手。h07 命名解释改为：“千里”点明马的远行尺度；“自在风”把不受普通切换动作限制的自由感写成随马而行的风。

- [x] **Step 2: 同步历史实施计划**

计划文件名与其目标名称改为 `h05-longyuji` / 「龙御极」，机制步骤保持原样。

- [x] **Step 3: 更新测试断言与测试函数名**

将 h05 名称断言期望值改为 `"龙御极"`；将 h07 测试函数名改为：

```gdscript
func test_h07_qianlizizaifeng_chongzhuang_on_switch_in() -> void:
```

- [x] **Step 4: 验证**

运行：

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300
```

结果：`test_hero_team_role.gd` 8/8、`test_heroes_zodiac_v4.gd` 64/64 通过；全局搜索旧名称及旧 h07 脚本路径为零。完整套件另有 9 个 Boot Screen 测试失败，失败文件不在本计划改动范围内。
