# Boot Formal Backdrop Integration Plan

> **For agentic workers:** Execute inline in the current BBZ task. Every task ends with a Godot runtime screenshot.

**Goal:** Replace the Boot remaster's draft-drawn background with project-native night-sky, moon, cloud, and layered-motion techniques.

**Architecture:** Compose a dedicated `BootRemasterBackdrop` scene from independent full-screen layers. Reuse Scene1 and Scene2 shaders without modifying either battle scene, and drive restrained per-layer drift from Boot-only metadata.

**Tech Stack:** Godot 4.7.1, Control nodes, canvas shaders, GDScript, GUT, `tools/run_godot.ps1`.

## Global Constraints

- Keep the production `boot_screen.tscn` unchanged.
- Replace the old draft cloudscape node instead of overlaying it.
- Do not modify Scene1, Scene2, or their shared shader source.
- Keep the existing `4.0`-second Boot reveal and input gate.
- Preserve the giant centered moon and final composition.

---

### Task 1: Formal layered backdrop

- [x] Add separate `Sky`, `Stars`, `MoonHalo`, `Moon`, `CloudBack`, and `CloudFront` nodes.
- [x] Reuse Scene1's night-sky, stars, moon-halo shaders, and moon texture.
- [x] Reuse Scene2 lower-cloud continuous-bank mode on two opposite-flow cloud layers.
- [x] Remove the old procedural block-cloud script from the active preview scene.

### Task 2: Background motion

- [x] Add Boot-only `parallax_factor` values to each background layer.
- [x] Add restrained horizontal idle drift, with front clouds moving farther than the moon.
- [x] Keep cloud shader flow independent from whole-layer drift.
- [x] Preserve the existing moon and cloud reveal controls used by the animation wrapper.

### Task 3: Verification

- [x] Add tests for shared shader paths, Scene1 moon reuse, Scene2 cloud mode, opposite cloud flow, and parallax ordering.
- [x] Capture a static 1920x1080 runtime screenshot.
- [x] Capture the six-frame Boot reveal contact sheet.
- [x] Capture a three-frame runtime contact sheet over four seconds to verify layered drift and cloud flow.
- [ ] Resolve unrelated pre-existing Scene2 test failures before claiming the entire project suite is green.
