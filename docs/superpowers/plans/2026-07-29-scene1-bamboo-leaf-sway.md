# Scene1 Bamboo Leaf Sway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan task-by-task in the current session.

**Goal:** Add sparse local leaf sway to the two Scene1 foreground bamboos.

**Architecture:** Generate two-channel source-resolution masks and hinge
underpaint with a reproducible Godot tool. Use one focused shader that composes
the two moving groups and then applies the existing night foliage grade.

**Tech Stack:** Godot 4.7, GDScript image tools and tests, canvas-item shader.

## Global Constraints

- Do not move bamboo culms, branches, roots, or unselected leaves.
- Preserve all existing Scene1 node geometry and parallax.
- Keep nearest-neighbor sampling and stepped animation.
- Verify actual runtime frames, not source structure alone.

---

### Task 1: Motion Assets

- [ ] Add `tools/prepare_scene1_bamboo_leaf_sway.gd`.
- [ ] Generate left/right leaf masks and hinge underpaint textures.
- [ ] Inspect selected-pixel counts and source-resolution previews.

### Task 2: Leaf Shader And Scene Materials

- [ ] Add `canvas_env_scene1_bamboo_leaf_sway.gdshader`.
- [ ] Replace only the two foreground bamboo materials.
- [ ] Preserve the current night grade and use different phase offsets.

### Task 3: Contract And Runtime Verification

- [ ] Extend Scene1 bamboo tests with mask, underpaint, and motion limits.
- [ ] Add an isolated three-frame bamboo probe.
- [ ] Run import, full tests, runtime screenshots, and static-pixel diff.
