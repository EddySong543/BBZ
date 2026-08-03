# Boot Horizontal Group Perspective Implementation Plan

> **For agentic workers:** Execute this plan inline and verify the real Godot Boot Screen after each runtime-facing task.

**Goal:** Recompose “波波攒” horizontally and make the three glyphs share one restrained inward perspective field.

**Architecture:** Keep the existing three PNGs, face materials, shadow materials, palette mapping, outline, and engraving-flow controller. Extend the existing title shader with a per-node slice of one normalized group X range; the three separate textures then sample one continuous perspective field without an extra viewport or new visual layer.

**Tech Stack:** Godot 4.7.1, Control nodes, CanvasItem shader, typed GDScript, GUT.

## Global Constraints

- Preserve the title palette `#F5E8D1`, `#0F1B26`, `#E25D49`, and the existing dark outline/shadow.
- Preserve all three title PNGs and the current engraving-flow timing.
- Do not change character, background, gold energy, blue layers, mouse parallax, or Boot Screen input.
- Do not commit or push.

---

### Task 1: Lock the horizontal group contract

**Files:**
- Modify: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Consumes: `BootScreen/TitleColumn` and the six title ShaderMaterials.
- Produces: A regression contract for horizontal layout and one continuous perspective field.

- [x] Add a test requiring `TitleColumn.position = Vector2(58, 350)` and `size = Vector2(692, 252)`.
- [x] Require face positions `(0, -12)`, `(220, 0)`, `(440, 0)` and shadow offsets `(5, 9)`.
- [x] Require zero node rotation and unit scale.
- [x] Require all six materials to use `perspective_strength = 0.10`.
- [x] Require group ranges `0..252/692`, `220/692..472/692`, and `440/692..1`.
- [x] Run the full GUT suite and verify the new contract fails against the vertical layout.

### Task 2: Apply one perspective field across three textures

**Files:**
- Modify: `assets/shaders/canvas_boot_title_perspective.gdshader`
- Modify: `src/ui/components/boot_title_controller.gd`

**Interfaces:**
- Produces shader uniforms `group_x_min: float` and `group_x_max: float`.
- `boot_title_controller.gd` writes each face material's normalized group slice in order `攒 / 中间波 / 顶部波`.

- [x] Add default uniforms:

```glsl
uniform float group_x_min : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float group_x_max : hint_range(0.0, 1.0, 0.001) = 1.0;
```

- [x] Replace local perspective progress with:

```glsl
float projected_x = clamp(
		mix(group_x_min, group_x_max, trapezoid_uv.x),
		0.0,
		1.0);
```

- [x] Add normalized group-range constants to the controller and write them beside the existing flow parameters.

### Task 3: Recompose the scene horizontally

**Files:**
- Modify: `src/ui/boot_screen.tscn`

**Interfaces:**
- Consumes: The existing six title nodes and their materials.
- Produces: One horizontal title group without adding or removing visual nodes.

- [x] Move and resize `TitleColumn` to `(58, 350, 692, 252)`.
- [x] Place faces at `(0, -12)`, `(220, 0)`, `(440, 0)`.
- [x] Place shadows exactly `(5, 9)` behind their matching faces.
- [x] Set each face and shadow material to `perspective_strength = 0.10` and its matching group range.
- [x] Keep the current palette, outline, shadow, texture filtering, and animation parameters unchanged.

### Task 4: Verify runtime composition

**Files:**
- Verify: `src/ui/boot_screen.tscn`
- Verify: `tools/boot_background_preview_runner.tscn`

**Interfaces:**
- Produces: Fresh test output and three runtime screenshots.

- [x] Run `& .\tools\run_godot.ps1 -Mode Test`.
- [x] Accept only the known stale character-shadow test if it remains the sole failure; require all Boot title/backdrop tests to pass.
- [x] Run `& .\tools\run_godot.ps1 -Mode Probe -Target res://tools/boot_background_preview_runner.tscn`.
- [x] Inspect the screenshots at full resolution for horizontal reading order, unified inward compression, clear palette, and no character/background regression.
- [x] Run scoped `git diff --check`.
