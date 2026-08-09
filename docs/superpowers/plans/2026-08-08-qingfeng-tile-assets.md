# Qingfeng Ricefield Tile Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and integrate the approved pixel soft-edge square tiles for the Sunny Wind Ricefield expedition map.

**Architecture:** Use image generation as the creative source and split map art into reusable ground, object, and runtime-marker layers. Keep three ground PNGs and two transparent object PNGs; draw functional markers in code. The fixed expedition grid remains project-native metadata and map rules do not change.

**Tech Stack:** Godot 4.x, GDScript, PNG, built-in image generation, PowerShell asset validation.

## Global Constraints

- Every gameplay cell is square and rendered without independent X/Y scaling.
- Rice art is sparse; at least half of the tile remains visually quiet.
- Searchable supplies and field boundaries contain no baked ground surface.
- Ground, object, and marker layers are independent; removing an object never changes its ground.
- Pixel textures use nearest filtering, no mipmaps, and lossless import.
- Existing expedition rules, interaction timing, map layout, and unrelated dirty worktree files are protected.

---

### Task 1: Generate and normalize the five approved assets

**Files:**
- Create: `assets/tilesets/qingfeng_ricefield/*.png`
- Create: `assets/tilesets/qingfeng_ricefield/*.prompt.txt`

**Interfaces:**
- Consumes: approved visual reference and the five roles in the design spec.
- Produces: five transparent 128x128 PNG textures with stable filenames.

- [x] Generate each distinct asset separately against a removable solid magenta background.
- [x] Remove the chroma key, crop to a square, and downsample with nearest-neighbor resampling.
- [x] Validate dimensions, RGBA alpha, transparent corners, and non-empty subject coverage.

### Task 2: Configure Godot import and three-layer runtime rendering

**Files:**
- Modify: `src/expedition/expedition_screen.gd`
- Modify: `assets/shaders/canvas_ui_expedition_terrain.gdshader`
- Create: `assets/tilesets/qingfeng_ricefield/*.png.import`

**Interfaces:**
- Consumes: the five normalized PNG textures.
- Produces: square texture rendering for the expedition grid while preserving fixed map metadata.

- [x] Add separate catalogs for ground and transparent world objects.
- [x] Render ground, object, and runtime-marker layers independently while retaining fog and entity overlays.
- [x] Keep searched ground stable when its supply object and marker disappear.
- [x] Lock the visible camera to a square-cell 9x5 presentation at 1920x1080.

### Task 3: Verify assets, seams, and runtime behavior

**Files:**
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd`
- Modify: `tools/expedition_shot_runner.gd`

**Interfaces:**
- Consumes: integrated tile textures and expedition screen.
- Produces: automated dimension/filter assertions and 1920x1080 runtime screenshots.

- [x] Assert every source texture is square and available at runtime.
- [x] Run Godot import and the full test suite.
- [x] Capture an enlarged tile view, a 3x3 seam preview, and the real expedition screen.
- [x] Inspect for rectangular stretching, large uncovered screen areas, noisy rice repetition, and accidental water imagery.
