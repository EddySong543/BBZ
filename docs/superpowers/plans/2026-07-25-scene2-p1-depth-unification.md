# Scene2 P1 Depth Unification Implementation Plan

> **For Eddy:** Execute this plan directly in the current task. No additional approval gate is required.

**Goal:** Make Scene2 read as one mature battle arena by unifying the distant mountains, clouds, waterfall, distant water, and bridge banks while preserving the user's latest mountain transforms and all battle/UI behavior.

**Architecture:** Keep `scene2.tscn` as a visual composition over the shared battle contracts. Use lightweight canvas-item shaders for palette/depth treatment and pixel-stepped overlays; do not resample or blur source pixel assets. Tests verify structure and relative depth rules rather than mutable editor positions.

**Tech Stack:** Godot 4, GDScript/GUT, Godot canvas-item shaders, PowerShell Godot wrapper.

---

### Task 1: Protect current composition geometry

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`
- Verify: `src/ui/scenes/scene2.tscn`

1. Record the current `FarMountain` and `MidMountain` transforms as user-owned composition data.
2. Add structural P1 checks that do not pin positions, sizes, or future manual layout adjustments.
3. Confirm P1 edits do not change either mountain's four offsets.

### Task 2: Unify distant depth and texture density

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`
- Reuse: `assets/shaders/canvas_env_scene2_depth_grade.gdshader`

1. Give far and mid mountains separate depth-grade materials.
2. Reduce contrast and saturation more aggressively in the far layer than the mid layer.
3. Tune cloud grading into the same cool atmospheric hierarchy.
4. Preserve nearest-neighbor pixel edges; do not add blur.

### Task 3: Couple waterfall and distant water

**Files:**
- Modify: `assets/shaders/canvas_env_pixel_waterfall.gdshader`
- Modify: `assets/shaders/canvas_env_pixel_distant_water.gdshader`
- Modify: `src/ui/scenes/scene2.tscn`
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

1. Refine the waterfall into a restrained dark-edge / mid-body / bright-core value structure.
2. Keep highlights sparse and animation slow enough for a background layer.
3. Reuse a closely related cool palette in the distant water and strengthen the visual flow into the river.
4. Verify body and impact materials share the key palette and rhythm parameters.

### Task 4: Ground bridge ends into the banks

**Files:**
- Create: `assets/shaders/canvas_env_pixel_bridge_bank.gdshader`
- Modify: `src/ui/scenes/scene2.tscn`
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

1. Add a pixel-stepped side-bank shadow treatment around the bridge ends.
2. Keep the playable bridge center clear and preserve character placement.
3. Layer the treatment locally so it does not alter shared battle logic or Scene1.

### Task 5: Runtime verification

**Files:**
- Verify: `src/ui/scenes/battle_screen1.tscn`
- Verify: `src/ui/scenes/battle_screen2.tscn`

1. Launch only through `tools/run_godot.ps1`.
2. Capture the necessary Scene2 screenshot and inspect depth, waterfall readability, bridge grounding, and water continuity.
3. Run a Scene1 runtime regression screenshot.
4. Run the full GUT suite and report exact results.
