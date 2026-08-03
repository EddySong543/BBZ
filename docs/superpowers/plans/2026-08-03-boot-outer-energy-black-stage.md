# Boot Screen Outer Energy and Black Stage Implementation Plan

> **For agentic workers:** Execute this plan inline and preserve the approved Boot Screen layout, interaction, character idle, blue-brush motion, title motion, and prompt perspective.

**Goal:** Remove the rejected gold-energy breathing/scan behavior, concentrate visible motion on the outer escape edge, and preview the established cream/red title on a black base.

**Architecture:** Keep the single existing `GoldEnergy` texture and flow map. Replace whole-ring sine/value modulation with restrained local hand distortion plus staggered outer-edge source-pixel transport; the transported outer pixels replace the original sample instead of being added as another layer. Change only the paper-base color and established title/prompt palette for the black-background preview.

**Tech Stack:** Godot 4.7.1, CanvasItem shaders, GDScript, GUT.

## Global Constraints

- No `sin`/`cos` breathing, whole-ring value pulse, reverse displacement, or global scan band.
- Do not add particles, duplicate gold nodes, additive copies, or a second visible energy texture.
- Hand-area motion stays subtle; outer-edge upward transport carries the readable motion.
- Preserve source alpha treatment and nearest-neighbor filtering.
- Keep all layout, title perspective, title timing, character animation, blue motion, and click behavior unchanged.
- Run Godot only through `tools/run_godot.ps1`.

---

### Task 1: Lock the corrected visual contracts

**Files:**
- Modify: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Consumes: `GoldEnergy` ShaderMaterial, `PaperBase`, title materials, and prompt colors.
- Produces: Regression assertions for one-way outer transport and the black/cream/red preview palette.

- [ ] Replace old sine-wave assertions with checks for layered local hand flow, staggered outer lanes, source-pixel replacement, and absence of sine/value modulation.
- [ ] Require `hand_flow_pixels = 1.4`, `escape_rise_pixels = 12.0`, and no value-strength uniforms.
- [ ] Require paper `#080A0D`, title face `#F5E8D1`, structure/outline `#0F1B26`, red cut `#E25D49`, and cream prompt.
- [ ] Run the test suite once and confirm the old implementation fails the new contracts.

### Task 2: Implement one-way gold-energy motion

**Files:**
- Modify: `assets/shaders/canvas_boot_gold_energy.gdshader`
- Modify: `src/ui/components/boot_pressure_motion.gd`
- Modify: `src/ui/boot_screen.tscn`

**Interfaces:**
- Consumes: `flow_texture`, `motion_time`, the `.35` hand region, and the `1.0` escape region.
- Produces: One sampled gold layer with restrained hand distortion and staggered upward outer transport.

- [ ] Use advected layered noise only for the 1.4-pixel hand-area source offset; do not change brightness or alpha.
- [ ] Divide the escape region into broad, softly blended lanes with deterministic phase offsets so resets cannot align into a scan band.
- [ ] Move outer source pixels upward by up to 12 pixels and crossfade only each lane's local wrap; normalized replacement must not add another energy copy.
- [ ] Rename controller/material parameters from pulse/value terminology to flow/transport terminology.

### Task 3: Apply the black-stage title preview

**Files:**
- Modify: `src/ui/components/boot_title_controller.gd`
- Modify: `src/ui/boot_screen.tscn`
- Test: `tests/unit/ui/test_boot_pressure_backdrop.gd`

**Interfaces:**
- Consumes: Existing title remap shader and prompt group.
- Produces: Black paper base, cream title, red cuts, dark structure/outline, and readable cream prompt.

- [ ] Set the paper base to `#080A0D` without changing its node or grain shader.
- [ ] Restore the established cream/red title palette while leaving title geometry and animation untouched.
- [ ] Change prompt text and decorative lines to cream so the black base does not make them disappear.

### Task 4: Verify in the real Boot Screen

**Files:**
- Verify: `src/ui/boot_screen.tscn`
- Verify: `tools/boot_background_preview_runner.tscn`

**Interfaces:**
- Consumes: Final runtime scene.
- Produces: Test log and three runtime screenshots.

- [ ] Run Godot import.
- [ ] Run GUT and record Boot Screen-specific and unrelated failures separately.
- [ ] Run the three-frame Boot Screen probe.
- [ ] Inspect the gold outer edge across frames for visible upward motion, no whole-ring bright/dark cycle, no aligned scan, readable cream/red title, and readable prompt.
- [ ] Run scoped `git diff --check`.
