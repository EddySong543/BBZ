# Shared Grid Gait And Portal Beam Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute inline with test-first checkpoints and image-free verification.

**Goal:** Make keyboard and click movement share a bounded continuous gait, turn toward blocked stones, replace mode-entry wave transitions with a nine-cell portal beam, and temporarily enlarge the expedition viewport.

**Architecture:** `GridMovementController` remains the sole movement scheduler for the hub and expedition. It commits only one active step plus one buffered keyboard step, and chains straight route segments just before the old target settles. `MainMenuWorld` owns portal obstruction and the 3×3 beam presentation; `main_menu.gd` performs a direct scene change only after the beam peaks.

**Tech Stack:** Godot 4, typed GDScript, CanvasItem shaders, GUT.

## Global Constraints

- Do not generate, read, or save screenshots.
- Preserve one shared movement implementation for main menu and expedition.
- The four stone cells remain unwalkable and a blocked horizontal attempt must update facing.
- Four fully colored stones remain the sole connected state.
- The portal beam footprint is exactly the center 3×3 cells.
- The interim expedition viewport is 19×11 complete cells with an exact centered 3×3; future work will align it to the hub count.

---

### Task 1: Shared bounded gait

**Files:**
- Modify: `src/expedition/grid_movement_controller.gd`
- Modify: `src/expedition/expedition_screen.gd`
- Test: `tests/unit/expedition/test_grid_movement_controller.gd`
- Test: `tests/unit/ui/test_main_menu_world.gd`

**Interfaces:**
- Produces: one buffered keyboard direction and `CHAIN_PROGRESS`-based straight-step continuation.
- Preserves: `request_keyboard_step(direction) -> String`, `request_path(destination) -> bool`, and movement signals.

- [x] Replace immediate multi-cell keyboard settlement tests with one-active-plus-one-buffer contracts.
- [x] Add a blocked-facing test and a route test proving the next straight cell commits before a full stop.
- [x] Implement bounded keyboard buffering, direction-aware route chaining, and blocked horizontal facing.
- [x] Run shared-controller and main-menu movement contracts.

### Task 2: Connected flicker and nine-cell beam

**Files:**
- Create: `assets/shaders/canvas_ui_portal_beam.gdshader`
- Modify: `assets/shaders/canvas_ui_portal_stone_energy.gdshader`
- Modify: `src/ui/components/main_menu_world.gd`
- Modify: `src/ui/main_menu.gd`
- Modify: `tools/main_menu_world_probe.gd`
- Test: `tests/unit/ui/test_main_menu_world.gd`

**Interfaces:**
- Produces: `play_portal_beam(color, duration)` and a beam node whose world rect equals the center 3×3.
- Stone shader produces: asynchronous `connected_flicker` while `energy_mix == 1.0`.

- [x] Add beam geometry, dynamic-connected-state, and old-transition-removal assertions.
- [x] Add visible irregular connected flicker without changing connection state.
- [x] Build a bottom-to-top pixel energy column and animate it only after all four stones connect.
- [x] Directly change to PVE/BP at beam peak instead of calling `TransitionManager.transition_to`.
- [x] Run the non-saving main-menu probe.

### Task 3: Interim expedition viewport

**Files:**
- Modify: `src/expedition/expedition_screen.gd`
- Test: `tests/unit/ui/test_expedition_pixel_tiles.gd`

**Interfaces:**
- Produces: `MAP_VIEW_COLS = 19`, `MAP_VIEW_ROWS = 11`, `MAP_RENDER_SCALE = 0.8`, and centered origin `(48, 12)`.

- [x] Replace the 13×7 geometry contract with a complete 19×11 contract.
- [x] Assert both counts exceed the hub's 15×9 and remain odd so the center 3×3 is exact.
- [x] Run expedition geometry and full-project tests.
