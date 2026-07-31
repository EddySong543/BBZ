# Boot Character Idle and Rear-Hand Energy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: execute this plan task-by-task in the current session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the existing boot character idle motion and add a procedural four-point energy star to the rear hand.

**Architecture:** Keep the current layered character rig, animate three hair layers, and rotate the full isolated right waist cloth around its belt root. Add a reusable shader-driven rear-hand VFX inside the character component, with separate behind-character glow and above-character star nodes.

**Tech Stack:** Godot 4.7, GDScript, Sprite2D, ColorRect, canvas-item shaders, AnimationPlayer.

## Global Constraints

- Do not change or implement the boot background in this pass.
- Preserve character position, visible size, textures, and neutral pose.
- Preserve boot input and transition behavior.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Reduce idle motion

**Files:**
- Modify: `src/ui/components/boot_character_idle.gd`

**Interfaces:**
- Consumes: existing aligned hair-tip Sprite2D nodes.
- Produces: a `4.8` second smooth loop led by three hair layers with one restrained waist-tip rotation.

- [x] Change the default loop duration to `4.8`.
- [x] Remove front-arm fur motion and full-waist translation.
- [x] Isolate the full right waist cloth and rotate it by at most `0.032` radians.
- [x] Limit outer hair movement to `0.38` source pixels.
- [x] Limit front hair movement to `0.19` source pixels.
- [x] Remove vertical movement and use smooth interpolation.

### Task 2: Add procedural rear-hand energy

**Files:**
- Create: `assets/shaders/canvas_boot_energy_glow.gdshader`
- Create: `assets/shaders/canvas_boot_energy_star.gdshader`
- Modify: `src/ui/components/boot_character_idle.tscn`

**Interfaces:**
- Consumes: user-authored rear-hand position `(112.68, 47.125)` and Scale `1.37`.
- Produces: `RearHandEnergyAnchor`, `RearHandGlow`, and `RearHandStar`.

- [x] Create a low-intensity additive halo shader.
- [x] Create a pixel-quantized four-point additive star shader.
- [x] Place the halo below `Base` and the star above all character sprites.
- [x] Expose color, intensity, size, and pulse parameters in the Inspector.
- [x] Bake anchor Scale into node dimensions and redesign rays as curved tapered lances.
- [x] Add a circular core, separated faint ring, and expanding release ring.
- [x] Keep ray lengths fixed and synchronize an outward-only brightness wave
  with the `4.8` second idle loop.

### Task 3: Runtime verification

**Files:**
- Modify if needed: `tools/boot_shot_runner.gd`
- Modify if needed: `tools/boot_idle_preview_runner.gd`

**Interfaces:**
- Consumes: integrated character and energy component.
- Produces: runtime screenshots, loop frames, and click-transition evidence.

- [x] Import the project with exit code `0`.
- [x] Capture the boot screen and inspect rear-hand placement.
- [x] Capture one idle loop and verify first/last pixel equality.
- [x] Verify fur remains static and the waist cloth stays attached while moving.
- [x] Require `BOOT_CHAR2_PROBE_OK` and `BOOT_CHAR2_INPUT_OK`.
- [x] Run `git diff --check` on changed text files.
