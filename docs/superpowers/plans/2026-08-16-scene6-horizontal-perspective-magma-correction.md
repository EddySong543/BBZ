# Scene6 Horizontal Perspective Magma Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected vertical ridge extension with a clearly foregrounded horizontal magma lake whose perspective, texture scale, and occlusion read as a surface below the battle platform.

**Architecture:** Keep `MagmaLake` behind the platform and foreground, but rebuild its shader around a full molten base, horizontally elongated crust rafts, compressed far lanes, and larger near lanes. Retain the deterministic 16-second circular phase while moving heat horizontally through stable rafts.

**Tech Stack:** Godot 4.7 canvas shaders, Scene6 ShaderMaterial parameters, GUT and the existing five-phase runtime probe.

## Global Constraints

- Preserve the current platform, foreground, character, HUD, input, and parallax geometry.
- Remove the vertical ridge topology completely; do not layer the horizontal lake over it.
- No rectangular cell boundaries, polygon web, full-width yellow lip, square particles, or hard time reset.
- The lake must remain visibly molten under dark crust instead of reading as another dark background layer.
- The normalized loop phases `0.0` and `1.0` must render identically.
- Do not commit or push unless explicitly requested.

---

### Task 1: Replace the rejected topology contract

**Files:**
- Modify: `tests/unit/ui/test_scene6_framework.gd`

- [ ] Require `perspective_depth`, `horizontal_flow`, `crust_raft`, `molten_base`, and `near_scale` markers.
- [ ] Reject `warped_ridge_field`, `organic_crust_field`, `micro_vein`, and any time `floor` operation.
- [ ] Keep the 16-second exact-loop, draw-order, parallax, palette-separation, and forbidden-route assertions.
- [ ] Run GUT and confirm Scene6 fails before the shader replacement.

### Task 2: Build a horizontal perspective lake

**Files:**
- Modify: `assets/shaders/canvas_env_scene6_occluded_magma.gdshader`
- Modify: `src/ui/scenes/scene6.tscn`

- [ ] Start from an opaque dark-red molten base below the irregular surface silhouette.
- [ ] Map depth nonlinearly so the far 25% is vertically compressed and near features grow toward the screen bottom.
- [ ] Generate stable horizontally elongated crust rafts from interpolated domain-warped noise; avoid binary internal cutouts.
- [ ] Animate only horizontal heat lanes and broken orange seams with the existing circular time phase.
- [ ] Keep the platform/lake contact shadow, central UI protection, `parallax_factor = 1.0`, and existing node geometry.

### Task 3: Verify the near-lake read

**Files:**
- Modify if evidence requires tuning: `assets/shaders/canvas_env_scene6_occluded_magma.gdshader`, `src/ui/scenes/scene6.tscn`
- Reuse: `tools/scene6_framework_probe.gd`

- [ ] Capture phases `00`, `25`, `50`, `75`, and `100` at 1920×1080.
- [ ] Reject any vertical river-like texture, hard internal boundary, or far-background continuation.
- [ ] Confirm smaller/dimmer far bands and larger/brighter near bands remain visible behind foreground occlusion.
- [ ] Require probe `loop_diff_pixels=0`, non-empty magma metrics, and `SCENE6_CHILU_VALLEY_PROBE: PASS`.
- [ ] Run Godot import and full GUT; report Scene6 separately from unrelated failures.
