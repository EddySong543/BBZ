# 新版道具图鉴属性与首批正式美术 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this plan inline in the current authorized task; do not dispatch subagents.

**Goal:** 接入首批新版道具美术，为图鉴补齐费用、耐久、占格与价格；源 PNG 承担默认方向，远征背包只跟随玩家实际旋转。

**Architecture:** `ItemCatalog` 继续作为显示名、文案、形状和正式图标路径的唯一数据源。图鉴用一个小型形状预览组件和现有 `IconBadge` 生成角标，场景文件保存右页稳定几何。背包视图只负责从初始形状和当前 placement 形状推导显示旋转，不改变背包规则。

**Tech Stack:** Godot 4、GDScript、GUT、PNG无损导入、现有 `tools/run_godot.ps1`。

## Global Constraints

- 不修改英雄。
- 不读取、生成、保存或返回截图。
- 不覆盖无关脏工作树改动。
- `assets/import/` 只作收件箱，已接入资源必须转入正式目录并清理对应旧路径 sidecar。
- 所有 Godot 自动化只通过 `tools/run_godot.ps1`。

---

### Task 1: 锁定新版目录和正式资产映射

**Files:**
- Modify: `src/battle/item_catalog.gd`
- Modify: `tests/unit/battle/v4/test_item_v2_catalog.gd`
- Add/replace: `assets/sprites/items/v2/*.png`
- Move: 隐藏旧素材到 `assets/sprites/items/legacy/*.png`
- Add: `assets/ui/icons/item_durability.png`

**Interfaces:**
- Consumes: `ItemCatalog.make(id) -> ItemData`
- Produces: 新显示名、文案、初始 `shape_cells` 与按显示名加载的新资产路径。

- [x] Step 1: 在目录测试中断言11件新名称、两条新文案和全部初始形状。
- [x] Step 2: 运行 `& .\tools\run_godot.ps1 -Mode Test -Target 'res://tests/unit/battle/v4/test_item_v2_catalog.gd'`，确认旧目录数据导致失败。
- [x] Step 3: 修改 `_V2_DEF`，新版20件全部使用 `v2/` 中自己的同名文件；暂时借图也复制为独立副本。
- [x] Step 4: 将明确的PNG移动至正式目录，删除这些源路径对应的旧 `.import`，不处理无关收件箱文件。
- [x] Step 5: 运行 Godot Import 和目录定向测试，确认数据与资源均可加载。

### Task 2: 图鉴费用、耐久和属性条

**Files:**
- Create: `src/ui/components/item_shape_preview.gd`
- Modify: `src/ui/item_gallery_screen.gd`
- Modify: `src/ui/item_gallery_screen.tscn`
- Modify: `tests/unit/ui/test_screen_compiles.gd`

**Interfaces:**
- Consumes: `ItemData.use_cost`, `max_durability`, `shape_cells`, `full_price`
- Produces: `ItemShapePreview.set_shape(Array[Vector2i])`, 左页 `UseCostBadge`/`DurabilityBadge`，右页 `UseCostBadge`/`DurabilityBadge`/`ShapePreview`/`PriceLabel`。

- [x] Step 1: 新增场景行为测试，断言0费仍显示、耐久读取最大值、价格带千位分隔符、形状预览读取初始形状。
- [x] Step 2: 运行图鉴定向测试，确认新节点尚不存在而失败。
- [x] Step 3: 实现只绘制初始占格的小型预览组件；状态变化统一调用 `queue_redraw()`。
- [x] Step 4: 在左页卡片构造中复用 `IconBadge` 添加两个对称角标。
- [x] Step 5: 在 `.tscn` 中加入右页角标与两栏属性条；占格只画手绘方格，不显示文字。
- [x] Step 6: 运行图鉴定向测试，确认节点、数值、排版顺序和可编辑场景归属通过。

### Task 3: 背包长条美术与旋转同步

**Files:**
- Create: `src/ui/components/item_grid_art_layout.gd`
- Modify: `src/ui/components/backpack_grid_view.gd`
- Modify: `src/expedition/expedition_screen.gd`
- Modify: `tests/unit/ui/test_expedition_pixel_tiles.gd`

**Interfaces:**
- Consumes: item `combat_id`、item初始 `shape`、placement当前 `shape`
- Produces: 共享的 `shape_rotation_quarters(base_shape: Array, current_shape: Array) -> int`、保持宽高比的旋转绘制参数，以及仓库/普通背包与PvE背包一致的绘制结果。

- [x] Step 1: 新增纯数据测试，覆盖横2→竖2、竖2→横2、横3初始态和方形态。
- [x] Step 2: 运行远征UI定向测试，确认旧视图缺少旋转推导接口而失败。
- [x] Step 3: 用四次规范化旋转比较推导当前朝向；找不到时安全回退0。
- [x] Step 4: 用整个placement包围盒做宽高比适配，围绕中心旋转美术及阴影；仓库/普通背包与PvE背包调用同一计算器。
- [x] Step 5: 运行远征UI定向测试，确认形状与绘制数据通过。

### Task 4: 全量验证与范围检查

**Files:**
- Verify only: all files above

**Interfaces:**
- Consumes: 三项已实现功能
- Produces: 可复核的导入、定向测试、全量测试和Git范围证据。

- [x] Step 1: 运行 `& .\tools\run_godot.ps1 -Mode Import`。
- [x] Step 2: 运行目录、图鉴、远征背包三组定向GUT。
- [x] Step 3: 运行 `& .\tools\run_godot.ps1 -Mode Test`（本次道具相关测试全过；全仓其余模块保留4项失败，详见执行汇报）。
- [x] Step 4: 用资源路径、PNG尺寸、节点几何和像素alpha包围盒数据检查正式接入；不生成截图。
- [x] Step 5: 检查 `git diff --check`、本任务文件差异及 `assets/import/` 遗留，汇报结果，不提交或推送。
