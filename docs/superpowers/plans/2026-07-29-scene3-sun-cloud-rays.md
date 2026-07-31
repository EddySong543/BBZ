# Scene3 Hidden-Sun Cloud Rays Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this focused plan inline and verify every checkbox.

**Goal:** Replace narrow vertical shafts with broad, intermittent cloud rays that fan outward from one hidden sun below the cloud sea.

**Architecture:** Keep the existing `SunRayField` node and layer order. Rebuild only its shader geometry and material parameters around a shared hidden direction source, while retaining independent CloudSeaMid-synchronized visibility gates.

**Tech Stack:** Godot 4.7, canvas-item shader, `.tscn` ShaderMaterial, GDScript/GUT, windowed screenshot probes.

## Global Constraints

- Use the replacement `scene3_sun.png` only through a graded `DawnSun` layer.
- Do not change mountains, cloud-sea nodes, chains, cliffs, UI, or battle behavior.
- Light-shaft roots must remain behind the cloud sea.
- Shafts may overlap, but must not form a continuously visible solid fan.

---

### Task 1: Lock The Revised Ray Contract

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

- [x] Assert one hidden sun direction source and upper-semicircle geometry.
- [x] Assert at least six independently gated candidate shafts.
- [x] Assert broader width and feather controls.
- [x] Run GUT and confirm the old shader fails the revised contract.

### Task 2: Rebuild SunRayField

**Files:**
- Modify: `assets/shaders/canvas_env_scene3_sun_rays.gdshader`
- Modify: `src/ui/scenes/scene3.tscn`

- [x] Implement six broad shafts radiating from the hidden source.
- [x] Add inner-body and outer-bloom feathering.
- [x] Preserve independent roll/billow opening phases and cloud-hidden roots.

### Task 3: Runtime Verification

- [x] Run Godot import and full GUT.
- [x] Capture and inspect three standalone Scene3 phases.
- [x] Capture and inspect the complete Scene3 battle screen.
- [x] Run scoped `git diff --check`.

### Task 4: Integrate Replacement Sun And Right Far Mountain

**Files:**
- Create: `assets/shaders/canvas_env_scene3_sun_grade.gdshader`
- Create: `tools/prepare_scene3_sun.gd`
- Modify: `src/ui/scenes/scene3.tscn`
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

- [x] Prepare the new import sun as a cropped true-alpha formal asset.
- [x] Add the replacement sun behind the cloud sea and above the ray field.
- [x] Grade the sun toward restrained warm gold and soften its lower half.
- [x] Apply a strong neutral haze and brightness lift to `RightFarMountain`.
- [x] Add two offset distant-range copies with increasing depth and parallax.
- [x] Verify the standalone and complete Scene3 battle views.
