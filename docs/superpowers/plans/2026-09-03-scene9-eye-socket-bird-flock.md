# Scene9 Eye-Socket Bird Flock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan task-by-task with TDD and fresh verification.

**Goal:** Replace the rejected Scene9 eye glow with a repeatable flock of small but readable pixel birds flying from the left mountain eye socket into the cloud bank.

**Architecture:** A Scene9-only `Control` draws eight birds from one three-frame hard-pixel strip. The existing stage keeps its validated environment-click probability gate and calls the new flock API.

**Tech Stack:** Godot 4.7, typed GDScript, GUT, generated raster master plus deterministic pixel reduction.

## Global Constraints

- Preserve all manually tuned Scene9 transforms and every non-easter-egg behavior.
- Use `tools/run_godot.ps1` for every Godot invocation.
- Use no screenshots, particle systems, blur, glow, or non-integer source-pixel positions. The accepted ending uses a one-second smooth opacity envelope while every bird continues moving.
- Do not commit or push without a separate user request.

---

### Task 1: Canonical bird asset and three-frame strip

**Files:**
- Create: `assets/scenes/scene9/source/scene9_distant_bird_master_generated.png`
- Create: `assets/scenes/scene9/scene9_distant_bird_strip.png`
- Create: `tools/generate_scene9_distant_bird_strip.gd`

**Interfaces:**
- Produces: a 15×3 RGBA strip with three 5×3 hard-alpha frames.

- [x] Save the generated master under the ignored Scene9 source directory.
- [x] Add a deterministic Godot builder containing the approved two-color pixel masks.
- [x] Run the builder and assert dimensions, alpha, palette size, and per-frame silhouette coverage.

### Task 2: Flock runtime and trigger replacement

**Files:**
- Create: `src/ui/components/scene9_eye_socket_bird_flock.gd`
- Modify: `src/ui/components/scene9_battle_stage.gd`
- Modify: `src/ui/scenes/scene9.tscn`
- Delete: `src/ui/components/scene9_eye_socket_glow.gd`

**Interfaces:**
- Produces: `start_flock() -> bool`, `is_active() -> bool`, `advance_for_testing(delta: float) -> void`, and `visual_contract_snapshot() -> Dictionary`.
- Consumes: the existing validated grass/cloud click and 12% repeatable probability gate.

- [x] Replace the eye-glow test contract with a failing flock contract.
- [x] Verify the new test fails before implementation.
- [x] Add the integer-grid flight simulation, three-frame wing cycle, diagonal up-right arc, and batched drawing.
- [x] Remove the rejected mountain-alpha/socket masking path; draw intact birds after the mountain and keep them moving through the final one-second fade.
- [x] Replace the Scene9 node and stage target without touching other scene composition.
- [x] Remove the rejected glow runtime file after all references are gone.

### Task 3: Verification

**Files:**
- Test: `tests/unit/ui/test_scene9_eye_socket_bird_flock.gd`
- Test: all `tests/unit/ui/test_scene9_*.gd`

- [x] Run the focused bird-flock test and inspect assertion counts.
- [x] Run all Scene9 tests through `tools/run_godot.ps1`.
- [x] Run Godot import and inspect asset/reference errors.
- [x] Verify task-scoped status and confirm no old eye-glow reference remains.
