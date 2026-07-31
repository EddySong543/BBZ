# Boot Title Pulse And Palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: implement this plan task-by-task and verify the real Godot scene after every runtime-facing task.

**Goal:** Add a restrained staggered energy pulse and centralized palette controls to the existing three Boot title glyphs.

**Architecture:** Extend the existing perspective canvas shader so it performs one texture sample, classifies the three opaque source colors, remaps them to target palette uniforms, and applies a short envelope only to the energy slot. Attach a focused controller script to `TitleColumn`; it owns one palette, one local `4.8s` phase, and writes shared parameters plus per-glyph delays into the three existing independent materials.

**Tech Stack:** Godot 4.7 CanvasItem shader, typed GDScript, existing screenshot probe.

## Global Constraints

- Keep all three PNG files byte-for-byte unchanged.
- Keep `perspective_strength = 0.26`, `edge_padding = 0.04`, nearest filtering, node positions, and node sizes unchanged.
- Do not modify character, star, background, or input behavior.
- Do not animate UVs, perspective, position, scale, rotation, or whole-glyph opacity.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Palette-aware pulse shader

**Files:**
- Modify: `assets/shaders/canvas_boot_title_perspective.gdshader`

**Interfaces:**
- Consumes source colors `#0F1B26`, `#F5E8D1`, and `#DD5639`.
- Produces uniforms `structure_color`, `face_color`, `energy_color`, `energy_peak_color`, `pulse_phase`, `pulse_delay`, `pulse_rise`, `pulse_fall`, and `pulse_strength`.

- [x] Add source color keys and target palette uniforms using `source_color`.
- [x] Classify every opaque sampled pixel by the nearest source color key after perspective sampling.
- [x] Build a one-shot envelope from normalized local phase: fast rise followed by natural decay.
- [x] Apply the envelope only while mapping the energy slot.
- [x] Run Godot import and confirm the shader compiles without changing the static geometry.

### Task 2: Central title controller

**Files:**
- Create: `src/ui/components/boot_title_controller.gd`
- Modify: `src/ui/boot_screen.tscn`

**Interfaces:**
- Produces `apply_palette(new_face: Color, new_structure: Color, new_energy: Color, new_energy_peak: Color) -> void`.
- Writes normalized `pulse_phase` to all three materials.
- Writes normalized delays `0.00 / 0.10 / 0.20` seconds in order `ZanBottom / BoMiddle / BoTop`.

- [x] Add typed palette and timing exports with defaults matching the approved design.
- [x] Cache the existing three unique `ShaderMaterial` instances without adding child nodes.
- [x] Apply the shared palette, pulse durations, strength, and per-glyph delays.
- [x] Drive a scene-local normalized phase with a looping `Tween.tween_method`, so every Boot entry starts at phase zero without adding an `_process` loop.
- [x] Attach the controller to `TitleColumn` without changing its layout or children.

### Task 3: Runtime palette-swap regression probe

**Files:**
- Modify: `tools/boot_shot_runner.gd`

**Interfaces:**
- Consumes `TitleColumn.apply_palette(...)`.
- Verifies default palette uniforms, delays, advancing phase, alternate palette application, restoration, and existing click transition.

- [x] Assert the controller script and all expected shader uniforms are present.
- [x] Assert all three materials share palette values while delays are `0.00 / 0.10 / 0.20` seconds normalized by `4.8s`.
- [x] Apply a high-contrast temporary test palette and assert all four target uniforms update on every material.
- [x] Wait frames and assert pulse phase advances while the temporary palette remains active.
- [x] Restore the approved default palette before saving the final screenshot.
- [x] Run the Boot probe and require `BOOT_CHAR2_PROBE_OK` plus `BOOT_CHAR2_INPUT_OK`.

### Task 4: Visual verification

**Files:**
- Verify: `D:/Game/BoBoZan/boot_char2_preview.png`

- [x] Inspect the real Godot screenshot at full resolution.
- [x] Confirm no title edge, transparent corner, character, star, or background regression.
- [x] Confirm the default palette remains visually subordinate to the rear-hand star.
- [x] Report the centralized Godot Inspector controls for future manual color changes.
