# Expedition Scheme A Dynamic Visibility Implementation Plan

> **For agentic workers:** Execute this plan inline and verify each task before continuing.

**Goal:** Adopt Scheme A with dynamic tile-shaped soft visibility, then apply the approved larger-framing revision so the grid and character no longer read too small.

**Architecture:** The 32×18 logical map remains the gameplay source of truth. The screen renders it at 0.6 scale with a clamped follow camera, while the shader samples the newly updated logical visibility texture through an offset derived from separate logical and visual vision centers.

**Tech Stack:** Godot 4, GDScript, CanvasItem shader, GUT, 1920×1080 screenshot probe.

## Global Constraints

- Preserve the approved Scheme A composition: 15 visible rows, about 26.67 visible columns, and a 72px on-screen character canvas.
- Gameplay visibility updates immediately; only the fog presentation interpolates.
- The soft edge follows tile boundaries and must not pulse or imply a changing sight radius.
- Preserve unrelated uncommitted workspace changes; do not reset, stash, or commit.

---

### Task 1: Lock the Scheme A viewport contract

**Files:**
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd`
- Modify: `src/expedition/expedition_screen.gd`

**Interfaces:**
- Consumes: `MAP_CELL`, `MAP_VIEW_SIZE`, existing camera clamp helpers.
- Produces: `MAP_RENDER_SCALE = 0.6`, `TOKEN_RENDER_COMPENSATION = 1.25`, 15-row clamped camera framing.

- [x] Update the viewport and camera tests to require 15 visible rows, 26.67 visible columns, a 72px token, and real-map edge clamps.
- [x] Run the focused GUT contract and confirm the old 0.5-scale implementation fails.
- [x] Change the screen constants and comments to the approved Scheme A values.
- [x] Re-run the focused tests and confirm the viewport contract passes.

### Task 2: Separate logical and visual visibility centers

**Files:**
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd`
- Modify: `assets/shaders/canvas_ui_expedition_terrain.gdshader`
- Modify: `src/expedition/expedition_screen.gd`

**Interfaces:**
- Consumes: `map.visible`, `_camera_visual_token_origin`, `vision_center_cell`.
- Produces: shader uniform `vision_logic_center_cell`; shifted mask sampling through `mask_position = grid_position + vision_logic_center_cell - vision_center_cell`.

- [x] Add a test proving the logical center jumps to the destination while the visual center starts at the previous position and converges monotonically.
- [x] Run the focused GUT contract and confirm the missing logical-center contract fails.
- [x] Write the logical center during terrain-data refresh and offset shader sampling by the visual/logical center delta.
- [x] Increase only the outer feather to 0.28 cell so complete visible cells remain fully lit.
- [x] Re-run the focused tests and confirm the dynamic visibility contract passes.

### Task 3: Runtime visual verification

**Files:**
- Reuse: `tools/expedition_density_visibility_preview.tscn`
- Create only if needed: `tools/expedition_dynamic_visibility_probe.gd`
- Create only if needed: `tools/expedition_dynamic_visibility_probe.tscn`

**Interfaces:**
- Consumes: formal expedition scene and Scheme A constants.
- Produces: 1920×1080 Scheme A screenshot and start/mid/end visibility-center evidence.

- [x] Run the scoped expedition tests through `tools/run_godot.ps1`.
- [x] Run a 1920×1080 probe and inspect the camera center, map edges, character size, and tile-following soft fog edge.
- [x] Run the full suite and distinguish any pre-existing unrelated failure from this task.
- [x] Review the exact diff and report without committing.

## Verification Record

- Expedition pixel/map/UI contract: 40/40 passed.
- Full suite: 920/921 passed; the only failure is the pre-existing unrelated Scene6 red-valley lighting tolerance at `tests/unit/ui/test_scene6_framework.gd:440`.
- Dynamic probe centers: `(15.5, 9.5)` visual vs `(16.5, 9.5)` logical immediately after the move, `(15.93333, 9.5)` mid-step, and exact convergence at `(16.5, 9.5)`.

### Task 4: Larger-framing revision

**Files:**
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd`
- Modify: `src/expedition/expedition_screen.gd`
- Reuse: `tools/expedition_dynamic_visibility_probe.tscn`

**Interfaces:**
- Consumes: the completed dynamic-visibility shader and real-map camera clamp.
- Produces: `MAP_RENDER_SCALE = 0.75`, `TOKEN_RENDER_COMPENSATION = 4.0 / 3.0`, a 12-row / 21.33-column viewport, 90px cells, and a 96px character canvas.

- [x] Change the viewport contract tests from 15 rows / 26.67 columns / 72px character to 12 rows / 21.33 columns / 96px character.
- [x] Run the full GUT command and confirm the old scale fails the revised contract.
- [x] Update only the formal framing constants and camera-edge expectations; retain the dynamic mask and 32×18 logical map.
- [x] Run the 1920×1080 dynamic probe and inspect the enlarged formal framing.
- [x] Run the full suite, review the scoped diff, and report without committing.

**Revision verification:** Expedition visual contracts 40/40 passed. Full suite 920/921 passed with only the unrelated existing Scene6 lighting-tolerance failure. The probe confirms 90px cells, a 96px character canvas, and the visual visibility center still converging from `15.5` through `15.93333` to the logical target `16.5`.

### Task 5: Complete grid bounds and character presentation controls

**Files:**
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd`
- Modify: `src/expedition/expedition_screen.gd`
- Reuse: `tools/expedition_dynamic_visibility_probe.tscn`

**Interfaces:**
- Produces: a centered 19×11 complete-cell viewport with 98px cells, authored-idle-only standing behavior, a pixel foot shadow, and `TestControls/NextHeroButton`.

- [x] Write failing contracts for complete outer cells, no stationary code rotation, foot-shadow geometry, and map-preserving character cycling.
- [x] Replace the fractional 21.33×12 framing with an odd 19×11 grid so the central character cell and all four outer boundaries settle on complete cells.
- [x] Remove `_token_idle_rotation_at`; keep movement hop/turn behavior and authored idle frame playback.
- [x] Draw a two-step coarse-pixel contact shadow below the token without restoring the rejected four-corner marker.
- [x] Add a screen-space `测试·下个角色` button that changes only the displayed idle art.
- [x] Verify at 1920×1080 and run the full suite.

**Task 5 verification:** Expedition visual contracts 41/41 passed. Full suite 921/922 passed with only the unrelated existing Scene6 lighting-tolerance failure. The settled 1920×1080 probe shows complete cells on all four sides.
