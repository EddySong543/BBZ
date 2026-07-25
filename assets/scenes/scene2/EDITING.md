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
- `Material > Shader Parameters`：用于天空、水面、瀑布，以及 Far/Mid Mountain 的非模糊景深调色。

主要节点：

| 层级 | 节点 |
|---|---|
| 天空 | `Sky` |
| 远景 | `FarMountain` |
| 中景 | `MidMountain`、`MountainLeft`、`MountainRight` |
| 瀑布与云幕 | `WaterfallLeft`、`WaterfallCloudUpper`、`WaterfallCloudLower` |
| 可站立前景 | `StoneBridge` |
| 桃树 | `BlossomTree` |
| 水面 | `DistantWater`、`River` |
| 前景雾 / 花瓣 | `FogFront`、`PetalFar`、`PetalNear` |

同级节点在场景树中越靠下，通常绘制得越靠前。改变顺序前先确认没有把桥、水面或角色遮住。

`WaterfallLeft` 与 `WaterfallImpactLeft` 是同一条瀑布的本体层和入水层。移动或缩放瀑布时必须在场景树中同时选中这两个节点再调整；两者的 Position、Size 和 `Material > Shader Parameters > size_px` 必须保持一致。`center_x` 控制水体在节点矩形中的水平位置，`top_half_width_px` / `bottom_half_width_px` 控制顶部和底部宽度。

`WaterfallCloudUpper` 位于瀑布之后、左右山体之前，用来切断瀑布上半段；`WaterfallCloudLower` 位于左右山体之后，用来覆盖山脚与瀑布下半段。优先只调 Position 和 `Self Modulate` 的 Alpha，不要缩放原生 `1521×1019` 云图。这样瀑布会呈现“露出—入云—再露出—再入云”的远景节奏，而不是一条连续水帘。

`DistantWater` 只负责桥洞后的亮色远水道；其 `anim_fps`、`flow_speed_px` 和 `line_density` 应始终低于前景 `River`。调高度时保持底边与 `River` 重叠，避免两层之间出现缝隙。

`FarMountain` 与 `MidMountain` 的材质只调整饱和度、对比度和空气色，不会模糊像素边缘。远山应保持更低的 `saturation / contrast` 和更高的 `atmosphere_strength`；手动移动或缩放山体不会破坏这套关系。

`StoneBridge/BridgeBankShade` 是石桥的子节点，会自动跟随石桥的位置和大小，用于压住左右桥岸接缝。通常不要单独移动它；若桥端过暗，只降低其材质的 `shadow_strength`。

`PetalFar` 与 `PetalNear` 共用 `scene2_petal_atlas.png` 的 4 帧翻页材质，并以固定 12fps、无插值方式运动。需要调整花瓣数量或景深时，优先修改节点的 `Amount` 和各自 `Process Material > Scale`；不要重新开启 `Interpolate` 或 `Fract Delta`，否则会失去像素步进感。

`River` 的岸线亮色已经改为短泡沫簇。`shore_cluster_density` 控制同时出现的簇数量，`shore_cluster_cycle_sec` 控制生灭周期，`shore_foam_strength` 控制亮度；保持低密度和四秒以上周期，避免恢复成持续发亮的整条白线。

## 保持像素比例

- 石桥源图 `237 × 55`；`Flip H` 已开启，用桥面自然高差同时承接 P1/P2。当前构图包含手工宽高微调，后续以角色脚底和桥面接触为第一约束。
- 桃树源图 `208 × 125`，当前显示 `624 × 375`，即 `3×`。
- 远山 `1608 × 508`、中山 `1672 × 752` 当前使用 `1×`。

优先使用等比例整数倍。若只改变宽或高，会把像素素材拉扁或拉长。

## 桥和角色一起调

1. 先在 `scene2.tscn` 调 `StoneBridge`。
2. 打开 `battle_screen2.tscn` 看完整合成。
3. 若桥面高度变了，只在 `battle_screen2.tscn` 调 `P1CharDisplay`、`P2CharDisplay` 的 Position Y。
4. 同步调 `P1Shadow`、`P2Shadow`，让阴影贴住脚底。

不要在 `battle_screen_base.tscn` 调 Scene2 专属站位，否则 Scene1 也会一起变化。
