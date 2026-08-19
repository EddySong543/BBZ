# Scene6 Heat Flow And Forge Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the distant lava visibly flow, strengthen localized heat pulses, add a world-only full-frame heat mirage, and replace the visually hidden abyss treatment with a readable furnace core beneath the platform.

**Architecture:** Far and midground source textures keep fixed UV, alpha, and silhouettes while only source-selected hot pixels animate. The existing pre-HUD PostFX pass gains an opt-in nearest-sampled heat-refraction branch whose defaults are zero for other scenes. A new transparent furnace-core layer sits behind the authored platform so its segmented glow is revealed only through platform openings.

**Tech Stack:** Godot 4 canvas_item shaders, ShaderMaterial scene resources, GUT, 1920x1080 runtime probe.

## Global Constraints

- Preserve all authored Scene6 positions, sizes, baselines, characters, UI, input, and parallax behavior.
- Do not scroll or deform source texture UVs for far or midground lava animation.
- Keep UI outside the heat-refraction pass; use nearest screen sampling and a 1-2 pixel displacement budget.
- Avoid a liquid horizon, bubbles, water-wave motion, or a full-width bright line.
- Verify with import, Scene6 GUT coverage, and time-separated 1920x1080 screenshots.

---

### Task 1: Lock the revised Scene6 visual contract

**Files:**
- Modify: `tests/unit/ui/test_scene6_framework.gd`

**Interfaces:**
- Consumes: Scene6 authored node and material resources.
- Produces: Assertions for far flow, pulse strength, heat mirage, and visible forge-core layering.

- [x] Add contract assertions for nonzero far moving gain, stronger pulses, world-only heat haze parameters, and a `ForgeCore` layer behind `BattlePlatform`.
- [x] Run the Scene6 test and confirm the new assertions fail before implementation.

### Task 2: Implement source-preserving far lava flow and stronger pulses

**Files:**
- Modify: `assets/shaders/canvas_env_scene6_far_heat.gdshader`
- Modify: `src/ui/scenes/scene6.tscn`

**Interfaces:**
- Consumes: Far-background source texels and existing midground lava masks.
- Produces: `far_lava_flow`, `flow_afterglow`, and `far_moving_gain` controls without source-UV displacement.

- [x] Add multiple moving heat bands and a dim trailing band inside the selected far crack pixels.
- [x] Increase far and midground pulse/moving-gain parameters while keeping static rock pixels unchanged.
- [x] Run import to catch shader compilation failures.

### Task 3: Add Scene6 heat mirage before the HUD

**Files:**
- Modify: `assets/shaders/post_fx_color_grade.gdshader`
- Modify: `src/ui/battle_screen6.tscn`

**Interfaces:**
- Consumes: The existing `WorldGrab` screen texture captured before HUD nodes.
- Produces: Opt-in `heat_haze_strength`, `heat_haze_speed`, `heat_haze_scale`, and vertical falloff parameters.

- [x] Add a zero-default nearest-sampled rising-refraction offset to the shared post shader.
- [x] Enable a restrained 1-2 pixel Scene6 heat haze with weaker top-screen influence.
- [x] Verify the PostFX node still precedes both HUD trees.

### Task 4: Make the platform furnace readable

**Files:**
- Create: `assets/shaders/canvas_env_scene6_forge_core.gdshader`
- Modify: `src/ui/scenes/scene6.tscn`

**Interfaces:**
- Consumes: The platform opening region and the existing dark abyss backdrop.
- Produces: Transparent segmented furnace chambers with upward heat travel and no liquid surface.

- [x] Build large irregular furnace chambers, dark separators, hot centers, and slow upward energy travel.
- [x] Place `ForgeCore` after local atmosphere/contact but before `BattlePlatform`, restricted to the visible platform-understructure band.
- [x] Keep the old dark abyss as a depth backing rather than the sole readable effect.

### Task 5: Verify behavior and visual readability

**Files:**
- Modify: `tools/scene6_framework_probe.gd`
- Modify: `assets/scenes/scene6/README.md`

**Interfaces:**
- Consumes: Final Scene6 scene and battle entry.
- Produces: Fresh tests, probe result, and time-separated runtime screenshots.

- [x] Update the probe environment contract to require `ForgeCore` and heat haze.
- [x] Run Scene6 GUT tests and import.
- [x] Run the 1920x1080 probe, inspect center/later/pointer-right screenshots, and compare time-separated far/mid movement.
- [x] Run scoped diff checks and record any unrelated suite failures without modifying them.
