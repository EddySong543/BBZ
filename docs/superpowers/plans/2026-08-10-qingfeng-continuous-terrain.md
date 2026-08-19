# 晴风稻田连续地形 Implementation Plan

**Goal:** 将被否定的全体立体卡块切换为 B 方案的连续地形、浅格缝和轻量人物标记。

**Architecture:** 保留 18×14 逻辑地图、16×8 视窗、低频区域配色、道路、麦穗、对象、迷雾和镜头。`GroundArtLayer` 先绘制连续地表色块，再只在每格右侧和底部绘制 2px 半透明格缝；草地与黄土交界使用 4px 边界。人物所在格恢复四角标记，不再使用完整卡块内沿。

**Tech Stack:** Godot 4、GDScript、CanvasItem custom drawing、GUT、1920×1080 Probe

## Constraints

- 普通地表没有切角、外框、内高光、底部厚边或格间暗槽。
- 草地继续使用浅、中、深三档连续区域配色，不做棋盘交替。
- 黄土道路保持连续，内部格缝弱于道路边界。
- 不恢复 PlayerBackdrop；人物所在格只显示四角标记。
- 不改变地图逻辑、麦穗数量、对象分层和镜头。

## Verification

- [ ] 更新 `test_expedition_pixel_tiles.gd`，固定浅格缝、区域边界和无完整人物卡块契约。
- [ ] 实装连续地表与四角人物标记。
- [ ] 运行 Godot Import。
- [ ] 运行全量 GUT，区分并行任务失败。
- [ ] 运行 `expedition_shot_runner.tscn` 并检查 1920×1080 截图。
