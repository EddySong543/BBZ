# Boot Screen Ivory Title and Energy Depth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the muddy black title with a readable ivory/navy/gold system and enrich the confirmed idle screen with restrained energy-print depth.

**Architecture:** Keep the existing abstract pressure-brush composition and interaction contract. Add one far contour shader layer, one masked near-brush layer, and a synchronized local energy-light response inside the existing character shader; do not add particles, environments, panels, or new camera behavior.

**Tech Stack:** Godot 4.7 `Control` scenes, `canvas_item` shaders, typed GDScript, GUT, project probe runner.

## Global Constraints

- Preserve the existing Boot Screen layout, click-to-enter behavior, mouse parallax, character idle animation, gold-ring motion, and title motion.
- Use only ivory `#F4E7D0`, deep navy `#0A1A40`, warm gold `#C8920A`, pale gold `#E8C870`, and existing background colors.
- New motion must remain slow, restrained, and derived from existing shapes rather than additive particles.
- Validate through `tools/run_godot.ps1`; do not launch Godot directly.

---

### Task 1: Ivory, Navy, and Gold Title

**Files:**
- Modify: `src/ui/components/boot_title_controller.gd`
- Modify: `src/ui/boot_screen.tscn`
- Test: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Consumes: existing `BootTitleController.apply_palette(...)`
- Produces: title face, structure, cut, highlight, outline, shadow, and prompt colors

- [x] Update the title palette test to expect ivory face, deep navy structure and outline, warm-gold cut, pale-gold peak, and deep navy shadow.
- [x] Update controller defaults and every editor-preview material in `boot_screen.tscn`.
- [x] Change “点击进入游戏” and both decorative lines from black to deep navy.
- [x] Run the full GUT suite and confirm the Boot Screen file passes.

### Task 2: Far Pressure Contours and Near Brush Edge

**Files:**
- Create: `assets/shaders/canvas_boot_pressure_contours.gdshader`
- Create: `assets/shaders/canvas_boot_foreground_brush.gdshader`
- Modify: `src/ui/boot_screen.tscn`
- Test: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Consumes: existing paper base, blue pressure texture, and `BattleStage` parallax metadata
- Produces: `BackgroundStage/PressureContours` and `BackgroundStage/ForegroundBrush`

- [x] Add failing contracts for shader paths, draw order, palette, parallax factors, and absence of particles.
- [x] Implement four large pixel-stepped broken contour arcs centered on the rear-hand energy source.
- [x] Implement a masked near layer that reveals only broad upper-right and lower-left portions of the existing blue brush texture.
- [x] Place contours behind the blue field and foreground brush after the gold layer but behind title and character.
- [x] Run the Boot Screen tests and inspect three runtime frames.

### Task 3: Character Energy-Light Response

**Files:**
- Modify: `assets/shaders/canvas_boot_character_depth.gdshader`
- Modify: `src/ui/components/boot_character_idle.gd`
- Modify: `src/ui/components/boot_character_idle.tscn`
- Test: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Consumes: existing idle `pulse_phase`
- Produces: `energy_phase` on the base character material

- [x] Add a failing contract for the rear-energy center, warm-light strength, and synchronized phase.
- [x] Add a source-pixel-only warm light falloff around the rear hand, shoulder, and nearby hair.
- [x] Forward the existing star pulse phase to the base character shader without adding another timer.
- [x] Run GUT and the Boot Screen probe; compare readability, depth, and motion across all captured frames.
