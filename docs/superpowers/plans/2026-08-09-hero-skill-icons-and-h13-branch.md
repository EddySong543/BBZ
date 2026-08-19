# Hero Skill Icons And H13 Branch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the newly supplied hero skill icons, mark h05/h13 as active enhancements in the Hero Gallery, and move h13's split-big-wave choice from above End to an icon branch above Big Wave.

**Architecture:** Keep each hero resource path stable by replacing only `hXX_skill.png` at its existing destination. Store skill classification in `HeroData.skill_type`; preserve the approved Hero Gallery layout. Reuse h05's runtime branch-button structure for h13 while keeping h13's existing BattleCore choice flag and network protocol unchanged.

**Tech Stack:** Godot 4, GDScript, `.tres` resources, GUT, PNG texture import.

## Global Constraints

- Only process the exact `assets/import/hXX.png` files present in this batch.
- Preserve existing `res://assets/sprites/heroes/hXX/hXX_skill.png` resource paths and destination `.import` settings.
- Do not alter the approved Hero Gallery geometry or visual rhythm.
- H13's branch is visible only after selecting `大波`, uses the h13 skill icon, and does not add an extra energy-cost badge.
- H24's branch must stack above the h13 branch when both apply to `大波`.
- Launch Godot only through `tools/run_godot.ps1`.

---

### Task 1: Lock the desired data and UI behavior with regression checks

**Files:**
- Modify: `tests/unit/ui/test_screen_compiles.gd`
- Modify: `tests/unit/ui/test_round_countdown_ui.gd`
- Modify: `tools/h13_split_big_wave_probe.gd`

**Interfaces:**
- Consumes: `HeroData.SkillType.ENHANCED_ACTION`, `BattleScreen.split_big_wave_picker`, `BattleScreen.btn_split_big_wave`.
- Produces: regression assertions for gallery tags, branch icon, branch alignment, selection state, and h05-style shadow.

- [x] **Step 1: Add gallery assertions for h05 and h13**

```gdscript
screen._select(4)
assert_eq(tag.text, "主动")
screen._select(12)
assert_eq(tag.text, "主动")
```

- [x] **Step 2: Update the h13 probe contract**

```gdscript
if not screen.split_big_wave_picker.visible:
	failures.append("选择大波后没有显示暗潮分支")
if branch_icon == null or branch_icon.texture == null:
	failures.append("暗潮分支内部缺少技能icon")
```

- [x] **Step 3: Run the focused checks before implementation**

Run: `& .\tools\run_godot.ps1 -Mode Test`

Expected: new h05/h13 active-label assertions fail while the resources still use the passive default.

### Task 2: Replace the supplied skill-icon sources

**Files:**
- Move and rename: `assets/import/h01.png`, `h02.png`, `h03.png`, `h04.png`, `h05.png`, `h07.png`, `h08.png`, `h10.png`, `h11.png`, `h14.png`, `h16.png`, `h23.png`
- Replace: corresponding `assets/sprites/heroes/hXX/hXX_skill.png`

**Interfaces:**
- Consumes: stable `HeroData.skill_icon_path` values.
- Produces: new source PNG contents at all existing skill-icon resource paths.

- [x] **Step 1: Resolve and validate every source and destination path**

```powershell
Get-ChildItem assets/import -File | Where-Object Name -Match '^h\d{2}\.png$'
```

- [x] **Step 2: Rename each source to `hXX_skill.png` and move it into `assets/sprites/heroes/hXX/`**

Use exact paths only; replace the tracked destination PNG and remove only the orphaned source-path `.png.import` sidecar.

- [x] **Step 3: Reimport through the project launcher**

Run: `& .\tools\run_godot.ps1 -Mode Import`

Expected: exit code 0 and regenerated destination texture caches without missing-resource errors.

### Task 3: Mark h05/h13 active and rebuild h13's branch presentation

**Files:**
- Modify: `assets/data/heroes/h05.tres`
- Modify: `assets/data/heroes/h13.tres`
- Modify: `src/ui/battle_screen.gd`

**Interfaces:**
- Consumes: existing `_split_big_wave_armed` and `BattleCore.can_split_big_wave_action(...)` behavior.
- Produces: `split_big_wave_picker: Control` above `btn_big_attack`, containing `btn_split_big_wave` with `h13_skill.png`.

- [x] **Step 1: Set both data resources to enhanced-action type**

```gdscript
skill_type = 2
```

- [x] **Step 2: Create h13's icon branch with the Big Wave button's existing style**

```gdscript
split_big_wave_picker = Control.new()
split_big_wave_picker.size = btn_big_attack.size
btn_split_big_wave = _make_split_big_wave_branch_button()
```

- [x] **Step 3: Show and align the branch only for the selected Big Wave**

```gdscript
var show_split_picker := state == State.PLAYER_SELECT and has_split \
		and selected_action == A.BIG_ATTACK and selected_btn == btn_big_attack
```

- [x] **Step 4: Stack h24 above h13 when both branch controls are visible**

```gdscript
if selected_btn == btn_big_attack and split_big_wave_picker.visible:
	stack_offset = split_big_wave_picker.size.y + 14.0
```

### Task 4: Verify import, data, UI, and interaction

**Files:**
- Verify: all files modified in Tasks 1-3.

**Interfaces:**
- Consumes: project launcher, GUT, h05/h13 probes.
- Produces: fresh import/test/probe evidence and a 1920x1080 h13 screenshot.

- [x] **Step 1: Run focused GUT files**

Run: `& .\tools\run_godot.ps1 -Mode Test`

Expected: all focused tests pass.

- [x] **Step 2: Run the h05 and h13 interaction probes**

Run: `& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/h05_longyuji_toggle_probe.tscn'`

Run: `& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/h13_split_big_wave_probe.tscn'`

Expected: `H05_LONGYUJI_BRANCH_PICKER_PROBE_PASS` and `H13_SPLIT_BIG_WAVE_PROBE_PASS`.

- [x] **Step 3: Run the full GUT suite**

Run: `& .\tools\run_godot.ps1 -Mode Test`

Expected: zero test failures attributable to this task.

- [x] **Step 4: Inspect scope and source paths**

Run: `git status --short` and `git diff -- <task files>`.

Expected: no `assets/import/hXX.png` remains from this batch; each target `hXX_skill.png` exists; unrelated dirty files remain untouched.
