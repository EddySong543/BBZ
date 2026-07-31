# Boot Title Engraving Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected whole-line title flash with a directional
left-to-right energy flow that follows the existing red engraving, tints only
adjacent dark structure, and releases small pixels toward the character.

**Architecture:** `TitleColumn` continues to own one scene-local normalized
phase and three independent ShaderMaterials. The perspective shader classifies
the existing source colors, computes a texel-space moving head and tail only on
energy pixels, samples the two pixels directly below the engraving for local
structure tint, and procedurally draws three endpoint fragments inside the
existing TextureRect.

**Tech Stack:** Godot 4.7 CanvasItem shader, typed GDScript, existing windowed
Boot render probes.

## Global Constraints

- Keep all three `252 × 252px` title PNG files byte-for-byte unchanged.
- Keep title layout, perspective, nearest filtering, palette API, character,
  star, background, and input behavior unchanged.
- Remove the previous whole-line pulse and two-pixel halo behavior.
- Do not add visible scene nodes or animate title position, scale, rotation,
  opacity, or perspective UV.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Add a failing spatial-flow render probe

**Files:**
- Modify: `tools/boot_shot_runner.gd`

**Interfaces:**
- Consumes deterministic controller phase control and the three title material
  instances.
- Produces rendered assertions for flow centroid, local coverage, structure
  tint, endpoint fragments, palette swap, and click transition.

- [ ] Replace the previous pulse/glow constants with period `4.2`, flow
  duration `0.45`, stagger `0.14`, release duration `0.22`, head width `6px`,
  and tail length `28px`.
- [ ] Assert each material receives `flow_delay`, `flow_start_uv_x`,
  `flow_end_uv_x`, and `fragment_origin_uv_y`.
- [ ] Capture each glyph at local flow progress `0.25` and `0.75`.
- [ ] On baseline energy-color pixels, calculate the weighted centroid of
  positive RGB difference. Require the late centroid to be at least `40px`
  farther right than the early centroid.
- [ ] Require each active frame to change less than `70%` of the engraving
  pixels so a whole-line flash cannot pass.
- [ ] Build a candidate mask from structure-color pixels one or two pixels
  below baseline energy pixels and require the changed structure centroid to
  follow the energy centroid.
- [ ] Capture release progress `0.5` and count changed non-title pixels to the
  right of the configured endpoint. Require at least two disconnected
  `1–2px` fragments.
- [ ] Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/boot_shot_runner.tscn'
```

Expected: non-zero exit because the current shader still performs a whole-line
pulse and halo.

### Task 2: Replace pulse parameters with engraving-flow parameters

**Files:**
- Modify: `src/ui/components/boot_title_controller.gd`

**Interfaces:**
- Keeps `apply_palette(face, structure, energy, energy_peak) -> void`.
- Produces `current_flow_phase() -> float` and `_set_flow_phase(phase: float)`.
- Writes shared flow parameters plus per-glyph engraving bounds.

- [ ] Replace Pulse and Glow exports with:

```gdscript
@export_group("Engraving Flow")
@export_range(1.0, 8.0, 0.1) var flow_period_seconds: float = 4.2
@export_range(0.0, 0.4, 0.01) var flow_stagger_seconds: float = 0.14
@export_range(0.1, 1.0, 0.01) var flow_duration_seconds: float = 0.45
@export_range(0.05, 0.5, 0.01) var release_duration_seconds: float = 0.22
@export_range(1.0, 12.0, 1.0) var head_width_texels: float = 6.0
@export_range(4.0, 48.0, 1.0) var tail_length_texels: float = 28.0
@export_range(0.0, 1.0, 0.01) var structure_tint_strength: float = 0.42
@export_range(0.0, 1.0, 0.01) var fragment_strength: float = 0.85
```

- [ ] Write normalized delays `0.00 / 0.14 / 0.28` seconds in order
  `ZanBottom / BoMiddle / BoTop`.
- [ ] Write normalized bounds from the measured source pixels:
  bottom `(63, 224, 78)`, middle `(45, 224, 78)`, top `(45, 215, 90)`.
- [ ] Rename the controller phase methods and update both probe runners.

### Task 3: Implement the moving head, tail, structure tint, and fragments

**Files:**
- Modify: `assets/shaders/canvas_boot_title_perspective.gdshader`

**Interfaces:**
- Consumes the controller flow uniforms.
- Keeps the existing nearest-source-color palette remap and perspective
  projection.

- [ ] Remove `pulse_hold`, `pulse_fall`, `pulse_strength`,
  `glow_strength`, `glow_radius_texels`, and all halo neighbor sampling.
- [ ] Convert the normalized phase and delay into local seconds within the
  `4.2s` cycle.
- [ ] Move a texel-space head from `flow_start_uv_x` to `flow_end_uv_x` during
  `flow_duration`, with a `6px` warm peak and `28px` fading red tail.
- [ ] Apply the flow intensity only when `energy_mask(sampled_color) == 1.0`.
- [ ] For structure pixels, sample source energy at one and two texels above;
  mix only adjacent structure color toward a dark derivative of
  `energy_color` while the head passes the same X position.
- [ ] During release time, draw three hard-edged `1–2px` fragments from
  `(flow_end_uv_x, fragment_origin_uv_y)` with different right/up/down
  trajectories and fade them without blur.
- [ ] Skip all extra texture samples and fragment math outside the active flow
  or release windows.
- [ ] Run Godot import and the Boot probe. Expected markers:
  `BOOT_TITLE_FLOW_OK`, `BOOT_TITLE_STRUCTURE_TINT_OK`,
  `BOOT_TITLE_FRAGMENT_RELEASE_OK`, `BOOT_TITLE_PALETTE_SWAP_OK`,
  `BOOT_CHAR2_PROBE_OK`, and `BOOT_CHAR2_INPUT_OK`.

### Task 4: Record and inspect the complete idle cycle

**Files:**
- Modify: `tools/boot_title_pulse_preview_runner.gd`
- Verify: `D:/Game/BoBoZan/boot_char2_preview.png`
- Verify: `D:/Game/BoBoZan/boot_title_flow_frames/`

**Interfaces:**
- Captures at least `4.2s` at `0.10s` intervals.

- [ ] Rename the preview output and success marker from pulse to flow.
- [ ] Capture `44` frames at `0.10s`, covering all three flows, fragment
  release, and the quiet return.
- [ ] Inspect the full animation at actual display scale. Confirm the motion
  reads as engraving flow rather than a light switch, fragments point toward
  the character, the title remains readable, and the hand star remains the
  brightest focal point.
- [ ] Re-run the main Boot probe after any tuning and preserve the first
  parameters that satisfy all rendered assertions.
