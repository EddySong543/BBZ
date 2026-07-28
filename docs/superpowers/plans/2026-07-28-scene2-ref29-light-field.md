# Scene2 Ref29 Light Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline in the current task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Scene2's upper-half lighting immediately readable at normal gameplay scale by replacing disconnected local-UV highlights with one coherent upper-right screen-space light field.

**Architecture:** Existing Scene2 receiver shaders will evaluate the same pixel-stepped `SCREEN_UV` cone and broad upper light pool. Each asset keeps its authored texture and alpha, but receives a material-specific warm light boost inside the field and saturated deep-teal shadow outside it. Existing layer order supplies occlusion; the two atmospheric Tyndall nodes remain subordinate cues rather than the primary lighting system.

**Tech Stack:** Godot 4 CanvasItem shaders, ShaderMaterial parameters in `.tscn`, GUT, `tools/run_godot.ps1`.

## Global Constraints

- Keep Scene2's existing upper-right source direction; do not copy ref29's direction.
- Do not change user-adjusted node positions, sizes, parallax values, animation timing, UI, or Scene1 composition.
- Preserve nearest-neighbour pixel edges and authored saturation; use no blur, gray wash, or fullscreen landing overlay.
- The light must be clearly visible without zooming in.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Shared screen-space light-field contract

**Files:**
- Modify: `assets/shaders/canvas_env_scene2_sky_grade.gdshader`
- Modify: `assets/shaders/canvas_env_scene2_depth_grade.gdshader`
- Modify: `assets/shaders/canvas_env_scene2_waterfall_mountain_grade.gdshader`
- Modify: `assets/shaders/canvas_env_scene2_tree_sway.gdshader`
- Modify: `assets/shaders/canvas_env_scene2_mountain_blossom_sway.gdshader`
- Modify: `assets/shaders/canvas_env_dark_smoke.gdshader`
- Modify: `assets/shaders/canvas_env_pixel_waterfall.gdshader`
- Modify: `assets/shaders/canvas_env_pixel_river.gdshader`
- Modify: `assets/shaders/canvas_env_scene2_bridge_light.gdshader`

**Interfaces:**
- Consumes: CanvasItem `SCREEN_UV`, existing texture alpha/luminance, current receiver-light uniforms.
- Produces: A consistent pixel-stepped upper-right light field and complementary chromatic shadow mask in every Scene2 receiving material.

- [x] Add screen-space source, target, width, pixel-grid, light-strength, and shadow-strength uniforms with zero-strength defaults where the shader is shared by Scene1.
- [x] Quantize `SCREEN_UV` to a 4-screen-pixel grid, build a widening cone plus broad upper pool, and break its edge into stable pixel bands.
- [x] Replace local-UV directional masks with the shared screen-space field while preserving each shader's authored alpha and animation.
- [x] Ensure outside-field shading multiplies toward deep teal rather than mixing toward gray.

### Task 2: Scene2 material tuning and occlusion

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`
- Modify: `src/ui/battle_screen2.tscn` only if the existing 1-pixel character rim needs a strength adjustment after runtime review.

**Interfaces:**
- Consumes: Task 1 light-field uniforms.
- Produces: One readable light domain across mountains, waterfall, cloud banks, tree canopy, bridge, water, and characters without changing layout.

- [x] Give far layers low contrast, mid layers medium contrast, and waterfall ridge/tree/bridge the strongest light-shadow separation.
- [x] Raise the occluded atmospheric beam to a visible supporting level while keeping it weaker than receiver lighting.
- [x] Retain the existing 1-pixel character rim and zero fill/backlight unless runtime evidence shows the rim is invisible.

### Task 3: Regression tests and runtime verification

**Files:**
- Modify: `tests/unit/ui/test_scene2_tyndall.gd`
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: Scene2 materials and shader source from Tasks 1-2.
- Produces: Structural regression coverage without hard-coding editable asset positions.

- [x] Assert receiving shaders use `SCREEN_UV`, preserve nearest filtering, and configure nonzero chromatic light/shadow strengths.
- [x] Run `& .\tools\run_godot.ps1 -Mode Import`; expect exit code `0` and no shader compilation errors.
- [x] Run `& .\tools\run_godot.ps1 -Mode Test`; expect all GUT tests to pass.
- [x] Run Scene2 probe and inspect the normal-scale screenshot for an obvious coherent upper-half light field, saturated shadows, crisp pixels, and unchanged layout.
- [x] Run Scene1 probe because `canvas_env_dark_smoke.gdshader` is shared; verify its zero-default Scene2 uniforms leave Scene1 visually unchanged.
- [x] Run `git diff --check` and report remaining unrelated dirty files without staging them.
