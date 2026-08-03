# Boot Screen Layered Idle Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flattened Boot Screen pressure background with genuinely moving blue brush and gold ring assets, then apply the approved high-contrast blue title palette.

**Architecture:** A deterministic Godot tool extracts transparent blue and gold layers from the approved source plate. Runtime shaders move the actual blue textures, a focused controller rotates the actual gold textures counterclockwise, and the existing `BattleStage` remains responsible only for established parallax. Title recoloring stays inside the existing title shader/material contract.

**Tech Stack:** Godot 4.7.1, GDScript, Godot canvas shaders, GUT, PNG assets.

## Global Constraints

- Do not implement the opening timeline in this plan.
- Future star pre-flash count is exactly two.
- Future blue reveal, gold ring entrance, and title blade sweep start concurrently.
- Remove old fake-motion runtime nodes instead of covering them.
- Preserve the current character idle, title loop timing, mouse parallax, and Boot Screen interaction.

---

### Task 1: Deterministic pressure-layer extraction

**Files:**
- Create: `tools/build_boot_pressure_layers.gd`
- Create: `assets/ui/boot/boot_pressure_blue_base.png`
- Create: `assets/ui/boot/boot_pressure_blue_mid.png`
- Create: `assets/ui/boot/boot_pressure_blue_light.png`
- Create: `assets/ui/boot/boot_pressure_gold_inner.png`
- Create: `assets/ui/boot/boot_pressure_gold_mid.png`
- Create: `assets/ui/boot/boot_pressure_gold_outer.png`
- Test: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Consumes: `res://assets/ui/boot/boot_pressure_background_v2.png`
- Produces: six full-resolution transparent PNG layers with identical dimensions.

- [ ] **Step 1: Write failing asset-contract assertions**

Add assertions that all six resources load, use the source dimensions, and contain transparent corners.

- [ ] **Step 2: Run the full GUT suite to verify the contract fails**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test
```

Expected: `test_boot_pressure_backdrop.gd` fails because the six layer assets do not exist.

- [ ] **Step 3: Implement the extraction tool**

Use `Image.load_from_file()`, classify blue pixels by `b - r > 0.035`, classify gold pixels by warm hue and saturation, split gold by distance from `Vector2(968, 338)`, and save all outputs with `Image.save_png()`.

- [ ] **Step 4: Generate and import the assets**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/build_boot_pressure_layers.gd'
& .\tools\run_godot.ps1 -Mode Import
```

Expected: six PNG files are generated and imported without shader or resource errors.

### Task 2: Actual blue and gold material motion

**Files:**
- Create: `assets/shaders/canvas_boot_paper.gdshader`
- Create: `assets/shaders/canvas_boot_blue_layer.gdshader`
- Create: `src/ui/components/boot_pressure_motion.gd`
- Modify: `src/ui/boot_screen.tscn`
- Modify: `tests/unit/ui/test_boot_pressure_backdrop.gd`
- Delete: `assets/shaders/canvas_boot_pressure_blue_motion.gdshader`
- Delete: `src/ui/components/boot_pressure_layer.gd`

**Interfaces:**
- `boot_pressure_motion.gd` consumes siblings `GoldInner`, `GoldMid`, and `GoldOuter`.
- It produces `animation_time() -> float` and continuously assigns negative rotations using periods 18, 24, and 32 seconds.
- `canvas_boot_blue_layer.gdshader` consumes `motion_pixels`, `motion_period`, `bend_pixels`, and `motion_direction`.

- [ ] **Step 1: Replace old-node tests with new layer contracts**

Assert that old nodes are absent, the three blue layers use the new shader and expected parameters, all three gold layers use the extracted textures and `pivot_offset = Vector2(968, 338)`, and the controller uses `boot_pressure_motion.gd`.

- [ ] **Step 2: Run tests and verify failure**

Run the full GUT command and expect failures for the missing new nodes and the still-present old nodes.

- [ ] **Step 3: Implement the paper and blue shaders**

The paper shader provides low-amplitude beige grain only. The blue shader samples the transparent layer with:

```glsl
float phase = TIME * TAU / max(motion_period, 0.001);
vec2 along = normalize(motion_direction);
vec2 across = vec2(-along.y, along.x);
float bend = sin(dot(UV, across) * TAU * 3.0 + phase) * bend_pixels;
vec2 offset_pixels = along * sin(phase) * motion_pixels + across * bend;
vec4 sampled = texture(TEXTURE, UV - offset_pixels * TEXTURE_PIXEL_SIZE);
COLOR = sampled * vertex_color;
```

- [ ] **Step 4: Implement actual counterclockwise gold rotation**

In `_process(delta)`, accumulate time and assign:

```gdscript
gold_inner.rotation = -TAU * _time / inner_period
gold_mid.rotation = -TAU * _time / mid_period
gold_outer.rotation = -TAU * _time / outer_period
```

- [ ] **Step 5: Replace the scene layers**

Remove `PressurePlate`, all three old `Blue*Flow` nodes, `GoldenHalo`, and `EnergyFragments`. Add paper, three transparent blue layers, three transparent gold layers, and the controller.

- [ ] **Step 6: Run tests and import**

Expected: the new scene contracts pass and no removed shader or script remains referenced.

### Task 3: High-contrast blue title

**Files:**
- Modify: `assets/shaders/canvas_boot_title_perspective.gdshader`
- Modify: `src/ui/boot_screen.tscn`
- Modify: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Preserves existing `flow_phase` animation control.
- Produces a continuous two-texel outline and the palette `#476F8E`, `#132B3B`, `#F1E5D0`, `#E25D49`.

- [ ] **Step 1: Add failing palette and outline assertions**

Assert all three face materials use the approved colors and `outline_width_texels = 2.0`.

- [ ] **Step 2: Run tests and verify failure**

Expected: materials still contain the old cream face and one-texel outline.

- [ ] **Step 3: Implement continuous two-texel outline**

Sample both one-texel and two-texel axial and diagonal neighbors, taking the maximum alpha so no gap appears between the glyph and outer contour.

- [ ] **Step 4: Apply the palette to every face and shadow material**

Set explicit shader parameters in `boot_screen.tscn`; do not modify title controller timing.

- [ ] **Step 5: Run tests**

Expected: all title material contracts pass.

### Task 4: Runtime visual verification and cleanup

**Files:**
- Modify: `tools/boot_background_preview_runner.gd`
- Modify: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- The preview runner captures at least three frames separated by 2.5 seconds.
- It verifies controller time and gold rotation advance.

- [ ] **Step 1: Extend the runtime probe**

Check that gold rotations become negative and differ from one another before saving the final frame.

- [ ] **Step 2: Run the probe**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/boot_background_preview_runner.tscn'
```

Expected: three runtime PNGs and `BOOT_BACKGROUND_FRAMES_OK`.

- [ ] **Step 3: Inspect the first and final frames**

Verify no blue or gold remains static underneath the moving layers, the title reads without a board, and transparent corners contain no old plate.

- [ ] **Step 4: Run fresh full verification**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test
git -c safe.directory='D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization' -C 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization' diff --check
```

Expected: all GUT tests pass and `diff --check` prints no errors.
