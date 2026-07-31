# Boot Title Visible Energy Pulse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing vertical Boot title energy pulse unmistakably visible
at full-screen size without moving the glyphs or changing their static design.

**Architecture:** Keep `TitleColumn` as the single timing and palette owner.
Extend the existing perspective shader with one shared rise/hold/fall envelope,
a stronger energy-core mix, and a two-texel neighbor-sampled halo. Strengthen the
existing runtime probe so it verifies rendered core and halo pixels rather than
uniforms alone.

**Tech Stack:** Godot 4.7 CanvasItem shader, typed GDScript, existing windowed
Boot screenshot probes.

## Global Constraints

- Keep the three title PNG files byte-for-byte unchanged.
- Keep title layout, size, nearest filtering, perspective strength, character,
  star, background, and input behavior unchanged.
- Do not add visible scene nodes or animate title UV, position, scale, rotation,
  or whole-glyph opacity.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Turn the visibility complaint into a failing render probe

**Files:**
- Modify: `tools/boot_shot_runner.gd`

**Interfaces:**
- Consumes the existing `TitleColumn` shader materials and deterministic
  `_set_pulse_phase` probe hook.
- Produces checks for `pulse_hold`, `glow_strength`,
  `glow_radius_texels`, core coverage, core average difference, and halo
  coverage.

- [x] Change expected timing constants to period `3.6`, stagger `0.12`, rise
  `0.12`, hold `0.08`, fall `0.55`, and core strength `0.70`.
- [x] Add expected halo constants `0.65` strength and `2.0` texel radius.
- [x] Keep the baseline energy-color mask and require at least `90%` of its
  pixels to change at each glyph peak.
- [x] Raise the active core average RGB difference requirement so the current
  `22%` implementation fails.
- [x] Build a halo candidate mask from non-energy pixels within two pixels of
  the baseline energy mask; require real rendered changes in that mask at the
  active glyph peak and no changes before its delay.
- [x] Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/boot_shot_runner.tscn'
```

Expected: non-zero exit because the current controller/shader lacks the new
timing and halo behavior.

### Task 2: Implement the stronger core and two-pixel halo

**Files:**
- Modify: `assets/shaders/canvas_boot_title_perspective.gdshader`
- Modify: `src/ui/components/boot_title_controller.gd`

**Interfaces:**
- Adds shader uniforms `pulse_hold`, `glow_strength`, and
  `glow_radius_texels`.
- Keeps `apply_palette(face, structure, energy, energy_peak) -> void`
  unchanged.

- [x] Add `pulse_hold_seconds = 0.08`, `glow_strength = 0.65`, and
  `glow_radius_texels = 2.0` exports to `TitleColumn`.
- [x] Change defaults to period `3.6`, stagger `0.12`, rise `0.12`, fall
  `0.55`, and pulse strength `0.70`.
- [x] Normalize rise, hold, fall, and delays by the period and send all shared
  parameters to each independent material.
- [x] Refactor the shader envelope into a function with explicit rise, hold,
  and fall intervals:

```glsl
float pulse_envelope() {
	float local_phase = fract(pulse_phase - pulse_delay);
	float rise_end = max(pulse_rise, 0.001);
	float hold_end = rise_end + max(pulse_hold, 0.0);
	float fall_end = min(hold_end + max(pulse_fall, 0.001), 0.999);
	float rise = smoothstep(0.0, rise_end, local_phase);
	float fall = 1.0 - smoothstep(hold_end, fall_end, local_phase);
	return rise * fall;
}
```

- [x] Add an `energy_mask(vec4 sampled_color)` helper using the same nearest
  source-color classification as the existing remap.
- [x] Sample the source texture at one- and two-texel cardinal/diagonal
  offsets, combine the neighbor masks into a restrained halo, and multiply it
  by the shared pulse envelope.
- [x] Composite halo color behind transparent pixels and as a restrained warm
  tint over adjacent opaque pixels; leave output unchanged when the envelope
  is zero.
- [x] Run Godot import and the Boot probe. Expected markers:
  `BOOT_TITLE_PALETTE_SWAP_OK`, `BOOT_TITLE_PULSE_SEQUENCE_OK`,
  `BOOT_TITLE_GLOW_OK`, `BOOT_CHAR2_PROBE_OK`, and
  `BOOT_CHAR2_INPUT_OK`.

### Task 3: Generate and inspect the full animation

**Files:**
- Modify: `tools/boot_title_pulse_preview_runner.gd`
- Verify: `D:/Game/BoBoZan/boot_char2_preview.png`
- Verify: `D:/Game/BoBoZan/boot_title_pulse_frames/`

**Interfaces:**
- Captures enough frames to show the full bottom-to-top wave and the return to
  idle at the new `3.6s` period.

- [x] Increase the capture window so it contains baseline, all three peaks,
  glow decay, and a quiet frame.
- [x] Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/boot_title_pulse_preview_runner.tscn'
```

Expected: `BOOT_TITLE_PULSE_FRAMES_OK` with no shader or script errors.

- [x] Inspect the captured frames and full screenshot at original resolution.
  Confirm the effect is visible without frame-by-frame comparison, the glow
  does not resemble neon signage, the rear-hand star remains the brightest
  focal point, and no title edge or character regression appears.
- [x] Re-run the Boot probe after any tuning and retain the first parameters
  that satisfy both visibility and restraint.
