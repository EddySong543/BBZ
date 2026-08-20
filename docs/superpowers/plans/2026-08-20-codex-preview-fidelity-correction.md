# Codex Preview Fidelity Correction Implementation Plan

> **For agentic workers:** Execute inline in the current BBZ workspace; preserve unrelated dirty-worktree changes and use `tools/run_godot.ps1` for every Godot run.

**Goal:** Make the unified codex reproduce the approved side-tab states and book/background proportions, while adding restrained motion only to the smoky-brown backdrop.

**Architecture:** Keep hero and item galleries authored at 1920x1080 and scale only `GalleryHost`. Replace the single stretched bookmark texture with deterministic idle/selected state textures derived from the approved generated paper source. Animate the background in a dedicated canvas shader that retains a fixed sharp base and mixes a very faint, manually interpolated moving texture layer.

**Tech Stack:** Godot 4 Control UI, GDScript, canvas_item shader, Pillow asset reduction, GUT.

## Global Constraints

- The approved preview is the visual source of truth for silhouette, texture, state contrast, relative scale, and orientation.
- Do not reflow hero or item page contents.
- Keep all tab assets true-pixel, hard-alpha, lossless, mipmap-free, and nearest-filtered.
- Background motion must not move or soften the book, side tabs, or page content.

---

### Task 1: Rebuild bookmark state assets

**Files:**
- Modify: `tools/prepare_codex_bookmarks.py`
- Create: `assets/ui/codex/bookmark_chapter_idle.png`
- Create: `assets/ui/codex/bookmark_chapter_selected.png`
- Create: `assets/ui/codex/bookmark_rarity_idle.png`
- Create: `assets/ui/codex/bookmark_rarity_selected.png`

- [ ] Generate distinct idle/selected canvases whose visible bounds match the approved preview.
- [ ] Preserve source paper luminance and add only hard pixel borders, restrained flecks, insertion edge, and hard shadow.
- [ ] Import through `tools/run_godot.ps1 -Mode Import` and verify lossless/no-mipmap settings.

### Task 2: Correct framing and background motion

**Files:**
- Create: `assets/shaders/canvas_ui_codex_backdrop_motion.gdshader`
- Modify: `src/ui/codex_screen.tscn`
- Modify: `src/ui/codex_screen.gd`

- [ ] Set `GalleryHost` to a centered 0.76 scale, leaving the approved amount of warm background visible.
- [ ] Give each bookmark separate idle and selected art nodes and preserve one click target.
- [ ] Switch state art in `_set_bookmark_state()` while retaining short press/hover motion.
- [ ] Apply slow subpixel-interpolated drift and low-amplitude center breathing only to `Backdrop`.

### Task 3: Guard runtime contracts

**Files:**
- Modify: `tests/unit/ui/test_screen_compiles.gd`
- Modify: `tools/codex_bookmark_probe.gd`

- [ ] Assert 0.76 framing, separate state textures, selected/idle visible bounds, and motion shader parameters.
- [ ] Run the full GUT suite and the non-saving codex bookmark probe.
- [ ] Run `git diff --check` and report without committing.
