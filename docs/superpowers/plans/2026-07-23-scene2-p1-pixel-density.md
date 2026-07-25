# Scene2 P1 Environment Pixel-Density Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Normalize Scene2 environment artwork to the characters' fixed two-screen-pixels-per-logical-pixel scale, improve actor readability, and preserve Scene1 and all character assets unchanged.

**Architecture:** Keep every imported source PNG intact and generate Scene2-only `*_px2.png` derivatives with deterministic BOX reduction, no-dither palette quantization, binary alpha, and exact target dimensions. Scene2 displays each derivative at exactly 2× with Nearest filtering; depth comes from palette/contrast/opacity and parallax instead of fractional scaling or texture blur.

**Tech Stack:** Python 3 + Pillow for deterministic raster normalization; Godot 4.7 `TextureRect`, canvas-item shaders, inherited Scene2 battle variant; GUT and real screenshot probes.

## Global Constraints

- Do not modify any character sprite, CharacterDisplay geometry, animation, or interaction behavior.
- Do not overwrite `scene1_mountain.png` or any original Scene2 PNG.
- Keep `battle_screen1.tscn` on Scene1; only `battle_screen2.tscn` uses Scene2.
- Use Lossless import, Nearest filtering, no mipmaps, no dithering, and hard alpha for derived pixel assets.
- Run Godot only through `tools/run_godot.ps1`; never close a pre-existing Godot process.
- Validate both Scene2 and Scene1 with real runtime screenshots before completion.

---

### Task 1: Lock the px2 asset contract with tests

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: existing `res://src/ui/scenes/scene2.tscn` node names.
- Produces: dimensions and isolation assertions for the derived textures and Scene2 node rectangles.

- [ ] **Step 1: Add a failing derived-texture contract test**

Assert these exact texture sizes after loading Scene2: far back `950×265`, far mid `860×250`, far near `690×215`, mountain gate `293×381`, mountain left `264×420`, blossom tree `390×230`, and stone bridge `1010×235`.

- [ ] **Step 2: Assert exact 2× display and fixed character geometry**

For every normalized node, assert `node.size == node.texture.get_size() * 2`. Retain the existing assertions that both CharacterDisplay nodes are `768×768`, positioned at `(96,258)` and `(1056,258)`, and use `sprite_scale = (2,2)`.

- [ ] **Step 3: Run the full test suite and verify RED**

Run `& .\tools\run_godot.ps1 -Mode Test`. Expected failure: the new `*_px2.png` resources are absent or Scene2 still references the original textures.

### Task 2: Generate deterministic Scene2-only px2 derivatives

**Files:**
- Create: `tools/normalize_scene2_pixel_assets.py`
- Create: `assets/scenes/scene2/scene2_px2_manifest.json`
- Create: `assets/scenes/scene2/scene2_far_mountain_back_px2.png`
- Create: `assets/scenes/scene2/scene2_far_mountain_mid_px2.png`
- Create: `assets/scenes/scene2/scene2_far_mountain_near_px2.png`
- Create: `assets/scenes/scene2/scene2_mountain_gate_px2.png`
- Create: `assets/scenes/scene2/scene2_mountain_left_px2.png`
- Create: `assets/scenes/scene2/scene2_blossom_tree_px2.png`
- Create: `assets/scenes/scene2/scene2_stone_bridge_px2.png`

**Interfaces:**
- Consumes: immutable original Scene1/Scene2 PNGs and an explicit job table.
- Produces: hard-alpha RGBA PNGs plus a manifest containing source path, output path, size, palette budget, and SHA-256.

- [ ] **Step 1: Implement the explicit normalization job table**

Use target sizes and palette budgets: far layers `16` colors; mountain gate/left `48`; blossom tree/stone bridge `64`. Resize premultiplied RGBA with `Image.Resampling.BOX`, quantize with `FASTOCTREE` and `Dither.NONE`, restore alpha to `0/255`, and save RGBA PNGs.

- [ ] **Step 2: Add `--check` validation**

The command must fail when an output is missing, has the wrong dimensions, is not RGBA, or contains alpha values other than `0` and `255`.

- [ ] **Step 3: Generate and validate assets**

Run the bundled workspace Python against `tools/normalize_scene2_pixel_assets.py`, then rerun with `--check`. Expected: seven assets validated and a manifest written.

### Task 3: Integrate px2 assets and depth grading

**Files:**
- Create: `assets/shaders/canvas_env_scene2_depth_grade.gdshader`
- Modify: `src/ui/scenes/scene2.tscn`

**Interfaces:**
- Consumes: the seven derived textures.
- Produces: exact 2× Scene2 node geometry, crisp depth-separated layers, and an actor-safe right-side negative shape.

- [ ] **Step 1: Replace only Scene2 texture references**

Assign the three far derivatives separately. Assign normalized mountain gate, mountain left, blossom tree, and stone bridge textures. Do not alter Scene1 resources.

- [ ] **Step 2: Make every normalized display rectangle exactly 2×**

Keep existing positions except set MountainGate right edge to `1376`, StoneBridge bottom edge to `1120`, and move BlossomTree horizontally to `(1280,296)-(2060,756)` to clear more of P2's silhouette while preserving its bridge contact.

- [ ] **Step 3: Replace blur-based depth with grade-based depth**

Set all far-layer `blur_amount` values to `0`. Apply the Scene2 depth-grade shader to MountainGate, MountainLeft, and BlossomTree with progressively stronger saturation/contrast toward the foreground; keep StoneBridge ungraded and fully crisp.

- [ ] **Step 4: Import and verify GREEN**

Run `& .\tools\run_godot.ps1 -Mode Import`, then the full GUT suite. Expected: all tests pass and no shader/scene parse errors occur.

### Task 4: Runtime A/B and Scene1 regression

**Files:**
- Modify: `assets/scenes/scene2/SPEC.md`

**Interfaces:**
- Consumes: runnable Scene2 and Scene1 battle variants.
- Produces: P0/P1 comparison screenshots and documented manual tuning controls.

- [ ] **Step 1: Capture Scene2 P1**

Run `& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/battle_scene2_shot.tscn'` and compare it with `D:/Game/BoBoZan/_probe_output/scene2_p1/battle_scene2_p0_baseline.png` at original resolution.

- [ ] **Step 2: Tune only environment parameters**

Adjust palette budgets, environment node rectangles, depth-grade saturation/contrast, and environment opacity. Do not alter character nodes, lighting contract, UI, combat behavior, or P0 reflection behavior.

- [ ] **Step 3: Capture Scene1 and run final verification**

Run `battle_shot.tscn`, full GUT, `git diff --check`, and the normalizer `--check`. Confirm Scene1 remains the default composition and visually retains its original role lighting and background.

- [ ] **Step 4: Update the Scene2 specification**

Document the px2 derivative filenames, exact logical sizes, source-preservation rule, depth-grade knobs, and runtime verification results in `assets/scenes/scene2/SPEC.md`.
