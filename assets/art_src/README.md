# assets/art_src — 尚未归属的本地原图源档

这里只保留尚未归属到具体英雄或场景、且确有返工价值的本地原图。英雄与场景母版分别进入对应 `hXX/source/`、`sceneX/source/`。

## 约定

- **文件名 = 对应成品名**：`ui/ui_tooltip.png`（源）↔ `assets/ui/ui_tooltip.png`（成品）——一眼对上。
- **不入库**（`.gitignore` 整目录排除·大图体积原因·与 import 暂存区同规）；**Godot 不导入**（本目录有 `.gdignore`）。
- 用途：重跑管线（重降采样/换色变体）、当 GPT 参考图喂回锁风格（如 `hero_avatar_frame.png` 锁回纹钩形制）。
- 已归属到具体英雄或场景的母版不得在这里保留第二份。
- 带 `retired`、`rejected`、`unused` 后缀的否决资产直接清理，不把本目录当历史垃圾箱。

## 落位管线（源 → 成品）

量边界（img_used_rect）→ 转透明（棋盘格=img_checker_to_alpha / 实色底泛光=img_bg_flood_to_alpha）→
裁整除区（img_crop）→ NEAREST 整数倍降采样（img_resize）→ 需要平铺的拉平中段（img_flatten_rows）→
`assets/ui/` 正式名 → `--import`。详见 `design/gpt-image-reference.md` §9-§13。
