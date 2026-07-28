# Scene2 Scene1-Style Particle Reuse Implementation Plan

> **For agentic workers:** Execute inline in the current task; do not delegate or touch unrelated user edits.

**Goal:** Remove Scene2 petals and reuse Scene1's proven four-layer dot-particle construction with Scene2-specific directions and colors.

**Architecture:** Copy Scene1's additive material, 8×8 radial texture, lifetime ramp, four process-material profiles, and four particle nodes into Scene2. Preserve Scene1 density, scale, lifetime, velocity, turbulence, and parallax values; change only particle names, colors, direction vectors, and direction-aligned gravity.

**Tech Stack:** Godot 4.x, `.tscn`, GPUParticles2D, GUT.

## Global Constraints

- Remove every `Petal*` scene node and petal-only subresource from Scene2.
- Do not modify Scene1.
- Do not alter user-authored Scene2 mountains, waterfall, clouds, bridge, UI, characters, positions, or sizes.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Protect the reuse contract

**Files:**
- Modify: `tests/unit/ui/test_battle_scene_variants.gd`

- [ ] Replace petal assertions with a four-layer mapping between Scene2 and Scene1.
- [ ] Assert equivalent amount, lifetime, scale, velocity, turbulence, and radial texture structure.
- [ ] Assert Scene2 changes direction and color while retaining no petal nodes.

### Task 2: Replace petals with Scene1 particle layers

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`

- [ ] Remove the petal atlas reference and petal-only resources.
- [ ] Add Scene1-compatible `PollenFar`, `ValleyDust`, `GroundPollen`, and `PollenNear` process materials.
- [ ] Add four particle nodes using Scene1 values and Scene2 warm peach/pink colors with slight lateral wind.

### Task 3: Verify

**Files:**
- Verify: `src/ui/scenes/scene2.tscn`
- Verify: `tests/unit/ui/test_battle_scene_variants.gd`

- [ ] Run the full GUT suite.
- [ ] Run the Scene2 screenshot probe and inspect the particle field at native resolution.
- [ ] Run `git diff --check` and report without committing.
