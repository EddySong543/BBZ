# Scene2 P2 Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Synchronize Scene2 environmental motion into 5/8/12fps pixel-art tiers, replace dot particles with a four-frame petal atlas, and replace the continuous shoreline highlight with restrained foam clusters.

**Architecture:** Keep all effects inside the existing Scene2 composition. Generate one deterministic raster atlas through a Godot tool script, configure the existing two GPUParticles2D nodes as shared flipbook consumers, and extend the existing river shader with a quantized shoreline cluster pass. No battle, character, UI, or Scene1 code changes.

**Tech Stack:** Godot 4.7, GDScript tool scripts, GPUParticles2D, CanvasItemMaterial, canvas-item shaders, GUT.

## Global Constraints

- Preserve all current Scene2 node transforms and character geometry.
- Preserve Scene1 and the shared BattleScreen behavior.
- Use nearest filtering and hard pixel steps; do not add blur or interpolation.
- Tests must verify structure and relative cadence, not mutable editor coordinates.
- Launch Godot only through `tools/run_godot.ps1`.

---

### Task 1: Add structural P2 regression tests

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: existing `PetalFar`, `PetalNear`, `WaterfallLeft`, and `River` scene nodes.
- Produces: `test_scene2_p2_motion_uses_pixel_cadence_and_petal_flipbook()` and shoreline-cluster assertions.

- [ ] Add a test that requires `scene2_petal_atlas.png`, a 4×1 particle flipbook material, 12fps fixed particle simulation, disabled interpolation, and a 5/8/12 relative cadence.
- [ ] Add river assertions for `shore_cluster_density`, `shore_cluster_cycle_sec`, and absence of the retired continuous `shore_light_mask`.
- [ ] Run the full suite through `tools/run_godot.ps1 -Mode Test`; expect the new assertions to fail before implementation.

### Task 2: Generate the four-frame petal atlas

**Files:**
- Create: `tools/generate_scene2_petal_atlas.gd`
- Create: `assets/scenes/scene2/scene2_petal_atlas.png`
- Create through import: `assets/scenes/scene2/scene2_petal_atlas.png.import`

**Interfaces:**
- Consumes: no runtime state.
- Produces: a deterministic 64×16 RGBA8 texture containing four 16×16 frames.

- [ ] Implement a `SceneTree` tool that clears a 64×16 image, paints four distinct pixel silhouettes with a muted outline/mid/highlight palette, saves the PNG, and exits nonzero on failure.
- [ ] Run the generator through `tools/run_godot.ps1 -Mode Tool -Target res://tools/generate_scene2_petal_atlas.gd`.
- [ ] Import through `tools/run_godot.ps1 -Mode Import` and inspect the atlas visually.

### Task 3: Replace dot particles with the flipbook

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`

**Interfaces:**
- Consumes: `res://assets/scenes/scene2/scene2_petal_atlas.png`.
- Produces: shared `PetalFlipbookMat`, updated `PetalFarMat`, updated `PetalNearMat`, and two 12fps stepped emitters.

- [ ] Remove `PetalDot` and `PetalTex`.
- [ ] Add a shared `CanvasItemMaterial` with particle animation enabled, four horizontal frames, one row, and looping enabled.
- [ ] Set each process material's animation speed to three atlas cycles per second over its authored lifetime, randomize initial frame offsets, and add restrained angular variation.
- [ ] Set both particle nodes to `fixed_fps = 12`, `interpolate = false`, and `fract_delta = false`; assign nearest filtering, the shared draw material, and the atlas.

### Task 4: Replace the continuous shoreline light with clusters

**Files:**
- Modify: `assets/shaders/canvas_env_pixel_river.gdshader`
- Modify: `src/ui/scenes/scene2.tscn`

**Interfaces:**
- Consumes: the river shader's quantized `t`, `px`, `quv`, and existing shore palette.
- Produces: `shore_cluster`, `shore_cluster_life`, and `shore_cluster_bright` masks controlled by scene material uniforms.

- [ ] Add density, spacing, cycle, drift, and strength uniforms with conservative defaults.
- [ ] Keep the dark shore contact band, remove the full-width bright mask, and generate staggered short segments from stable cell hashes.
- [ ] Configure low density and a cycle longer than four seconds in `RiverMat`.

### Task 5: Document and verify

**Files:**
- Modify: `assets/scenes/scene2/EDITING.md`
- Modify: `assets/scenes/scene2/SPEC.md`

**Interfaces:**
- Consumes: final scene and shader parameters.
- Produces: editor guidance and verification evidence.

- [ ] Document atlas playback, 5/8/12fps tiers, and shoreline controls.
- [ ] Run Scene2 battle and two-frame probes; inspect silhouettes, cadence, seams, and visual noise.
- [ ] Run the Scene1 battle probe.
- [ ] Run the full GUT suite and `git diff --check`; report exact results without committing or pushing.
