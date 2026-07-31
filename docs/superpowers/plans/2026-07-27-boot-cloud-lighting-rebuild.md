# Boot Cloud and Lighting Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unstable procedural cloud silhouette and add multi-scale moon glow plus synchronized character backlighting to the separate Boot remaster preview.

**Architecture:** Use a Boot-only continuous height-field shader with a four-neighbor topology filter for both cloud banks. Add independent additive MoonDeepGlow and CharacterBacklight layers while keeping the existing Scene1 moon texture, reveal controller, pointer parallax, and production Boot entry unchanged.

**Tech Stack:** Godot 4, GDScript, canvas-item shaders, GUT, windowed screenshot probes.

## Global Constraints

- Do not modify `res://src/ui/boot_screen.tscn` or `project.godot`.
- Do not modify shared Scene1 or Scene2 shader sources.
- Keep all new materials local to the Boot remaster preview.
- CharacterBacklight must remain aligned with Character during reveal and pointer motion.

---

### Task 1: Lock the new visual structure in tests

**Files:**
- Modify: `tests/unit/ui/test_boot_remaster_preview.gd`

**Interfaces:**
- Consumes: `BootRemasterBackdrop`, `BootRemasterAnimationPreview`
- Produces: assertions for cloud topology, MoonDeepGlow, and CharacterBacklight

- [x] **Step 1: Add shader-path constants**

Add constants for `canvas_boot_cloud_bank.gdshader`, `canvas_boot_deep_glow.gdshader`, and `canvas_boot_character_backlight.gdshader`.

- [x] **Step 2: Assert the two cloud banks use the Boot shader**

Assert each material exposes `topology_cleanup = 1.0`, `minimum_neighbors = 2.0`, a fixed silhouette, and different internal flow speeds.

- [x] **Step 3: Assert the new lighting layers**

Assert `MoonDeepGlow` is behind `Moon`, `CharacterBacklight` is immediately behind `Character`, and their shader paths match the Boot-only resources.

- [x] **Step 4: Assert foreground synchronization**

After `seek_idle_pointer(-1.0)` and `seek_idle_pointer(1.0)`, assert CharacterBacklight travels exactly the same horizontal distance as Character and both energy layers.

### Task 2: Build the topology-safe Boot cloud shader

**Files:**
- Create: `assets/shaders/canvas_boot_cloud_bank.gdshader`
- Modify: `src/ui/components/boot_remaster_backdrop.tscn`

**Interfaces:**
- Consumes: fixed height-field parameters, `TIME`, and pixel-grid dimensions
- Produces: a continuous cloud bank mask with four-neighbor cleanup and internal light flow

- [x] **Step 1: Implement the fixed height field**

Use periodic sine components with integer frequencies and a static phase. Quantize the resulting height into broad pixel rows without using `TIME` in the silhouette.

- [x] **Step 2: Implement topology cleanup**

Sample raw coverage at the four cardinal neighboring cells. Keep a covered cell only when at least two neighbors are also covered.

- [x] **Step 3: Implement stable internal motion**

Animate only body shading and moonlit edge intensity. Do not morph or scroll the silhouette.

- [x] **Step 4: Replace both cloud materials**

Assign distinct palette, height, phase, grid, and internal-flow values to CloudBack and CloudFront.

### Task 3: Add multi-scale moon glow

**Files:**
- Create: `assets/shaders/canvas_boot_deep_glow.gdshader`
- Modify: `src/ui/components/boot_remaster_backdrop.tscn`
- Modify: `src/ui/components/boot_remaster_backdrop.gd`

**Interfaces:**
- Consumes: `moon_entry_progress`
- Produces: `MoonDeepGlow` with core, medium, and outer additive glow

- [x] **Step 1: Implement the additive glow shader**

Calculate three exponential falloffs outside the moon radius, tint them blue-white to deep blue, and multiply them by `reveal_progress`.

- [x] **Step 2: Insert MoonDeepGlow**

Place it behind MoonHalo and Moon with the same parallax factor as MoonHalo.

- [x] **Step 3: Synchronize reveal and position**

Include MoonDeepGlow in backdrop base-position caching, pointer motion, visibility, and `moon_entry_progress`.

### Task 4: Add synchronized character backlighting

**Files:**
- Create: `assets/shaders/canvas_boot_character_backlight.gdshader`
- Modify: `src/ui/boot_screen_remaster_preview.tscn`
- Modify: `src/ui/boot_screen_remaster_animation_preview.gd`

**Interfaces:**
- Consumes: character alpha texture and reveal alpha
- Produces: CharacterBacklight aligned with Character

- [x] **Step 1: Implement outer rim and soft glow**

Sample alpha at near and far texel offsets, output only pixels outside the source silhouette, use additive blue-white light, and weight the upper body more strongly.

- [x] **Step 2: Insert CharacterBacklight**

Duplicate Character geometry and texture, place it immediately behind Character, and assign the new material.

- [x] **Step 3: Synchronize animation**

Capture the backlight base position, apply the same reveal alpha and pointer offset as Character, and reset it with the preview.

### Task 5: Run runtime verification

**Files:**
- Verify: `tools/boot_remaster_preview_runner.gd`
- Verify: `tools/boot_remaster_animation_preview_runner.gd`

**Interfaces:**
- Consumes: the existing preview scenes
- Produces: fresh static, animation, motion, and pointer contact sheets

- [x] **Step 1: Run Godot import**

Run `& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 180` and require exit code `0`.

- [x] **Step 2: Run GUT**

Run `& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300` and require `All tests passed!`.

- [x] **Step 3: Run both Boot probes**

Run the static and animation preview runner scenes in Probe mode and require both to exit `0`.

- [x] **Step 4: Inspect all output images**

Confirm there are no isolated cloud cells, the moon glow has three readable scales without washing out the title, and CharacterBacklight remains aligned in all three pointer positions.
