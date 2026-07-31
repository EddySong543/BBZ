# Boot Character Layered Idle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: execute this plan task-by-task in the current session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the saved scaled boot character with an exactly positioned layered pixel rig and add a subtle 3.2-second idle loop.

**Architecture:** Generate full-canvas PNG layers from the latest Photoshop source, reconstruct the neutral pose through a reusable character component, and animate only outer hair, fur, and cloth tips in native pixel coordinates. The boot scene keeps all existing input and transition behavior.

**Tech Stack:** Godot 4.7, GDScript image tooling, Sprite2D, AnimationPlayer, nearest-neighbor PNG assets.

## Global Constraints

- Source image is `assets/import/bootchar.png`, `319x171`, with native alpha.
- Preserve saved runtime presentation from position `(374.99994, 32.0)`, size `1052x636`, scale `1.595`.
- Bake the root scale into layout while keeping the visible bounds unchanged.
- The foreground hand, legs, face, and core costume never move.
- Motion is at most one native source pixel per animated layer.
- Do not modify boot input gating or main-menu transition behavior.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Lock the source and presentation baseline

**Files:**
- Replace: `assets/ui/boot/boot_char2.png`
- Modify: `src/ui/boot_screen.tscn`
- Produce: `D:/Game/BoBoZan/boot_character_idle_baseline.png`

**Interfaces:**
- Consumes: saved `Character` Control transform and latest Photoshop PNG.
- Produces: scale-free root layout and a runtime baseline screenshot.

- [x] Copy `assets/import/bootchar.png` over `assets/ui/boot/boot_char2.png`.
- [x] Record the current screenshot with the saved `scale = Vector2(1.595, 1.595)`.
- [x] Bake uniform scale into the Control rectangle:
  - size becomes approximately `(1677.94, 1014.42)`;
  - top-left remains `(374.99994, 32.0)` because the saved pivot is `(0,0)`;
  - root scale becomes `(1,1)`.
- [x] Force Godot import and capture a second screenshot.
- [x] Pixel-compare visible bounds and require no more than one screen-pixel drift.

### Task 2: Generate and verify motion layers

**Files:**
- Create: `tools/prepare_boot_character_idle_layers.gd`
- Create: `assets/ui/boot/character/boot_char_base.png`
- Create: `assets/ui/boot/character/boot_char_hair_left_tips.png`
- Create: `assets/ui/boot/character/boot_char_hair_right_tips.png`
- Create: `assets/ui/boot/character/boot_char_hair_front_tips.png`
- Create: `assets/ui/boot/character/boot_char_fur_right_tips.png`
- Create: `assets/ui/boot/character/boot_char_waist_cloth_tips.png`
- Produce: `D:/Game/BoBoZan/boot_character_layer_atlas.png`

**Interfaces:**
- Consumes: `res://assets/import/bootchar.png`.
- Produces: six aligned `319x171` RGBA textures and a neutral composite verification result.

- [x] Define extraction polygons and smaller exclusive-clear polygons for
  each animated tip layer.
- [x] Copy source pixels inside extraction polygons into each transparent
  layer.
- [x] Clear only exclusive pixels from the base; retain root overlap.
- [x] Save all PNGs losslessly with native alpha.
- [x] Composite base plus all neutral layers in source order.
- [x] Compare every RGBA pixel against the Photoshop source; require
  `changed_pixels=0`.
- [x] Generate a nearest-neighbor enlarged atlas showing each isolated
  layer for visual inspection.

### Task 3: Build the reusable pixel rig

**Files:**
- Create: `src/ui/components/boot_character_idle.tscn`
- Modify: `src/ui/boot_screen.tscn`

**Interfaces:**
- Consumes: the aligned layer textures from Task 2.
- Produces: `BootCharacterIdle` component with native-pixel child positions
  and an autoplaying `idle` animation.

- [x] Create a `Control` root with the baked layout size.
- [x] Add a native-resolution `Node2D` rig positioned at the exact vertical
  centering offset used by `Keep Aspect Centered`.
- [x] Add `Sprite2D` children with `centered=false`, identical origins, and
  nearest filtering.
- [x] Add `AnimationPlayer` and a looping `idle` animation of `3.2` seconds.
- [x] Key hair tips through one-pixel positions with different phases.
- [x] Key fur tips with delayed one-pixel response.
- [x] Key waist cloth one pixel in the opposite phase.
- [x] Use discrete/stepped interpolation and identical first/final keys.
- [x] Replace the old single `TextureRect` in `boot_screen.tscn` with the
  component instance at the preserved top-left position.

### Task 4: Runtime verification

**Files:**
- Modify only if necessary: `tools/boot_shot_runner.gd`
- Produce: `D:/Game/BoBoZan/boot_character_idle_preview.png`
- Produce: `D:/Game/BoBoZan/boot_character_idle_preview.gif`

**Interfaces:**
- Consumes: integrated boot character component.
- Produces: runtime evidence for visual reconstruction, loop quality, and
  existing boot transition behavior.

- [x] Run `tools/run_godot.ps1 -Mode Import` and require exit code `0`.
- [x] Run the boot screenshot probe and require `BOOT_CHAR2_PROBE_OK`.
- [x] Require `BOOT_CHAR2_INPUT_OK: res://src/ui/main_menu.tscn`.
- [x] Capture neutral, left-extreme, and right-extreme animation frames.
- [x] Inspect hair roots, fur roots, waist cloth edges, transparent corners,
  face, fingers, and feet at original pixel scale.
- [x] Capture one complete loop and verify the last-to-first transition has
  no visible jump.
- [x] Run `git diff --check` on the changed scene and tool files.
