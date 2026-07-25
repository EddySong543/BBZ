# 场景 2 — 层山峻岭中的桃花源（Scene 2: Hidden Blossom Vale）

> Godot 场景：`src/ui/scenes/scene2.tscn`（复用 `src/ui/components/battle_stage.gd` 视差引擎·metadata `parallax_factor` 声明层深）。
> 画布 **1920×1080**，像素画。本目录存放本场景美术，命名 **`scene2_<部分>`**（小写下划线）。
> 立项（2026-07-18 Eddy）：scene2 同时为 **boot screen / main menu 重制**供层——山、雾、河、瓣四族件都可拆去复用。
> 当前状态 = **7 项正式环境素材 + 新 Far/Mid Mountain 双层背景 + 左侧通高瀑布与近景河流程序 V2 + P0 角色倒影/Scene2 专属融光已接入**。`battle_screen1.tscn` 与 `battle_screen2.tscn` 分别静态挂载 Scene1 / Scene2，并通过 `battle_screen_base.tscn` 复用同一套角色、UI 与战斗行为。

## 构图锚点（与 scene1 对齐·角色/镜头零改动直接换景）

| 锚点 | 值 | 说明 |
|------|-----|------|
| 角色站立线 | y ≈ 745 | 与 BattleScreen 现有 P1/P2 脚底线一致；石桥主动对齐角色，角色节点零改动 |
| 构图引导线 | 左上→左下 | 单条天河沿约 x=280 从顶部画外直泻前景河面，主体控制在 P1 左侧，Scene2 不采用 Scene1 的中心对称构图 |
| 镜头对焦点 | (960, 600) | battle_stage `focus_point` 默认·不改 |
| 远景带 | y 98-850 | `scene2_far_mountain.png` / `scene2_mid_mountain.png` 两张独立资产，以 0.04/0.08 视差、原生 1× 尺寸和分层透明度建立空气透视，不施加纹理模糊 |
| 近前景 | y 676+ | 石桥站立层 1.0；固定桥面线 y=745，远水 y=845、近河水线 y≈867；河 1.18，前雾 1.5 / 近瓣 1.45（scene1 近景 1.4-1.65 同档） |

## 分层清单（由远及近 = 树序 = 绘制序）

| 节点 | 视差 | 内容 | 状态 |
|------|------|------|------|
| `Sky` | 0 | `scene2_sky.png` 全屏青蓝—淡紫横向像素天空，保留 48px 左右视差余量 | ✅ 美术实装 |
| `FarMountain` | 0.04 | `scene2_far_mountain.png`，原生 `1608×508`，矩形 `(156,212)-(1764,720)`；最远层青蓝山影 | ✅ 新素材实装 |
| `MidMountain` | 0.08 | `scene2_mid_mountain.png`，原生 `1672×752`；紫灰峡谷主体背景，与左侧程序瀑布保持独立叠层 | ✅ 新素材实装 |
| `MountainLeft` | 0.24 | `scene2_mountain_left.png`，源图清除浅底并裁切为 `122×194`，Nearest 整数放大 3×；位于瀑布之前形成左侧岩壁遮挡和桃枝框景 | ✅ 新素材实装 |
| `MountainRight` | 0.24 | `scene2_mountain_right.png`，源图清除深色外底并保留岩缝阴影，裁切为 `140×235`、Nearest 整数放大 3×；位于桃树后方形成右侧山壁纵深 | ✅ 新素材实装 |
| `ValleyGlow` | 0.08 | 谷中暖光（moon_halo shader 暖参·“桃源在谷里”的光信号） | 🟡 程序增强 |
| `HorizonHaze` | 0.38 | 暖雾横带，统一两组山体与天空的空气透视 | ✅ 复用件 |
| `BlossomTree` | 0.48 | `scene2_blossom_tree.png` 右侧近中景桃树；源尺寸 `208×125`，Nearest 整数放大 3×，矩形 `(1320,370)-(1944,745)`；树根落桥且树干避开 P2 主轮廓 | ✅ 新素材实装 |
| `PetalFar/Near` | 0.48/1.45 | 桃瓣飘落（远小密/近大疏·⚠占位=圆点粒子，待换花瓣贴图） | 🟡 程序占位 |
| `WaterfallLeft` | 0.18 | **左侧通高天河水柱**（`canvas_env_pixel_waterfall`）：节点矩形 `(-80,-96)-(640,1120)`，水体中心约 x=280；4px 硬像素格内以 6fps / 96px·s⁻¹ 驱动纵向水丝，顶部只保留少量间歇转面高光，轮廓每约 96px 分段收放。主高光、水滴和空隙密度均压低，水柱绘制在山体之后、石桥与河面之前 | ✅ 单瀑布程序 V5·低噪声 |
| `DistantWater` | 0.72 | 桥后远水面 y=845-910，只在拱洞中露出；与桥面保留约 100px 的桥墩纵深，避免直接透出天空底部色带并强化“桥立于水上”的前后关系 | ✅ 代码组装 |
| `StoneBridge` | 1.0 | `scene2_stone_bridge.png` 作为正式战斗站立层；新源图以有色前景为种子并额外保留 2px 深色描边，清除深色底后为 `237×55`，Nearest 严格整数放大 7×，水平镜像后矩形 `(130,709)-(1789,1094)`。P1/P2 分别落在原图 `(186,9)` / `(49,5)` 的桥面支撑点上，利用桥面自然高差承接当前两名角色而不改角色节点；桥体仅作 0.9 亮度压制，不挂模糊或调色材质 | ✅ 新素材实装 |
| `River` | 1.18 | **近景像素河流 V2**：水线 y≈867.46、高约 217.09px（向屏幕底边额外 overscan，避免露出白线），绘制在石桥之后，使新桥下部约 55px 入水且桥体进入屏幕空间倒影；远细近粗的水平切片、分层横移、长短水线与稀疏高光；P1/P2 另由实时 `CharacterDisplay` 纹理以脚底锚点翻转、切片并裁切在河内；不再生成由瀑布落点向两侧持续扩散的同心波纹 | ✅ 程序 V2 + 角色倒影 |
| `WaterfallImpactLeft` | 0.18 | 与 `WaterfallLeft` 同坐标、同参数的**河面冲击层**：仅绘制断裂白色入水区、19/23/29 帧错拍短水花和 5.6 秒双组局部亮/暗波纹；波纹亮段占比不超过约 32%，位于 `River` 之后、`FogFront` 之前，不会恢复已移除的全屏持续扩散波纹 | ✅ 单瀑布表面特效 V5·低噪声 |
| `FogFront` | 1.5 | 近前暖雾薄带 | 🟡 复用件 |

