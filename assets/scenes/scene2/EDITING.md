# Scene2 手动微调速查

## 打开哪个场景

- 调山、树、桥、水、瀑布、天空：打开 `res://src/ui/scenes/scene2.tscn`。
- 看完整战斗合成、只调 Scene2 角色/阴影：打开 `res://src/ui/battle_screen2.tscn`。
- 调两个场景共用的 HUD / 按钮：打开 `res://src/ui/battle_screen_base.tscn`。
- 不要为了调 Scene2 去改 `battle_screen1.tscn`。

## 调环境元素

在 `scene2.tscn` 的场景树选中元素，然后在 Inspector 使用：

- `Layout > Transform > Position`：位置。
- `Layout > Transform > Size`：显示大小。
- `Visibility > Modulate`：整体颜色与透明度。
- `Material > Shader Parameters`：只用于天空、水面、瀑布等 Shader 元素。

主要节点：

| 层级 | 节点 |
|---|---|
| 天空 | `Sky` |
| 远景 | `FarMountain` |
| 中景 | `MidMountain`、`MountainGate`、`MountainLeft` |
| 瀑布 | `WaterfallLeft` |
| 可站立前景 | `StoneBridge` |
| 桃树 | `BlossomTree` |
| 水面 | `DistantWater`、`River` |
| 前景雾 / 花瓣 | `FogFront`、`PetalFar`、`PetalNear` |

同级节点在场景树中越靠下，通常绘制得越靠前。改变顺序前先确认没有把桥、水面或角色遮住。

调 `WaterfallLeft` 时，先用 Position 移动整条瀑布；若修改 Size，必须把 `Material > Shader Parameters > size_px` 改成相同尺寸，避免像素格被拉伸。`center_x` 控制水体在节点矩形中的水平位置，`top_half_width_px` / `bottom_half_width_px` 控制顶部和底部宽度。

## 保持像素比例

- 石桥源图 `237 × 55`，当前显示 `1659 × 385`，即严格 `7×`；`Flip H` 已开启，用桥面自然高差同时承接 P1/P2。
- 桃树源图 `208 × 125`，当前显示 `624 × 375`，即 `3×`。
- 远山 `1608 × 508`、中山 `1672 × 752` 当前使用 `1×`。

优先使用等比例整数倍。若只改变宽或高，会把像素素材拉扁或拉长。

## 桥和角色一起调

1. 先在 `scene2.tscn` 调 `StoneBridge`。
2. 打开 `battle_screen2.tscn` 看完整合成。
3. 若桥面高度变了，只在 `battle_screen2.tscn` 调 `P1CharDisplay`、`P2CharDisplay` 的 Position Y。
4. 同步调 `P1Shadow`、`P2Shadow`，让阴影贴住脚底。

不要在 `battle_screen_base.tscn` 调 Scene2 专属站位，否则 Scene1 也会一起变化。
