# Scene2 River Quiet Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this focused plan inline and verify each checkbox before completion.

**Goal:** Make Scene2 River read as quietly flowing by reducing reflection sway, block breakup, ripple speed, and shore-foam drift.

**Architecture:** Keep the existing `canvas_env_pixel_river.gdshader` unchanged and tune only its `RiverMat` instance in Scene2. Extend the existing Scene2 River GUT contract so the calmer motion cannot silently regress.

**Tech Stack:** Godot 4.7, `.tscn` ShaderMaterial parameters, GDScript/GUT, windowed runtime screenshot probes.

## Global Constraints

- Do not change River geometry, colors, reflection bindings, lighting, shoreline topology, or Scene2 node positions.
- Keep `anim_fps = 6.0`.
- Use `tools/run_godot.ps1` for import, tests, and windowed probes.

---

### Task 1: Lock And Apply Quiet-Flow Parameters

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`
- Modify: `src/ui/scenes/scene2.tscn`

**Interfaces:**
- Consumes: Existing `River` ColorRect and `RiverMat` ShaderMaterial.
- Produces: A parameter-only quiet-flow River configuration.

- [x] Add GUT assertions for `slice_shift_px = 5.0`, `slice_speed = 0.11`,
  `breakup_strength = 0.20`, `ripple_speed_px = 8.0`,
  `shore_cluster_drift_px = 1.5`, and unchanged `anim_fps = 6.0`.
- [x] Run GUT and confirm the new assertions fail against the old values.
- [x] Update only the six `RiverMat` values in `scene2.tscn`.
- [x] Run Godot import and full GUT; require all tests to pass.
- [x] Capture multiple windowed Scene2 runtime frames and inspect the River.
- [x] Run `git diff --check` on the modified files.
