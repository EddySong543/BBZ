# Scene Environment Ownership and Scene4 Canopy Sky Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修订新场景环境复用条例，并让 Scene4 使用巨树森林专属的天空、角色光照、接触阴影、调色和粒子。

**Architecture:** 保持 `battle_screen_base.tscn` 与 Scene1–3 不变，在 `battle_screen4.tscn`
中覆盖共享入口的环境表现，在 `scene4.tscn` 中承载 Scene4 专属天空和微尘。规则写入
新场景制作手册，测试只保护环境归属和资源隔离，不锁死可手调坐标。

**Tech Stack:** Godot 4.7.1、GDScript、CanvasItem Shader、GPUParticles2D、GUT

## Global Constraints

- 不修改或重构 Scene1、Scene2、Scene3 与 `battle_screen_base.tscn`。
- 复用 UI、人物节点/动画/站位、交互、视差算法和技术框架。
- Scene4 环境资源必须带 `scene4` 命名，不得引用其他场景的专属环境 Shader。
- 不生成天空位图；天空由轻量 CanvasItem Shader 绘制。
- 不 commit 或 push，除非 Eddy 后续明确要求。

---

### Task 1: 固化环境归属条例与回归测试

**Files:**
- Modify: `docs/operations/NEW-SCENE-PRODUCTION-PLAYBOOK.md`
- Modify: `tests/unit/ui/test_scene4_framework.gd`

**Interfaces:**
- Consumes: `battle_screen4.tscn`、`scene4.tscn` 的节点路径。
- Produces: 环境资源隔离、共享粒子停用和 Scene4 专属天空/微尘的测试契约。

- [ ] 在制作手册中区分“可直接复用的行为/结构”和“必须按场景重做的环境表现”。
- [ ] 新增失败测试：Scene4 必须使用独立角色光照、PostFX、接触阴影和树冠天空。
- [ ] 新增失败测试：共享 `ForeDust/LowerDust` 停止发射，`CanopyMotes` 使用 Scene4 配色。
- [ ] 运行全量 GUT，确认新增断言在实现前失败，并记录既有无关失败。

### Task 2: Scene4 树冠天空与森林微尘

**Files:**
- Create: `assets/shaders/canvas_env_scene4_canopy_sky.gdshader`
- Modify: `src/ui/scenes/scene4.tscn`

**Interfaces:**
- Produces: `SkySlot/CanopySky` 与 `AtmosphereFrontSlot/CanopyMotes`。

- [ ] 创建深翡翠程序化天空 Shader：纵向色场、中央叶隙、大块量化树影、极慢漂移。
- [ ] 在 `SkySlot` 中加入全屏 `CanopySky`，保持鼠标忽略和最远景视差。
- [ ] 创建 18–24 个暗金绿色 `CanopyMotes`，限制在中央叶隙区域。
- [ ] 保持现有树木、平台、人物基线与七层视差契约不变。

### Task 3: Scene4 专属角色光照、阴影与 PostFX

**Files:**
- Create: `assets/shaders/canvas_env_scene4_character_light.gdshader`
- Create: `assets/shaders/canvas_env_scene4_root_contact_shadow.gdshader`
- Modify: `src/ui/battle_screen4.tscn`

**Interfaces:**
- Produces: P1/P2 独立 Character ShaderMaterial、共享 Scene4 接触阴影材质和 Scene4 PostFX。

- [ ] 创建无月光语义的角色 Shader，保留 flash、nearest 像素与 authored saturation。
- [ ] P1/P2 使用相对的中央上方光源方向和克制黄绿色边光。
- [ ] 将长斜月影替换为紧贴脚底的像素分级根系阴影。
- [ ] 为 Scene4 配置深绿中性 PostFX，保留战斗冲击帧参数接口。
- [ ] 将继承的 `ForeDust/LowerDust` 设为不可见且 `emitting = false`。

### Task 4: 导入、测试与运行验证

**Files:**
- Modify: `tools/scene4_framework_probe.gd`（仅在现有探针不足以验证时）

**Interfaces:**
- Consumes: Scene4 独立入口和现有 `run_godot.ps1`。
- Produces: 导入日志、测试结果、中心/右侧指针截图与视差同步误差。

- [ ] 运行 `& .\tools\run_godot.ps1 -Mode Import`，确认 Shader 和场景解析成功。
- [ ] 运行 `& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 240`，核对 Scene4 专项结果与既有失败。
- [ ] 运行 `& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/scene4_framework_probe.tscn'`。
- [ ] 检查真实截图中的天空、角色清晰度、粒子密度、平台接触和 UI 可读性。
- [ ] 用 `git diff --check`、`git status --short` 和 Scene1–3 路径状态确认没有越界改动。