> 加新层 = 加 TextureRect/ColorRect 子节点 + 设 `metadata/parallax_factor` + 拖图（scene1 同规）。
> ⚠ 环境倒影仍只采样**树序在 River 之前**的层，因此石桥必须排在 River 前；角色在 Stage 之后绘制，改由 `battle_screen.gd` 把两张实时 SubViewportTexture 独立绑定给 River，禁止复制第二套角色节点。

## 已归档素材与待补增强件

统一要求：像素画、Nearest、透明素材必须为真 alpha；画面左右各留约 64px 视差余量。除天空外均不要烘入其他层、角色、UI、花瓣或瀑布光效。

| 优先级 | 文件名 | 建议尺寸 | 透明 | 内容与接口要求 |
|---|---|---:|:---:|---|
| Done | `scene2_sky.png` | 576×324 | 否 | 从暂存区归档；以 Nearest 拉伸到 1920×1080，并保留舞台震屏余量 |
| Done | `scene2_mountain_left.png` | 122×194 | 是 | 从新 `leftmountain.png` 清除浅色背景并裁切；左侧瀑布岩壁和桃枝框景 |
| Done | `scene2_mountain_right.png` | 140×235 | 是 | 从 `rightmountain.png` 清除深色外底并保留内部岩缝；右侧桃树后山壁 |
| Done | `scene2_blossom_tree.png` | 208×125 | 是 | 从新 `blossomtree.png` 清除白底并裁切；右侧角色后方桃树 |
| Done | `scene2_stone_bridge.png` | 237×55 | 是 | 从替换后的 `stone bridge.png` 提取有色前景，删除外部黑色描边，并以 3px 闭合保护桥石内部黑色阴影；正式战斗站立层 |
| Done | `scene2_mid_mountain.png` | 1672×752 | 是 | 从 `midmountain.png` 清除烘焙棋盘格并裁切；中远景峡谷 |
| Done | `scene2_far_mountain.png` | 1608×508 | 是 | 从 `farmountain.png` 清除烘焙棋盘格并裁切；最远景青蓝山影 |
| Done | `scene2_cloud_bank.png` | 1521×1019 | 是 | 从 `cloud2.png` 按真实 Alpha 裁切；天空最远层横向云海，低对比、低透明度 |
| Done | `scene2_cloud_tower.png` | 1513×486 | 是 | 从 `cloud.png` 按真实 Alpha 裁切；远山与中山之间的云峰层，避免遮挡战斗主体 |
| P1 | `scene2_waterfall_mask_left.png` | 720×1216 | 是 | 可选的单瀑布轮廓蒙版：白/灰水体、透明背景，顶部和底部均接画外/河面；只定义连续水帘边缘，不要山、桥、雾或前景河面 |
| P2 | `scene2_petal_atlas.png` | 64×16 | 是 | 4 个 16×16 单格桃瓣姿态，轮廓清晰、灰粉低饱和；不带发光和阴影底色 |
| P2 | `scene2_water_ripple_atlas.png` | 256×32 | 是 | 4 帧×64×32 的手绘横向水线/泡沫簇，可在代码水面上作为美术增强；每帧可无缝循环、无整块底色 |

