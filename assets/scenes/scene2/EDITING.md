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
| 瀑布与云幕 | `Waterfall`、`WaterfallRidgeLeft/Right`、`WaterfallCloudUpper`、`WaterfallCloudLower/Lower2` |
| 可站立前景 | `StoneBridge` |
| 桃树 | `BlossomTree` |
| 水面 | `DistantWater`、`River` |
| 前景雾 / 花瓣 | `FogFront`、`PetalFar`、`PetalNear` |

同级节点在场景树中越靠下，通常绘制得越靠前。改变顺序前先确认没有把桥、水面或角色遮住。

`Waterfall` 是当前唯一的瀑布水体节点；旧的 `WaterfallImpactLeft` 入水冲击叠层已经移除。当前启用 `ridge_profile_enabled=1` 的非对称轮廓：`left_top_edge_px` 是顶部左岸，`left_ridge_edge_px` 是沿左 ridge 内缘收紧后的最内侧位置；`left_ridge_turn` 当前提前到约 55% 高度，让水体在左 ridge 后方先开始隐藏式展开至 `left_lower_edge_px=164px`，但不改变左 ridge 素材。右岸使用三段轮廓：`right_top_edge_px` 保持已确认的顶部宽度；`right_flare_turn` 到 `right_fan_turn` 之间加速追随退让的右 ridge，并在 `right_fan_edge_px` 处保留约一个屏幕像素格以上的遮挡重叠；最后缓慢展开至 `right_bottom_edge_px`。当前两段转折约为 46% / 72%，扇面与底部右岸分别为 `712px` / `718px`；这样在 ridge 底端可见高度，瀑布总宽已经超过顶部，同时不会在右 ridge 与水体之间露出透明缝。瀑布外缘按 `section_height_px` 形成长竖边，只在分段交界处以 `edge_step_px` 产生短阶梯；当前 48px 分段用于避免大块梯级。水体参考 ref26 的 8 帧方法，以完全不透明的青灰主体承载三个宽而稀疏的分段纵向水带；瀑布口的两至三个亮块与水带横移/下落均只在 8 个离散状态间切换，Scene2 以 8fps 播放。P1-A 使用贯穿全高的主体、阴影和高光三个色面替换随机大块，细碎白线密度由 `flow_highlight_density` 控制；P1-B 由 `contact_shadow_*` 和 `contact_glint_*` 在专属 ridge 遮挡下保留窄幅湿暗边与稀疏断续亮边。P1-C 不改变云节点，而由 `cloud_cut_*` 在 UpperCloud 背后的水体上生成小尺度、低透明切除的青白雾舌；节点移动后只需重新对齐 `cloud_cut_center_y`。需要调整水纹繁简时，优先改 `lane_width_px`、`streak_period_px` 和 `flow_highlight_density`，不要通过降低 `body_alpha` 或挖大面积透明孔制造流动。

`WaterfallRidgeLeft/Right` 分别使用独立素材 `scene2_waterfall_ridge_left.png` / `scene2_waterfall_ridge_right.png`，只用于夹住瀑布上段；源图由 `tools/prepare_scene2_waterfall_ridges.gd` 去除浅色底并裁成真透明边缘，不再复制 `scene2_far_mountain.png`。P0-C 的绘制契约为：Far/Mid Mountain 与普通远云在后，`Waterfall` 水体居中，专属 ridge 在前切出两岸硬遮挡，`WaterfallCloudUpper/Lower` 再遮住中段与底部。节点的 Position/Size 保持人工构图值。显示保持 Nearest；专属材质只从源图读取硬 alpha 轮廓，内部颜色主要由更深的实体青灰高度渐变和轻量天空色空气透视生成，并以邻域平均恢复克制的纵向岩面明暗。P2 的 `inner_edge_direction` 指向各自瀑布侧，shader 仅在这条真透明内缘生成两级青灰反光；调强弱只改 `inner_reflect_strength`，不要用发光或模糊。右 ridge 另由 `inner_trim_*` 重画整条朝瀑布内缘：基础轮廓从顶部源图 `x=10px` 退到下端 `x=54px`，模拟左 ridge 的上缓、中段短肩、下段加速节奏；`inner_trim_lower_start` 之后再由 `inner_trim_lower_extra_px` 仅对下半段追加单调退让，当前最多增加 8 个源像素，使最终内缘约退至 `x=62px`。所有变化仍保持 1px 小台阶，上半部、源 PNG 和右侧外轮廓不受影响。

