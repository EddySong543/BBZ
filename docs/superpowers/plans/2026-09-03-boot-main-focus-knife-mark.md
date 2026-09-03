# Boot Main Focus Knife Mark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace whole-label gold tinting on the four Boot main actions with a clean gold knife-mark cursor while preserving the approved layout, icon controls, startup state, and input flow.

**Architecture:** Add one small custom-drawn `Control` below each main `Button`, driven by the existing `BootMenuButtonMotion` focus and press strengths. Keep the text at its authored ink color by disabling main-label tinting; leave icon tint and cross-star behavior unchanged.

**Tech Stack:** Godot 4.7, typed GDScript, CanvasItem drawing, GUT.

## Global Constraints

- Do not alter `BootMenu`, `MainButtons`, or `SmallButtons` authored geometry.
- Do not change the default no-selection state, intro input lock, icon animation, or sweep-free contract.
- Use `tools/run_godot.ps1` for all Godot execution.
- Do not commit: the user requested local implementation only.

---

### Task 1: Lock the focus-mark contract

**Files:**
- Modify: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Consumes: `BootMenuButtonMotion.debug_state() -> Dictionary`
- Produces: assertions for an independent `FocusMark`, zero main-text tint, unchanged icon tint, 1.03 focus scale, and 4 px text offset.

- [x] **Step 1: Write the failing test**

Add assertions that every main button owns a `FocusMark`; selected main text keeps `focus_tint_strength == 0.0`; the mark reaches an 18 px gold core with a dark separating edge; and Discord keeps its existing gold tint parameters.

- [x] **Step 2: Run test to verify it fails**

Run: `& .\tools\run_godot.ps1 -Mode Test -Target res://tests/unit/ui/test_boot_pressure_backdrop.gd`

Expected: FAIL because `FocusMark` does not exist and the main label still uses full tint.

### Task 2: Implement and verify the knife-mark cursor

**Files:**
- Create: `src/ui/components/boot_menu_focus_mark.gd`
- Modify: `src/ui/components/boot_menu_button_motion.gd`
- Modify: `src/ui/boot_screen.tscn`
- Modify: `assets/shaders/canvas_ui_boot_menu_focus.gdshader`
- Test: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Consumes: `BootMenuFocusMark.set_state(focus: float, press: float)` from `BootMenuButtonMotion`.
- Produces: `BootMenuFocusMark.debug_state() -> Dictionary` with exact geometry and palette values for image-free verification.

- [x] **Step 1: Write the minimal focus mark**

Create a full-button, mouse-ignoring `Control` that measures the parent button label, positions a dark-edged gold slash 16 px to its left, grows it from 4 px to 18 px in two-pixel steps, and follows the existing focus/press offset.

- [x] **Step 2: Connect the existing tween state**

Export `focus_mark_path`, resolve it only for `MAIN_TEXT`, call `set_state()` from `_sync_visual_state()`, set main `focus_tint_strength` to `0.0`, use focus scale `1.03`, and preserve icon parameters exactly.

- [x] **Step 3: Author four scene children without moving controls**

Add one full-rect `FocusMark` child to each main button and point its `Motion.focus_mark_path` to `../FocusMark`; make no offset or size edits to the buttons or containers.

- [x] **Step 4: Run verification**

Run the Boot pressure test, Boot intro test, Boot scene probe, and `git diff --check`. Expected: 21/21 Boot pressure tests, 14/14 intro tests, probe success, and no whitespace errors.
