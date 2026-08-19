# Scene6 Occluded Magma and Stable Character Light Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected underbridge forge with an unmistakable, naturally occluded magma lake and prevent Scene6 action rim pulses from turning fighters bright red.

**Architecture:** A dedicated `MagmaLake` ColorRect is drawn before `BattlePlatform`, so the authored platform and foreground assets provide real alpha occlusion. A Scene6-only character shader cap constrains the shared battle `pulse_rim()` effect without changing global combat behavior.

**Tech Stack:** Godot 4.7 canvas_item shaders, `.tscn` scene composition, GUT, existing Scene6 runtime probe.

## Global Constraints

- Do not change the current platform, foreground, character positions, sizes, or parallax composition.
- Do not restore a high magma wall, black abyss rectangle, foreground orange blocks, straight yellow surface lip, square bubbles, or hard stepped animation.
- Magma motion stays slow and uses continuous time with spatial/edge feathering.
- HUD and fighters must not be sampled or distorted by the magma shader.
- Do not commit or push unless explicitly requested.

---

### Task 1: Lock the Scene6 magma and character-light contracts

**Files:**
- Modify: `tests/unit/ui/test_scene6_framework.gd`

**Interfaces:**
- Consumes: `MagmaLake`, `BattlePlatform`, `ForegroundLeft`, `ForegroundRight`, Scene6 character ShaderMaterials.
- Produces: a GUT contract for draw order, material parameters, forbidden visual markers, and rim peak limiting.

- [ ] Replace the underbridge-forge assertions with `MagmaLake` assertions: lake before platform, foreground after platform, nearest filtering, parallax `0.98–1.0`, top between `830–890`, bottom at least `1080`.
- [ ] Assert the magma shader includes `occluded_magma_lake`, `crust_plate`, `slow_convection`, `motion_feather`, and `broken_surface_mask`.
- [ ] Assert the magma shader excludes `bubble`, `stepped_time`, `hint_screen_texture`, and full-width bright-lip markers.
- [ ] Assert Scene6 character materials expose `rim_strength_cap <= 0.32`, use muted amber rim colors, and reduce static red fill/bounce energy.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Test`; expect the Scene6 file to fail before implementation while existing unrelated failures remain unchanged.

### Task 2: Implement the naturally occluded magma lake

**Files:**
- Create: `assets/shaders/canvas_env_scene6_occluded_magma.gdshader`
- Modify: `src/ui/scenes/scene6.tscn`

**Interfaces:**
- Consumes: viewport-local UV, `TIME`, the existing scene draw order.
- Produces: `MagmaLake` with a dark-crust/red-orange palette and slow continuous internal convection.

- [ ] Implement a 4px grid shader with an irregular 8–16px top silhouette, large dark crust plates, sparse red-orange seams, and yellow cores under 5% coverage.
- [ ] Use two weak opposing horizontal convection fields and continuous edge feathering; keep silhouette and alpha stable.
- [ ] Add `MagmaLake` after `ThermalAtmosphere` and before `BattlePlatform`, spanning approximately `x=-32..1952`, `y=850..1080`, with parallax near `0.98`.
- [ ] Remove `UnderbridgeForge` and its shader resource from production Scene6, or replace it only with a non-animated narrow contact reflection if runtime evidence requires it.
- [ ] Preserve the exact authored transforms of `BattlePlatform`, `ForegroundLeft`, and `ForegroundRight`.

### Task 3: Stabilize Scene6 fighter lighting

**Files:**
- Modify: `assets/shaders/canvas_env_scene6_character_light.gdshader`
- Modify: `src/ui/battle_screen6.tscn`

**Interfaces:**
- Consumes: shared `pulse_rim()` writes to the `rim_strength` uniform.
- Produces: Scene6-local `rim_strength_cap` and stable lower-body magma bounce.

- [ ] Add `rim_strength_cap` and use `min(rim_strength, rim_strength_cap)` for final rim energy.
- [ ] Change Scene6 rim colors from saturated red-orange to muted amber and set the cap to `0.24–0.30`.
- [ ] Reduce `ambient_amount`, `fill_amount`, and `lava_bounce_amount`; keep the bounce static and directional.
- [ ] Preserve P1 left-lower and P2 right-lower light directions and independent exposure/highlight compression.

### Task 4: Update probe and documentation, then verify visually

**Files:**
- Modify: `tools/scene6_framework_probe.gd`
- Modify: `assets/scenes/scene6/README.md`

**Interfaces:**
- Consumes: `MagmaLake` and Scene6 character material contracts.
- Produces: 1920×1080 time-separated screenshots and a pass/fail runtime report.

- [ ] Update the probe to require `MagmaLake`, correct draw order, magma material, and capped character rims; reject `UnderbridgeForge`.
- [ ] Update the README with the new layer structure and rejected-route constraints.
- [ ] Run import through `& .\tools\run_godot.ps1 -Mode Import`; expect exit code `0`.
- [ ] Run the full GUT suite and record Scene6-specific and unrelated results separately.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/scene6_framework_probe.tscn'`; expect `SCENE6_CHILU_VALLEY_PROBE: PASS`.
- [ ] Inspect center and delayed 1920×1080 screenshots. Iterate until magma is clearly readable, naturally hidden by platform/foreground, has no orange rectangles, and characters have no excessive red rim.
