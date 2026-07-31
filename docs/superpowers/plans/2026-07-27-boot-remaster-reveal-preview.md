# Boot Remaster Reveal Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline in the current task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a separate 4.0-second Boot remaster reveal preview that reaches the approved giant-moon static frame, locks input during the reveal, and holds an animated idle frame afterward.

**Architecture:** Instantiate `boot_screen_remaster_preview.tscn` inside a new full-screen animation wrapper. A typed controller drives zoom, opacity, ribbon growth, and the interaction gate without changing the production `boot_screen.tscn`; a windowed probe captures six runtime checkpoints into a contact sheet.

**Tech Stack:** Godot 4.7.1, GDScript, Control nodes, custom 2D drawing, GUT, `tools/run_godot.ps1`.

## Global Constraints

- Keep `res://src/ui/boot_screen.tscn` as the unchanged production main scene.
- Keep `res://src/ui/boot_screen_remaster_preview.tscn` as the editable approved final-frame composition.
- Use exactly `4.0` seconds for camera motion and reveal.
- Block entry interaction before `4.0` seconds; unlock only after the final frame settles.
- Reveal ribbons by growing their geometry from the orb; do not fade ribbon opacity.
- Do not add production scene routing, hair deformation, audio, or skip behavior in this phase.
- Launch Godot only through `tools/run_godot.ps1`.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Add the reveal-preview contract

**Files:**
- Modify: `tests/unit/ui/test_boot_remaster_preview.gd`
- Create: `src/ui/boot_screen_remaster_animation_preview.tscn`
- Create: `src/ui/boot_screen_remaster_animation_preview.gd`

**Interfaces:**
- Consumes: `res://src/ui/boot_screen_remaster_preview.tscn`.
- Produces: `seek_preview(seconds: float)`, `restart_preview()`, and `can_enter() -> bool`.

- [ ] Add a GUT test that loads the animation preview and asserts `show_duration == 4.0`.
- [ ] Assert `can_enter()` is false after `seek_preview(3.99)`.
- [ ] Assert `can_enter()` is true after `seek_preview(4.0)`.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 180` and confirm the missing preview fails the new contract.

### Task 2: Implement the 4.0-second reveal

**Files:**
- Create: `src/ui/boot_screen_remaster_animation_preview.gd`
- Create: `src/ui/boot_screen_remaster_animation_preview.tscn`

**Interfaces:**
- Consumes: child nodes `Composition/Backdrop`, `Composition/Title`, `Composition/Character`, `Composition/EnergyBack`, and `Composition/Energy`.
- Produces: deterministic timeline state for any timestamp from `0.0` through `4.0`.

- [ ] Start with a black full-screen background, composition zoom `3.35`, and the energy orb centered on screen.
- [ ] Reveal the orb during `0.0–1.0`, the zoomed hands and torso during `0.5–3.0`, and thin ribbon overflow after `2.0`.
- [ ] Run a slow zoom from `3.6` to `3.1` before `1.90`.
- [ ] Push in from `3.1` to `3.25` during `1.90–2.05` as anticipation.
- [ ] Run the fast pullback from `3.25` to `1.0` during `2.05–2.90`; never scale below the viewport-covering final composition.
- [ ] Reveal the sky/cloud background during `1.95–3.05`.
- [ ] Bring the moon in by scaling it from `0.34` and moving it upward during `2.05–2.90`, without a moon opacity fade.
- [ ] Bring the three title glyphs in from left, top, and right during `2.12–3.20`, with staggered back-ease settle and no title opacity fade.
- [ ] Set the interaction gate true only when elapsed time reaches `4.0`.

### Task 3: Add restrained energy idle motion

**Files:**
- Modify: `src/ui/components/boot_energy_preview.gd`
- Modify: `src/ui/boot_screen_remaster_animation_preview.gd`

**Interfaces:**
- Consumes: `flow_phase: float` on both energy layers.
- Produces: continuous low-amplitude ribbon undulation with no camera movement after `5.8`.

- [ ] Export `flow_phase` with a redraw setter.
- [ ] Apply at most four pixels of normal-direction sway inside `_ribbon_polygon()`.
- [ ] Advance the phase slowly during the reveal and continue it after the final frame.
- [ ] Keep `Composition.scale == Vector2.ONE` and `Composition.position == Vector2.ZERO` after `4.0`.

### Task 4: Capture and verify the timeline

**Files:**
- Create: `tools/boot_remaster_animation_preview_runner.gd`
- Create: `tools/boot_remaster_animation_preview_runner.tscn`
- Output outside repository: `D:/Game/BoBoZan/boot_remaster_animation_contact_sheet.png`

**Interfaces:**
- Consumes: `seek_preview(seconds)` at `0.15`, `0.75`, `1.95`, `2.35`, `2.9`, and `4.0`.
- Produces: one 2304×216 six-frame contact sheet and a clean probe exit.

- [ ] Capture the six exact checkpoints at `0.15`, `0.75`, `1.95`, `2.35`, `2.9`, and `4.0` from the windowed viewport.
- [ ] Resize each checkpoint to `384×216` with nearest-neighbor interpolation and place them left-to-right.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 180`.
- [ ] Run `& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/boot_remaster_animation_preview_runner.tscn' -TimeoutSeconds 120`.
- [ ] Inspect the contact sheet for black opening, progressive hand reveal, slow zoom, fast pullback, balanced ribbons, moon/cloud reveal, and final static camera.
