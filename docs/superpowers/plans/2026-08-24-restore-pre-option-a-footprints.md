# Restore Pre-Option-A Footprints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline because Eddy explicitly selected the rollback target. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the footprint stream to its exact pre-option-A geometry and rasterization while keeping continuous route motion and changing only the trail color to bright gold-yellow.

**Architecture:** `GridRoutePreview` remains shared by the main menu and expedition. Restore the previously approved two-part forefoot-plus-heel construction, original density and side offsets, and absolute per-vertex pixel rounding. Preserve distance sampling, route-length-dependent count, endpoint fading, and `0.32` cells-per-second continuous motion.

**Tech Stack:** Godot 4.7, statically typed GDScript, `CanvasItem` custom drawing, GUT, image-free runtime probes.

## Global Constraints

- Restore `FOOTPRINT_SPACING_CELLS = 0.34`, `SOLE_LENGTH_CELLS = 0.20`, `SOLE_WIDTH_CELLS = 0.092`, `SIDE_OFFSET_CELLS = 0.082`, and `BASE_OPACITY = 0.72`.
- Keep `STREAM_SPEED_CELLS_PER_SECOND = 0.32` and the full-route continuous footprint stream.
- Restore two parts per footprint: a six-point forefoot and four-point heel.
- Restore direct `point.round()` rasterization and remove `rasterize_sole_parts`.
- Set `TRAIL_COLOR = Color("FFD34E")` as the only new visual choice.
- Remove all option-A and option-B style-contract keys and their plan file.
- Do not add brightness waves, per-foot flashes, arrows, dashes, ribbons, nodes, glow, shadows, textures, shaders, or sprite sheets.
- Do not run, save, read, or return screenshots.
- Do not commit unless Eddy separately requests commit+push.

---

### Task 1: Lock the restored baseline in tests and probes

**Files:**
- Modify: `tests/unit/expedition/test_grid_route_preview.gd`
- Modify: `tools/main_menu_world_probe.gd`
- Modify: `tools/expedition_click_move_probe.gd`

**Interfaces:**
- Consumes: `GridRoutePreview.build_sole_parts(center, direction, length, width)` and `get_style_contract()`.
- Produces: Failing assertions for the original constants, two-part sole, absence of option-A/B rasterization contracts, and bright-gold color.

- [x] **Step 1: Restore the baseline constant and sole assertions**

```gdscript
assert_almost_eq(GridRoutePreviewScript.FOOTPRINT_SPACING_CELLS, 0.34, 0.001)
assert_almost_eq(GridRoutePreviewScript.SOLE_LENGTH_CELLS, 0.20, 0.001)
assert_almost_eq(GridRoutePreviewScript.SOLE_WIDTH_CELLS, 0.092, 0.001)
assert_almost_eq(GridRoutePreviewScript.SIDE_OFFSET_CELLS, 0.082, 0.001)
assert_almost_eq(GridRoutePreviewScript.BASE_OPACITY, 0.72, 0.001)
assert_eq(GridRoutePreviewScript.TRAIL_COLOR, Color("FFD34E"))
assert_eq(parts.size(), 2)
assert_eq(parts[0].size(), 6)
assert_eq(parts[1].size(), 4)
```

- [x] **Step 2: Restore both probe part-count assertions**

```gdscript
if parts.size() != 2 or parts[0].size() != 6 or parts[1].size() != 4:
    failures.append("footprint does not use the forefoot and heel sole")
```

- [x] **Step 3: Run the focused route test and verify option B fails**

Run: `& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/expedition/test_grid_route_preview.gd'`

Expected: FAIL on the option-B constants, single polygon, and style contract.

### Task 2: Restore the pre-option-A implementation

**Files:**
- Modify: `src/expedition/grid_route_preview.gd`
- Test: `tests/unit/expedition/test_grid_route_preview.gd`

