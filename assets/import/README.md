# assets/import — 外部导入资源统一暂存区

**所有从外部导入的美术 / 音频资源先落这里**（英雄立绘与 idle sheet、道具图标、音效……），
经导入工具或手动归位到正式目录后再清空。**统一此一个入口**，替代原先散落的
`sprites/NewAssets/` 与 `sprites/items/newAssets/`。

## 铁规

- ⚠ **禁止直接引用本目录下的文件**——暂存区随时会清，资源必须先移入正式目录再引用。
- 本目录内容**默认不入库**（`.gitignore` 只保留本 README）：中文名有跨平台编码风险、大素材有体积问题。

## 用法

- **道具图标**：按【道具中文名】命名 PNG 丢进来 → 跑 `tools/import_item_art.gd` 同名归位到 `assets/sprites/items/`。
- **英雄美术**：`hXX.png`（立绘）+ `hXX_idle.png`（idle sheet）复制到 `assets/sprites/heroes/hXX/`，再跑 `tools/import_hero_art.gd` 切帧（256px 网格·4 列·跳全透明格）。
- 归位并确认无误后，清空本目录。
