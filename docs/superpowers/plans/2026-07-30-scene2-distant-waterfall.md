# Scene2 Distant Waterfall Group Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把现有单独远景瀑布替换为一套三层山体承托的远景瀑布组。

**Architecture:** 在 `scene2.tscn` 中增加一个拥有统一视差的 `Node2D` 组合节点，内部按主瀑布顺序放置三座 ridge 与瀑布。山体与水体分别使用独立远景材质，不修改主景资源和交互代码。

**Tech Stack:** Godot 4.7、TextureRect、ColorRect、ShaderMaterial、现有 Scene2 像素 shader。

## Global Constraints

- 保留 `FarMountain2.visible = false`。
- 只修改 Scene2 远景瀑布相关节点、材质和本设计记录。
- 不写死会频繁手调的精确位置测试，以实机截图和语义检查验收。
- 所有 Godot 自动化均通过 `tools/run_godot.ps1`。

---

### Task 1: 替换为远景四件套

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`

**Interfaces:**
- Consumes: `scene2_waterfall_ridge.png`、`canvas_env_scene2_waterfall_mountain_grade.gdshader`、`canvas_env_pixel_waterfall.gdshader`
- Produces: `DistantWaterfallGroup` 及其三座山体和一条瀑布

- [ ] **Step 1:** 保留用户现有 Scene2 参数，只移除上一版独立 `DistantWaterfall` 节点和材质。
- [ ] **Step 2:** 新建三份独立灰蓝远景山体材质，景深由后到前逐层增强。
- [ ] **Step 3:** 用主瀑布三山体的相对坐标建立缩小后的 `DistantWaterfallGroup`。
- [ ] **Step 4:** 把瀑布改为更明确的蓝青色阶、低速和稀疏纹理。

### Task 2: 运行验收

**Files:**
- Verify: `src/ui/scenes/scene2.tscn`

**Interfaces:**
- Consumes: `tools/battle_scene2_shot.tscn`
- Produces: Scene2 运行截图和回归结果

- [ ] **Step 1:** 运行 `& .\tools\run_godot.ps1 -Mode Import`，预期退出码为 0。
- [ ] **Step 2:** 运行 Scene2 截图探针，检查山体承托、遮挡、蓝色辨识度和远近关系。
- [ ] **Step 3:** 仅按截图做必要参数微调，不扩大到主瀑布或其他场景层。
- [ ] **Step 4:** 运行全量 GUT，预期所有测试通过。
- [ ] **Step 5:** 用 `git diff --check` 和精确文件 diff 确认没有覆盖其他改动。
