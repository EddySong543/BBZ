# Left Codex Tabs Redesign Implementation Plan

> **For agentic workers:** Execute inline in the current BBZ workspace; preserve unrelated dirty-worktree changes and use `tools/run_godot.ps1` for all Godot runs.

**Goal:** Replace the rejected right-facing codex tabs with tactile left-edge inserted tabs and make the main-menu codex entry exactly reuse the battle codex button visual.

**Architecture:** Keep `codex_screen` as the full-screen cached wrapper. Replace only its bookmark assets, bookmark scene geometry, and state animation; add a focused reusable builder for the battle-style main-menu button without changing battle runtime behavior.

**Tech Stack:** Godot 4.7, GDScript, Control/Button/TextureRect, ShaderMaterial, Tween, transparent PNG, GUT.

## Global Constraints

- The 1920×1080 book and both gallery internal layouts remain unchanged.
- Main tabs point left: embedded edge on the right, exposed edge on the left.
- No scale bounce, glow, gold flash, pseudo-3D, western ornament, or soft alpha fringe.
- Existing unrelated workspace changes are preserved; no commit or push without an explicit request.

---

### Task 1: Lock the rejected behavior with tests

**Files:**
- Modify: `tests/unit/ui/test_screen_compiles.gd`
- Modify: `tests/unit/ui/test_main_menu_world.gd`

- [ ] Assert the main-menu codex button is 108×108, textless, and contains the 64×64 battle codex icon plus matching jelly shader parameters.
- [ ] Assert tab embedded/right edge is square, exposed/left corners are transparent, selected X is less than idle X, and rarity tabs form one compact subordinate group.
- [ ] Run full GUT and retain the expected RED evidence.

### Task 2: Produce left-facing art assets

**Files:**
- Create: `assets/ui/codex/bookmark_chapter_left.png`
- Create: `assets/ui/codex/bookmark_rarity_left.png`
- Create: `assets/ui/codex/bookmarks_left.prompt.txt`
- Create or modify: `tools/prepare_codex_bookmarks.py`

- [ ] Generate separate transparent source art for chapter and rarity tabs with the right edge explicitly defined as the insertion edge.
- [ ] Quantize, harden alpha, lock logical pixels, and upscale by an exact integer with the preparation script.
- [ ] Run Godot Import and verify Lossless, mipmaps off, nearest sampling, transparent exposed corners, and opaque square insertion edge.

### Task 3: Rebuild the bookmark hierarchy and motion

**Files:**
- Modify: `src/ui/codex_screen.tscn`
- Modify: `src/ui/codex_screen.gd`

- [ ] Replace asset references and establish selected/idle/pressed X constants where selected is farther left.
- [ ] Track and kill per-button Tweens before creating a cubic ease-out pull/retract animation.
- [ ] Make rarity bookmarks expand from behind Item with compact spacing and short sequential delays; reverse the motion when leaving Item.
- [ ] Preserve current section caching, direct rarity jumps, and continuous bottom pagination sync.

### Task 4: Reuse the battle codex button in the main menu

**Files:**
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/main_menu.tscn`

- [ ] Remove codex text, long navigation plate, and left text margin.
- [ ] Set the codex button to 108×108 and build the same jelly background, 64×64 book icon, ButtonJuice, and bottom shadow recipe used by battle UI.
- [ ] Keep Shop and all other main-menu behavior unchanged.

### Task 5: Verify the complete integration

**Files:**
- Modify: `tools/codex_bookmark_probe.gd`

- [ ] Run `tools/run_godot.ps1 -Mode Import`.
- [ ] Run the full GUT suite and require `All tests passed!`.
- [ ] Run the non-saving 1920×1080 codex probe and require full-screen, cache, rarity-jump, and animation-terminal markers.
- [ ] Run `git diff --check` on the precise task files and report remaining unrelated changes separately.
