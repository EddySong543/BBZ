# Scene3 Environmental Richness Implementation Plan

> **For agentic workers:** Execute these tasks in order and verify each
> deliverable before continuing.

**Goal:** Implement approved Scene3 richness tasks 2, 3, and 4 with no external
assets.

**Architecture:** Extend the existing active cliff shader for cloud-synchronized
lighting, use native Godot particle subresources for two dust depths, and add a
small procedural glint shader beneath the existing sword-grave parent.

**Tech Stack:** Godot 4.7, canvas-item shaders, `GPUParticles2D`, GUT.

## Global Constraints

- Do not change user-authored Scene3 transforms or BattleScreen3 character
  geometry.
- Keep every new resource Scene3-only.
- Use nearest filtering and low particle counts.
- Do not commit or push unless the user explicitly requests it.

---

### Task 1: Focused Regression Contract

**Files:**
- Create: `tests/unit/ui/test_scene3_environmental_richness.gd`

- [ ] Add a focused scene test that checks cliff timing parameters, two sparse
  particle depths, and two staggered low-frequency glints.
- [ ] Run:
  `godot --headless --path <repo> -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/ui/test_scene3_environmental_richness.gd -gexit`
- [ ] Confirm the test fails because the three approved effects do not exist.

### Task 2: Cloud-Synchronized Cliff Bands

**Files:**
- Modify: `assets/shaders/canvas_env_scene3_cliff_grass_sway.gdshader`
- Modify: `src/ui/scenes/scene3.tscn`

- [ ] Add screen-space broad light and shadow bands after the established cliff
  grade and before palette quantization.
- [ ] Use `cloud_roll_speed = 0.42` and `cloud_billow_speed = 0.82`.
- [ ] Configure nonzero strengths and different phases on left/right materials.

### Task 3: Sparse Two-Depth Motes

**Files:**
- Modify: `src/ui/scenes/scene3.tscn`

- [ ] Add an additive blend material, generated dot texture, lifetime ramp, and
  two `ParticleProcessMaterial` subresources.
- [ ] Add `SunMotesFar` after `SunRayField` with nine particles and parallax
  `0.28`.
- [ ] Add `SunMotesNear` after `MidSwordGrave` with six particles and parallax
  `0.32`.

### Task 4: Staggered Sword Glints

**Files:**
- Create: `assets/shaders/canvas_env_scene3_sword_glint.gdshader`
- Modify: `src/ui/scenes/scene3.tscn`

- [ ] Add a pixel-stepped additive cross with configurable cycle and phase.
- [ ] Parent one glint to each existing sword cluster so later cluster movement
  keeps the glint aligned.
- [ ] Use cycles longer than eight seconds and phases separated by more than
  `0.1`.

### Task 5: Verification

**Files:**
- Test: `tests/unit/ui/test_scene3_environmental_richness.gd`
- Probe: `tools/scene3_shot_runner.tscn`
- Probe: `tools/battle_scene3_shot.tscn`

- [ ] Run Godot import and reject scene/shader errors.
- [ ] Run the focused Scene3 richness test and require all tests to pass.
- [ ] Capture the three timed pure-scene screenshots and inspect cliff regions,
  particle sparsity, glint timing, and unchanged composition.
- [ ] Capture BattleScreen3 and require pointer/platform sync error `0.0`.
- [ ] Run `git diff --check` on the files changed by this task.
