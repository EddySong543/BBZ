# Boot Vertical Perspective Title Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Boot Screen 的横排“波波攒”替换为三个独立纵排字，并以无厚度 2D Shader 模拟统一朝角色旋转的 3D 平面透视。

**Architecture:** Python 生成器从现有 24 格字模直接输出三张同尺寸透明 PNG，并以少量外轮廓切角和浅金脉冲格形成静态能量刻印；Boot Screen 使用 `TitleColumn` 管理三个独立 `TextureRect`。共享 CanvasItem Shader 执行逆透视 UV 映射，每字使用独立材质，背景与角色模块保持原样。

**Tech Stack:** Godot 4.7、GDScript、CanvasItem Shader、TSCN、Python Pillow、Lossless RGBA PNG。

## Global Constraints

- 不修改 `Background` 的节点类型、颜色、材质或子节点。
- 不修改 `boot_character_idle.tscn`、`boot_character_idle.gd` 或任何角色分层资源。
- 不修改 `boot_screen.gd` 的输入、门禁和切场逻辑。
- 三个字必须是独立 PNG、独立节点和独立材质。
- “波”表示能量波；标题不得新增水滴、涟漪、曲线或连续波纹。
- 每字刻印与缺口合计不得超过主体笔画面积的 `5%`，且不得改变关键偏旁。
- 透视只有平面投影，没有文字厚度、挤出、倒角、底板或发光。
- 所有纹理使用 nearest、无 mipmap，旧横排标题必须删除而非覆盖。
- 自动化 Godot 只通过 `tools/run_godot.ps1` 启动，不关闭用户已有 Godot 进程。
- 不提交或推送 Git。

---

### Task 1: 生成三个独立像素字图

**Files:**
- Modify: `tools/prepare_boot_title.py`
- Create: `assets/ui/boot/title_bo_top.png`
- Create: `assets/ui/boot/title_bo_middle.png`
- Create: `assets/ui/boot/title_zan_bottom.png`
- Delete: `assets/ui/boot/title_bobozan.png`

**Interfaces:**
- Consumes: `WAVE_GLYPH`、`GATHER_GLYPH`、逐字刻印表和金色色板
- Produces: 三张 `252×252` RGBA PNG

- [ ] **Step 1: 将生成器改为逐字输出**

  生成器使用固定映射：

  ```python
  OUTPUTS = (
      ("title_bo_top.png", WAVE_GLYPH, TOP_WAVE_TREATMENT),
      ("title_bo_middle.png", WAVE_GLYPH, MIDDLE_WAVE_TREATMENT),
      ("title_zan_bottom.png", GATHER_GLYPH, GATHER_TREATMENT),
  )
  CELL_SIZE = 9
  CANVAS_CELLS = (28, 28)
  ```

- [ ] **Step 2: 为每张 PNG 执行同一组硬校验**

  检查 `RGBA`、`252×252`、允许色板、透明四角、3×3 关键孔洞、刻印像素上限和重复生成字节稳定；两个“波”必须共享基础字模但输出不同的刻印像素。

- [ ] **Step 3: 生成资产**

  Run:

  ```powershell
  & 'C:\Users\Edzzz\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/prepare_boot_title.py
  ```

  Expected: 输出三个文件及各自 SHA256；重复运行哈希不变。

### Task 2: 实现平面透视 Shader

**Files:**
- Create: `assets/shaders/canvas_boot_title_perspective.gdshader`

**Interfaces:**
- Consumes: TextureRect 的内建 `TEXTURE`、`UV` 和 `COLOR`
- Produces: 左侧保持完整、右侧朝角色收窄的透明平面投影

- [ ] **Step 1: 建立可调参数**

  Shader 暴露以下参数：

  ```glsl
  uniform float perspective_strength : hint_range(0.0, 0.35, 0.01) = 0.26;
  uniform float edge_padding : hint_range(0.0, 0.45, 0.01) = 0.04;
  ```

- [ ] **Step 2: 使用逆映射生成单一连续梯形**

  Fragment 根据输出 `UV.x` 计算从左到右递减的可见半高，将目标梯形反算回源纹理 UV；梯形外部输出透明。映射必须连续，不通过两个独立三角形拼接，避免对角接缝。

