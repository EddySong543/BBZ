# Qingfeng Ref37 Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved Ref37-style Qingfeng Ricefield grid at runtime without changing the fixed map layout or existing exploration rules.

**Architecture:** Keep the existing project-native `grid_mode` and three-layer map model. Add four reusable grass-surface variants, render one deterministic variant per grass cell inside a shared chamfered double frame, and let the existing terrain shader provide visible green fog plus a low-frequency screen-space grade. Preserve rice, objects, markers, and camera behavior as independent layers.

**Tech Stack:** Godot 4.x, typed GDScript, canvas-item shaders, GUT, PNG assets, built-in image generation, Pillow normalization.

## Global Constraints

- Keep `QingfengLayout` at 18×14 and do not move gameplay anchors.
- Set `MAP_CELL=107`, `MAP_VIEW_SIZE=(1920,1080)`, and `MAP_VIEW_ORIGIN=(0,0)`.
- Preserve `RiceFoliageLayer`, object/marker separation, nearest filtering, camera dead zone, and 0.28-second easing.
- Do not touch unrelated dirty files.
- Do not commit or push unless the user explicitly requests it.

---

### Task 1: Formal Grass Variant Assets

**Files:**
- Create: `assets/tilesets/qingfeng_ricefield/grass_light_01.png`
- Create: `assets/tilesets/qingfeng_ricefield/grass_light_02.png`
- Create: `assets/tilesets/qingfeng_ricefield/grass_dark_01.png`
- Create: `assets/tilesets/qingfeng_ricefield/grass_dark_02.png`
- Create: matching `.prompt.txt` files
- Modify: `tools/process_qingfeng_tiles.py`

**Interfaces:**
- Produces: four 128×128 opaque/surface PNGs addressable by `ExpeditionScreen`.

- [x] Generate four calm top-down grass surfaces from the approved preview, with no border, object, character, text, or directional path.
- [x] Add `normalize_grass_variant(source, destination)` that center-crops to a square and resizes to 128×128 RGBA.
- [x] Validate all four files are 128×128 RGBA and visually distinct.

### Task 2: Grid Rendering and Fog

**Files:**
- Modify: `src/expedition/expedition_screen.gd`
- Modify: `assets/shaders/canvas_ui_expedition_terrain.gdshader`

**Interfaces:**
- Produces: `_grass_variant_index(cell: Vector2i) -> int`, `_ground_texture_for(cell)`, `_ground_tint_for(cell, revealed)`, and a 107px chamfered double-frame draw contract.

- [x] Set the viewport constants to 107px cells on a full 1920×1080 clipped view; scale token, offsets, shadows, and markers to stay inside one cell.
- [x] Preload the four grass variants and select them with a stable coordinate hash independent of run seed.
- [x] Draw every terrain cell even when unrevealed: dark outer frame, light inner rim, then the terrain texture inside an inset rectangle.
- [x] Remove the old source-edge crop and 1px table-grid lines.
- [x] Change fog from brown/black hidden cards to a translucent deep-green per-cell overlay; retain reveal animation and object hiding.
- [x] Add only low-frequency screen-space warm light and vignette inside the same terrain shader.

### Task 3: Regression Tests and Runtime Evidence

**Files:**
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd`
- Modify: `tools/expedition_shot_runner.gd`

**Interfaces:**
- Produces: stable semantic tests plus 1920×1080 idle, reveal/search, and camera captures.

- [x] Update size assertions for 107px cells and a 1920×1080 full-screen view while keeping 18×14 world data.
- [x] Assert all grass variants exist, are square, and both light/dark families occur across the map.
- [x] Keep the layer-order, rice-over-grass, search-object removal, no-corner-HUD, active-extraction, and backpack-space tests.
- [x] Scale camera expectations from 128 to 107 and verify dead-zone behavior semantically.
- [x] Capture idle, fully revealed composition, search opened/closed, and time-separated camera frames.
- [x] Run `& .\tools\run_godot.ps1 -Mode Import`, `-Mode Test`, and `-Mode Probe -Target 'res://tools/expedition_shot_runner.tscn'`.
- [x] Inspect the resulting 1920×1080 captures against the approved preview before reporting completion.
