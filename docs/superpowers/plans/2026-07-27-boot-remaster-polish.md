# Boot Remaster Draft Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shorten the Boot reveal lead-in, clean the cloud silhouette, add settled-state pointer parallax, and neutralize the character's excessive orange lighting.

**Architecture:** Keep the separate preview architecture intact. Tune Boot-only scene material parameters, extend the existing backdrop with a normalized pointer input, and let the animation controller synchronize foreground presentation layers after the reveal.

**Tech Stack:** Godot 4, GDScript, canvas-item shaders, GUT, windowed screenshot probes.

## Global Constraints

- Do not modify `res://src/ui/boot_screen.tscn` or the production main-scene entry.
- Reuse the existing Scene1 background shaders and Scene2 lower-cloud shader.
- Pointer motion begins only after the reveal has fully settled.
- Do not edit the source character PNG.

---

### Task 1: Lock the requested behavior in tests

**Files:**
- Modify: `tests/unit/ui/test_boot_remaster_preview.gd`

**Interfaces:**
- Consumes: `BootRemasterAnimationPreview.seek_preview(seconds)`
- Produces: assertions for timing, cloud contour parameters, pointer parallax, and character light parameters

- [x] **Step 1: Replace the old timing assertions**

Assert `show_duration == 3.35`, `burst_start == 1.55`, and that entry remains locked immediately before `show_duration`.

- [x] **Step 2: Add Boot cloud cleanup assertions**

Assert both cloud materials use a coarser `pixel_grid`, `lobe_min_step_px >= 3.0`, and `bank_join_variation == 0.0`.

- [x] **Step 3: Add pointer-parallax assertions**

Call `seek_idle_pointer(-1.0)` and `seek_idle_pointer(1.0)` after seeking the final frame. Assert that character and both energy layers remain synchronized, title motion is smaller, and front-cloud motion is larger than moon motion.

- [x] **Step 4: Add character-light assertions**

Assert the character material uses a lower light strength and a pale-gold light color whose green channel is at least `0.78`.

### Task 2: Implement the four polish changes

**Files:**
- Modify: `src/ui/boot_screen_remaster_animation_preview.gd`
- Modify: `src/ui/components/boot_remaster_backdrop.gd`
- Modify: `src/ui/components/boot_remaster_backdrop.tscn`
- Modify: `src/ui/boot_screen_remaster_preview.tscn`

**Interfaces:**
- Consumes: normalized pointer x in `[-1.0, 1.0]`
- Produces: `BootRemasterAnimationPreview.seek_idle_pointer(normalized_x)` and `BootRemasterBackdrop.pointer_offset`

- [x] **Step 1: Move the reveal timings earlier**

Set the focus, burst, background, title, and settle points to the approved shorter timing while preserving the existing easing functions and minimum zoom of `1.0`.

- [x] **Step 2: Clean the Boot cloud contours**

Adjust only the two Boot cloud `ShaderMaterial` instances: use fewer virtual pixels, a three-pixel minimum contour step, and zero join variation.

- [x] **Step 3: Add backdrop pointer input**

Add an exported normalized `pointer_offset` property to `BootRemasterBackdrop` and combine it with the existing per-layer parallax factors without vertical motion.

- [x] **Step 4: Synchronize the foreground**

In the animation controller, smooth the mouse x position only after the reveal. Move character and both energy layers together, move the title less, and pass the same normalized value into the backdrop.

- [x] **Step 5: Neutralize character lighting**

Change the Boot-only character light material to a pale gold with lower strength and lower ambient lift.

### Task 3: Produce runtime evidence

**Files:**
- Modify: `tools/boot_remaster_animation_preview_runner.gd`

**Interfaces:**
- Consumes: `seek_preview(seconds)` and `seek_idle_pointer(normalized_x)`
- Produces: `boot_remaster_animation_contact_sheet.png` and `boot_remaster_idle_pointer_contact.png`

- [x] **Step 1: Update animation checkpoints**

Capture frames before, during, and after the earlier pullback.

- [x] **Step 2: Capture left-center-right idle frames**

Seek to the settled frame, apply pointer values `-1.0`, `0.0`, and `1.0`, and write a three-frame contact sheet.

- [x] **Step 3: Run verification**

Run Godot import, the Boot GUT test file, and both windowed Boot probes through `tools/run_godot.ps1`. Inspect the resulting screenshots and run a scoped `git diff --check`.
