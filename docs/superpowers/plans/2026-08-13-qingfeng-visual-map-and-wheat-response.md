# 晴风稻田可视化地图与麦浪响应 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将晴风稻田地表迁移为 Godot 可直接绘制的分层 TileMapLayer 场景，并为角色踏入连续稻田提供粗像素局部麦浪传播。

**Architecture:** 新建独立的晴风稻田视觉地图场景和外部 TileSet，Ground 层成为地表资产选择的运行时来源，空的装饰/障碍/交互层为后续拖放留位；现有 `expedition_map_state.gd` 继续独占通行、事件与交互规则。麦浪响应记录短生命周期的格级脉冲，在已通过麦浪底图上绘制 4px 步进的局部纹理位移，不修改原始资产。

**Tech Stack:** Godot 4.7、GDScript、TileMapLayer、TileSetAtlasSource、GUT、CanvasItem 粗像素绘制。

## Global Constraints

- 保留当前 18×14 逻辑地图、120px 运行格、60px 原生资产、Nearest 2×放大。
- 保留已通过的统一圆角、描边、迷雾、镜头、传送点与现有玩法逻辑。
- 地表、装饰、障碍、容器与标识保持独立层；可视化编辑不能把玩法判定反向绑定到装饰图片。
- 麦浪只响应实际成功移动，持续约 0.55 秒，最多向连续稻田传播 2 格，不消耗额外回合。
- 不 reset、stash 或覆盖仓库中其他任务的修改；不提交。

---

### Task 1: 可视化分层地图资源

**Files:**
- Create: `assets/tilesets/qingfeng_ricefield/qingfeng_ground_tileset.tres`
- Create: `src/expedition/maps/qingfeng_ricefield_visual_map.tscn`
- Modify: `src/expedition/expedition_screen.gd`
- Test: `tests/unit/ui/test_expedition_pixel_tiles.gd`

**Interfaces:**
- Produces: `Ground`、`GroundDetail`、`LowDecoration`、`BlockingObjects`、`Containers`、`MarkerGuides` 六个 `TileMapLayer`；`_ground_terrain_at(cell)` 与 `_ground_texture_for(cell)` 查询当前可视化图块。

- [ ] 写入失败测试：地图场景可加载，六层可见，Ground 覆盖 18×14，每个正式图块暴露 `ground_type` 和 `asset_id`。
- [ ] 运行远征像素测试，确认测试在资源缺失时失败。
- [ ] 创建外部 TileSet 与可视化地图场景，并把当前地表布局无损迁移到 Ground。
- [ ] 让远征画面实例化该地图，以 Ground 图块而不是字符表决定具体地表资产与稻田语义。
- [ ] 运行导入和远征专项测试。

### Task 2: 角色经过稻田时的麦浪响应

**Files:**
- Modify: `src/expedition/expedition_screen.gd`
- Test: `tests/unit/ui/test_expedition_pixel_tiles.gd`
- Create: `tools/expedition_wheat_wave_probe.gd`
- Create: `tools/expedition_wheat_wave_probe.tscn`

**Interfaces:**
- Produces: `_trigger_wheat_wave(from_cell, to_cell, move_dir)`；活动脉冲包含 `cell/start_time/distance/direction`。

- [ ] 写入失败测试：非稻田不触发；进入稻田后只沿连续稻田传播，半径不超过 2，延迟按距离增长。
- [ ] 在成功移动后触发麦浪，开局和战斗回图不触发。
- [ ] 在 `RiceFoliageLayer` 用当前麦浪纹理绘制 4px 步进的局部位移带，并在 0.55 秒后清理。
- [ ] 运行专项测试，执行 1920×1080 峰值动效探针并人工检查角色、圆角和迷雾层级。

### Task 3: 花草叠层预览

**Files:**
- 旧预览产物已清理；正式 overlay 资产位于 `assets/tilesets/qingfeng_ricefield/overlays/`。

**Interfaces:**
- Consumes: 当前普通/深色草地的正式资产和实机粗像素尺度。
- Produces: 一张包含白花、黄花、粉花、短草簇、三叶草及混合小簇的场景内叠层预览。

- [ ] 以当前正式草地为可见参考生成预览，不修改地表颜色、圆角或纹理。
- [ ] 检查每组装饰完整落在单格内、真像素硬边、无抗锯齿、无细碎脏噪点。
- [ ] 将预览保存到项目并在交付消息中显示。
