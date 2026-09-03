# Scene9 Eye Socket Easter Egg Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use verification-before-completion while implementing this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a restrained Scene9 pixel eye-socket glow that may trigger after any valid environment interaction.

**Architecture:** Add one child overlay beneath `DistantLeftMountain` so it inherits the accepted mountain transform and parallax. Build a small hard-alpha animation from the mountain source pixels once at startup, then let `scene9_battle_stage.gd` perform one probabilistic roll after a grass or cloud click has been validated.

**Tech Stack:** Godot 4.7, typed GDScript, generated `ImageTexture` frames, GUT, `tools/run_godot.ps1`.

## Global Constraints

- Scene9 only; do not modify Scene1-8 or shared Battle/UI behavior.
- Preserve the current mountain transform, texture, palette shader, wind animation, and draw order.
- Use nearest filtering, hard-alpha pixels, three restrained cold colors, and no blur, bloom, particles, `Light2D`, or whole-node opacity tween.
- Invalid/transparent clicks and battle UI clicks must never roll the easter-egg probability.
- Each valid environment click may roll whenever the glow is idle; the glow can play again after its full recovery finishes.

---

### Task 1: Pixel eye overlay

**Files:**
- Create: `src/ui/components/scene9_eye_socket_glow.gd`
- Modify: `src/ui/scenes/scene9.tscn`
- Test: `tests/unit/ui/test_scene9_eye_socket_easter_egg.gd`

**Interfaces:**
- Consumes: `DistantLeftMountain.texture` and source rect `Rect2i(45, 94, 42, 20)`.
- Produces: `start_glow() -> bool`, `is_active() -> bool`, `advance_for_testing(delta: float) -> void`, and `visual_contract_snapshot() -> Dictionary`.

- [x] Add a failing test for the node, mask bounds, hard-alpha frames, palette, and one-shot timing.
- [x] Run the focused test and confirm the missing overlay fails.
- [x] Build cropped source-pixel frames once and animate the eye core plus one-source-pixel inner bone rim by changing pixel membership and discrete colors, never node opacity.
- [x] Parent the overlay to `DistantLeftMountain` and verify its inherited transform and parallax chain.
- [x] Run the focused test and confirm the visual contract passes.

### Task 2: Valid-interaction probability routing

**Files:**
- Modify: `src/ui/components/scene9_battle_stage.gd`
- Modify: `src/ui/components/scene9_interaction_controller.gd`
- Test: `tests/unit/ui/test_scene9_eye_socket_easter_egg.gd`
- Test: `tests/unit/ui/test_scene9_environment_interaction.gd`

**Interfaces:**
- Consumes: a confirmed grass/cloud interaction from `register_scene_click_at_canvas_position(canvas_position)`.
- Produces: a 12 percent roll whenever the glow is idle and deterministic testing seams `set_easter_egg_roll_for_testing(value)` and `easter_egg_contract_snapshot()`.

- [x] Add failing tests proving invalid clicks do not roll, valid grass and cloud clicks do roll, and success is one-shot.
- [x] Return a valid grass hit even during its visual-response cooldown so a cloud behind it is never triggered accidentally.
- [x] Route every confirmed environment hit through one Scene9-only probability method.
- [x] Run Scene9 interaction and easter-egg tests.

### Task 3: Regression verification

**Files:**
- Test: `tests/unit/ui/test_scene9_easter_egg_retirement.gd`
- Test: `tests/unit/ui/test_scene9_framework.gd`
- Test: `tests/unit/ui/test_scene9_environment_motion.gd`
- Test: `tests/unit/ui/test_screen_compiles.gd`

- [x] Run all focused Scene9 tests and battle-screen compile coverage.
- [x] Run Godot import through `tools/run_godot.ps1`.
- [x] Confirm the runtime scene contains no retired easter-egg resources and the new overlay stays confined to its source rect.

### Task 4: Palette-ramp local bone relight

**Status:** Superseded by Task 5 after visual review rejected the dotted local-relight pattern.

**Files:**
- Modify: `src/ui/components/scene9_eye_socket_glow.gd`
- Modify: `src/ui/scenes/scene9.tscn`
- Test: `tests/unit/ui/test_scene9_eye_socket_easter_egg.gd`

