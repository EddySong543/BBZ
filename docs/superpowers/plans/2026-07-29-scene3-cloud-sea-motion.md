# Scene3 Cloud Sea Motion Implementation Plan

> **For agentic workers:** Implement this plan inline in the current task. Keep all edits scoped to Scene3 cloud rendering and its regression contract.

**Goal:** Give Scene3's layered lower cloud sea visible counter-flow and rolling, locally billowing motion while preserving Scene2 and all authored Scene3 layout.

**Architecture:** Fork the stable pixel-cloud shader into a Scene3-only resource. Add quantized large-scale vertical rolling and per-lobe height evolution with zero-effect defaults, then tune the three existing cloud materials independently.

**Tech Stack:** Godot 4 canvas-item shader, `.tscn` ShaderMaterial parameters, GUT scene contract tests.

## Global Constraints

- Do not change Scene2's shared `canvas_env_dark_smoke.gdshader`.
- Do not change Scene3 node positions, dimensions, mountain art, characters, UI, or interaction.
- Reverse only `CloudSeaMid` horizontal flow.
- Verify with Godot import, the full GUT suite, and the Scene3 screenshot probe.

---

### Task 1: Scene3 cloud motion shader

**Files:**
- Create: `assets/shaders/canvas_env_scene3_cloud_sea.gdshader`
- Modify: `src/ui/scenes/scene3.tscn`
- Test: `tests/unit/ui/test_battle_scene_variants.gd`

- [x] Copy the stable pixel-cloud implementation into a Scene3-only shader.
- [x] Add quantized large-scale roll and local lobe-height evolution.
- [x] Point all three Scene3 cloud materials to the new shader.
- [x] Set `CloudSeaMid.flow_speed` to `0.0074`.
- [x] Give all three layers distinct seeds, phases, amplitudes, and speeds.
- [x] Assert the dedicated shader, counter-flow direction, distinct seeds, and active roll/billow parameters.
- [x] Run import, GUT, and the Scene3 screenshot probe.
