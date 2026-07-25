# Scene2 New Environment Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Scene2's rejected P1 tree, bridge, and far-mountain stack with the four newly imported environment assets while preserving P0 characters and the default Scene1.

**Architecture:** A fixed Godot headless preparation tool converts the baked white/checkerboard backgrounds to true alpha and crops each source deterministically. Scene2 then references the canonical cleaned assets as four independent `TextureRect` layers with native or integer scaling; runtime tests lock their paths, source sizes, display rectangles, draw order, and parallax metadata.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn`, GUT, PNG Lossless/Nearest import.

## Global Constraints

- Scene2 remains the separate `src/ui/battle_screen2.tscn` composition.
- `src/ui/battle_screen1.tscn` continues to load Scene1.
- Character assets, geometry, animation timing, P0 reflection, and Scene2 character lighting do not change.
- New tree and bridge use uniform integer scaling; new mountains use native 1× size.
- New Far/Mid Mountain layers replace the rejected three-layer `*_px2` far-mountain stack.
- Godot commands run only through `tools/run_godot.ps1`.

---

### Task 1: Lock the new scene contract with a failing test

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: `SCENE2_PATH` and the existing variant-scene instantiation helper.
- Produces: a contract for `FarMountain`, `MidMountain`, `BlossomTree`, and `StoneBridge`.

- [ ] **Step 1: Replace the rejected px2 contract**

Assert these source/display pairs and positions:

```gdscript
var contract := {
	"FarMountain": [
		"res://assets/scenes/scene2/scene2_far_mountain.png",
		Vector2(1608, 508), Vector2(156, 212), Vector2(1608, 508), 0.04],
	"MidMountain": [
		"res://assets/scenes/scene2/scene2_mid_mountain.png",
		Vector2(1672, 752), Vector2(124, 98), Vector2(1672, 752), 0.08],
	"BlossomTree": [
		"res://assets/scenes/scene2/scene2_blossom_tree.png",
		Vector2(208, 125), Vector2(1240, 370), Vector2(624, 375), 0.48],
	"StoneBridge": [
		"res://assets/scenes/scene2/scene2_stone_bridge.png",
		Vector2(262, 64), Vector2(67, 647), Vector2(1834, 448), 1.0],
}
```

Also assert that `FarMountainBack`, `FarMountainMid`, and `FarMountainNear` no longer exist.

- [ ] **Step 2: Update grounding expectations**

Set the expected bridge rectangle to `(67,647)` / `1834×448` and the tree rectangle to `(1240,370)` / `624×375`. Keep all character geometry assertions unchanged.

- [ ] **Step 3: Run the full suite to verify RED**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test
```

Expected: the new Scene2 environment contract fails because the scene still uses the rejected px2 paths and nodes; unrelated tests pass.

### Task 2: Build deterministic cleaned assets

**Files:**
- Create: `tools/prepare_scene2_environment_assets.gd`
- Modify: `assets/scenes/scene2/scene2_blossom_tree.png`
- Modify: `assets/scenes/scene2/scene2_stone_bridge.png`
- Create: `assets/scenes/scene2/scene2_mid_mountain.png`
- Create: `assets/scenes/scene2/scene2_far_mountain.png`

**Interfaces:**
- Consumes: four fixed files under `res://assets/import/`.
- Produces: four true-alpha, cropped PNGs with the exact sizes in Task 1.

- [ ] **Step 1: Implement one fixed preparation tool**

For every source pixel, remove high-luminance low-chroma baked background pixels, crop `Image.get_used_rect()`, save PNG, and fail if the result size differs from the contract. Use luminance/chroma thresholds `0.90/0.06` for tree/bridge and `0.70/0.08` for mountains.

- [ ] **Step 2: Run the tool**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/prepare_scene2_environment_assets.gd'
```

Expected output lists four generated files with sizes `208×125`, `262×64`, `1672×752`, and `1608×508`.

- [ ] **Step 3: Import and inspect**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Import
```

Inspect all four output PNGs for true transparency, complete silhouettes, and no white fringe.

### Task 3: Replace Scene2 nodes and rejected artifacts

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`
- Modify: `tools/normalize_scene2_pixel_assets.py`
- Modify: `assets/scenes/scene2/scene2_px2_manifest.json`
- Delete: rejected Far/Tree/Bridge `*_px2.png` files and their `.import` sidecars

**Interfaces:**
- Consumes: the four cleaned assets from Task 2.
- Produces: an ordered Scene2 layer stack with two new mountain nodes and new tree/bridge bounds.

- [ ] **Step 1: Replace resources and nodes**

Declare the four canonical texture resources. Replace the three old far-mountain nodes with:

```text
FarMountain  rect=(156,212)-(1764,720)  parallax=0.04
MidMountain  rect=(124,98)-(1796,850)   parallax=0.08
```

Both use Nearest and no blur material. Preserve their order before `WaterfallUpper`.

- [ ] **Step 2: Place the new tree and bridge**

Use:

```text
BlossomTree rect=(1240,370)-(1864,745) parallax=0.48
StoneBridge rect=(67,647)-(1901,1095)  parallax=1.0
```

Remove the old tree quiet-zone material from the new tree. Keep the bridge ungraded.

- [ ] **Step 3: Remove rejected generated files**

Delete only the obsolete far/tree/bridge px2 outputs and sidecars. Keep `scene2_mountain_gate_px2.png` and `scene2_mountain_left_px2.png`; reduce the normalization job/manifest to those still-used assets.

- [ ] **Step 4: Run import and full tests**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Import
& .\tools\run_godot.ps1 -Mode Test
```

Expected: all tests pass, including the unchanged Scene1 character contract.

### Task 4: Runtime visual tuning and documentation

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`
- Modify: `assets/scenes/scene2/SPEC.md`

**Interfaces:**
- Consumes: the green structural test baseline.
- Produces: final 1920×1080 runtime composition and documented manual tuning anchors.

- [ ] **Step 1: Capture Scene2**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/battle_scene2_shot.tscn'
```

Inspect bridge contact at both characters, tree grounding and occlusion, mountain valley clearance, white fringe, and water/reflection integration.

- [ ] **Step 2: Tune only environment nodes**

Adjust only integer positions, environment opacity/modulate, or mountain placement. Do not change character nodes. Update tests if the accepted final environment rectangles change.

- [ ] **Step 3: Capture Scene1**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/battle_shot.tscn'
```

Verify the default Scene1 composition and character geometry remain unchanged.

- [ ] **Step 4: Run final verification**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Test
git -c safe.directory='D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization' diff --check
```

Expected: zero test failures and no whitespace errors.