`WaterfallCloudUpper`、`WaterfallCloudLower` 与 `WaterfallCloudLower2` 使用 Scene1 同机制的程序像素云 `ColorRect`，三层必须保留独立材质和互不相同的确定性 `seed`，这样编辑器与运行时保持一致，同时云形不会在层间重样。Upper 使用 `mode_isolated=1`，但复用 Lower 的扁平复合云丘参数；`isolated_forced_stride=2` 控制最大间隔，较宽的 `isolated_len_cap` 允许相邻云丘组合成不规则大轮廓，`isolated_break_stride` 再保证它不会连成横贯画面的长条。两个 Lower 使用 `mode_isolated=0` 和较低的 `lobe_height_scale` 压低尖峰；`WaterfallCloudLower2` 使用负 `flow_speed` 与第一层相向漂移。`bank_join_height` 生成不会被桥面遮成透明孔洞的连续云肩，`bank_join_variation` 只给云肩加入少量阶梯变化。`bank_valley_center/width/depth` 形成固定在瀑布轴上的最低点，`bank_valley_peak_scale` 同时压低谷内随机峰，`bank_side_rise` 则把轮廓向左山体和右桃树两端逐级抬高；节点移动后应重新对齐 `bank_valley_center`，不要通过改节点 Size 补偿。`continuous_bob_scale` 控制 Lower 各团的独立纵向起伏，`lobe_min_step_px=2` 保证峰顶至少两个像素格宽。颜色与透明度仍由 `fill_color/lit_color/alpha_max` 控制；`inner_contrast` 保持为 `0`，避免内部深色块看成反向移动的空洞。`CloudFar/CloudFar2/CloudMid/CloudMid2` 继续保留。

`DistantWater` 只负责桥洞后的亮色远水道；其 `anim_fps`、`flow_speed_px` 和 `line_density` 应始终低于前景 `River`。P2 的 `landing_*` 在原远水 shader 内生成窄幅、断续、明暗错拍的落水响应，不再创建独立 `WaterfallImpact`，也不会产生向两侧扩散的同心波纹。移动瀑布后以 `landing_center_x` 重新对齐瀑布轴；`landing_period_sec` 保持 5 秒以上。调高度时保持底边与 `River` 重叠，避免两层之间出现缝隙。

`WaterfallCloudUpper` 的 `water_reflect_*` 只给瀑布附近独立云团的下缘增加一档克制青灰反光；共享的 Scene1 云 shader 默认强度为 0，因此 Scene1 不受影响。不要给连续的 Lower 云墙开启同类轮廓，否则会出现整条发光边。

`FarMountain` 与 `MidMountain` 的材质只调整饱和度、对比度和空气色，不会模糊像素边缘。远山应保持更低的 `saturation / contrast` 和更高的 `atmosphere_strength`；手动移动或缩放山体不会破坏这套关系。

`MountainLeft` 的 `MountainLeftMat` 在保留原有景深调色的同时，只移动 `scene2_mountain_left_branch_mask.png` 标记的三组外伸桃花枝梢。红、绿、蓝通道分别对应上、中、下枝，山体、树干和连接根部不在遮罩中。`motion_fps` 控制像素步进帧率，`cycle_sec` 控制缓慢往复，`max_angle_deg` 控制三组枝梢的最大摆幅；不要扩大遮罩到山体内部，否则需要额外底绘且容易产生穿帮。

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
