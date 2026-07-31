# Boot Remaster Static Golden Motes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline with TDD and preserve unrelated worktree changes.

**Goal:** Replace the independent Boot Remaster preview with a camera-free pixel-character idle composition driven only by a hand energy mote and two restrained upward particle layers.

**Architecture:** Promote the mislabeled WebP source into a valid lossless PNG, then replace the preview scene tree instead of overlaying it. A small typed `@tool` controller owns only hand-mote breathing and the immediate-entry contract; Godot particle resources own background motion.

**Tech Stack:** Godot 4.7, GDScript, Control UI, GPUParticles2D, GUT.

## Global Constraints

- Do not modify `res://src/ui/boot_screen.tscn` or the configured main scene.
- Remove old visual nodes rather than hiding them.
- Keep pixel textures lossless, mipmap-free, and nearest-filtered.
- Launch Godot only through `tools/run_godot.ps1`.
- Do not stop pre-existing Godot processes.

---

### Task 1: Promote the pixel character asset

**Files:**
- Create: `tools/promote_boot_pixel_character.gd`
- Create: `assets/ui/boot/boot_char_pixel.png`
- Test: `tests/unit/ui/test_boot_remaster_preview.gd`

**Interfaces:**
- Consumes: `res://assets/import/boot_char_pixel.png` WebP bytes.
- Produces: valid `res://assets/ui/boot/boot_char_pixel.png`, 172×259 RGBA.

- [ ] Add a failing GUT test that decodes the source with `Image.load_webp_from_buffer()`, loads the runtime PNG, and compares size, alpha, and `get_data()`.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Test`; expect the runtime-path assertions to fail.
- [ ] Add a Godot tool script which reads the source bytes, calls `load_webp_from_buffer`, validates `Vector2i(172, 259)`, and saves with `save_png`.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/promote_boot_pixel_character.gd'`.
- [ ] Run import mode and the full GUT suite; expect the promotion test to pass.

### Task 2: Replace the preview scene and idle behavior

**Files:**
- Replace: `src/ui/boot_screen_remaster_preview.tscn`
- Replace: `src/ui/boot_screen_remaster_animation_preview.gd`
- Modify: `src/ui/boot_screen_remaster_animation_preview.tscn`
- Test: `tests/unit/ui/test_boot_remaster_preview.gd`

**Interfaces:**
- Produces nodes `Background`, `FarMotes`, `Title`, `MidMotes`, `GroundShadow`, `Character`, and `HandMote`.
- Produces `func can_enter() -> bool` returning `true`, plus `func seek_idle(seconds: float) -> void` for deterministic probes.

- [ ] Replace old scene assertions with failing tests for the exact new node order, absence of old visual nodes, runtime texture path, nearest filtering, integer display scale, particle texture/direction/counts, and immediate entry.
- [ ] Run the full GUT suite; expect Boot Remaster tests to fail against the old scene.
- [ ] Replace the scene with a full-rect dark gradient/vignette background, two preprocessed `GPUParticles2D` layers using `energy_mote.png`, an upper-half dark-gold title, a pixel ground shadow, the centered 4× character, and the hand mote.
- [ ] Replace the animation controller with a typed idle controller that changes only hand-mote alpha and exposes deterministic `seek_idle`.
- [ ] Simplify the animation preview wrapper so it no longer contains a black reveal layer or composition camera transform.
- [ ] Run the full GUT suite; expect all tests to pass.

### Task 3: Runtime visual verification

**Files:**
- Modify: `tools/boot_remaster_preview_runner.gd`
- Modify: `tools/boot_remaster_animation_preview_runner.gd`

**Interfaces:**
- Produces `D:/Game/BoBoZan/boot_remaster_static_preview.png`.
- Produces an idle contact sheet showing fixed composition and changing particles/mote only.

- [ ] Update probes to call `seek_idle` and remove timeline/pointer assertions.
- [ ] Run both preview scenes through `tools/run_godot.ps1 -Mode Probe`.
- [ ] Inspect the static image, idle contact sheet, and transparent corners for old moon/cloud/ribbon remnants, blurred character pixels, poor particle balance, or a floating character.
- [ ] Adjust only approved composition parameters, then rerun probes.
- [ ] Run `diff --check`, full GUT, and final probes; report evidence without committing or pushing.
