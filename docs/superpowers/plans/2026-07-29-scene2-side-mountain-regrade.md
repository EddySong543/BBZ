# Scene2 Side Mountain Regrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Scene2 左右山体调整为接近瀑布 ridge 的灰岩色，同时保持前后景层级。

**Architecture:** 沿用现有两个独立 ShaderMaterial，只在场景文件中调整颜色分级参数和节点调制。所有空间参数、贴图、遮罩和动效保持不变。

**Tech Stack:** Godot 4、TextureRect、canvas_item ShaderMaterial、GUT

## Global Constraints

- 只修改 `MountainLeft` 与 `MountainRight` 的颜色表现。
- 不修改位置、大小、层级、视差、贴图、遮罩或动效。
- 左山较实，右山较冷且更退后。
- 保持像素边缘清晰，不引入模糊后处理。

---

### Task 1: 调整两个独立山体材质

**Files:**
- Modify: `src/ui/scenes/scene2.tscn`
- Test: `tools/battle_scene2_shot.tscn`

**Interfaces:**
- Consumes: `MountainLeftMat`、`MountainRightMat` 与两个 TextureRect 节点
- Produces: 保持原节点接口不变的灰岩配色

- [ ] **Step 1: 记录修改前的材质参数和 Scene2 截图**

Run:
```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/battle_scene2_shot.tscn' -TimeoutSeconds 60
```

Expected: exit code `0`，截图写入 `_probe_output/battle_scene2_shot.png`。

- [ ] **Step 2: 调整 MountainLeft**

在 `MountainLeftMat` 中降低绿色 atmosphere 影响，改用中性灰蓝 atmosphere；
保持饱和度和对比度足以保护桃花，并将节点 `self_modulate` 改为中性颜色。

- [ ] **Step 3: 调整 MountainRight**

在 `MountainRightMat` 中移除强灰绿色雾化，改用较冷的灰蓝 atmosphere；
适度恢复饱和度和对比度，将节点 `self_modulate` 改为中性冷灰。

- [ ] **Step 4: 运行截图并比较**

Run:
```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/battle_scene2_shot.tscn' -TimeoutSeconds 60
```

Expected: 两山不再显绿，左山更实，右山更退后。

- [ ] **Step 5: 运行导入和全量测试**

Run:
```powershell
& .\tools\run_godot.ps1 -Mode Import -TimeoutSeconds 120
& .\tools\run_godot.ps1 -Mode Test -TimeoutSeconds 300
```

Expected: 两条命令 exit code `0`，GUT 报告全部通过。
