# 晴风稻田固定地图灰盒 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用固定的 18×14 晴风稻田地形替换旧版 12×12 随机墙地图，并让检修院后侧、收割场后侧成为隐藏探索、始终开放的 1—2 个撤离点。

**Architecture:** 新增只负责固定地形和合法候选点的布局脚本；`expedition_map_state.gd` 只从候选点中抽取本局内容，不再随机生成地形。现有 `expedition_screen.gd` 与地形 shader 改为支持长方形地图，并继续只绘制已进入视野的对象。

**Tech Stack:** Godot 4.x、GDScript、CanvasItem shader、GUT、项目内 `tools/run_godot.ps1`。

## Global Constraints

- 地图结构固定，每局只改变敌人、搜索对象和撤离点的启用组合。
- 本轮只做灰盒，不锁定搜索内容、正式任务、NPC事件或最终美术。
- 每局启用 1—2 个撤离点；候选点固定为检修院后侧与收割场后侧。
- 启用的撤离点从开局起始终开放，但只有进入玩家视野后才显示。
- 不覆盖工作区内英雄、启动界面、Scene4及其他并行任务改动。

---

### Task 1: 固定地图布局数据

**Files:**
- Create: `src/expedition/maps/qingfeng_ricefield_layout.gd`
- Test: `tests/unit/expedition/test_qingfeng_ricefield_layout.gd`

**Interfaces:**
- Produces: `WIDTH`, `HEIGHT`, `START`, `EXIT_CANDIDATES`, `MONSTER_ANCHORS`, `SEARCH_ANCHORS` and `build_grid(wall_tile, floor_tile, start_tile) -> Array`.

- [ ] **Step 1: Write the failing test**

  Test exact dimensions, fixed start, two legal exit candidates, and BFS reachability of both candidates.

- [ ] **Step 2: Run test to verify it fails**

  Run: `& .\tools\run_godot.ps1 -Mode Test -ExtraArgs @('-gtest=res://tests/unit/expedition/test_qingfeng_ricefield_layout.gd')`
  Expected: FAIL because the layout script does not exist.

- [ ] **Step 3: Write minimal implementation**

  Encode the fixed 18×14 walkable/wall silhouette as 14 strings of 18 characters. Keep named content as coordinate metadata rather than baking actors or loot into terrain.

- [ ] **Step 4: Run test to verify it passes**

  Expected: layout dimensions and both routes PASS.

### Task 2: 单局选择与常开撤离

**Files:**
- Modify: `src/expedition/expedition_map_state.gd`
- Modify: `tests/unit/expedition/test_expedition_map.gd`

**Interfaces:**
- Consumes: `QingfengRicefieldLayout` constants and `build_grid`.
- Produces: rectangular `WIDTH`/`HEIGHT`; `ext_pos` containing one or two entries; `ext_open(tile) == true` for every active extraction tile.

- [ ] **Step 1: Replace obsolete tests**

  Remove assertions that lock random walls, three extraction windows, hunger damage, and danger escalation. Add assertions for fixed terrain across seeds, deterministic same-seed content, 1—2 active exits, candidate-only placement, permanent openness, and entry-to-exit reachability.

- [ ] **Step 2: Run tests to verify they fail**

  Expected: FAIL against the old 12×12 random generator.

- [ ] **Step 3: Implement fixed generation**

  Build terrain from the layout; select one or both exit candidates from the seeded RNG; populate only predefined graybox enemy/search anchors; clear stale dictionaries before each setup; stop spawning the obsolete danger wanderer.

- [ ] **Step 4: Run expedition logic tests**

  Expected: all expedition map tests PASS.

### Task 3: 长方形地图渲染与撤离交互

**Files:**
- Modify: `src/expedition/expedition_screen.gd`
- Modify: `assets/shaders/canvas_ui_expedition_terrain.gdshader`
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd` only if its existing square-size assumption fails.

**Interfaces:**
- Consumes: `MapState.WIDTH`, `MapState.HEIGHT`, active `ext_pos` and `revealed`.
- Produces: 18×14 world rendering inside the existing 7×7 camera; discovered extraction arch; direct extraction prompt without time-window state.

- [ ] **Step 1: Add rectangular-size assertions where practical**

  Ensure terrain data image dimensions equal map width/height and the scene parses.

- [ ] **Step 2: Update renderer**

  Replace square loops and `grid_n` with width/height. Keep current pixel block appearance, camera follow, player token, and user-modified layout intact.

- [ ] **Step 3: Simplify extraction presentation**

  Draw an extraction arch only after its cell is revealed; remove extraction numbering and open/closed animation logic; prompt with one always-open action.

- [ ] **Step 4: Run import and targeted tests**

  Run: `& .\tools\run_godot.ps1 -Mode Import`
  Run: `& .\tools\run_godot.ps1 -Mode Test`
  Expected: import succeeds and GUT has zero failures.

### Task 4: 1920×1080 runtime verification

**Files:**
- Modify: `tools/expedition_shot_runner.gd` only if the fixed route requires deterministic movement changes.

- [ ] **Step 1: Run the official probe**

  Run: `& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/expedition_shot_runner.tscn'`
  Expected: runner exits normally and writes 1920×1080 screenshots.

- [ ] **Step 2: Inspect runtime screenshots**

  Confirm 7×7 viewport clipping, camera movement, no map-outside exposure, hidden undiscovered exits, and readable discovered exit tiles.

- [ ] **Step 3: Run final focused diff check**

  Verify only the plan, new layout/test files, and explicitly named expedition files changed for this task. Do not commit or push unless Eddy explicitly requests it.
