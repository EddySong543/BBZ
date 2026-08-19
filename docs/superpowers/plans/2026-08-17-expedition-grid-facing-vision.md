# Expedition Grid, Facing, and Vision Implementation Plan

> **For agentic workers:** Execute inline in the current task; do not delegate because `expedition_screen.gd` contains overlapping uncommitted visual work.

**Goal:** Increase the visible grid density while preserving the current character screen size, add animated left/right facing, and replace the circular fog edge with a stable cell-aligned irregular near-square.

**Architecture:** Keep the 120px world cell and 96px normalized idle token so approved assets are untouched. Render the world at 0.5 scale for an exact 32x18 screen grid, counter-scale only the player token to preserve its existing 72px screen canvas, and express facing through a foot-pivoted squeeze/lean transition. Use one deterministic near-square visibility predicate in map logic and a matching row/column-jittered box distance in the terrain shader.

**Tech Stack:** Godot 4, typed GDScript, canvas-item shader, GUT.

## Global Constraints

- Preserve existing terrain textures, pixel-rounded cell mask, narrow gaps, and character idle SpriteFrames.
- Do not add 2px/3px character resampling.
- Do not restore the four-corner player-cell marker.
- Keep all motion pixel-snapped and all fog irregularity stable between frames.
- Do not commit or touch unrelated dirty-worktree files.

---

### Task 1: Lock the new visual contracts

**Files:**
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd`
- Modify: `tests/unit/expedition/test_expedition_map.gd`

- [ ] Assert a 32x18 visible grid, a 72px rendered token canvas, animated horizontal facing, and near-square visibility extents.
- [ ] Run the scoped tests and confirm the old implementation fails those assertions.

### Task 2: Implement grid density and animated facing

**Files:**
- Modify: `src/expedition/expedition_screen.gd`

- [ ] Set the world render scale to 0.5 and counter-scale the player token to a 72px screen canvas.
- [ ] Track last horizontal facing and animate a foot-pivoted squeeze, one logical-pixel lean, sign switch, and rebound during a horizontal step.
- [ ] Keep vertical steps facing the last horizontal direction.

### Task 3: Implement the cell-aligned irregular vision shape

**Files:**
- Modify: `src/expedition/expedition_map_state.gd`
- Modify: `assets/shaders/canvas_ui_expedition_terrain.gdshader`
- Modify: `src/expedition/expedition_screen.gd`

- [ ] Replace circular visibility with a stable 13x9 near-square whose row and column edges vary by one cell.
- [ ] Match the shader boundary to the same deterministic row/column pattern and feather only the outer one-cell band.

### Task 4: Verify runtime behavior

**Files:**
- Modify only if required by verified regressions: the scoped files above.

- [ ] Run scoped GUT tests.
- [ ] Run the complete GUT suite.
- [ ] Run the 1920x1080 expedition motion probe, capture idle and left/right movement frames, and inspect the fog contour and character scale.
