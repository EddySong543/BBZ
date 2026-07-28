# Scene2 Focus And Motion Polish Implementation Plan

> **For agentic workers:** Implement inline in the current checkout. Do not commit unless Eddy explicitly requests `commit+push`.

**Goal:** Complete Scene2 P1 and P2 by clarifying visual focus and establishing a calmer, staggered motion hierarchy without changing authored geometry, character sprites, UI behavior, or Scene1.

**Architecture:** Reuse the existing Scene2 palette, receiver-light, depth-grade, motion, and particle controls instead of adding another full-screen or per-pixel effect. Tune only Scene2 material instances and particle nodes so shared resources retain their current behavior outside Scene2.

**Tech Stack:** Godot 4.7, GDScript, Godot canvas-item shaders, GPUParticles2D, GUT.

## Global Constraints

- Preserve the bright, saturated peach-blossom sanctuary direction; no global gray wash, blur, or blanket desaturation.
- Preserve Scene2 node positions, sizes, parallax metadata, character pixels, UI, input, and battle behavior.
- Preserve the approved waterfall silhouette and all existing waterfall animation components.
- Keep Scene1 unchanged and verify it at runtime.
- Use semantic parameter relationships in tests; do not freeze manually adjustable element positions.

---

### Task 1: Add semantic P1 and P2 contracts

**Files:**
- Modify: `tests/unit/ui/test_scene2_tyndall.gd`

**Produces:** Tests that require restrained material highlights, foreground-to-background contrast ordering, waterfall-led motion, faster upper cloud drift, and irregular restrained particles.

- [ ] Add a P1 test that checks waterfall foam, ridge brightness, and blossom receiver light remain restrained, and that far mountain contrast remains below mid-mountain contrast.
- [ ] Add a P2 test that compares animation cadence instead of exact positions and checks particle randomness/count budgets.
- [ ] Run the full GUT suite and confirm the new tests fail before implementation.

### Task 2: Implement P1 visual focus routing

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`

**Produces:** A material-only highlight budget with characters and UI remaining the strongest readable elements.

- [ ] Preserve the waterfall top-lip structure while lowering only its authored light and foam palette values.
- [ ] Restrain blossom receiver light and rim strength while retaining the authored pink texture.
- [ ] Move the largest pale ridge planes slightly toward warm atmospheric gray-green through existing grade parameters without changing alpha or edge geometry.
- [ ] Tune far and mid materials so far layers stay lighter and lower contrast than mid layers.

### Task 3: Implement P2 motion hierarchy

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`

**Produces:** Waterfall-led motion, calmer river and distant water, slower staggered cloud breathing, restrained branch movement, and less persistent particles.

- [ ] Keep waterfall cadence unchanged and reduce river/distant-water cadence and highlight density.
- [ ] Preserve the earlier requirement that upper cloud drift is faster than lower cloud drift while reducing synchronized sway and breathing.
- [ ] Lengthen and offset tree and mountain-branch cycles.
- [ ] Reduce particle counts and alpha, narrow the fully visible lifetime window, and randomize emission timing.

### Task 4: Verify runtime and performance

**Files:**
- Test: `tests/unit/ui/test_scene2_tyndall.gd`
- Test: `tests/unit/ui/test_battle_scene_variants.gd`

**Produces:** Fresh evidence that visual changes compile, remain isolated to Scene2, preserve Scene1, and retain the optimized render budget.

- [ ] Run Godot import and inspect logs for shader or parse errors.
- [ ] Run the full GUT suite.
- [ ] Capture Scene2 and Scene1 runtime screenshots and inspect focus, pixel sharpness, and UI separation.
- [ ] Run the Scene2 performance probe and compare draw calls and frame time to the existing baseline.
- [ ] Run `git diff --check` on the touched files.
