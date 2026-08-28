# Battle Status Name Anchor Implementation Plan

> **For agentic workers:** Implement inline in the current task; subagent delegation is not authorized. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move persistent battle Buff icons from character feet to mirrored anchors after the player names.

**Architecture:** Keep `BattleStatusRow` responsible for icon/count rendering and animation. Add editable anchor controls to the shared battle scene, parent each runtime row to its player's anchor, and calculate only the row-local mirrored offset from the icon union bounds.

**Tech Stack:** Godot 4, GDScript, GUT

## Global Constraints

- Do not alter the approved icon art, optical scale, count typography, shadows, or animation timing.
- Alignment ignores count geometry and uses only visible icon bounds.
- Do not use screenshots; verify with tests and geometry assertions.
- Do not touch unrelated dirty-worktree files.

---

### Task 1: Replace the foot anchor contract

**Files:**
- Modify: `tests/unit/ui/test_battle_status_row.gd`
- Modify: `src/ui/battle_screen_base.tscn`
- Modify: `src/ui/battle_screen.gd`

**Interfaces:**
- Consumes: `BattleStatusRow.debug_icon_alignment_rect() -> Rect2`
- Produces: `P1Hud/P1StatusAnchor`, `P2Hud/P2StatusAnchor`, and mirrored local row positioning

- [ ] **Step 1: Write the failing geometry test**

Replace the foot-follow assertions with checks that P1 grows right from the fourth-energy-point anchor, P2 grows left from its mirror, and character visual offsets do not move either status row.

- [ ] **Step 2: Run the focused test and confirm RED**

Run: `& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/ui/test_battle_status_row.gd'`

Expected: the new player-name anchor nodes or fixed-HUD positioning assertions fail against the old foot-follow implementation.

- [ ] **Step 3: Add editable anchors and mirrored positioning**

Add zero-size `P1StatusAnchor` and `P2StatusAnchor` controls centered on the player-name line. Parent runtime status rows to those nodes and set local X using the icon union left edge for P1 and right edge for P2; set local Y from the icon union center.

- [ ] **Step 4: Run focused and full verification**

Run the focused status-row test, then `& .\tools\run_godot.ps1 -Mode Test`. Inspect exit codes and distinguish unrelated pre-existing failures.

- [ ] **Step 5: Review scope**

Use `git diff --check` and targeted diffs for the two implementation files, the status-row test, and these design records. Do not commit or push unless Eddy explicitly asks.
