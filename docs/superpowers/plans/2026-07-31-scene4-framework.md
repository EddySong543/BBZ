# Scene4 空场景框架实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建独立可运行、等待 Eddy 导入素材的 Scene4 空场景骨架。

**Architecture:** Scene4 只提供 BattleStage 分层插槽和基线标记；完整战斗入口直接
继承共享 Battle Screen，因此 UI、人物和交互不复制、不改写。

**Tech Stack:** Godot 4.7.1、GDScript、GUT。

## Global Constraints

- 不设计 Scene4 主题，不生成场景美术；只接入 Eddy 明确提供的正式素材副本。
- Scene4 素材由 Eddy 后续在 Godot 中导入。
- 不修改 Scene1–3 入口和共享战斗行为。
- 不 commit 或 push，除非 Eddy 明确要求。

---

### Task 1: 空舞台层级

**Files:**
- Create: `src/ui/scenes/scene4.tscn`
- Create: `assets/scenes/scene4/README.md`

- [ ] 创建七个 TextureRect 插槽容器，设置最近邻采样和远近视差。
- [ ] 设置 `PlatformSlot.parallax_factor = 1.0` 作为人物同步地面。
- [ ] 创建三个不可见 Marker2D，记录 P1、P2 和平台基线。
- [ ] 添加一层中性 PreviewBackdrop，仅服务空框架可视验证。

### Task 2: 共享 UI 与人物入口

**Files:**
- Create: `src/ui/battle_screen4.tscn`

- [ ] 直接实例化 `battle_screen_base.tscn`。
- [ ] 在 `StageSlot` 静态挂接 `scene4.tscn`。
- [ ] 开启成熟鼠标视差，关闭 standalone 点击震屏。
- [ ] 保留共享人物尺寸、站位、动画、UI 和交互。

### Task 2.1: 接入 Eddy 提供的 Scene4 素材

**Files:**
- Modify: `src/ui/scenes/scene4.tscn`
- Modify: `assets/scenes/scene4/README.md`

- [ ] 将 `bgtree` 的正式副本接入 `FarBackdropSlot`。
- [ ] 将 `middletreeplatform` 的正式副本接入 `PlatformSlot`。
- [ ] 将 `lefttree` 与 `righttree` 的正式副本接入 `ForegroundSlot`。
- [ ] 保持 `assets/import` 中 Scene4 原文件不变，场景不得直接引用暂存区。

### Task 3: 框架测试

**Files:**
- Create: `tests/unit/ui/test_scene4_framework.gd`

- [ ] 验证 Scene4 和 BattleScreen4 独立资源存在。
- [ ] 验证七个插槽顺序正确且视差从远到近递增。
- [ ] 验证四张树木素材只引用 `assets/scenes/scene4` 正式副本。
- [ ] 验证 BattleScreen4 的人物与 UI 来自共享基础场景。
- [ ] 验证 Scene4 不引用 Shader 或 `assets/import/`。

### Task 4: 真实运行探针

**Files:**
- Create: `tools/scene4_framework_probe.gd`
- Create: `tools/scene4_framework_probe.tscn`

- [ ] 窗口运行 BattleScreen4 并保存中心与右侧指针截图。
- [ ] 检查 UI、人物、按钮和中性背景真实可见。
- [ ] 比较 PlatformSlot 与 WorldGroup 位移，要求同步误差 `0.0`。

### Task 5: 完整验证

- [ ] 运行 `& .\tools\run_godot.ps1 -Mode Import`。
- [ ] 运行 `& .\tools\run_godot.ps1 -Mode Test`。
- [ ] 运行 `& .\tools\run_godot.ps1 -Mode Probe -Target
  'res://tools/scene4_framework_probe.tscn'` 并查看截图。
- [ ] 用 `git diff --check` 与 `git status --short` 复核范围。
