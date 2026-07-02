# 道具图标（items sprites）

道具图标的**正式目录**。约定与代码：`src/battle/item_catalog.gd` 的 `ICON_DIR` / `icon_path()`。

## 布局

```
assets/sprites/items/
├── README.md            ← 本文件
├── t1_xiangjiaopi.png   ← 正式图标，文件名 = 道具内部 id
├── t2_jiandun.png
└── ...
```

- **正式图标文件名 = 道具 id**（如 `t1_xiangjiaopi.png`），纯 ASCII，可被代码按约定加载。
- UI（道具芯片 + 抽取 3 选 1 卡）按 `ICON_DIR/<id>.png` 自动加载；**缺图则回退占位文字**，所以没图也不会坏画面。
- ⚠ **不要直接往这里放中文名文件**——中文名进仓库有跨平台编码风险。中文名只放 `assets/import/`（统一暂存区），由导入工具归位。

## 工作流（你丢图 → 自动归位 → 游戏显示）

1. 把图标 PNG 丢进 `assets/import/`，**按道具中文名命名**（见 `assets/import/README.md`）。
2. 运行导入工具：
   ```
   <godot> --headless --path . --script res://tools/import_item_art.gd
   ```
   工具会把 `assets/import/臭鸡蛋.png` → `t1_xiangjiaopi.png` 放到本目录，并打印未匹配清单。
3. 在 Godot 编辑器里让它导入一次（开编辑器或 `--import`），游戏里对应道具就显示出来了。

## 图标规格（建议）

- **128×128 PNG · 透明底 · 像素图**（芯片 64px、抽取卡更大，128 源图缩放都干净）。
- UI 节点已设 `texture_filter = NEAREST`，像素清晰、无需特意配 `.import`。
