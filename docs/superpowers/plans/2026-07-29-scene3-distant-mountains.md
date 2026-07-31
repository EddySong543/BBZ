# Scene3 Distant Mountains Implementation Plan

> **For agentic workers:** Implement inline in the current task. Preserve the user's authored Scene3 node transforms.

**Goal:** Add the supplied sword-grave far mountains and Scene2's pale mountain range to Scene3, then make the existing cliffs and cloud motion visibly stronger without overwhelming the battle read.

**Architecture:** Convert temporary white-background imports into cropped true-alpha Scene3 assets. Compose one pale full-width range and two sword-grave side mountains behind the cloud sea, grade them for dawn depth, and add controlled exposure/midtone lift to the existing cliff shader.

**Tech Stack:** Godot 4 Image API, canvas-item shaders, `.tscn` composition, GUT, screenshot probes.

## Global Constraints

- Scene3 must not reference `assets/import`.
- Do not use Scene2's deep-purple `scene2_mid_mountain.png`.
- Do not change existing Scene3 node positions, characters, UI, or interaction.
- Use nearest filtering and retain the existing pointer-parallax contract.
- Visual changes must be clearly visible at runtime without washing out silhouettes.

---

### Task 1: Prepare formal far-mountain assets

- [x] Add a deterministic Scene3 import preparation tool.
- [x] Key the white background, feather pale edge contamination, and crop both supplied assets.
- [x] Import the outputs through Godot and inspect their alpha edges.

### Task 2: Compose and grade the mountain layers

- [x] Add Scene2's pale far range behind `BackFog`.
- [x] Add the new left/right sword-grave mountains between `BackFog` and `CloudSeaBack`.
- [x] Apply stronger dawn-depth materials and distinct parallax factors.

### Task 3: Strengthen existing Scene3 depth

- [x] Add exposure and midtone lift controls to the cliff sway shader.
- [x] Raise both cliff materials out of the current near-black grade.
- [x] Increase cloud roll and billow amplitudes enough to read during play.

### Task 4: Verify

- [x] Extend Scene3 tests for formal assets, layer order, non-purple selection, alpha, and stronger grading.
- [x] Run Godot import and the full GUT suite.
- [x] Run Scene3 double-frame and complete battle screenshot probes.