9 项主构图素材已经接入；`assets/import/` 中的新原图保持不变。后续单瀑布蒙版、花瓣和水线图集属于增强层，当前代码版本在它们导入前可独立运行。

### 新环境素材运行时规范

角色素材、角色节点尺寸、缩放和动画帧率均不改。新素材不再强行匹配被否定 P1 的统一 2× 衍生框，而按自身有效内容尺寸接入：山体原生 1×、桃树整数 3×、石桥整数 7×；全部使用 Nearest，禁止非等比拉伸。

| 运行时素材 | 源尺寸 | 场景显示尺寸 |
|---|---:|---:|
| `scene2_cloud_bank.png` | 1521×1019 | 1521×1019 |
| `scene2_cloud_tower.png` | 1513×486 | 1513×486 |
| `scene2_far_mountain.png` | 1608×508 | 1608×508 |
| `scene2_mid_mountain.png` | 1672×752 | 1672×752 |
| `scene2_blossom_tree.png` | 208×125 | 624×375 |
| `scene2_mountain_left.png` | 122×194 | 366×582 |
| `scene2_mountain_right.png` | 140×235 | 420×705 |
| `scene2_stone_bridge.png` | 237×55 | 1659×385（7×，水平镜像） |
| `scene2_mountain_gate_px2.png` | 293×381 | 586×762 |
| `scene2_mountain_left_px2.png` | 264×420 | 528×840 |

八张当前素材由 `tools/prepare_scene2_environment_assets.gd` 固定清底规则、有效内容裁切和预期尺寸；源图变化导致尺寸不符时工具直接失败。旧 `MountainGate` / `scene2_mountain_left_px2.png` 已退出 Scene2 运行时树，仅保留为未清理的历史文件。

### 瀑布与山体资产边界

- 最终运行时山体素材不得烘入完整瀑布水体；带瀑布的生成图仅作为构图参考。
- 山体可以包含干燥崖口、水道凹槽、被冲刷的岩壁形状和用于遮挡水流的前缘，但水帘、泡沫、落点飞溅与水雾必须独立。
- 瀑布运行时顺序为：远/中山体 → `WaterfallLeft` 水柱/可选蒙版 → 石桥与河面遮挡 → `WaterfallImpactLeft` 入水白区、错拍飞溅及局部慢波纹 → 前雾。水柱和冲击层共享坐标与关键参数，以正确遮挡代替单层硬压桥体。

## 调色纪律

- 全台**低饱和**：青玉群山 + 暖纸光 + 灰粉桃瓣。**桃粉压灰压淡**——大面积艳粉/艳红会抢 P2 阵营红，艳蓝同理抢 P1（scene1 铁律延续）。
- 谷口暖光是全场唯一高亮暖点（对位 scene1 明月的冷白）。

## 后续视觉统一任务（按优先级）

1. **✅ P0·角色落地感**：P1/P2 直接复用现有实时 SubViewportTexture；以脚底为水线锚点翻转，裁切在 River 内并沿用河面的水平切片、像素量化和深度衰减；换人、位移和动作帧自动同步。
2. **✅ P0·角色融光**：`battle_screen2.tscn` 单独覆盖角色 `rim_color / shadow_tint / fill_color` 和接触阴影色，从 Scene1 冷月光切换为青玉环境光与暖日光补色；Scene1 参数及角色阵营色保持不变。
3. **✅ P1 重制·新环境素材替换**：新桃树、新石桥、新 Far/Mid Mountain 已按各自有效内容尺寸接入；被否定的远山/桃树/石桥 `*_px2` 衍生件不再使用。
4. **✅ P1 重制·战斗可读性**：桃树右移后树干避开 P2 主体，双方脚底均落在新桥素材自身的草石表面；角色素材和几何保持不变。
5. **✅ P1 重制·景深重排**：Far/Mid Mountain 作为独立节点使用 0.04/0.08 视差和分层透明度，不模糊新像素轮廓；山门、瀑布、桥保持各自独立层。
6. **P2·动效同拍**：瀑布、河面、花瓣统一到 6/8/12fps 的分档节奏和同一像素格；用花瓣图集替换圆点粒子，再补克制的岸线泡沫簇。

## 快照自检

`& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/scene2_shot_runner.tscn'` → `D:/Game/BoBoZan/scene2_shot_a/b.png`（两帧 0.6s 距·验波光在动+零爬缝）。终审 Eddy F6。
