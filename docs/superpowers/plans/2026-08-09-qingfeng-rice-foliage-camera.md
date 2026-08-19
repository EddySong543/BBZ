# Qingfeng Rice Foliage And Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the baked rice ground tile with transparent golden rice foliage and make the expedition viewport denser and calmer.

**Architecture:** Keep the existing three logical layers—ground, object, marker—but render walkable rice through its own foliage draw node inside the object layer. Keep map coordinates and rice terrain metadata unchanged. Replace per-step camera recentering with a pixel-rounded 5x3 dead-zone target and a short tween.

**Tech Stack:** Godot 4.x, typed GDScript, GUT, PNG with alpha, built-in image generation.

## Global Constraints

- The visible cell size is exactly 128 pixels; the 1920x1080 presentation shows a cropped 15x9-cell viewport.
- Rice cells draw grass first and transparent golden rice second.
- The current supply basket remains untouched and provisional.
- Camera movement is pixel-rounded, clamped to world bounds, and does not react while the player remains inside the 5x3 dead zone.
- Unrelated dirty worktree files are protected.

---

### Task 1: Lock the new asset and viewport contracts with tests

**Files:**
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd`

**Interfaces:**
- Consumes: `ExpeditionScreen` constants and layer nodes.
- Produces: regression coverage for transparent rice foliage, 128-pixel cells, a 15x9 viewport, and dead-zone targeting.

- [ ] Replace `rice_01.png` in the ground list with a foliage list and assert its visible ratio is below 0.70.
- [ ] Assert `RiceFoliageLayer` is ordered after fog and before static objects.
- [ ] Assert the viewport is `1920x1152`, world is `2304x1792`, and its origin is `(0,-36)`.
- [ ] Assert a player step within the dead zone leaves the target unchanged and crossing one column changes it by exactly 128 pixels.
- [ ] Run the focused GUT script and confirm the new expectations fail against the old implementation.

### Task 2: Generate and normalize transparent golden rice

**Files:**
- Modify: `assets/tilesets/qingfeng_ricefield/rice_01.png`
- Modify: `assets/tilesets/qingfeng_ricefield/rice_01.prompt.txt`
- Modify: `tools/process_qingfeng_tiles.py`

**Interfaces:**
- Consumes: approved golden-rice preview style.
- Produces: one 128x128 transparent rice foliage texture with no baked ground.

- [ ] Generate one calm band of mature golden rice against a flat removable chroma background.
- [ ] Remove the chroma key and normalize it as an object-layer texture without expanding the subject to fill the cell.
- [ ] Validate RGBA, transparent corners, visible coverage, and nearest-neighbor dimensions.

### Task 3: Integrate foliage and the dead-zone camera

**Files:**
- Modify: `src/expedition/expedition_screen.gd`

**Interfaces:**
- Consumes: `QingfengLayout.GroundTerrain.RICE`, `rice_01.png`, player grid coordinates.
- Produces: `_draw_rice_foliage()`, `_camera_target_for_player()`, and rounded tweened map movement.

- [ ] Set `MAP_CELL=128`, `MAP_VIEW_COLS=15`, `MAP_VIEW_ROWS=9`, `MAP_VIEW_ORIGIN=(0,-36)`, and `TOKEN_SIZE=(104,104)`.
- [ ] Make rice terrain return grass from `_ground_texture_for()` and draw `rice_01.png` only from `RiceFoliageLayer`.
- [ ] On first map refresh, center and clamp immediately.
- [ ] On later refreshes, keep the camera still inside the central 5x3 cells; on exit, target the nearest dead-zone edge.
- [ ] Tween for 0.28 seconds with sine-out easing and round every intermediate offset to whole pixels.

### Task 4: Verify motion and full-project safety

**Files:**
- Modify: `tools/expedition_shot_runner.gd`

**Interfaces:**
- Consumes: the integrated expedition screen.
- Produces: 1920x1080 idle and multi-step movement captures plus automated test evidence.

- [ ] Capture an idle frame showing the denser map and transparent rice on grass.
- [ ] Capture time-separated movement frames proving the camera stays fixed for in-dead-zone steps and eases after a boundary crossing.
- [ ] Run Godot import, focused GUT coverage, and the full GUT suite.
- [ ] Inspect the 1920x1080 runtime captures for screen coverage, square cells, camera jitter, texture blur, and rice readability.
