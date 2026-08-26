# Effect Codex Single-Column Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the overlapping two-column effect index with a seven-row single-column directory and rebuild the right page as the same stable detail axis and footer navigation used by the hero and item codex pages.

**Architecture:** Keep `EffectCatalog` and the existing external icon paths unchanged. Scene files own all editable geometry; `effect_gallery_screen.gd` only binds catalog data, selection, hover preview, and previous/next navigation. Tests verify non-overlap, page hierarchy, and navigation behavior without screenshots.

**Tech Stack:** Godot 4.7.2, GDScript, `.tscn`, GUT 9.6.0.

## Global Constraints

- Reuse the approved codex book, fonts, semantic colors, and native text layer.
- Add no visual assets and do not modify the seven imported effect icons.
- The left page is a single column of seven icon-and-name rows.
- The right page order is name, large icon, divider, centered description, footer navigation.
- Do not commit or push unless Eddy explicitly requests it.

---

### Task 1: Lock the single-column and detail contracts

**Files:**
- Modify: `tests/unit/ui/test_effect_gallery.gd`

**Interfaces:**
- Consumes: `EffectGalleryScreen.select_effect(effect_id: StringName) -> void`
- Produces: geometry and navigation regression assertions for the final scene contract

- [ ] **Step 1: Add a failing layout test**

Assert that all seven `EffectList` children share one horizontal span, appear in increasing Y order without intersecting, and preserve their expected labels.

- [ ] **Step 2: Add a failing detail-navigation test**

Assert that `DetailNavigation` starts at `01 / 07`, disables Previous, enables Next, and selects `true_damage` after Next is pressed.

- [ ] **Step 3: Run the focused test before implementation**

Run: `& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/ui/test_effect_gallery.gd'`

Expected: FAIL because the current layout uses two columns and has no `DetailNavigation`.

### Task 2: Rebuild scene geometry and bind navigation

**Files:**
- Modify: `src/ui/components/effect_gallery_entry.tscn`
- Modify: `src/ui/effect_gallery_screen.tscn`
- Modify: `src/ui/effect_gallery_screen.gd`
- Test: `tests/unit/ui/test_effect_gallery.gd`

**Interfaces:**
- Consumes: `EffectCatalog.all() -> Array[Dictionary]`
- Produces: `_turn_detail(step: int) -> void` and `_refresh_detail_navigation() -> void`

- [ ] **Step 1: Convert the entry component to a compact directory row**

Use a fixed row height, a left icon slot, a full-width name area, and a selected paper/bar treatment that remains inside the row bounds.

- [ ] **Step 2: Place seven rows in one column**

Give every entry the same left/right offsets and a constant vertical step with no rectangle intersection.

- [ ] **Step 3: Reorder the right-page hierarchy**

Place `EffectName` at the item-page title position, enlarge `EffectIcon`, place `Rule` beneath it, center the description block, and add the item/hero-style footer navigation.

- [ ] **Step 4: Bind previous/next navigation**

Connect both buttons, clamp at the first and last effects, refresh `NN / 07`, and keep left-directory selection synchronized.

- [ ] **Step 5: Run the focused test**

Run: `& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/ui/test_effect_gallery.gd'`

Expected: 5 tests pass with the expanded layout/navigation assertions.

- [ ] **Step 6: Run the image-free codex probe**

Run: `& .\tools\run_godot.ps1 -Mode Tool -Target 'res://tools/codex_effect_gallery_probe.gd'`

Expected: `CODEX_EFFECT_PROBE_OK` with seven entries and a complete native text layer.
