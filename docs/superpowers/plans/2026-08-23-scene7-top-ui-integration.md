# Scene7 Top UI Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline in the current task; do not dispatch subagents.

**Goal:** Replace Scene7's visually continuous top dark band with three separated, sky-colored HUD support fields whose vertical falloff has no hard edge.

**Architecture:** Keep the existing `UiReadabilityVeil` node and bottom-button support, but replace the top screen-reading shader masks. The new shader uses three non-overlapping horizontal masks, a long vertical falloff, bright-pixel gating, and a deep blue-teal support color derived from the oasis palette. Runtime probes measure the protected HUD regions, untouched gaps, dark-pixel preservation, and transition continuity.

**Tech Stack:** Godot 4.7 `canvas_item` shaders, inherited `.tscn` overrides, GUT, non-saving pixel-data probes.

## Global Constraints

- Modify only Scene7 top HUD integration; preserve bottom buttons, HUD geometry, interaction, characters, stage composition, and parallax.
- Do not generate, read, save, display, or return screenshots.
- Preserve the newly replaced `assets/scenes/scene7/scene7_sky.png` unchanged.
- Do not create a continuous full-width top mask.
- Do not commit or push unless explicitly requested.

---

### Task 1: Encode the separated-mask contract

**Files:**
- Modify: `tests/unit/ui/test_scene7_framework.gd`
- Modify: `tools/scene7_stage4_palette_ui_probe.gd`

**Interfaces:**
- Consumes: `UiReadabilityVeil.material` and the rendered frame with UI temporarily hidden.
- Produces: assertions for separate P1/timer/P2 fields, untouched gaps, dark-pixel preservation, and a gradual vertical falloff.

- [ ] Replace old full-band parameter assertions with `hud_support_strength`, `timer_support_strength`, `support_tint`, `top_fade_start`, and `top_fade_end` assertions.
- [ ] Assert that the shader contains `local_horizontal_mask`, `top_falloff`, and `support_gate`, and no longer contains `soft_rounded_box` for the top HUD.
- [ ] Add two gap regions between P1/timer and timer/P2 to the runtime probe and require absolute attenuation below `0.006`.
- [ ] Measure the upper and lower portions of the fade and reject a hard transition larger than `0.025` mean luminance.

### Task 2: Implement local sky-colored HUD support

**Files:**
- Modify: `assets/shaders/canvas_env_scene7_ui_readability.gdshader`
- Modify: `src/ui/battle_screen7.tscn`

**Interfaces:**
- Consumes: `SCREEN_UV`, the current Scene7 background, and the existing full-screen `UiReadabilityVeil` node.
- Produces: three separated top support masks and the unchanged bottom-button highlight compression.

- [ ] Replace the overlapping rounded boxes with horizontal fields centered at `0.205`, `0.500`, and `0.795`, using half-widths `0.158`, `0.070`, and `0.158` plus no more than `0.018` horizontal feather.
- [ ] Apply a vertical falloff beginning at `0.055` and reaching zero at `0.225`, without a horizontal cutoff line.
- [ ] Blend only bright background pixels toward `support_tint = Color(0.13, 0.29, 0.35, 1)` at strengths `0.18` for P1/P2 and `0.22` for the timer.
- [ ] Preserve dark background pixels and leave the two inter-HUD gaps unmodified.
- [ ] Retain the existing bottom-button mask and strength independently.

### Task 3: Verify without screenshots

**Files:**
- Verify: `assets/shaders/canvas_env_scene7_ui_readability.gdshader`
- Verify: `src/ui/battle_screen7.tscn`
- Verify: `tests/unit/ui/test_scene7_framework.gd`
- Verify: `tools/scene7_stage4_palette_ui_probe.gd`

**Interfaces:**
- Consumes: the completed shader and Scene7 scene.
- Produces: fresh import, runtime-pixel, and GUT evidence.

- [ ] Run `& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 180` and require exit code `0`.
- [ ] Run the non-saving Scene7 palette/UI probe and require the HUD support, gap preservation, fade continuity, sky, palette, and platform checks to pass.
- [ ] Run the focused Scene7 GUT file and require `13/13 passed`.
- [ ] Run `git diff --check` on the touched text files and report any unrelated full-suite failure separately.
