# Scene2 Waterfall Cloud Continuity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline in the current task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the obsolete waterfall-impact contract and make Scene2's three moving waterfall-cloud layers continuous, independently seeded, and visually calm.

**Architecture:** Keep Scene1's shared procedural pixel-cloud shader as the rendering mechanism. Scene2 supplies three independent `ShaderMaterial` instances with deterministic, distinct seeds so the editor and runtime remain reproducible while layers do not repeat. Preserve all user-authored node geometry and opacity.

**Tech Stack:** Godot 4, `.tscn` resources, Godot canvas-item shaders, GUT.

## Global Constraints

- Do not change Scene2 cloud node positions, sizes, or alpha values.
- Do not change Scene1 material parameters or appearance.
- Keep `CloudFar`, `CloudFar2`, `CloudMid`, and `CloudMid2`.
- Launch Godot only through `tools/run_godot.ps1`.

---

### Task 1: Update the Scene2 contracts

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`
- Modify: `assets/scenes/scene2/SPEC.md`
- Modify: `assets/scenes/scene2/EDITING.md`

- [x] Remove assertions that require `WaterfallImpactLeft`.
- [x] Assert that the retired impact node stays absent.
- [x] Describe the three procedural moving cloud layers and their independent materials.

### Task 2: Separate and tune the cloud layers

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`

- [x] Give `WaterfallCloudLower2` its own material and distinct deterministic seed.
- [x] Disable the moving internal two-tone blocks that read as holes.
- [x] Increase the upper cloud speed and occupancy without changing its node geometry.

### Task 3: Verify behavior

**Files:**
- Verify: `src/ui/scenes/scene1.tscn`
- Verify: `src/ui/scenes/scene2.tscn`

- [x] Import resources through `tools/run_godot.ps1`.
- [x] Capture a Scene2 runtime screenshot and inspect the cloud veil.
- [x] Run the full GUT suite.
- [x] Run the Scene1 runtime probe as a regression check.

### Task 4: Shape the lobe clouds with bounded gaps and a waterfall valley

**Files:**
- Modify: `assets/shaders/canvas_env_dark_smoke.gdshader`
- Modify: `src/ui/scenes/scene2.tscn`
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`
- Modify: `assets/scenes/scene2/SPEC.md`
- Modify: `assets/scenes/scene2/EDITING.md`

- [x] Compress Lower lobe height without changing node geometry or opacity.
- [x] Reverse only the copied Lower layer.
- [x] Guarantee an Upper group every two cells and cap group length below one cell.
- [x] Add a default-off, quantized Lower valley envelope aligned to the waterfall.
- [x] Import, capture two runtime frames, run full GUT, and regress Scene1.

### Task 5: Correct repeated Upper silhouettes and the Lower bridge-line gap

- [x] Give Upper clouds seeded asymmetric silhouette families instead of only minor height jitter.
- [x] Add a default-off continuous Lower shoulder so lifting the node cannot expose holes between lobes.
- [x] Keep the waterfall center visibly lower by suppressing random peaks inside the stepped valley.
- [x] Import, capture two runtime frames, run full GUT, and regress Scene1.

### Task 6: Match Upper to the Lower cloud language and smooth Lower motion

- [x] Build Upper from wider compound lobes while scheduling breaks to prevent a full-width strip.
- [x] Extend the Lower envelope from the waterfall minimum to raised left and right scene edges.
- [x] Match Scene1's pixel-step travel rate and reduce independent vertical bobbing.
- [x] Quantize lobe crests to a minimum width of two pixel cells.
- [x] Import, capture two runtime frames, run full GUT, and regress Scene1.

### Task 7: Revert the rejected Upper gap pass and animate foreground art

- [x] Revert only the one-cloud-per-cell Upper gap pass while retaining approved speed increases.
- [x] Add an authored branch-mask sway shader to `BlossomTree`; keep the trunk and load-bearing limbs static while three terminal branch groups pivot independently.
- [x] Remove top exterior dark pixels from the bridge without touching internal stone shadows.
- [x] Regularize isolated one-row and one-column extraction spikes around the bridge opening.
- [x] Import, capture runtime frames, run full GUT, and regress Scene1.
