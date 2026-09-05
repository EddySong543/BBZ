# Portal Stone Interaction And Warm Fog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute these tasks inline and verify each contract before completion.

**Goal:** Block the four portal cells with readable feedback, turn the stones into a readable expedition-entry indicator, and replace dark expedition fog with animated warm fog.

**Architecture:** Keep pathfinding and keyboard movement in `GridMovementController`; `MainMenuWorld` only supplies walkability and presentation feedback. Store connection level per stone so the ordered state is independent from the shader's continuous energy motion. Keep permanent exploration data unchanged and alter only the terrain overlay's fog rendering.

**Tech Stack:** Godot 4, typed GDScript, CanvasItem shaders, GUT.

## Global Constraints

- Do not generate, read, or save screenshots.
- Preserve the shared main-menu/expedition movement controller.
- Expedition activation lasts exactly 2 seconds and orders stones top-left, top-right, bottom-left, bottom-right.
- Four colored stones mean the expedition entry is ready.
- Unknown expedition space uses animated warm light fog, never a dark shadow.

---

### Task 1: Portal cells and blocking feedback

**Files:**
- Modify: `src/ui/components/main_menu_world.gd`
- Test: `tests/unit/ui/test_main_menu_world.gd`

**Interfaces:**
- Consumes: `GridMovementController.step_attempted` and `_is_main_cell_walkable(cell)`.
- Produces: `_play_portal_blocked_feedback(from_cell, direction, stone_index)` plus visual-contract fields for blocked cells and feedback strength.

- [x] Add a test proving all four stone cells are unwalkable and keyboard collision does not change the logical cell.
- [x] Connect `step_attempted`, reject stone cells in both pathfinding and step commit, and animate a short character lean plus stone recoil/white impact flash.
- [x] Run `tests/unit/ui/test_main_menu_world.gd` and confirm the movement contracts pass.

### Task 2: Four-stone connection state

**Files:**
- Modify: `src/ui/components/main_menu_world.gd`
- Modify: `src/ui/main_menu.gd`
- Modify: `assets/shaders/canvas_ui_portal_stone_energy.gdshader`
- Modify: `tools/main_menu_world_probe.gd`
- Test: `tests/unit/ui/test_main_menu_world.gd`

**Interfaces:**
- Produces: `play_portal_activation(color, duration)`, `begin_portal_search(color)`, `complete_portal_connection(color)`, and `reset_portal_energy()`.
- Shader consumes: `energy_color`, per-stone `energy_mix`, `energy_phase`, `activation_flash`, `impact_flash`, and `anim_time`.

- [x] Replace the old simultaneous-color test with ordered activation and incomplete/complete state tests.
- [x] Set `PORTAL_ACTIVATION_DURATION` to `2.0`; light the four stones in row-major corner order for expedition entry.
- [x] When the expedition entry completes, color all four immediately and emit a short energy surge.
- [x] Upgrade the shader from flat tint to upward energy bands, irregular internal sparkle, a bright core pulse, and activation/impact flashes constrained to the source alpha.
- [x] Run the main-menu unit test and the non-saving world probe.

### Task 3: Animated warm exploration fog

**Files:**
- Modify: `assets/shaders/canvas_ui_expedition_terrain.gdshader`
- Modify: `src/expedition/expedition_screen.gd`
- Test: `tests/unit/ui/test_expedition_pixel_tiles.gd`
- Test: `tests/unit/expedition/test_expedition_fog_reveal.gd`

**Interfaces:**
- Preserves: permanent cleared-cell data and timestamped reveal.
- Produces: `fog_low_color`, `fog_high_color`, and time-driven map-space drift.

- [x] Add assertions that both configured fog colors are warm/light and the shader contains time-driven drift.
- [x] Mix two parchment-white colors with low-frequency moving waves and warm grain while preserving reveal transparency.
- [x] Run the focused expedition tests and then the full GUT suite.
