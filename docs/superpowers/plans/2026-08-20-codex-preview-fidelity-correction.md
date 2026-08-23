# Codex Preview Fidelity Correction Implementation Plan

> **For agentic workers:** Execute inline in the current BBZ workspace; preserve unrelated dirty-worktree changes and use `tools/run_godot.ps1` for every Godot run.

**Goal:** Make the unified codex reproduce the approved side-tab states and book/background proportions, while adding restrained motion only to the smoky-brown backdrop.

**Architecture:** Keep hero and item galleries authored at 1920x1080 and scale only `GalleryHost`. Replace scripted paper simulation with four external ImageGen idle/selected sources followed only by chroma cleanup, hard-alpha reduction, and integer scaling. Keep the static smoky-brown texture shader-free and place the faint procedural motion on a separate transparent layer so material failure cannot black out the background.

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

- [ ] Set `GalleryHost` to scale 0.84 at `(210, 86)`, preserving side-tab space while restoring text readability.
- [ ] Give each bookmark separate idle and selected art nodes and preserve one click target.
- [ ] Switch state art in `_set_bookmark_state()` while retaining short press/hover motion.
- [ ] Keep `Backdrop` static and shader-free; apply slow procedural warm-veil motion only to `BackdropMotion`.

### Task 3: Guard runtime contracts

**Files:**
- Modify: `tests/unit/ui/test_screen_compiles.gd`
- Modify: `tools/codex_bookmark_probe.gd`

- [ ] Assert 0.84 framing, generated separate state textures, selected/idle visible bounds, static background fallback, and motion-overlay parameters.
- [ ] Run the full GUT suite and the non-saving codex bookmark probe.
- [ ] Run `git diff --check` and report without committing.