**Interfaces:**
- Preserves: `build_stream_footprints`, `build_sole_parts`, `draw_preview`, and `get_style_contract` call signatures.
- Removes: `rasterize_sole_parts` and all option-A/B contract keys.

- [x] **Step 1: Restore the original constants and apply bright gold**

```gdscript
const FOOTPRINT_SPACING_CELLS: float = 0.34
const SOLE_LENGTH_CELLS: float = 0.20
const SOLE_WIDTH_CELLS: float = 0.092
const SIDE_OFFSET_CELLS: float = 0.082
const BASE_OPACITY: float = 0.72
const TRAIL_COLOR := Color("FFD34E")
```

- [x] **Step 2: Restore the original six-point forefoot and four-point heel geometry**

```gdscript
var forefoot_length: float = safe_length * 0.56
var heel_length: float = safe_length * 0.27
var forefoot_center: Vector2 = center + forward * safe_length * 0.22
var heel_center: Vector2 = center - forward * safe_length * 0.36
var forefoot_front: Vector2 = forefoot_center + forward * forefoot_length * 0.5
var forefoot_middle: Vector2 = forefoot_center + forward * forefoot_length * 0.08
var forefoot_back: Vector2 = forefoot_center - forward * forefoot_length * 0.5
var forefoot_half_width: float = safe_width * 0.5
var forefoot := PackedVector2Array([
    forefoot_front + normal * forefoot_half_width * 0.38,
    forefoot_middle + normal * forefoot_half_width,
    forefoot_back + normal * forefoot_half_width * 0.78,
    forefoot_back - normal * forefoot_half_width * 0.78,
    forefoot_middle - normal * forefoot_half_width,
    forefoot_front - normal * forefoot_half_width * 0.38,
])
var heel_half_width: float = safe_width * 0.31
var heel_front: Vector2 = heel_center + forward * heel_length * 0.5
var heel_back: Vector2 = heel_center - forward * heel_length * 0.5
var heel := PackedVector2Array([
    heel_front + normal * heel_half_width,
    heel_back + normal * heel_half_width,
    heel_back - normal * heel_half_width,
    heel_front - normal * heel_half_width,
])
parts.append(forefoot)
parts.append(heel)
```

- [x] **Step 3: Restore direct absolute vertex rounding**

```gdscript
for part: PackedVector2Array in parts:
    var pixel_part := PackedVector2Array()
    for point: Vector2 in part:
        pixel_part.append(point.round())
    canvas.draw_colored_polygon(pixel_part, Color(TRAIL_COLOR, opacity))
```

- [x] **Step 4: Run the focused route test**

Run: `& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/expedition/test_grid_route_preview.gd'`

Expected: all route-preview tests pass.

### Task 3: Verify both shared callers

**Files:**
- Verify: `src/ui/main_menu_world.gd`
- Verify: `src/expedition/expedition_screen.gd`
- Test: `tests/unit/ui/test_main_menu_world.gd`
- Test: `tests/unit/ui/test_expedition_click_move.gd`
- Verify: `tools/main_menu_world_probe.gd`
- Verify: `tools/expedition_click_move_probe.gd`

**Interfaces:**
- Consumes: unchanged `GridRoutePreview.draw_preview(canvas, cells, cell_size, anim_time)`.
- Produces: image-free shared-runtime evidence.

- [x] **Step 1: Run both UI tests and probes**

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/ui/test_main_menu_world.gd'
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/ui/test_expedition_click_move.gd'
& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/main_menu_world_probe.gd'
& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/expedition_click_move_probe.gd'
```

Expected: both GUT targets pass and both probes print their `*_PROBE_OK` markers.

- [x] **Step 2: Audit exact task files**

Run: `git -c safe.directory=$Repo -C $Repo diff --check -- src/expedition/grid_route_preview.gd tests/unit/expedition/test_grid_route_preview.gd tools/main_menu_world_probe.gd tools/expedition_click_move_probe.gd`

Expected: no whitespace errors and no unrelated task changes.
