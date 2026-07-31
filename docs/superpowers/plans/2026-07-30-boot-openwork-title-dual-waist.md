# Boot Openwork Title And Dual Waist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Boot Screen 恢复为纯黑背景，接入清晰的 24 格开孔标题，并为画面左右两块腰布制作独立慢速 Idle。

**Architecture:** 标题由不依赖字体的硬编码像素网格生成透明 PNG；角色分层生成器从同一源图提取两块腰布并以逐像素重建校验保护中立姿势。头发/星芒继续使用现有主 AnimationPlayer，腰布改由独立的 8 秒 AnimationPlayer 驱动。

**Tech Stack:** Godot 4.7、GDScript、TS CN、Python Pillow、PNG Lossless。

## Global Constraints

- 不修改角色位置、头发动画关键帧、星芒 Shader 或 Boot 输入切场逻辑。
- 背景必须是纯黑 ColorRect，旧波场 Shader 必须删除而非覆盖。
- 标题不得使用字体直接渲染、全向描边、MaxFilter、字符底板或发光。
- 两块腰布资源都必须来自同一 `bootchar.png` 原像素，neutral composite 必须 `changed_pixels == 0`。
- 自动化 Godot 只通过 `tools/run_godot.ps1` 启动，不关闭用户现有 Godot 进程。
- 不提交或推送 Git。

---

### Task 1: 24 格开孔标题

**Files:**
- Modify: `tools/prepare_boot_title.py`
- Regenerate: `assets/ui/boot/title_bobozan.png`

**Interfaces:**
- Consumes: 三个硬编码像素网格 `WAVE_GLYPH`、`GATHER_GLYPH`
- Produces: 透明、最近邻、无全向描边的 `title_bobozan.png`

- [ ] **Step 1: 用 24 格网格定义字形**

  每个“波”复用同一网格；“攒”使用独立网格。验证每个网格行宽一致、主 mask 非空，并对关键透明孔洞做坐标断言。

- [ ] **Step 2: 只绘制单侧投影和局部高光**

  先以 `(1,1)` 网格偏移绘制 `#7a5518` 投影，再绘制上下两段金色主面，最后用“主面减去右下偏移主面”得到 `#ffe08a` 左上高光；禁止膨胀 mask。

- [ ] **Step 3: 生成并验证 PNG**

  Run: `python tools/prepare_boot_title.py`

  Expected: 四角透明、只含允许色板、三个连通字组互相分离、重复运行 SHA256 一致。

### Task 2: 双腰布分层

**Files:**
- Modify: `tools/prepare_boot_character_idle_layers.gd`
- Create: `assets/ui/boot/character/boot_char_waist_screen_left.png`
- Create: `assets/ui/boot/character/boot_char_waist_screen_right.png`
- Regenerate: `assets/ui/boot/character/boot_char_base.png`
- Delete: `assets/ui/boot/character/boot_char_waist_cloth_tips.png`

**Interfaces:**
- Consumes: `assets/import/bootchar.png`
- Produces: 两张全画布透明腰布层和逐像素一致的中立重建

- [ ] **Step 1: 将现有腰布规范重命名为 screen-right**

  保留现有长布多边形与 `(183,91)` 根部。

- [ ] **Step 2: 增加 screen-left 白色短布**

  使用多边形 `[(108,89),(126,86),(138,88),(143,92),(141,98),(137,106),(132,108),(127,103),(123,99),(108,96)]` 和 overlap `Rect2i(133,88,10,12)`。

- [ ] **Step 3: 执行分层工具**

  Run: `powershell -ExecutionPolicy Bypass -File tools/run_godot.ps1 -Mode Tool -Target res://tools/prepare_boot_character_idle_layers.gd`

  Expected: 日志包含两个腰布 `BOOT_IDLE_LAYER` 和 `BOOT_IDLE_RECONSTRUCTION_OK: changed_pixels=0`。

### Task 3: 独立慢速腰布 Idle

**Files:**
- Modify: `src/ui/components/boot_character_idle.tscn`
- Modify: `src/ui/components/boot_character_idle.gd`

**Interfaces:**
- Consumes: Task 2 的两张腰布层
- Produces: 主 `AnimationPlayer` 的 4.8 秒头发/星芒循环与 `WaistAnimationPlayer` 的 8 秒腰布循环

- [ ] **Step 1: 在场景中建立两个独立 pivot**

  `WaistScreenLeftPivot=(139,91)`、`WaistScreenRightPivot=(183,91)`；子 Sprite 使用对应负坐标恢复原画布位置。

- [ ] **Step 2: 从主 Idle 删除腰布 rotation track**

  现有头发关键帧和 `_sync_energy_pulse()` 保持原样。

- [ ] **Step 3: 安装并播放 waist_idle**

  新动画时长 `8.0` 秒，两条 rotation track 使用 `Animation.INTERPOLATION_CUBIC_ANGLE`；screen-right 最大约 `0.030rad`，screen-left 最大约 `0.022rad` 且错相。

### Task 4: 背景撤销与标题接入

**Files:**
- Modify: `src/ui/boot_screen.tscn`
- Delete: `assets/shaders/canvas_boot_graphic_wave_field.gdshader`
- Delete: `assets/shaders/canvas_boot_graphic_wave_field.gdshader.uid`

**Interfaces:**
- Consumes: Task 1 标题 PNG
- Produces: `Background + Title + Character` 三层纯黑 Boot Screen

- [ ] **Step 1: 删除背景 Shader 资源与 Material**

  `Background.color` 恢复为 `Color(0.004, 0.003, 0.009, 1)`，`material` 为空。

- [ ] **Step 2: 按标题自然尺寸更新 TextureRect**

  使用最近邻过滤和 `mouse_filter = IGNORE`，不得非整数拉伸标题。

### Task 5: 运行时回归

**Files:**
- Modify: `tools/boot_shot_runner.gd`
- Verify: `src/ui/boot_screen.tscn`
- Verify: `src/ui/components/boot_character_idle.tscn`

**Interfaces:**
- Consumes: 完整 Boot Screen
- Produces: 运行时截图、双 AnimationPlayer 结构断言、点击切场结果

- [ ] **Step 1: 更新探针断言**

  要求背景 Material 为空且颜色为纯黑；标题纹理存在；角色包含 `idle` 和 `waist_idle` 两个 AnimationPlayer；两张腰布纹理均存在。

- [ ] **Step 2: 导入资源并执行截图探针**

  Run: `powershell -ExecutionPolicy Bypass -File tools/run_godot.ps1 -Mode Import`

  Run: `powershell -ExecutionPolicy Bypass -File tools/run_godot.ps1 -Mode Probe -Target res://tools/boot_shot_runner.tscn`

  Expected: 无 Shader/脚本错误，日志包含 `BOOT_CHAR2_PROBE_OK` 与 `BOOT_CHAR2_INPUT_OK`。

- [ ] **Step 3: 检查动画帧**

  输出一个完整 8 秒腰布循环的多帧预览，检查画面左右衣摆均移动、根部不脱节、首尾帧一致，并确认头发速度未变化。
