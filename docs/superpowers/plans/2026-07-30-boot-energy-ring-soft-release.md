# Boot Energy Ring Soft Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the visible pop when the rear-hand energy ring is born while preserving the fixed-length outward ray pulse.

**Architecture:** Keep the existing `pulse_phase` synchronization and two releases per `4.8` second idle loop. Replace the ring's discontinuous sawtooth opacity with a continuous birth-and-fade envelope, keep the newborn ring merged into the static core halo, and move it outward only after it becomes visible.

**Tech Stack:** Godot 4.7, canvas-item shader, GDScript-driven animation phase, runtime screenshot probes.

## Global Constraints

- Preserve the character position, size, layered idle animation, and rear-hand anchor.
- Preserve fixed ray lengths and the core-to-tip brightness wave.
- Do not add the approved background during this pass.
- Preserve boot input and transition to `main_menu.tscn`.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Replace the ring opacity discontinuity

**Files:**
- Modify: `assets/shaders/canvas_boot_energy_star.gdshader`
- Modify: `src/ui/components/boot_character_idle.tscn`

**Interfaces:**
- Consumes: normalized `pulse_phase` from `boot_character_idle.gd`.
- Produces: `ring_birth_duration` and `ring_fade_start` Inspector parameters.

- [x] Add the two tuning uniforms and matching scene parameters:

```glsl
uniform float ring_birth_duration : hint_range(0.06, 0.3, 0.01) = 0.16;
uniform float ring_fade_start : hint_range(0.3, 0.8, 0.01) = 0.52;
```

- [x] Replace the release-ring phase block with the continuous envelope:

```glsl
float ring_birth = smoothstep(
		0.02,
		ring_birth_duration,
		outward_phase);
float ring_fade = (
		1.0
		- smoothstep(ring_fade_start, 1.0, outward_phase));
float ring_visibility = ring_birth * ring_fade;
float ring_travel = smoothstep(0.04, 0.92, outward_phase);
float release_ring_radius = mix(
		static_ring_radius + 0.008,
		0.54,
		ring_travel);
float release_ring_width = mix(0.055, 0.014, ring_travel);
float release_ring = (
		1.0
		- smoothstep(
			release_ring_width,
			release_ring_width + 0.025,
			abs(radial_distance - release_ring_radius)));
release_ring *= ring_visibility;
```

- [x] Replace the reset-time core flash with a short continuous bell:

```glsl
float core_release_progress = min(outward_phase / 0.32, 1.0);
float core_release = sin(core_release_progress * 3.14159265);
float pulse = 1.0 + core_release * pulse_amount;
```

### Task 2: Verify the complete loop

**Files:**
- Modify: `tools/boot_idle_preview_runner.gd`

**Interfaces:**
- Consumes: the integrated `boot_screen.tscn`.
- Produces: 17 evenly spaced runtime frames across the `4.8` second loop.

- [x] Change `CAPTURE_COUNT` from `9` to `17` so the ring birth is visible
  between the old samples.
- [x] Require the first and final frames to be pixel-identical.
- [x] Inspect a rear-hand close-up across at least eight consecutive frames.
- [x] Require `BOOT_CHAR2_PROBE_OK`.
- [x] Require `BOOT_CHAR2_INPUT_OK: res://src/ui/main_menu.tscn`.
- [x] Run `git diff --check` on the modified text files.
