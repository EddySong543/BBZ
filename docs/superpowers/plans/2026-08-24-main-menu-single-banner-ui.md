# Main Menu Single Banner UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline; do not delegate because the shared worktree contains unrelated active changes.

**Goal:** Replace the two bottom mode squares with one 344×108 banner button plus a 72×72 switch, then place codex, online battle, backpack, and a warehouse placeholder at the requested screen edges.

**Architecture:** `main_menu.tscn` owns fixed 1920×1080 geometry. `main_menu.gd` owns one `PrimaryMode` state and swaps the sole banner texture without instantiating two visible mode entries. Existing match, expedition, portal, backpack, and codex flows remain intact.

**Tech Stack:** Godot 4.7, GDScript, TextureRect, Button, GUT.

## Global Constraints

- Banner button height is exactly `108px`, matching the existing square dock buttons.
- Banner textures preserve their complete original aspect ratio; no crop, NinePatch, tiling, or internal recomposition.
- Only one banner is visible at any time.
- No warehouse page, warehouse art, warehouse final icon, or portal beam changes in this plan.
- No screenshots; validate with node geometry, resource paths, state transitions, and headless probes.

---

### Task 1: Asset intake and RED layout contract

**Files:**
- Move: `assets/import/battle banner.png` → `assets/ui/main_menu/battle_banner.png`
- Move: `assets/import/explore banner.png` → `assets/ui/main_menu/expedition_banner.png`
- Move/update: both `.import` sidecars
- Modify: `tests/unit/ui/test_main_menu_world.gd`
- Modify: `tools/main_menu_world_probe.gd`

**Interfaces:**
- Produces: `res://assets/ui/main_menu/battle_banner.png`
- Produces: `res://assets/ui/main_menu/expedition_banner.png`

- [ ] Replace the two-square assertions with a single `UI/ModeBanner` contract at `Rect2(788, 916, 344, 108)` and a `UI/ModeSwitch` contract at `Rect2(1156, 934, 72, 72)`.
- [ ] Assert `UI/ModeMatch` and `UI/ModeTower` no longer exist.
- [ ] Assert `ModeBanner/Banner` initially uses `battle_banner.png`, one switch press changes it to `expedition_banner.png`, and no second banner node exists.
- [ ] Assert `NavHeroes=(48,916)`, `NavBackpack=(1640,916)`, `NavWarehouse=(1772,916)`, and `NetLobbyButton=(1652,108)`.
- [ ] Run `./tools/run_godot.ps1 -Mode Test -Target res://tests/unit/ui/test_main_menu_world.gd -TimeoutSeconds 180`; expect the old scene to fail the new node contract.

### Task 2: Implement the single active mode banner

**Files:**
- Modify: `src/ui/main_menu.tscn`
- Modify: `src/ui/main_menu.gd`

**Interfaces:**
- Produces: `enum PrimaryMode { MATCH, EXPEDITION }`
- Produces: `_on_mode_banner_pressed() -> void`
- Produces: `_on_mode_switch_pressed() -> void`
- Produces: `_refresh_mode_banner() -> void`

- [ ] Replace `ModeMatch` and `ModeTower` with `ModeBanner` and `ModeSwitch` using the exact Task 1 geometry.
- [ ] Add `NavWarehouse`, move the other three requested entries, and move the runtime-created online button below Settings.
- [ ] Preload both banner textures and the existing static `switch.png`; initialize `PrimaryMode.MATCH`.
- [ ] Build one aspect-preserving `Banner` TextureRect plus a texture-shaped shadow under `ModeBanner`; do not use a rectangular background fill.
- [ ] Route banner presses to the existing match or expedition handlers based on `PrimaryMode`, and disable switching during search/portal activation.
- [ ] Configure `NavWarehouse` with the existing potion glyph strictly as a temporary placeholder and only play click feedback; do not create warehouse behavior.

### Task 3: GREEN verification

**Files:**
- Verify: `src/ui/main_menu.tscn`
- Verify: `src/ui/main_menu.gd`
- Verify: `tests/unit/ui/test_main_menu_world.gd`
- Verify: `tools/main_menu_world_probe.gd`

- [ ] Run the focused main-menu GUT and require all tests to pass.
- [ ] Run `./tools/run_godot.ps1 -Mode Tool -Target res://tools/main_menu_world_probe.gd -TimeoutSeconds 120` and require exit code 0.
- [ ] Run `./tools/run_godot.ps1 -Mode Import -TimeoutSeconds 120` and require exit code 0.
- [ ] Run `git diff --check` on the tracked task files and verify the import inbox no longer contains the two integrated banners.
