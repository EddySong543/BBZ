# Scene3 Chain, Interlayer Rays, and Flying Fish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Scene3's authored fighter baseline, lower only the playable chain contact group, replace malformed cloud-interlayer light with the established radial sunlight language, and add sparse flying-fish schools emerging from the cloud sea.

**Architecture:** Keep the mature BattleScreen character and interaction contract intact. Scene3 owns platform geometry, cloud draw order, light materials, and a self-contained decorative fish controller with a runtime-generated nearest-neighbor atlas and a fixed sprite pool.

**Tech Stack:** Godot 4, GDScript, CanvasItem shaders, GUT, windowed Godot screenshot probes.

## Global Constraints

- Preserve P1's authored `x = 92` and restore both fighters to `y = 258`.
- Move only `MainChain`, `ChainFootOccluder`, and chain-local contact shadows; do not move decorative chains.
- Interlayer light must use the same hidden sun and six-ray upper-semicircle construction as `SunRayField`.
- Flying fish are decorative only, sparse, bounded away from the battle focus, and exclusive to Scene3.
- Do not modify Scene1 or Scene2 presentation or interaction.

---

### Task 1: Restore Character Baseline and Lower the Playable Chain

**Files:**
- Modify: `src/ui/battle_screen3.tscn`
- Modify: `src/ui/scenes/scene3.tscn`
- Modify: `tests/unit/ui/test_scene3_visual_integrity.gd`
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: inherited BattleScreen fighter geometry and Scene3's `MainChain` contact mask.
- Produces: fighters at the authored ground baseline and a platform-local contact group shifted down by 20 pixels.

- [ ] Restore `P1CharDisplay` and `P2CharDisplay` to `y = 258` while retaining P1 `x = 92`.
- [ ] Move `MainChain` and `ChainFootOccluder` from `y = 572..936` to `y = 592..956`.
- [ ] Move `P1Shadow` and `P2Shadow` from `y = 720..752` to `y = 740..772`.
- [ ] Update structural tests to assert the restored baseline, preserved P1 x-coordinate, and shared platform geometry.
- [ ] Run the Scene3 UI tests and confirm the contact nodes remain aligned.

### Task 2: Rebuild Cloud-Interlayer Sunlight

**Files:**
- Modify: `assets/shaders/canvas_env_scene3_cloud_interlayer_light.gdshader`
- Modify: `src/ui/scenes/scene3.tscn`
- Modify: `tests/unit/ui/test_scene3_visual_integrity.gd`

**Interfaces:**
- Consumes: the established `SunRayField` hidden sun, six radial shaft angles, cloud roll speed, and cloud billow speed.
- Produces: two staggered, vertically banded instances whose fragments align with the main ray fan.

- [ ] Replace the three slope lanes with the same `semicircle_direction`, `cloud_gap_opening`, and six `rising_shaft` calls used by the main sun-ray shader.
- [ ] Use `hidden_sun_center = Vector2(0.52, 1.06)` and the same `-80,260 .. 2000,830` reference rectangle for both interlayer nodes.
- [ ] Keep separate vertical masks, intensities, and pulse phases while sharing ray geometry and cloud rhythm.
- [ ] Assert that the old `soft_lane` geometry is absent and both light nodes share the main ray reference rectangle.
- [ ] Capture multiple runtime frames to verify soft staggered reveals without spotlight wedges.

### Task 3: Add Sparse Flying-Fish Schools

**Files:**
- Create: `src/ui/components/scene3_flying_fish_school.gd`
- Modify: `src/ui/scenes/scene3.tscn`
- Modify: `tests/unit/ui/test_scene3_environmental_richness.gd`
- Modify: `tools/battle_scene3_shot_root.gd`

**Interfaces:**
- Consumes: Scene3 direct-child parallax metadata and cloud-layer draw order.
- Produces: `trigger_school(direction_override: int = 0) -> bool`, `get_active_fish_count() -> int`, and `get_pool_size() -> int`.

- [ ] Build a three-frame `ImageTexture` atlas at runtime and assign it to a fixed pool of nearest-neighbor `Sprite2D` nodes.
- [ ] Animate each fish on a bounded parabolic arc, rotate it along the tangent, stagger its start, and cycle tail frames.
- [ ] Draw restrained entry and re-entry cloud puffs from the controller without external textures.
- [ ] Add `FlyingFishFar` between `CloudSeaBack` and `CloudSeaMid`, and `FlyingFishNear` between `CloudSeaFoundation` and `CloudSeaFront`.
- [ ] Configure combined events to remain sparse, with 4-8 fish per school and long randomized cooldowns.
- [ ] Add structural and runtime tests for pooling, generated art, draw order, timing bounds, and Scene3-only isolation.
- [ ] Extend the Scene3 probe with a forced fish event so a deterministic screenshot can verify the animation.

### Task 4: Runtime Verification

**Files:**
- Verify: `src/ui/scenes/scene3.tscn`
- Verify: `src/ui/battle_screen3.tscn`
- Verify: Scene1 and Scene2 variants

**Interfaces:**
- Consumes: completed Scene3 changes.
- Produces: fresh test logs and windowed screenshots.

- [ ] Run Godot import through `tools/run_godot.ps1`.
- [ ] Run focused Scene3 GUT tests, then the battle-scene variant regression tests.
- [ ] Run the windowed Scene3 probe and inspect full-frame and fighter-foot crops.
- [ ] Run Scene1/Scene2 regression coverage and confirm no shared scene contract changed.
- [ ] Inspect `git status --short` and report only files changed by this task.
