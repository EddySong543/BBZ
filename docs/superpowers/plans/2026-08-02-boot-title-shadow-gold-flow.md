# Boot Title, Character Shadow, and Gold Flow Implementation Plan

> **For agentic workers:** Execute this plan inline and preserve all approved Boot Screen interaction, character idle, blue-flow, and layout behavior.

**Goal:** Apply the approved antique-gold title palette, make the existing character shadow render above the Boot Screen background, and replace block-based gold-ring reconstruction with continuous original-texture motion.

**Architecture:** Keep the existing title shader and change only its palette uniforms. Keep the split character shadow sprites, but return them to the character's draw plane and rely on `show_behind_parent` for local ordering. Keep one visible `GoldEnergy` layer and its flow map; replace quantized phase and alpha removal with a continuous arc phase, small UV displacement, and restrained value modulation.

**Tech Stack:** Godot 4.7.1, GDScript, CanvasItem shaders, GUT.

## Global Constraints

- Do not change title size, position, perspective, or animation timing.
- Do not change character idle animation, foreground-hand depth treatment, or energy star.
- Do not change approved blue layers or blue-flow parameters.
- Do not add another visible gold layer or additive particle copy.
- Run Godot only through `tools/run_godot.ps1`.

---

### Task 1: Lock the new visual contracts in tests

**Files:**
- Modify: `tests/unit/ui/test_boot_pressure_backdrop.gd`
- Modify: `tests/unit/ui/test_boot_character_shadow.gd`

**Interfaces:**
- Consumes: `BootScreen`, `BootCharacterIdle`, title and gold ShaderMaterials.
- Produces: Exact palette, draw-order, and continuous-flow regression contracts.

- [ ] Update the title assertions to `structure_color = #CD894A`, `face_color = #E6B983`, `energy_peak_color = #FFF8BC`, and `outline_color = #0D2B45`.
- [ ] Require every character shadow to use `z_index = 0`, `show_behind_parent = true`, offset `(2.1, 3.2)`, and near-black 82% opacity. The character rig scales this to approximately `(11, 17)` screen pixels.
- [ ] Require `escape_rise_pixels = 4.0`, a continuous escape phase in the generated flow map, and no shader alpha fade or block reconstruction.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Test` and confirm the old implementation fails these assertions.

### Task 2: Apply title and character-shadow changes

**Files:**
- Modify: `src/ui/boot_screen.tscn`
- Modify: `src/ui/components/boot_character_idle.tscn`

**Interfaces:**
- Consumes: Existing title perspective shader and shared character shadow material.
- Produces: Antique-gold glyphs and visible, locally-behind character shadows.

- [ ] Change only title palette uniforms and matching `TitleColumn` exported colors.
- [ ] Change all split-part shadow nodes from `z_index = -10` to `z_index = 0`; keep `show_behind_parent = true`.
- [ ] Leave all transforms, animation resources, and node names otherwise unchanged.

### Task 3: Replace block reconstruction with continuous gold flow

**Files:**
- Modify: `tools/build_boot_pressure_layers.gd`
- Modify: `assets/shaders/canvas_boot_gold_energy.gdshader`
- Modify: `src/ui/boot_screen.tscn`

**Interfaces:**
- Consumes: `boot_pressure_gold_combined.png`, `boot_pressure_gold_flow.png`, and `motion_time`.
- Produces: One visible gold layer with continuous flow and unchanged source alpha.

- [ ] Encode escape phase continuously from vertical arc position instead of 24-pixel blocks.
- [ ] Use a traveling sine wave over the continuous phase, with 4-pixel maximum source displacement.
- [ ] Keep source alpha unchanged; add at most 12% traveling value modulation.
- [ ] Regenerate the combined and flow textures with `& .\tools\run_godot.ps1 -Mode Tool -Target res://tools/build_boot_pressure_layers.gd`.
- [ ] Re-import with `& .\tools\run_godot.ps1 -Mode Import`.

### Task 4: Verify the integrated Boot Screen

**Files:**
- Verify: `src/ui/boot_screen.tscn`
- Verify: `tools/boot_background_preview_runner.tscn`

**Interfaces:**
- Consumes: The finished scene and runtime probe.
- Produces: Automated and visual evidence without committing or pushing.

- [ ] Run `& .\tools\run_godot.ps1 -Mode Test`; require zero failures.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Probe -Target res://tools/boot_background_preview_runner.tscn`.
- [ ] Inspect all three runtime frames for visible character shadow, readable antique-gold title, continuous gold motion, and absence of block disappearance.
- [ ] Run scoped `git diff --check` and report exact verification results.
