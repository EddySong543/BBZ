# Battle Render Performance Pass Implementation Plan

> **For agentic workers:** Execute inline in the current checkout. Preserve all authored Scene1/Scene2 composition, color, animation, UI, character, and interaction parameters.

**Goal:** Reduce sustained GPU work when previewing the battle scenes without changing their visible result.

**Architecture:** Add a reusable windowed performance probe that loads one battle variant at a time and records stable, uncapped render metrics after shader warm-up. Optimize the shared full-screen post-process shader with uniform-coherent fast paths for disabled blur and inactive impact-frame effects; keep the existing multi-sample and combat-effect paths unchanged when enabled.

**Tech Stack:** Godot 4.7, GDScript, Godot canvas-item shaders, GUT.

## Global Constraints

- Launch Godot automation only through `tools/run_godot.ps1`.
- Never stop a pre-existing Godot process.
- Preserve Scene1 as the default battle variant and Scene2 as its separate runnable variant.
- Do not change authored scene positions, sizes, colors, parallax, UI, character presentation, or interaction behavior.
- Do not reduce character SubViewport resolution unless the fast-path result is insufficient and visual parity has been separately approved.

---

### Task 1: Reproducible battle performance probe

**Files:**
- Create: `tools/battle_performance_probe.gd`
- Create: `tools/battle_screen1_performance_probe.tscn`
- Create: `tools/battle_screen2_performance_probe.tscn`

**Interfaces:**
- Consumes: an exported `target_scene_path` pointing to one battle variant.
- Produces: JSON metrics and a final PNG under the configured probe-output directory.

- [ ] Add a windowed probe that warms the scene, samples rendered frame intervals, and records FPS, average/p95 frame time, draw calls, rendered objects/primitives, video memory, and pipeline compilation counts.
- [ ] Run the Scene1 and Scene2 probes before optimization and retain their JSON output as the baseline.

### Task 2: Zero-cost disabled post-process branches

**Files:**
- Modify: `assets/shaders/post_fx_color_grade.gdshader`
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: existing `edge_blur_amount` and `impact_strength` uniforms.
- Produces: one screen-texture sample when blur is disabled; skips impact-frame math while impact strength is zero.

- [ ] Add a GUT contract test for the two uniform-driven fast paths.
- [ ] Add the single-sample blur-disabled path while preserving the five-tap path for Scene1.
- [ ] Wrap impact-frame calculations in a zero-strength fast path while preserving combat visuals when active.
- [ ] Run the targeted test, re-run both performance probes, and compare results.

### Task 3: Runtime and regression verification

**Files:**
- Verify: `src/ui/battle_screen1.tscn`
- Verify: `src/ui/battle_screen2.tscn`

**Interfaces:**
- Consumes: optimized shared shader.
- Produces: runtime screenshots and test evidence.

- [ ] Capture Scene1 and Scene2 runtime screenshots through the existing probe scenes.
- [ ] Confirm Scene2 remains crisp and Scene1 retains its authored edge blur.
- [ ] Run the complete GUT suite because the shared battle post-process shader affects both variants.
