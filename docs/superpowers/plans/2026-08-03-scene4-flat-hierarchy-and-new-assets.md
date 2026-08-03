# Scene4 Flat Hierarchy and New Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扁平化 Scene4 场景树，接入正式天空、第二背景树和顶部垂叶，并移除深绿色程序化天空。

**Architecture:** Scene4 的每个实际美术节点直接挂在 BattleStage 根节点下，并在节点自身保存 `parallax_factor`。天空使用一张正式纹理和一个只负责低饱和调色的 Scene4 Shader；不新增 Slot 或第二套视差实现。

**Tech Stack:** Godot 4.7、`.tscn`、CanvasItem Shader、GUT、`tools/run_godot.ps1`

## Global Constraints

- 只移动 `sky.png`、`bgtree2.png`、`leaves.png` 及其对应 sidecar。
- 不修改 `assets/import` 中任何其他文件。
- 不改 Scene1–3、`battle_screen_base.tscn` 或成熟 UI/人物/交互。
- 保留 Eddy 已手调的四张现有 Scene4 素材变换。
- 不提交、不推送；用户本轮未要求 commit+push。

---

### Task 1: 锁定扁平层级契约

**Files:**
- Modify: `tests/unit/ui/test_scene4_framework.gd`

**Interfaces:**
- Consumes: `BattleStage` 根直属节点通过 `metadata/parallax_factor` 参与视差。
- Produces: Scene4 扁平节点、正式素材路径和无 Slot 的自动化契约。

- [ ] **Step 1: 将 Slot 测试改为实际节点测试**

要求根直属节点依次包含 `Sky`、两棵背景树、微尘、平台、左右近景和 `TopLeaves`，
并断言场景中不存在名称以 `Slot` 结尾的节点。

- [ ] **Step 2: 添加三张新正式素材断言**

断言天空、第二背景树和顶部垂叶指向 `assets/scenes/scene4/` 下的新名称，并继续使用
最近邻过滤与忽略鼠标。

- [ ] **Step 3: 运行全量 GUT 建立失败基线**

Run: `& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 240`

Expected: Scene4 新扁平层级断言失败；记录与本任务无关的既有失败。

### Task 2: 正式化三张导入素材

**Files:**
- Move: `assets/import/sky.png` → `assets/scenes/scene4/scene4_sky.png`
- Move: `assets/import/bgtree2.png` → `assets/scenes/scene4/scene4_background_tree_2.png`
- Move: `assets/import/leaves.png` → `assets/scenes/scene4/scene4_top_leaves.png`

**Interfaces:**
- Consumes: 用户提供的三张透明/像素素材。
- Produces: Scene4 稳定正式路径和 Godot 生成的 `.import` sidecar。

- [ ] **Step 1: 验证源文件与目标路径**

确认三个源 PNG 存在、三个目标 PNG 不存在，并记录解析后的绝对路径。

- [ ] **Step 2: 只移动三个 PNG 和对应 sidecar**

使用 PowerShell `Move-Item -LiteralPath` 精确移动，不使用通配符。

- [ ] **Step 3: 运行 Godot Import**

Run: `& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 240`

Expected: 三个正式路径生成有效导入信息，其他 `assets/import` 文件不变。

### Task 3: 扁平化 Scene4 并替换天空

**Files:**
- Create: `assets/shaders/canvas_env_scene4_sky_grade.gdshader`
- Delete: `assets/shaders/canvas_env_scene4_canopy_sky.gdshader`
- Modify: `src/ui/scenes/scene4.tscn`
- Modify: `src/ui/battle_screen4.tscn`

**Interfaces:**
- Consumes: 三张新正式纹理和现有 BattleStage metadata 视差接口。
- Produces: 无 Slot、可直接手调、拥有正式天空的 Scene4。

- [ ] **Step 1: 新建低饱和天空调色 Shader**

Shader 读取 `TEXTURE`，保留源图明度和水平分层，将颜色映射到鼠尾草灰、雾蓝绿和
浅灰绿，不生成程序化噪声或深墨绿色。

- [ ] **Step 2: 删除所有 Slot 并提升实际节点**

将现有节点的 offset、scale、texture 和 unique_id 原样保留，只修改 parent 和
`parallax_factor` 所在位置。

- [ ] **Step 3: 接入新节点**

添加全屏 `Sky`、右侧 `BackgroundTree2` 和画面顶缘 `TopLeaves`，全部最近邻且
`mouse_filter = Control.MOUSE_FILTER_IGNORE`。

- [ ] **Step 4: 中性化 Scene4 PostFX**

降低绿色 tint、split tone 和绿色暗角，保留亮度、对比度、冲击帧参数及角色专属光照。

### Task 4: 验证和回归

**Files:**
- Verify: `src/ui/scenes/scene4.tscn`
- Verify: `src/ui/battle_screen4.tscn`
- Verify: `tests/unit/ui/test_scene4_framework.gd`
- Modify: `tools/scene4_framework_probe.gd`

**Interfaces:**
- Consumes: 扁平 Scene4 完整实现。
- Produces: 自动化与实机证据。

- [ ] **Step 1: 运行 Godot Import**

Run: `& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 240`

- [ ] **Step 2: 运行全量 GUT**

Run: `& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 240`

Expected: Scene4 专项全部通过；仅允许记录已确认与本任务无关的失败。

- [ ] **Step 3: 运行 Scene4 截图与视差探针**

先把探针的平台路径从 `PlatformSlot` 改为扁平节点 `BattlePlatform`，再运行：

Run: `& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/scene4_framework_probe.tscn' -TimeoutSeconds 180`

Expected: 输出中心/右移截图，`platform_delta` 与 `world_delta` 同步误差为 `0.0`。

- [ ] **Step 4: 检查工作区边界**

确认 Scene1–3、基础 Battle Screen 和其余 `assets/import` 文件没有本任务改动，并
执行 `git diff --check`。
