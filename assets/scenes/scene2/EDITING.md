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
| 瀑布与云幕 | `WaterfallLeft`、`WaterfallCloudUpper`、`WaterfallCloudLower/Lower2` |
| 可站立前景 | `StoneBridge` |
| 桃树 | `BlossomTree` |
| 水面 | `DistantWater`、`River` |
| 前景雾 / 花瓣 | `FogFront`、`PetalFar`、`PetalNear` |

同级节点在场景树中越靠下，通常绘制得越靠前。改变顺序前先确认没有把桥、水面或角色遮住。

`WaterfallLeft` 是当前唯一的瀑布水体节点；旧的 `WaterfallImpactLeft` 入水冲击叠层已经移除。`center_x` 控制水体在节点矩形中的水平位置，`top_half_width_px` / `bottom_half_width_px` 控制顶部和底部宽度。需要调整水纹繁简时，优先改 `lane_width_px`（数值越大，水带越宽）、`major_streak_density`（主亮流数量）和 `flow_highlight_density`（细亮纹数量），不要通过缩小像素格来堆叠细线。

`WaterfallCloudUpper`、`WaterfallCloudLower` 与 `WaterfallCloudLower2` 使用 Scene1 同机制的程序像素云 `ColorRect`，三层必须保留独立材质和互不相同的确定性 `seed`，这样编辑器与运行时保持一致，同时云形不会在层间重样。Upper 使用 `mode_isolated=1`，但复用 Lower 的扁平复合云丘参数；`isolated_forced_stride=2` 控制最大间隔，较宽的 `isolated_len_cap` 允许相邻云丘组合成不规则大轮廓，`isolated_break_stride` 再保证它不会连成横贯画面的长条。两个 Lower 使用 `mode_isolated=0` 和较低的 `lobe_height_scale` 压低尖峰；`WaterfallCloudLower2` 使用负 `flow_speed` 与第一层相向漂移。`bank_join_height` 生成不会被桥面遮成透明孔洞的连续云肩，`bank_join_variation` 只给云肩加入少量阶梯变化。`bank_valley_center/width/depth` 形成固定在瀑布轴上的最低点，`bank_valley_peak_scale` 同时压低谷内随机峰，`bank_side_rise` 则把轮廓向左山体和右桃树两端逐级抬高；节点移动后应重新对齐 `bank_valley_center`，不要通过改节点 Size 补偿。`continuous_bob_scale` 控制 Lower 各团的独立纵向起伏，`lobe_min_step_px=2` 保证峰顶至少两个像素格宽。颜色与透明度仍由 `fill_color/lit_color/alpha_max` 控制；`inner_contrast` 保持为 `0`，避免内部深色块看成反向移动的空洞。`CloudFar/CloudFar2/CloudMid/CloudMid2` 继续保留。

`DistantWater` 只负责桥洞后的亮色远水道；其 `anim_fps`、`flow_speed_px` 和 `line_density` 应始终低于前景 `River`。调高度时保持底边与 `River` 重叠，避免两层之间出现缝隙。

`FarMountain` 与 `MidMountain` 的材质只调整饱和度、对比度和空气色，不会模糊像素边缘。远山应保持更低的 `saturation / contrast` 和更高的 `atmosphere_strength`；手动移动或缩放山体不会破坏这套关系。

`StoneBridge/BridgeBankShade` 是石桥的子节点，会自动跟随石桥的位置和大小，用于压住左右桥岸接缝。通常不要单独移动它；若桥端过暗，只降低其材质的 `shadow_strength`。

`BlossomTree` 的 `BlossomTreeSwayMat` 只移动 `scene2_blossom_branch_mask.png` 划定的左、上、右枝梢与黄色编码的下垂小花束；树根、主干和承重主枝不在遮罩中，始终读取原始像素。`scene2_blossom_underpaint.png` 是独立的静态底绘层：主枝连接处用附近木质调色板补出隐藏结构；左枝与上枝相接的窄缝、黄色小花束连接处，以及 P2 头顶随左枝移动的垂落桃花，都必须从原图邻近桃花色板取样，禁止以黑色木质像素填花。`motion_fps` 控制像素步进帧率，`cycle_sec` / `max_angle_deg` 控制大枝组的缓慢往复，`bouquet_cycle_sec` / `bouquet_angle_deg` 控制小花束更轻的独立节奏。不要改回按 `UV.y` 扫描整图的波纹，也不要用节点旋转替代，否则主干会随枝冠一起漂移。修改桃树源图轮廓后，运行 `tools/prepare_scene2_blossom_branch_mask.gd`，并分别复核枝梢遮罩与底绘层。

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
