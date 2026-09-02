# H19 Arc Energy Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace H19's worm-like shared ribbon phases with inward arc gathering, a coreless tapered arc wave, and a two-fragment impact split.

**Architecture:** Keep `DamageTransferTrail` as the single drawing component and preserve the existing battle event order. Give gathering, travel, and impact separate deterministic draw paths, then let `battle_screen.gd` drive a short `impact_progress` phase alongside the existing reserve-avatar hit feedback.

**Tech Stack:** Godot 4 GDScript, `Control._draw()`, deterministic Tween playback, GUT.

## Global Constraints

- Preserve H19 damage settlement, damage-number timing, reserve-avatar red flash, and damped shake.
- Preserve the approved curved route and black/burgundy palette.
- Do not add particles, powder, random offsets, antialiasing, screenshots, or new raster assets.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Lock the three-phase visual contract

**Files:**
- Modify: `tests/unit/ui/test_battle_resolution_bubble.gd`

**Interfaces:**
- Consumes: `DamageTransferTrail.configure()`, `gather_progress`, `progress`, `impact_progress`.
- Produces: regression assertions for inward gathering, no full-length core, tapered wave profile, and two impact fragments.

- [x] **Step 1: Replace the old shared-ribbon assertions with the three-phase contract.**
- [x] **Step 2: Run `tools/run_godot.ps1` against the UI test and confirm it fails before implementation.**

### Task 2: Rebuild the H19 drawing phases

**Files:**
- Modify: `src/ui/components/damage_transfer_trail.gd`

**Interfaces:**
- Consumes: source and target points from `configure(from_point, to_point)`.
- Produces: `impact_progress: float`, inward source arcs, a coreless wave with a sharp head and tail, and two deterministic impact fragments.

- [x] **Step 1: Draw gathering as three concentric broken arcs collapsing toward the source.**
- [x] **Step 2: Remove alternating tail slivers and the full-length center core from travel.**
- [x] **Step 3: Use a width profile that peaks before the head and then sharpens again.**
- [x] **Step 4: Draw two outward-splitting curved fragments during `impact_progress`.**

### Task 3: Drive impact without changing settlement order

**Files:**
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/unit/ui/test_battle_resolution_bubble.gd`

**Interfaces:**
- Consumes: completed H19 travel tweens and `DamageTransferTrail.impact_progress`.
- Produces: simultaneous impact split plus existing reserve hit feedback, followed by cleanup.

- [x] **Step 1: Add a tunable `h19_transfer_impact_duration` defaulting to `0.14`.**
- [x] **Step 2: Start impact splitting only after travel reaches the target, at the same moment as the existing reserve hit.**
- [x] **Step 3: Await impact completion before freeing trails; do not move damage or Buff settlement earlier.**

### Task 4: Verify regressions

**Files:**
- Verify: `src/ui/components/damage_transfer_trail.gd`
- Verify: `src/ui/battle_screen.gd`
- Verify: `tests/unit/ui/test_battle_resolution_bubble.gd`

- [x] **Step 1: Run the complete battle-resolution UI test.**
- [x] **Step 2: Run the dark-hero battle test.**
- [x] **Step 3: Run `git diff --check` for the touched tracked files and inspect the exact diff.**
