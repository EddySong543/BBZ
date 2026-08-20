# Unified Codex Framing Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Present the merged hero/item codex as a reduced open book on a low-saturation smoky-brown backdrop, with the approved long chapter tabs and expandable rarity tabs fully outside the pages.

**Architecture:** Keep `HeroGalleryScreen` and `ItemGalleryScreen` unchanged at their authored 1920x1080 coordinate system. `CodexScreen` owns the full-screen backdrop and a 1920x1080 `GalleryHost` positioned at `(230, 130)` with uniform scale `0.76`; the bookmark layer stays in the unscaled 1920x1080 screen coordinate system. Existing cached galleries, continuous item pagination, rarity signals, close routing, and main-menu entry remain authoritative.

**Tech Stack:** Godot 4.7, GDScript, GUT, lossless PNG UI art, nearest-neighbour canvas rendering.

## Global Constraints

- Use the first preview's low-saturation smoky-brown palette, not the rejected blue-gray or bright clay variants.
- Preserve all hero/item page-relative geometry, page content, selection effects, pagination behavior, and editable scene nodes.
- Preserve the approved left-facing long chapter tab and three expanded rarity-tab silhouettes.
- Keep the book front-facing 2D; no perspective, pseudo-3D, ornaments, props, or pure-black background.
- Keep the main-menu codex entry as the existing battle-UI-style icon-only button.
- Do not touch unrelated dirty worktree files.

---

### Task 1: Add the smoky-brown backdrop asset

**Files:**
- Create: `assets/ui/codex/codex_smoky_brown_backdrop.png`
- Create after import: `assets/ui/codex/codex_smoky_brown_backdrop.png.import`

**Interfaces:**
- Produces: a full-screen-coverable opaque `Texture2D` used by `CodexScreen/Backdrop`.

- [ ] Generate one prop-free 2D pixel-art surface using base `#40372F`, center `#55493C`, and edge `#2D2823` with broad low-contrast texture.
- [ ] Copy the selected generated image into `assets/ui/codex/` without overwriting the approved bookmark assets.
- [ ] Import through `tools/run_godot.ps1 -Mode Import`; confirm lossless/no-mipmap settings and a loadable `Texture2D`.

### Task 2: Reframe the unified codex without changing either page scene

**Files:**
- Modify: `src/ui/codex_screen.tscn`
- Modify: `src/ui/codex_screen.gd`

**Interfaces:**
- Consumes: `GALLERY_SCENES`, `show_section(section: int)`, `select_tier(tier: int)`, and `tier_changed(tier: int)`.
- Produces: `BOOK_ORIGIN := Vector2(230, 130)` and `BOOK_SCALE := Vector2(0.76, 0.76)` as the single framing contract.

- [ ] Add a full-rect mouse-ignoring `TextureRect` backdrop behind `GalleryHost` using `STRETCH_KEEP_ASPECT_COVERED`.
- [ ] Set the authored 1920x1080 `GalleryHost` to position `(230, 130)`, scale `(0.76, 0.76)`, and pivot `(0, 0)`.
- [ ] Keep instantiated galleries at position zero and scale one inside the scaled host so their internal coordinates and state logic remain untouched.
- [ ] Reposition approved chapter tabs against the reduced book's left cover and keep rarity tabs entirely in the exposed backdrop margin.
- [ ] Retain horizontal-only tab interaction, fixed-scale buttons, reverse collapse, state caching, and continuous pagination synchronization.

### Task 3: Lock the framing and navigation contracts

**Files:**
- Modify: `tests/unit/ui/test_screen_compiles.gd`
- Modify: `tools/codex_bookmark_probe.gd`

**Interfaces:**
- Consumes: `CodexScreen.BOOK_ORIGIN`, `CodexScreen.BOOK_SCALE`, and the existing public codex navigation API.
- Produces: automated geometry, backdrop, cache, rarity jump, and transition checks.

- [ ] Replace obsolete full-screen-book assertions with exact host position/scale and transformed 1459.2x820.8 bounds.
- [ ] Assert the backdrop texture path, full-screen cover mode, non-interactive mouse filter, and non-black smoky-brown color data.
- [ ] Assert chapter and rarity tabs remain outside the transformed page area and never use scale animation.
- [ ] Retain tests for tier jumps, continuous page crossing, selected-tab synchronization, cached section state, and main-menu icon-only routing.
- [ ] Run `tools/run_godot.ps1 -Mode Test` and the codex probe; require zero new failures and `CODEX_BOOKMARK_PROBE_OK`.
