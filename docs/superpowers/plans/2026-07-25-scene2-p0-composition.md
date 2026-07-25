# Scene2 P0 Composition Implementation Plan

> **For agentic workers:** Implement this plan task-by-task in the current session. No subagent execution skill is installed in this workspace.

**Goal:** Turn Scene2 into a mature battle composition by protecting editable art from brittle tests, synchronizing the moved waterfall, building a Ref25-style valley funnel, and preserving clear character/UI reading zones.

**Architecture:** Keep `scene2.tscn` as a layered raster battle stage using the existing `BattleStage` contract. Scene geometry remains editor-authored; GUT protects structure, relative layer relationships, synchronization, coverage, and shader behavior rather than mutable absolute coordinates. P0 reuses existing mountain, cloud, waterfall, tree, bridge, and water assets without adding new art.

**Tech Stack:** Godot 4, `.tscn` layered `Control` nodes, CanvasItem shaders, GDScript/GUT, `tools/run_godot.ps1`.

## Global Constraints

- Preserve the user's current `WaterfallLeft` rectangle and do not move either character.
- Do not modify Scene1, shared battle behavior, HUD geometry, or character assets.
- Do not add new raster assets during P0.
- Keep pixel textures on nearest filtering; do not use blur to hide density mismatch.
- Validate the final composition in the full `battle_screen2.tscn`, not only the standalone stage.
- Run Scene1 regression and the full GUT suite before reporting completion.
- Do not commit or push this run unless Eddy explicitly requests it.

---

### Task 1: Replace brittle Scene2 geometry assertions

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: `Scene2` node names, shader resource paths, texture filtering, render order, and `size_px`.
- Produces: tests that tolerate editor-authored positions while still rejecting broken layering, seams, and waterfall desynchronization.

- [ ] **Step 1: Remove mutable absolute geometry assertions**

Remove assertions equivalent to:

```gdscript
assert_eq(waterfall.position, Vector2(-80, -96))
assert_eq(waterfall.size, Vector2(720, 1216))
assert_lte(body_right_edge, 460.0)
assert_gt(right_mountain.position.x, 1500.0)
assert_lt(left_mountain.position.x + left_mountain.size.x * left_mountain.scale.x, 720.0)
```

Do not assert exact positions, display sizes, or scales for mountains, clouds, waterfall, bridge, tree, or distant water.

- [ ] **Step 2: Keep structural and relative contracts**

Use relative assertions:

```gdscript
assert_eq(impact.position, waterfall.position)
assert_eq(impact.size, waterfall.size)
assert_eq(material.get_shader_parameter("size_px"), waterfall.size)
assert_eq(impact_material.get_shader_parameter("size_px"), impact.size)
assert_lt(waterfall.get_index(), upper_cloud.get_index())
assert_lt(distant_water.get_index(), bridge.get_index())
assert_lte(distant_water.position.y, river.position.y)
assert_gte(distant_water.position.y + distant_water.size.y, river.position.y)
assert_gte(river.position.y + river.size.y, 1080.0)
```

Retain stable character geometry assertions because P0 explicitly protects character positions and sizes.

- [ ] **Step 3: Run the full test suite as a red check**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 240
```

Expected: the geometry-lock failures disappear, while waterfall body/impact synchronization still fails until Task 2.

---

### Task 2: Synchronize the moved waterfall system

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`
- Modify: `assets/scenes/scene2/EDITING.md`

**Interfaces:**
- Consumes: the current user-authored `WaterfallLeft` rectangle.
- Produces: identical body/impact rectangles and an editor instruction that both nodes are one logical waterfall.

- [ ] **Step 1: Copy the authored waterfall rectangle to the impact layer**

Set `WaterfallImpactLeft` offsets and its material `size_px` from `WaterfallLeft`:

```ini
[node name="WaterfallImpactLeft" type="ColorRect" parent="."]
offset_left = 388.0
offset_top = -124.0
offset_right = 1108.0
offset_bottom = 1092.0
```

Both waterfall ShaderMaterials must keep:

```ini
shader_parameter/size_px = Vector2(720, 1216)
```

- [ ] **Step 2: Document safe manual movement**

Update `EDITING.md` so moving the waterfall requires multi-selecting `WaterfallLeft` and `WaterfallImpactLeft`, while cloud nodes remain independently art-directed occluders.

- [ ] **Step 3: Run the Scene2 test suite through full GUT**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 240
```

Expected: all Scene2 structural tests pass.

---

### Task 3: Build the Ref25-style valley funnel and battle quiet zones

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`
- Modify: `assets/scenes/scene2/SPEC.md`

**Interfaces:**
- Consumes: existing Far/Mid Mountain, framing mountains, waterfall, two cloud veils, blossom tree, bridge, and water layers.
- Produces: a three-depth composition with characters/bridge as primary reading layer, waterfall as secondary landmark, and blossom as restrained warm accent.

- [ ] **Step 1: Recompose the distant valley**

Adjust only `FarMountain`, `CloudMid`, and `MidMountain` rectangles/modulation so their silhouettes converge toward the waterfall axis around the left-center third. Keep the center-bottom river corridor open and keep all three layers behind `WaterfallLeft`.

- [ ] **Step 2: Re-anchor the cloud veils**

Place `WaterfallCloudUpper` so its opaque cloud mass crosses the waterfall around the upper-middle fall. Place `WaterfallCloudLower` so it hides the lower fall and mountain bases without covering the bridge deck. Preserve native `1521×1019` display size and nearest filtering.

- [ ] **Step 3: Establish battle reading zones**

Use existing layer positions and depth-grade materials to:

```text
P1 zone: light, low-detail cool background
P2 zone: remove the darkest blossom trunk overlap from head/torso/weapon silhouette
HUD zone: lower waterfall/cloud contrast behind reserve portraits and the turn counter
```

Do not move `P1CharDisplay`, `P2CharDisplay`, shadows, HUD controls, or bridge support geometry.

- [ ] **Step 4: Rebalance P0 values**

Keep the following hierarchy in a grayscale thumbnail:

```text
Primary: character silhouettes and bridge deck
Secondary: waterfall core and distant river corridor
Accent: peach blossoms
Support: clouds and far/mid mountains
```

Reduce local saturation/contrast through existing modulation and depth-grade shader parameters. Do not add a global blur or a new post-processing pass.

- [ ] **Step 5: Update the Scene2 spec**

Record the new waterfall axis, cloud occlusion roles, character quiet zones, and the distinction between editor-authored geometry and GUT-protected structural contracts.

---

### Task 4: Runtime visual verification and regression

**Files:**
- Verify: `src/ui/scenes/scene2.tscn`
- Verify: `src/ui/battle_screen2.tscn`
- Verify: `src/ui/battle_screen1.tscn`
- Verify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: final P0 scene and tests.
- Produces: fresh runtime screenshots and complete test evidence.

- [ ] **Step 1: Capture the standalone Scene2**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/scene2_shot_runner.tscn' -TimeoutSeconds 60
```

Inspect both `D:\Game\BoBoZan\scene2_shot_a.png` and `scene2_shot_b.png`.

- [ ] **Step 2: Capture the complete Scene2 battle screen**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/battle_scene2_shot.tscn' -TimeoutSeconds 60
```

Confirm the characters, weapons, top HUD, bridge deck, waterfall, and distant water remain readable.

- [ ] **Step 3: Capture the Scene1 regression**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/battle_shot.tscn' -TimeoutSeconds 60
```

Confirm Scene1 still uses its night sky, moon, rooftop, bamboo, characters, and HUD unchanged.

- [ ] **Step 4: Run final full GUT**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 240
```

Expected: every test passes with no Scene2 position lock.

- [ ] **Step 5: Check the final diff**

Run:

```powershell
git -c safe.directory='D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization' -C 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization' diff --check
git -c safe.directory='D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization' -C 'D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization' status --short
```

Expected: no whitespace errors; only P0 and previously reviewed Scene2 files are modified.