- [ ] **Step 3: 保持像素采样**

  Shader 不做平滑、模糊、导数抗锯齿或发光；节点使用 `texture_filter = 1`，确保源纹理 nearest。

### Task 3: 替换 Boot 标题节点

**Files:**
- Modify: `src/ui/boot_screen.tscn`
- Delete after import: `assets/ui/boot/title_bobozan.png.import`

**Interfaces:**
- Consumes: Task 1 的三张 PNG 和 Task 2 的共享 Shader
- Produces: `Background + TitleColumn + Character` 三模块场景

- [ ] **Step 1: 删除旧 Title 节点与横排纹理引用**

  `Background` 和 `Character` 块保持字节级不变；只将旧 `Title:TextureRect` 替换为 `TitleColumn:Control`。

- [ ] **Step 2: 创建三个独立材质**

  三个 `ShaderMaterial` 都引用同一 Shader，分别保留自己的 `perspective_strength = 0.26` 和 `edge_padding = 0.04`，不得共享同一可变 Material 实例。

- [ ] **Step 3: 纵向自然尺寸排版**

  使用：

  ```text
  TitleColumn: x=176..428, y=146..934
  BoTop:       x=0..252, y=0..252
  BoMiddle:    x=0..252, y=268..520
  ZanBottom:   x=0..252, y=536..788
  ```

  三个节点 `mouse_filter = IGNORE`，标题列继续位于 Character 之前。

### Task 4: 更新运行时探针

**Files:**
- Modify: `tools/boot_shot_runner.gd`

**Interfaces:**
- Consumes: 新 `TitleColumn` 场景结构
- Produces: 标题结构、背景未改和点击切场的自动断言

- [ ] **Step 1: 将单 Title 断言替换为三字断言**

  探针要求 `TitleColumn/BoTop`、`BoMiddle`、`ZanBottom` 均为有纹理且有 `ShaderMaterial` 的 `TextureRect`；三者材质实例不得相同。

- [ ] **Step 2: 增加替换与范围保护**

  断言旧 `Title` 节点不存在、旧 `title_bobozan.png` 文件不存在、根仍为三个模块；继续要求 Background 为近黑无材质，并保留角色、星芒、双腰布和动画断言。

- [ ] **Step 3: 保留输入回归**

  继续在截图后模拟左键点击，日志必须包含 `BOOT_CHAR2_INPUT_OK: res://src/ui/main_menu.tscn`。

### Task 5: 导入和实机验收

**Files:**
- Verify: `src/ui/boot_screen.tscn`
- Verify: `assets/ui/boot/title_bo_top.png`
- Verify: `assets/ui/boot/title_bo_middle.png`
- Verify: `assets/ui/boot/title_zan_bottom.png`

**Interfaces:**
- Consumes: 完整 Boot Screen
- Produces: 1920×1080 运行时截图和日志证据

- [ ] **Step 1: 导入资源**

  Run:

  ```powershell
  & .\tools\run_godot.ps1 -Mode Import
  ```

  Expected: 三张标题 PNG 和透视 Shader 成功导入，无相关 Parse/Shader 错误。

- [ ] **Step 2: 执行真实窗口探针**

  Run:

  ```powershell
  & .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/boot_shot_runner.tscn'
  ```

  Expected: 日志包含 `BOOT_CHAR2_PROBE_OK` 与 `BOOT_CHAR2_INPUT_OK`。

- [ ] **Step 3: 检查截图**

  检查三个字纵向分离、左侧完整而右侧朝角色收窄、无厚度、无裁边、无对角接缝；刻印呈硬朗能量切缝而非水波；确认背景仍为纯近黑，角色位置和所有 Idle 动效未改变。

- [ ] **Step 4: 文件级检查**

  Run:

  ```powershell
  git -c safe.directory='D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization' diff --check -- src/ui/boot_screen.tscn tools/boot_shot_runner.gd
  ```

  Expected: 无空白错误，且项目中没有 `title_bobozan.png` 的运行引用。