**Interfaces:**
- Consumes: the existing eye-socket connected component and nearby opaque bone pixels within three source pixels.
- Produces: a 1.1-second rise, 3.5-second live hold, and 1.3-second fall using a stable core, one-pixel inner rim, and sparse local bone relight.

- [x] Extend the contract test to require explicit phase timing, local bone relight coverage, hard alpha, and restrained hold-frame variation.
- [x] Replace the old pulse-only frame generator with discrete rise, hold, and fall phases whose total duration is 5.9 seconds.
- [x] Add palette-locked inner-rim and sparse two-to-three-pixel bone response without blur, `Light2D`, additive blending, or node opacity animation.
- [x] Update the Scene9-only node description and run focused plus Scene9 regression coverage through `tools/run_godot.ps1`.

### Task 5: Replace dotted relight with a solid additive pixel halo

**Status:** Superseded by Task 6 after visual review preferred material relighting over a geometric additive halo.

**Files:**
- Modify: `src/ui/components/scene9_eye_socket_glow.gd`
- Modify: `src/ui/scenes/scene9.tscn`
- Test: `tests/unit/ui/test_scene9_eye_socket_easter_egg.gd`

**Interfaces:**
- Consumes: the existing connected eye-socket mask, 5.9-second phase timing, and repeatable Scene9 interaction trigger.
- Produces: one normally blended core layer plus one additively blended halo layer containing complete one-pixel and two-pixel stepped contours.

- [x] Replace the local-relight contract with separate core and halo frames, additive halo material, and a no-dither continuous-ring guarantee.
- [x] Remove every coordinate-hash, sparse-membership, and per-pixel flicker path from the eye effect.
- [x] Generate complete inner and outer pixel contours and animate only whole-layer palette strength while the core remains stable during the hold phase.
- [x] Preserve the 1.1-second rise, 3.5-second hold, 1.3-second fall, repeatable trigger, nearest filtering, and Scene9-only transform inheritance.
- [x] Run focused eye-effect coverage, all Scene9 UI tests, battle-screen compile coverage, and Godot import through `tools/run_godot.ps1`; Scene9 coverage passes, while the shared compile suite retains four unrelated item-gallery failures.

### Task 6: Continuous palette-ramp bone relight

**Files:**
- Modify: `src/ui/components/scene9_eye_socket_glow.gd`
- Modify: `src/ui/scenes/scene9.tscn`
- Test: `tests/unit/ui/test_scene9_eye_socket_easter_egg.gd`

**Interfaces:**
- Consumes: the connected eye-socket mask and the source mountain's existing bone luminance bands.
- Produces: one normal-blend frame sequence whose complete one-pixel inner band rises two palette steps and whose connected two-to-three-pixel bone region rises one step.

- [x] Replace the additive core/halo contract with opaque source-material relighting and remove the generated `Core` child.
- [x] Grow the relight mask continuously from the eye socket through three source pixels with no randomized omissions, dithering, isolated pixels, or geometric glow rings.
- [x] Preserve source texture detail by mapping each affected bone pixel through authored silver-cyan palette ramps according to its original luminance.
- [x] Keep the full relight stable throughout the 3.5-second hold and retain the accepted 1.1-second rise, 1.3-second fall, and repeatable trigger.
- [x] Run focused eye-effect coverage, all Scene9 UI tests, and Godot import through `tools/run_godot.ps1`.

### Task 7: Scene9-aligned silver-blue palette

**Status:** Superseded by the approved eye-socket bird-flock redesign after the glow presentation was rejected.

**Files:**
- Modify: `src/ui/components/scene9_eye_socket_glow.gd`
- Test: `tests/unit/ui/test_scene9_eye_socket_easter_egg.gd`

- [x] Replace only the eleven core and bone-ramp colors with the approved far-mountain silver-blue palette.
- [x] Lock the exact palette in the eye-socket contract test.
- [x] Run focused eye-effect coverage, all Scene9 UI tests, and Godot import through `tools/run_godot.ps1`.
