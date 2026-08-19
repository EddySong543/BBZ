# Expedition Runtime Realignment Implementation Plan

> **For agentic workers:** Implement each task with precise patches. Preserve unrelated dirty work and do not commit or push unless the user explicitly requests it.

**Goal:** Remove the obsolete expedition monster prototype, implement smooth always-centered map following, and make expedition battles consume the same current combat rules and hero definitions as PvP.

**Architecture:** Keep the 18×14 expedition simulation and current battle scene. Strip concrete legacy monster content while retaining generic encounter seams. Drive map and token rendering from one critically damped visual position over a non-interactive fog padding layer. Pass complete hero identities into one shared battle setup; keep PvE-specific code limited to opponent choice and result routing.

**Tech Stack:** Godot 4.x, typed GDScript, GUT, project-native `tools/run_godot.ps1` probes.

## Global Constraints

- Preserve the already approved 107px Ref37 grid, grass variants, rice foliage, object/marker layers and unrelated expedition visual work.
- Do not modify `BattleCore` or network protocol unless a failing current contract proves it unavoidable.
- Do not replace removed legacy monsters with placeholders.
- Use `apply_patch` for code and documentation edits.

### Task 1: Remove Legacy Monster Runtime

**Files:** `src/expedition/expedition_map_state.gd`, `src/expedition/expedition_screen.gd`, legacy monster data/policy/prototype files, active expedition tests and docs.

- [ ] Stop runtime loading, spawning, wandering, auto-fighting and difficulty scaling of legacy monsters.
- [ ] Remove old monster markers, prompts, probability tells, nest fallbacks and auto-battle UI paths.
- [ ] Delete isolated legacy data/policy/simulation artifacts while preserving generic anchors and encounter/result seams.
- [ ] Replace fixed-monster tests with assertions that normal Qingfeng generation contains no legacy enemies.

### Task 2: Implement Smooth Centered Follow

**Files:** `src/expedition/expedition_screen.gd`, `tests/unit/ui/test_expedition_pixel_tiles.gd`, `tools/expedition_shot_runner.gd`.

- [ ] Replace dead-zone and dual Tween movement with one critically damped visual player position.
- [ ] Derive token and map offsets from the same rounded coordinate so the screen anchor stays fixed.
- [ ] Draw non-interactive fog padding around the logical map to avoid black edges at all four corners.
- [ ] Add semantic motion tests and 1920×1080 time-separated edge/continuous-move captures.

### Task 3: Unify PvE Battle Input and Rules

**Files:** `src/battle/battle_setup.gd`, `src/ui/components/battle_pve.gd`, targeted blocks in `src/ui/battle_screen.gd`, expedition handoff and battle bridge tests.

- [ ] Preserve selected hero identity and load real duplicated `HeroData` for expedition battles.
- [ ] Remove blank-hero construction and legacy monster policy from the PvE adapter.
- [ ] Route PvE opponent choices through current legal actions, action application and resolution.
- [ ] Keep mode-specific code limited to initial HP, result packaging and return to expedition.
- [ ] Add equivalence tests that fail if PvE loses hero identity or bypasses current combat rules again.

### Task 4: Integration and Verification

- [ ] Run Godot Import.
- [ ] Run focused expedition, camera and battle bridge GUT tests.
- [ ] Run the complete GUT suite.
- [ ] Run 1920×1080 expedition and PvE battle probes through `tools/run_godot.ps1` and inspect captures.
- [ ] Report changed scope, evidence, remaining unrelated worktree changes and commit status.
