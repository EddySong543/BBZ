# 远征可见范围与格子密度预览实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use the current-session inline workflow; the shared dirty worktree forbids broad rollback or staging.

**Goal:** 修正贴格近方形视野的奇怪半格雾边，并用当前正式地表与人物生成四档行列密度实机预览。

**Architecture:** 逻辑可见格继续由 `MapState.visible` 唯一决定；迷雾 shader 改为采样 `map_data.G`，完整保留可见格，仅在相邻不可见格内生成不足五分之一格的外沿柔化。行列比较只存在于独立 Probe，通过改变世界显示比例并反向补偿人物大小生成截图，不改正式地图尺寸。

**Tech Stack:** Godot 4.7、GDScript、CanvasItem shader、TileMapLayer、GUT。

## Global Constraints

- 已通过的草地、泥土、麦浪、传送点资产不得改色、重采样或替换。
- 人物在四档预览中保持当前 72px 屏幕画布。
- 正式地图维持 32×18，行列方案只输出预览，待用户选择后再接入。
- 视野边界必须是贴单格边界的不规则近方形，不得变成圆形、菱形或整格内部渐变。

### Task 1: 贴格外沿迷雾

**Files:**
- Modify: `assets/shaders/canvas_ui_expedition_terrain.gdshader`
- Modify: `src/expedition/expedition_screen.gd`
- Test: `tests/unit/ui/test_expedition_pixel_tiles.gd`

- [x] 测试锁定 shader 必须读取 `map_data.G`，并把柔化限制为 0.18 格。
- [x] 删除按中心坐标解析生成的整圈半格渐变，改为完整可见格 + 相邻不可见格外沿柔化。
- [x] 运行远征 UI 范围测试，确认 shader 编译和现有地表契约不回归。

### Task 2: 四档密度实机预览

**Files:**
- Create: `tools/expedition_density_visibility_preview.gd`
- Create: `tools/expedition_density_visibility_preview.tscn`

- [x] 在当前正式地图中心固定同一人物、同一视野和同一光照时刻。
- [x] 输出 26×15、28×16、30×17、32×18 四张 1920×1080 PNG。
- [x] 每档反向补偿人物缩放，使其屏幕画布均为 72px。
- [x] 目视检查格子数量、视野外沿、人物比例和像素清晰度。
