# Scene1 Bamboo Decoration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the two imported bamboo assets as crisp, night-graded Scene1 side decorations without affecting Scene2 or shared battle behavior.

**Architecture:** Move the source PNGs from the transient import directory into Scene1's environment asset directory, reference them from two independent `TextureRect` layers, and share one focused foliage-grade shader. Scene1 owns all placement and parallax data.

**Tech Stack:** Godot 4.7.1, `.tscn`, canvas_item shader, GUT, Lossless PNG import.

## Global Constraints

- Never reference `assets/import` from a production scene.
- Preserve source pixels; use integer `2×` display scaling and Nearest filtering.
- Modify Scene1 only; Scene2, character geometry, UI and battle behavior remain unchanged.
- Run Godot only through `tools/run_godot.ps1`.

---

### Task 1: Lock the bamboo scene contract

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

**Interfaces:**
- Consumes: `SCENE1_PATH`
- Produces: assertions for `BambooLeft`, `BambooRight`, formal asset paths, sizes, order and parallax.

- [ ] Add a test that loads Scene1 and asserts both bamboo nodes use `scene1_bamboo_left.png` / `scene1_bamboo_right.png`, preserve `128×256` / `64×256` source sizes, display at `256×512` / `128×512`, use parallax `1.25`, and render between `LightShaft` and `closeRf1`.
- [ ] Run the full GUT suite and confirm the new test fails before the nodes exist.

### Task 2: Move assets and implement the night foliage grade

**Files:**
- Move: `assets/import/left bamboo.png` → `assets/scenes/scene1/scene1_bamboo_left.png`
- Move: `assets/import/right bamboo.png` → `assets/scenes/scene1/scene1_bamboo_right.png`
- Create: `assets/shaders/canvas_env_night_foliage.gdshader`

**Interfaces:**
- Consumes: source RGBA PNG pixels.
- Produces: two formal Scene1 textures and one non-animated canvas shader.

- [ ] Move and rename both PNGs without resampling.
- [ ] Add a shader that preserves alpha, computes luminance, reduces saturation, multiplies brightness, and blends toward an indigo night tint.
- [ ] Run Godot import and verify both `.import` sidecars are Lossless with mipmaps disabled.

### Task 3: Compose and verify

**Files:**
- Modify: `src/ui/scenes/scene1.tscn`
- Modify: `assets/scenes/scene1/SPEC.md`

**Interfaces:**
- Consumes: formal bamboo textures and foliage shader.
- Produces: Scene1-only side decoration layers.

- [ ] Add `BambooLeft` and `BambooRight` after `LightShaft`, with integer sizes, edge-framing positions, local materials and `parallax_factor = 1.25`.
- [ ] Update the Scene1 layer specification.
- [ ] Run complete GUT, `git diff --check`, Scene1 screenshot and one Scene2 regression screenshot.
- [ ] Inspect only the two bamboo edges, character silhouettes, bottom grounding and Scene2 non-regression.
