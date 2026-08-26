# Continuous Footprint Route Stream Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline because the user already selected the design and explicitly requested implementation. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace cell-filled footprint pairs with an alternating footprint stream that covers the full hovered route and continuously travels toward the destination.

**Architecture:** `GridRoutePreview` remains the only route-visual implementation shared by the main menu and expedition. It converts grid-cell centers into a compact rounded polyline, derives an even footprint count from route length and target spacing, moves every footprint forward with cyclic distance sampling, and draws each footprint as a procedural forefoot-plus-heel sole without textures, shadows, glow cores, arrows, dashes, nodes, or ribbons.

**Tech Stack:** Godot 4.7, statically typed GDScript, `CanvasItem` custom drawing, GUT, existing image-free runtime probes.

## Global Constraints

- Main menu and expedition must continue to call the same `GridRoutePreview.draw_preview` implementation.
- Cover the full route at a maximum target spacing of 0.34 cells; footprint count increases with route length and has no fixed cap.
- Footprints continuously translate toward the destination and rotate from the sampled route tangent.
- Alternate left and right lateral offsets at constant distance spacing.
- Use uniform base opacity plus endpoint fading; do not flash footprints individually.
- Move at 0.32 cells per second, slower than the rejected 0.55-cells-per-second version.
- Do not use screenshots, external textures, shaders, sprite sheets, arrows, chevrons, dashes, nodes, ribbons, or inset edge bars.
- Do not commit unless Eddy separately requests commit+push.

---

### Task 1: Specify the full-route moving footprint stream

**Files:**
- Modify: `tests/unit/expedition/test_grid_route_preview.gd`

**Interfaces:**
- Consumes: `GridRoutePreview.build_stream_footprints(cells: Array[Vector2i], cell_size: float, anim_time: float) -> Array[Dictionary]`
- Produces: Regression coverage for route-length-dependent count, full-route coverage, slower continuous distance movement, left/right alternation, smooth turn tangents, two-part soles, and the rejected-family contract.

- [x] **Step 1: Replace the per-cell-pair assertions with full-route stream assertions**

```gdscript
var footprints := GridRoutePreviewScript.build_stream_footprints(cells, 120.0, 0.0)
assert_true(bool(contract["covers_full_route"]))
assert_true(bool(contract["count_scales_with_route_length"]))
assert_false(bool(contract["uses_footprint_count_cap"]))
assert_true(bool(contract["moves_continuously_forward"]))
assert_false(bool(contract["lights_individual_footprints"]))
```

- [x] **Step 2: Run the focused test and verify the old implementation fails**

Run: `& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/expedition/test_grid_route_preview.gd'`

Expected: FAIL because `build_stream_footprints` and the continuous-stream contract do not exist.

### Task 2: Implement distance-sampled continuous footprints

**Files:**
- Modify: `src/expedition/grid_route_preview.gd`
- Test: `tests/unit/expedition/test_grid_route_preview.gd`

**Interfaces:**
- Produces: `build_route_curve`, `sample_curve`, `build_stream_footprints`, `build_sole_parts`, `draw_preview`, and `get_style_contract`.
- Preserves: `draw_preview(canvas: CanvasItem, cells: Array[Vector2i], cell_size: float, anim_time: float) -> void` for both existing callers.

- [x] **Step 1: Build a compact rounded route curve from cell centers**

```gdscript
static func build_route_curve(cells: Array[Vector2i], cell_size: float) -> PackedVector2Array:
    # Preserve straight segments and insert compact quadratic samples around 90-degree turns.
```

- [x] **Step 2: Sample evenly spaced footprints across the complete route**

```gdscript
var footprint_count := ceili(total_length / target_spacing)
var actual_spacing := total_length / float(footprint_count)
for stream_index in footprint_count:
    var distance := fposmod(float(stream_index) * actual_spacing + phase, total_length)
    # Sample position/tangent and alternate lateral offset.
```

- [x] **Step 3: Draw only a forefoot and heel for each sampled footprint**

```gdscript
for part: PackedVector2Array in footprint["parts"]:
    canvas.draw_colored_polygon(part, Color(TRAIL_COLOR, footprint["opacity"]))
```

- [x] **Step 4: Run the focused test and verify it passes**

Run: `& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/expedition/test_grid_route_preview.gd'`

Expected: all route-preview tests pass.

### Task 3: Update shared-call contracts and runtime probes

**Files:**
- Modify: `tests/unit/ui/test_main_menu_world.gd`
- Modify: `tools/main_menu_world_probe.gd`
- Modify: `tools/expedition_click_move_probe.gd`

**Interfaces:**
- Consumes: `GridRoutePreview.get_style_contract()` and `build_stream_footprints`.
- Produces: Image-free evidence that both screens receive hover paths and generate the same continuously moving stream.

- [x] **Step 1: Replace old per-cell and sequential-light assertions**

```gdscript
assert_eq(contract["implementation"], "full_route_alternating_footprint_stream")
assert_true(bool(contract["covers_full_route"]))
assert_true(bool(contract["count_scales_with_route_length"]))
assert_false(bool(contract["uses_fixed_visible_count"]))
assert_true(bool(contract["moves_continuously_forward"]))
assert_false(bool(contract["uses_footprint_count_cap"]))
```

- [x] **Step 2: Run focused UI tests and both tool probes**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/ui/test_main_menu_world.gd'
& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/ui/test_expedition_click_move.gd'
& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/main_menu_world_probe.gd'
& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/expedition_click_move_probe.gd'
```

Expected: all GUT tests pass and logs contain `MAIN_MENU_PROBE_OK` and `EXPEDITION_CLICK_MOVE_PROBE_OK`.

- [x] **Step 3: Audit scope and formatting**

Run: `git diff --check -- <the exact files above>` and search the route files for the removed per-cell-pair contract.

Expected: no whitespace errors and no active runtime reference to per-cell footprint filling.
