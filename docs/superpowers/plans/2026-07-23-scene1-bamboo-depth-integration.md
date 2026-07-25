# Scene1 Bamboo Depth Integration Implementation Plan

> **For agentic workers:** Execute inline in the current session. Subagent delegation is disabled for this task.

**Goal:** Integrate two dedicated far-bamboo-grove assets behind the two crisp Scene1 main bamboo cutouts while preserving Scene1 battle behavior and Scene2 isolation.

**Architecture:** Use each dedicated far-grove texture exactly once and remove every background node that reused the main bamboo textures. Extend the shared foliage shader with alpha-aware blur and an opt-in baked-checkerboard key; main bamboo keeps authored alpha and full opacity.

**Tech Stack:** Godot 4.6, `.tscn` resources, Godot canvas-item shader language, GDScript GUT tests.

## Global Constraints

- Modify only Scene1 bamboo visuals, their shader, documentation, and relevant regression tests.
- Do not modify characters, HUD, Scene2 visuals, or battle behavior.
- Preserve the user's tall edge-framing composition while restoring each source texture's aspect ratio.
- Main bamboo uses nearest filtering and `blur_amount = 0`; only background bamboo may blur.
- Use `tools/run_godot.ps1` for every Godot invocation.
- Do not commit or push implementation files without an explicit commit request; the approved design document is already isolated in commit `ef930b9`.

---

### Task 1: Bamboo depth regression contract

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: `res://src/ui/scenes/scene1.tscn`
- Produces: assertions for four bamboo nodes, dedicated far-grove paths, correct source aspect ratios, removed copy nodes, layer order, full-opacity main bamboo, baked-background keying, and Scene2 isolation.

- [ ] Assert one dedicated far grove and one main bamboo on each side.
- [ ] Assert that every displayed bamboo keeps the aspect ratio of its assigned source texture.
- [ ] Assert far nodes are below `HorizonHaze` and main nodes remain between `RooftopL` and `RooftopR`.
- [ ] Assert main materials use `blur_amount = 0`, `alpha_scale = 1`, and no background key.
- [ ] Assert dedicated far materials use `blur_amount = 1.2` and enable baked-background keying.
- [ ] Assert all six old copy-node names are absent and Scene2 has none of the four final bamboo nodes.
- [ ] Run the repository GUT suite and confirm the new contract fails before implementation
  (the project launcher intentionally exposes only the full-suite Test mode):

```powershell
& .\tools\run_godot.ps1 -Mode Test
```

Expected: failure because the scene still references reused bamboo copies instead of the two dedicated grove textures.

### Task 2: Depth-capable foliage shader

**Files:**
- Modify: `assets/shaders/canvas_env_night_foliage.gdshader`

**Interfaces:**
- Consumes: sprite `TEXTURE`, `UV`, and per-material uniforms.
- Produces: `blur_amount`, `shadow_tint`, `shadow_lift`, rim controls, and opt-in baked-background key controls in addition to the existing grade.

- [ ] Add alpha-weighted nine-tap sampling so transparent pixels cannot darken blurred edges.
- [ ] Keep the exact source sample when `blur_amount = 0`.
- [ ] Add a low-luminance shadow lift toward a configurable indigo shadow tint.
- [ ] Add an alpha-edge rim that samples toward `rim_side`, allowing left and right main bamboo to face the central moon.
- [ ] Add high-luminance low-chroma background keying and apply it before every blur/rim sample.
- [ ] Preserve the source alpha multiplied by `alpha_scale`.
- [ ] Run Godot import and confirm the shader compiles:

```powershell
& .\tools\run_godot.ps1 -Mode Import
```

Expected: exit code `0` with no shader parse error.

### Task 3: Dedicated far-grove Scene1 composition

**Files:**
- Modify: `src/ui/scenes/scene1.tscn`
- Modify: `assets/scenes/scene1/SPEC.md`

**Interfaces:**
- Consumes: formal left/right bamboo textures and the depth-capable foliage shader.
- Produces: two dedicated far-grove and two main bamboo `TextureRect` nodes.

- [ ] Move and rename the imported far-grove textures into `assets/scenes/scene1/`.
- [ ] Remove every far/mid node and material that reused `scene1_bamboo_left.png` or `scene1_bamboo_right.png`.
- [ ] Add two far-layer materials with baked-checkerboard keying, atmospheric tint, low alpha, and light blur.
- [ ] Update main materials with full opacity, no blur, blue-violet shadow lift, and inward-facing moon rim.
- [ ] Insert far bamboo after `Mountain_right` and before `HorizonHaze`.
- [ ] Reframe main bamboo at aspect-correct integer sizes and crop it farther outside both screen edges.
- [ ] Document all four nodes and their visual roles in the Scene1 layer table.
- [ ] Run the repository GUT suite:

```powershell
& .\tools\run_godot.ps1 -Mode Test
```

Expected: all tests in the suite pass.

### Task 4: Runtime visual and full regression verification

**Files:**
- Verify: `battle_screen_shot.png`
- Verify: `battle_scene2_shot.png`

**Interfaces:**
- Consumes: completed Scene1 composition.
- Produces: runtime evidence for depth, HUD safety, pixel integrity, and Scene2 isolation.

- [ ] Capture Scene1:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/battle_shot.tscn'
```

- [ ] Inspect for three readable depth levels, no HUD/character obstruction, no white or black blur halos, and natural roof occlusion.
- [ ] Capture Scene2:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/battle_scene2_shot.tscn'
```

- [ ] Confirm Scene2 contains no bamboo and its stage layout is unchanged.
- [ ] Run the full suite:

```powershell
& .\tools\run_godot.ps1 -Mode Test
```

Expected: zero failures.
- [ ] Run `git diff --check` and report only bamboo-task files plus any pre-existing unrelated worktree changes.
