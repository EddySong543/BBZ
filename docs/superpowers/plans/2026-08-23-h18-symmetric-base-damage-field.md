# H18 Symmetric Base Damage Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace h18's retired HP redistribution active with an active-only symmetric battlefield passive that makes both sides' Wave and Big Wave base damage equal 1 HP.

**Architecture:** Add one stateless battlefield-level base-attack hook to `HeroSkill`, invoked by `BattleCore._calc_outgoing()` before existing attacker and team modifiers. H18 overrides only that hook; no runtime state, timers, networking fields, or action-flow changes are introduced.

**Tech Stack:** Godot 4 GDScript, BattleCore v4, GUT.

## Global Constraints

- Use 2 half-points as 1 HP.
- Apply the field after switches and forced pulls, when base-attack hit snapshots are built.
- Normalize only Wave and Big Wave base damage; modifiers remain later in the pipeline.
- Do not affect active attacks, pursuits, counters, or independent damage.
- Keep simultaneous resolution and all defense penetration rules unchanged.
- Use “待命名” as the temporary display name until Eddy approves a candidate.
- Do not touch unrelated dirty Scene 7, UI, item, expedition, runner, or test files.

---

### Task 1: Lock the new H18 behavior with failing tests

**Files:**
- Modify: `tests/unit/battle/v4/test_heroes_dark_v4.gd`
- Modify: `tests/unit/battle/v4/test_hero_team_role.gd`

**Interfaces:**
- Consumes: `BattleCore.select_action()`, `BattleCore.select_active()`, `BattleCore.resolve()`, `BattleCore.set_status()`.
- Produces: behavioral contracts for symmetric normalization, active-only presence, modifier ordering, independent active damage, and published hero data.

- [ ] **Step 1: Replace the retired redistribution tests**

```gdscript
func test_h18_field_normalizes_both_sides_big_wave_base_damage() -> void:
    var b := _battle("h18", 5, 20)
    b.select_action(0, ActionDef.Action.BIG_ATTACK)
    b.select_action(1, ActionDef.Action.BIG_ATTACK)
    b.resolve()
    assert_eq(b.hp[0][0], 8)
    assert_eq(b.hp[1][0], 8)
```

- [ ] **Step 2: Add boundary tests**

```gdscript
func test_h18_field_requires_active_unsilenced_h18() -> void:
    var reserve := _battle_team(["test_p0_0", "h18", "test_p0_2"], 5, 20)
    _resolve(reserve, ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE)
    assert_eq(reserve.hp[1][0], 6)

    var silenced := _battle("h18", 5, 20)
    silenced.set_status(0, 0, "silenced", 1)
    _resolve(silenced, ActionDef.Action.CHARGE, ActionDef.Action.BIG_ATTACK)
    assert_eq(silenced.hp[0][0], 6)

func test_h18_field_preserves_empowered_wave_and_vulnerability_after_base_value() -> void:
    var empowered := _battle_team(["h18", "h05", "test_p0_2"], 5, 20)
    assert_true(empowered.select_action(0, ActionDef.Action.ATTACK, -1, true))
    empowered.select_action(1, ActionDef.Action.CHARGE)
    empowered.resolve()
    assert_eq(empowered.hp[1][0], 6)

    var vulnerable := _battle("h18", 5, 20)
    vulnerable.set_status(1, 0, "vuln", 1)
    _resolve(vulnerable, ActionDef.Action.ATTACK, ActionDef.Action.CHARGE)
    assert_eq(vulnerable.hp[1][0], 7)

func test_h18_field_does_not_modify_attack_active_damage() -> void:
    var b := _battle_vs(
        ["h18", "test_p0_1", "test_p0_2"],
        ["h10", "test_p1_1", "test_p1_2"], 5, 20)
    b.set_status(1, 0, "jianqi", 4)
    b.select_action(0, ActionDef.Action.CHARGE)
    assert_true(b.select_active(1))
    b.resolve()
    assert_eq(b.hp[0][0], 4)
```

- [ ] **Step 3: Update the data contract test**

```gdscript
assert_eq(h.max_hp, 5)
assert_eq(h.team_role, "防守")
assert_eq(h.skill_type, HeroData.SkillType.PASSIVE)
assert_eq(h.skill_description, "待命名")
assert_eq(h.skill_detail, "相柳【蛇】出战时，双方「波」与「大波」的基础伤害均视为1点。")
```

