# Scene6 Seamless Magma and Platform Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Scene6's rectangular, periodically snapping lower magma with an irregular 16-second seamless loop and separate the battle platform from the lake through an iron-dark palette and localized under-light.

**Architecture:** Keep the approved `MagmaLake` draw order behind `BattlePlatform` and both foreground assets. The magma shader owns a static domain-warped organic ridge topology and moves only thermal energy with a circular time orbit; the existing depth-grade shader remains the platform interface, with Scene6-local material parameters providing the iron/cool separation.

**Tech Stack:** Godot 4.7 `canvas_item` shaders, `.tscn` ShaderMaterial parameters, GUT, Scene6 screenshot probe.

## Global Constraints

- Preserve all authored Scene6 node transforms, character geometry, UI, input, and parallax behavior.
- Do not restore a high magma wall, black abyss rectangle, square particles, straight bright lip, or screen-sampling magma effect.
- Keep the approved slow rhythm; solve stepping with continuous periodic phase, never by increasing speed.
- The magma loop must be mathematically identical at normalized phases `0.0` and `1.0`.
- Do not commit or push unless explicitly requested.

---

### Task 1: Lock the seamless-magma contract

**Files:**
- Modify: `tests/unit/ui/test_scene6_framework.gd`

**Interfaces:**
- Consumes: `MagmaLake` ShaderMaterial and `BattlePlatform` ShaderMaterial.
- Produces: source and material assertions that reject the old rectangular and discontinuous routes.

- [ ] Assert the magma material exposes `loop_duration_sec = 16.0`, `phase_override = -1.0`, and keeps `parallax_factor = 1.0` at the platform contact.
- [ ] Assert the shader contains `loop_phase`, `time_orbit`, `warped_ridge_field`, `organic_crust_field`, `static_crust_topology`, `thermal_advection`, and `contact_shadow`.
- [ ] Assert the shader excludes `floor(TIME`, `floor(travel`, `plate_noise`, `hot_pool_gate`, and `floor(px / vec2(72.0, 48.0))`.
- [ ] Assert platform saturation is at most `0.68`, platform palette light red is below `0.50`, and the magma hot color remains above `0.80` red.
- [ ] Run the full GUT command and record the Scene6 failure before implementation.

### Task 2: Rebuild the magma topology and exact loop

**Files:**
- Modify: `assets/shaders/canvas_env_scene6_occluded_magma.gdshader`
- Modify: `src/ui/scenes/scene6.tscn`

**Interfaces:**
- Consumes: `UV`, `TIME`, `size_px`, `loop_duration_sec`, and `phase_override`.
- Produces: a stable irregular crust with periodic heat movement and no axis-aligned cell masks.

- [ ] Quantize only spatial pixels: `vec2 px = floor(UV * size_px / pixel_size) * pixel_size;`.
- [ ] Compute exact periodic time with `loop_phase = phase_override >= 0.0 ? fract(phase_override) : fract(TIME / loop_duration_sec)` and `time_orbit = vec2(cos(loop_phase * TAU), sin(loop_phase * TAU))`.
- [ ] Domain-warp and skew interpolated multi-octave noise into curved ridge fields; derive crust tones from the same organic field instead of rectangular `floor` masks or straight cellular polygons.
- [ ] Keep topology static and animate heat with circular noise sampling plus integer harmonics of the same loop phase.
- [ ] Add top contact shadow, central UI brightness protection, and a stable irregular alpha profile without a bright full-width lip.
- [ ] Set the lake parallax factor to `1.0`, preserving its existing geometry and draw order.

### Task 3: Separate the platform palette

**Files:**
- Modify: `src/ui/scenes/scene6.tscn`

**Interfaces:**
- Consumes: existing `Scene6PlatformGradeMat` parameters.
- Produces: a cooler iron platform with a broken warm underside response.

- [ ] Reduce platform saturation to `0.58-0.66` and brightness to `0.88-0.94`.
- [ ] Map platform shadows to charcoal-purple, mids to iron-red, and lights to muted brick below the magma's body color.
- [ ] Keep `lava_bounce_amount` between `0.04-0.07`, beginning in the lower half of the platform texture.
- [ ] Do not change platform position, size, scale, patch margins, or tiling mode.

### Task 4: Add deterministic loop and visual probes

**Files:**
- Modify: `tools/scene6_framework_probe.gd`

**Interfaces:**
- Consumes: `phase_override` on the lake material.
- Produces: phase `0`, quarter, half, three-quarter, and phase `1` screenshots plus an exact loop-image comparison.

- [ ] Duplicate the scene-local lake material before setting probe-only phase values.
- [ ] Capture `scene6_magma_phase_00.png`, `25`, `50`, `75`, and `100` at 1920×1080.
- [ ] Compare phase `0` and `1` image bytes pixel-by-pixel and fail the probe when any pixel differs.
- [ ] Restore `phase_override = -1.0`, then preserve the existing switch, character, pointer-parallax, and layer checks.

### Task 5: Verify and visually tune

**Files:**
- Modify only if evidence requires tuning: `assets/shaders/canvas_env_scene6_occluded_magma.gdshader`, `src/ui/scenes/scene6.tscn`

**Interfaces:**
- Consumes: Godot import, GUT output, probe screenshots and log.
- Produces: a verified Scene6 handoff.

- [ ] Run `& .\tools\run_godot.ps1 -Mode Import`; require exit code `0`.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Test`; require Scene6 `7/7` and record unrelated failures separately.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/scene6_framework_probe.tscn'`; require `SCENE6_CHILU_VALLEY_PROBE: PASS` and `loop_diff_pixels=0`.
- [ ] Inspect all five phase screenshots plus center and pointer-right screenshots for rectangular boundaries, hard resets, platform/lava merging, UI competition, and occlusion gaps.
- [ ] Run scoped `git diff --check` and report modified files without staging or committing.
