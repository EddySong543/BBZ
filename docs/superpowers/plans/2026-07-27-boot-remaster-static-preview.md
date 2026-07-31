# Boot Remaster Static Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one separate, runnable 1920×1080 static preview of the approved H01 Boot Screen final frame.

**Architecture:** Preserve the generated PNG as an immutable art source, copy an identical runtime preview asset into the formal UI asset tree, and compose it in a new scene that does not replace `boot_screen.tscn`. A lightweight character-light shader and custom-drawn temporary energy orb provide enough lighting and focal information to judge composition before pixel processing or animation.

**Tech Stack:** Godot 4.7.1, GDScript, Control nodes, canvas-item shader, GUT, windowed screenshot probe.

## Global Constraints

- Keep `res://src/ui/boot_screen.tscn` as the unchanged `project.godot` main scene.
- Use `res://assets/import/boot_character.png` only as the incoming source.
- Preserve an unchanged copy at `res://assets/art_src/ui/boot/boot_h01_master_source.png`.
- Reference only `res://assets/ui/boot/boot_h01_master.png` from the preview scene.
- Render a black background, title behind H01, H01 in front, and the temporary gold orb above H01.
- Do not add the 5.8-second animation, input handling, PixelLab output, particles, or production scene routing in this phase.
- Run Godot only through `tools/run_godot.ps1`.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Promote and verify the approved source image

**Files:**
- Read: `assets/import/boot_character.png`
- Create: `assets/art_src/ui/boot/boot_h01_master_source.png`
- Create: `assets/ui/boot/boot_h01_master.png`
- Create: `tests/unit/ui/test_boot_remaster_preview.gd`

**Interfaces:**
- Consumes: the approved 1024×1536 transparent H01 PNG.
- Produces: one immutable source and one runtime preview texture with identical SHA-256 hashes.

- [ ] Copy the incoming PNG unchanged to both formal paths.
- [ ] Add a GUT contract that checks source existence, dimensions, alpha, and exact runtime scene independence.
- [ ] Run the focused test and confirm it fails before the preview scene exists.

### Task 2: Build the isolated static composition

**Files:**
- Create: `assets/shaders/canvas_boot_character_light_preview.gdshader`
- Create: `src/ui/components/boot_energy_preview.gd`
- Create: `src/ui/boot_screen_remaster_preview.tscn`

**Interfaces:**
- Consumes: `res://assets/ui/boot/boot_h01_master.png`.
- Produces: a full-rect 1920×1080 static composition with named nodes `Backdrop`, `Title`, `Character`, and `Energy`.

- [ ] Add a transparent-safe canvas shader that applies a restrained warm chest light without changing alpha.
- [ ] Add a non-animated `Control` drawer for the temporary orb, downward/lateral guide streams, and restrained glow.
- [ ] Author the preview scene with the title before the character in draw order and the energy after it.
- [ ] Run the focused GUT contract and confirm it passes.

### Task 3: Render and tune the real preview

**Files:**
- Create: `tools/boot_remaster_preview_runner.gd`
- Create: `tools/boot_remaster_preview_runner.tscn`
- Output outside repository: `D:/Game/BoBoZan/boot_remaster_static_preview.png`

**Interfaces:**
- Consumes: `res://src/ui/boot_screen_remaster_preview.tscn`.
- Produces: one real 1920×1080 screenshot and a clean probe exit.

- [ ] Import the new assets with `tools/run_godot.ps1 -Mode Import`.
- [ ] Run the windowed probe with `tools/run_godot.ps1 -Mode Probe`.
- [ ] Inspect the screenshot for title/character/orb hierarchy, transparent edges, crop, and chest placement.
- [ ] Adjust only the preview composition until the screenshot passes.
- [ ] Run the focused test and the screenshot probe again as final evidence.