- [ ] **Step 4: Run the two scoped test files and verify RED**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_heroes_dark_v4.gd'
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_hero_team_role.gd'
```

Expected: failures reference the missing battlefield normalization and old h18 data.

### Task 2: Implement the stateless battlefield hook

**Files:**
- Modify: `src/battle/hero_skill.gd`
- Modify: `src/battle/battle_core.gd`
- Create: `src/battle/skills/h18_base_damage_field.gd`
- Create: `src/battle/skills/h18_base_damage_field.gd.uid`
- Delete: `src/battle/skills/h18_chanrao.gd`
- Delete: `src/battle/skills/h18_chanrao.gd.uid`

**Interfaces:**
- Produces: `HeroSkill.modify_battlefield_base_attack_damage(dmg: int, action: int, battle: BattleCore, attacker_player: int, attacker_slot: int, self_player: int, self_slot: int) -> int`.
- Consumes: `ActionDef.HP_UNIT`, `BattleCore.active_index`, and the existing silence-time nulling of `_skills`.

- [ ] **Step 1: Add the default no-op hook**

```gdscript
func modify_battlefield_base_attack_damage(dmg: int, _action: int, _battle: BattleCore,
        _attacker_player: int, _attacker_slot: int, _self_player: int, _self_slot: int) -> int:
    return dmg
```

- [ ] **Step 2: Apply active battlefield hooks before outgoing modifiers**

```gdscript
func _apply_battlefield_base_attack_damage(dmg: int, action: int,
        attacker_player: int, attacker_slot: int) -> int:
    for field_player: int in [0, 1]:
        var field_slot: int = active_index[field_player]
        var field_skill: HeroSkill = _skills[field_player][field_slot]
        if field_skill != null and hp[field_player][field_slot] > 0:
            dmg = field_skill.modify_battlefield_base_attack_damage(
                dmg, action, self, attacker_player, attacker_slot, field_player, field_slot)
    return dmg
```

- [ ] **Step 3: Implement H18 and update its preload**

```gdscript
extends HeroSkill

func modify_battlefield_base_attack_damage(_dmg: int, _action: int, _battle: BattleCore,
        _attacker_player: int, _attacker_slot: int, _self_player: int, _self_slot: int) -> int:
    return ActionDef.HP_UNIT
```

- [ ] **Step 4: Run the scoped hero behavior test and verify GREEN**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_heroes_dark_v4.gd'
```

Expected: all tests in the file pass.

### Task 3: Publish the approved data and canonical documentation

**Files:**
- Modify: `assets/data/heroes/h18.tres`
- Modify: `design/heroes.md`
- Modify: `design/heroes-redesign.md`
- Modify: `design/heroes-schools.md`

**Interfaces:**
- Produces: HP5 passive data, defensive legacy role, pending display name, exact player copy, and updated design history.

- [ ] **Step 1: Update h18 resource data**

```text
team_role = "防守"
max_hp = 5
skill_type = 0
skill_description = "待命名"
skill_detail = "相柳【蛇】出战时，双方「波」与「大波」的基础伤害均视为1点。"
```

- [ ] **Step 2: Replace the retired h18 canonical documentation**

Record the passive field rule, modifier ordering, independent-damage exclusion, HP5, control main role, and pending name. Move h18 from Defense to Control in the five-role roster table.

- [ ] **Step 3: Run the scoped data test**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_hero_team_role.gd'
```

Expected: all published-data contracts pass.

### Task 4: Verify the integrated result

**Files:**
- Inspect only all files modified by Tasks 1-3.

**Interfaces:**
- Consumes: the complete feature and test suite.
- Produces: fresh evidence for delivery.

- [ ] **Step 1: Run focused hero tests**

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_heroes_dark_v4.gd'
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_hero_team_role.gd'
```

- [ ] **Step 2: Run the full GUT suite**

```powershell
& .\tools\run_godot.ps1 -Mode Test
```

- [ ] **Step 3: Inspect scope and whitespace**

```powershell
git -c safe.directory=$Repo -C $Repo diff --check
git -c safe.directory=$Repo -C $Repo diff -- src/battle/hero_skill.gd src/battle/battle_core.gd src/battle/skills/h18_base_damage_field.gd assets/data/heroes/h18.tres tests/unit/battle/v4/test_heroes_dark_v4.gd tests/unit/battle/v4/test_hero_team_role.gd design/heroes.md design/heroes-redesign.md design/heroes-schools.md
```

Expected: no whitespace errors and no unrelated files in the feature diff.
