# Boot Title And Graphic Background Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为当前 Boot Screen 产出独立“波波攒”标题，并接入明亮的近景图形波场背景。

**Architecture:** 标题由可复现脚本生成透明无损 PNG，背景由单个全屏 `canvas_item` Shader 绘制，二者作为独立节点接入 `boot_screen.tscn`。现有角色实例、Idle、星芒与输入脚本保持原样。

**Tech Stack:** Godot 4.7、GDScript/TS CN、Godot CanvasItem Shader、Python Pillow、PNG Lossless。

## Global Constraints

- 只修改 Boot Screen 标题、背景和对应验证工具。
- 不修改角色场景、星芒 Shader、Idle 动画或 Main Menu 跳转逻辑。
- 标题颜色固定为 `#f4c84b`、`#d6a73d`、`#ffe08a`、`#7a5518`。
- 目标画布固定为 1920×1080，所有装饰节点 `mouse_filter = IGNORE`。
- 只通过 `tools/run_godot.ps1` 启动自动化 Godot 实例。
- 不关闭用户已经打开的 Godot 进程。

---

### Task 1: 独立标题资产

**Files:**
- Create: `tools/prepare_boot_title.py`
- Create: `assets/ui/boot/title_bobozan.png`

**Interfaces:**
- Consumes: `assets/font/ark-pixel-16px-proportional-zh_cn.ttf`
- Produces: 透明 RGBA 纹理 `res://assets/ui/boot/title_bobozan.png`

- [ ] **Step 1: 编写可复现标题生成脚本**

  在低分辨率像素网格上逐字排版“波波攒”，为“攒”增加约 8% 的尺寸和笔画重量，再以最近邻放大；生成深蓝黑外轮廓、深影、上下两段金色字身和少量亮金高光。

- [ ] **Step 2: 生成并检查透明 PNG**

  Run: `python tools/prepare_boot_title.py`

  Expected: 输出非空 RGBA PNG，四角 alpha 为 0，画面中存在且只存在三枚完整汉字。

### Task 2: 图形波场背景

**Files:**
- Create: `assets/shaders/canvas_boot_graphic_wave_field.gdshader`

**Interfaces:**
- Consumes: 全屏 `UV`、`TIME`
- Produces: 明亮暖灰基底、蓝灰斜切承托形、双不闭合粗环和低亮金色聚集块

- [ ] **Step 1: 实现全屏背景 Shader**

  使用宽高比修正后的 SDF 圆环、斜切遮罩和量化网格噪声构造背景；动画速度低于角色 Idle，不读取屏幕纹理，不引入额外贴图。

- [ ] **Step 2: 检查边缘与动画**

  Expected: 无单像素亮点、无高频闪烁、无闭合靶心感；金色背景元素亮度低于后手星芒。

### Task 3: 场景接入

**Files:**
- Modify: `src/ui/boot_screen.tscn`
- Modify: `tools/boot_shot_runner.gd`

**Interfaces:**
- Consumes: Task 1 标题 PNG、Task 2 背景 Shader
- Produces: `Background + Title + Character` 三层 Boot Screen

- [ ] **Step 1: 为 Background 绑定独立 ShaderMaterial**

  将现有黑色 `ColorRect` 改为全屏图形波场，不改变根节点输入处理。

- [ ] **Step 2: 在 Character 之前插入 Title**

  使用锚点和固定 1920×1080 偏移将标题放在左侧；保持纹理比例、禁用鼠标输入并使用最近邻过滤。

- [ ] **Step 3: 更新 Boot 探针结构断言**

  探针必须验证背景 Material、标题纹理、角色 Idle 和后手星芒，同时继续执行点击进入 Main Menu 的回归检查。

### Task 4: 运行时验证

**Files:**
- Verify: `src/ui/boot_screen.tscn`
- Verify: `tools/boot_shot_runner.gd`

**Interfaces:**
- Consumes: 完整 Boot Screen
- Produces: 1920×1080 运行时截图与输入回归结果

- [ ] **Step 1: 导入新增资源**

  Run: `powershell -ExecutionPolicy Bypass -File tools/run_godot.ps1 -Mode Import`

  Expected: Godot 退出码 0，新增 PNG 和 Shader 无导入错误。

- [ ] **Step 2: 执行 Boot 运行时探针**

  Run: `powershell -ExecutionPolicy Bypass -File tools/run_godot.ps1 -Mode Probe -Target res://tools/boot_shot_runner.tscn`

  Expected: 日志同时包含 `BOOT_CHAR2_PROBE_OK` 和 `BOOT_CHAR2_INPUT_OK`，无 `ERROR` 或 Shader 编译失败。

- [ ] **Step 3: 人工检查运行时截图**

  检查 1920×1080 截图中的标题可读性、角色轮廓、星芒层级、背景亮度、无黑边与无异常像素。
