# H22 Energy Burn Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace h22【焚天火兆】with an active skill that makes both teams lose all energy at the end of the next round.

**Architecture:** Store one public global deadline (`energy_burn_turn`) in `BattleCore`, because the effect applies equally to both teams and must survive switching, death, AI cloning, and reconnect snapshots. The active skill only schedules the deadline; `BattleCore.resolve()` performs the reset after all end-of-round energy gains, emits one event, and clears the deadline.

**Tech Stack:** Godot 4.x, typed GDScript, GUT, project launcher `tools/run_godot.ps1`.

## Global Constraints

- Player copy is exactly: `下一回合结束时，双方失去全部能量。`
- Preserve h22 HP 5, skill name【焚天火兆】, active cost 0, per-game cap 2, and action-slot consumption.
- Remove the retired shield and next-attack-pierces-big-defense behavior completely.
- A scheduled burn is global, cannot be stacked or refreshed, and survives h22 switching out, dying, or transforming.
- Burn after all next-round action, item, death, relic, and passive-energy settlement, so the resulting energy is exactly zero for both sides.
- Preserve unrelated dirty-worktree changes and do not commit or push unless Eddy explicitly asks.

---

### Task 1: Lock the new h22 contract with tests

**Files:**
- Modify: `tests/unit/battle/v4/test_heroes_dark_v4.gd`
- Modify: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`
- Modify: `tests/unit/battle/ai/test_battle_clone_ai.gd`
- Modify: `tests/unit/battle/v4/test_battle_snapshot.gd`

**Interfaces:**
- Consumes: `BattleCore.turn_number`, `BattleCore.resolve()`, active-use cap state.
- Produces: behavioral expectations for `BattleCore.energy_burn_turn: int` and the `h22_energy_burn` event.

- [ ] **Step 1: Replace retired fire-omen tests**

  Cover: no immediate reset on the cast round; both teams become zero at the end of the following round; energy gained during that round is also removed; the timer survives switching; a pending timer blocks another cast; the second cast is legal after the first timer resolves; the third cast is blocked by the per-game cap.

- [ ] **Step 2: Remove old cross-hero fixtures**

  Remove direct `pierce_next_attack` setup and replace unrelated penetration fixtures with the existing `t3_jianyi` item where penetration is still the actual subject under test.

- [ ] **Step 3: Add clone and snapshot assertions**

  Assert that `energy_burn_turn` is copied into an AI clone, serialized, restored, required by the schema, and independently mutable between clone and source.

- [ ] **Step 4: Run the tests to verify RED**

  Run: `& .\tools\run_godot.ps1 -Mode Test`

  Expected: failure because `energy_burn_turn` and the new h22 behavior do not exist yet.

### Task 2: Implement the global deadline and h22 active

**Files:**
- Modify: `src/battle/battle_core.gd`
- Modify: `src/battle/skills/h22_yiming.gd`

**Interfaces:**
- Consumes: `turn_number`, end-of-round passive-energy phase, snapshot schema.
- Produces: `var energy_burn_turn: int = -1`; one `h22_energy_burn` event with both pre-reset energy values.

- [ ] **Step 1: Add and initialize the global deadline**

  Declare `energy_burn_turn` beside other serialized cross-round states and reset it to `-1` in `setup()`.

- [ ] **Step 2: Schedule from h22**

  `can_use_active()` returns true only when `energy_burn_turn < 0`. `execute_active()` assigns `battle.turn_number + 1`. It does not add shield or damage.

- [ ] **Step 3: Resolve at the correct boundary**

  After passive energy is granted, if `energy_burn_turn == turn_number`, append `{id = "h22_energy_burn", p1_amount = energy[0], p2_amount = energy[1]}`, set `energy = [0, 0]`, then clear `energy_burn_turn = -1`.

- [ ] **Step 4: Replace the retired serialized state**

  Remove `pierce_next_attack` from action-hit construction, clone, snapshot keys, snapshot payload, restore, and comments. Add `energy_burn_turn` to all four schema surfaces and increment `SNAPSHOT_VERSION`.

- [ ] **Step 5: Run tests to verify GREEN**

  Run: `& .\tools\run_godot.ps1 -Mode Test`

  Expected: all GUT tests pass with zero failures.

### Task 3: Align player data, design truth, and runtime feedback

**Files:**
- Modify: `assets/data/heroes/h22.tres`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `src/ui/battle_screen.gd`
- Modify: `design/heroes.md`
- Modify: `design/heroes-dark-h21-h24.md`
- Modify: `design/heroes-schools.md`
- Modify: `design/heroes-redesign.md`
- Modify: `design/skill-design-reference.md`

**Interfaces:**
- Consumes: `h22_energy_burn` event and approved player copy.
- Produces: gallery copy, battle event annotation, and current design records without retired mechanics presented as current.

- [ ] **Step 1: Update player-facing data**

  Set `skill_detail = "下一回合结束时，双方失去全部能量。"`; retain name, icon, HP, active type, cost, and cap.

- [ ] **Step 2: Add concise burn feedback**

  Map `h22_energy_burn` to a readable energy-reset annotation for both sides without introducing a persistent custom HUD widget.

- [ ] **Step 3: Update current design records**

  Mark the old shared-pierce version as retired history, record the global energy deadline as current, and classify the new primary design role as control while leaving legacy `.tres` UI fields untouched until the roster-wide migration.

- [ ] **Step 4: Scan for retired references**

  Run: `rg -n "pierce_next_attack|蓄力并获得 1 点护盾|我方下一次攻击穿大防|火兆共享" assets src tests design`

  Expected: no code, test, or current-mechanic claim remains; historical mentions are explicitly labeled retired.

- [ ] **Step 5: Import and run the complete suite**

  Run: `& .\tools\run_godot.ps1 -Mode Import`

  Run: `& .\tools\run_godot.ps1 -Mode Test`

  Expected: import exits 0 and the complete GUT suite reports zero failures.

- [ ] **Step 6: Review the exact task diff**

  Run targeted `git diff --` only for the files listed in this plan. Confirm no unrelated dirty-worktree content was overwritten and leave all changes uncommitted.
