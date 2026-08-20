# Scene4 正式素材

本目录保存 Eddy 提供的 Scene4 正式素材。场景树已经扁平化，实际使用的素材节点均直接位于
`src/ui/scenes/scene4.tscn` 根节点下，方便在 Godot 编辑器中直接选择和调整。

| 正式文件 | 来源暂存文件 | 当前用途 |
|---|---|---|
| `scene4_sky.png` | `sky.png` | `Sky` |
| `scene4_far_forest.png` | `bg.png`（2026-08-09 替换） | `FarForest` |
| `scene4_background_top_leaves.png` | `backleaves.png` | `BackgroundTopLeaves` |
| `scene4_background_tree.png` | `bgtree.png` | `BackgroundTree` |
| `scene4_background_tree_2.png` | `bgtree2.png` | `BackgroundTree2` |
| `scene4_midground_ruin_stone_1.png` | `stone1.png` | `RuinStone1`、`RuinStone3`、`RuinStone4` |
| `scene4_midground_ruin_stone_2.png` | `stone2.png` | `RuinStone2` |
| `scene4_battle_platform.png` | `platform.png`（2026-08-09 替换） | `BattlePlatform`、`BattlePlatformDepthShadow` |
| `scene4_foreground_left_tree.png` | `lefttree.png`（旧版） | 备用素材，当前未实例化 |
| `scene4_foreground_right_tree.png` | `righttree.png`（旧版） | 备用素材，当前未实例化 |
| `scene4_foreground_left_tree_2.png` | `lefttree.png`（2026-08-09 替换） | `LeftTree2`（当前正式左树） |
| `scene4_foreground_right_tree_2.png` | `righttree.png`（2026-08-09 替换） | `RightTree2`（当前正式右树） |
| `scene4_top_leaves.png` | `leaves.png` | 备用素材，当前未实例化 |
| `scene4_foreground_near_center.png` | `front.png` | 备用近景素材，当前未接入 |
| `scene4_foreground_near_left.png` | `near left.png` | 备用近景素材，当前未接入 |
| `scene4_foreground_near_right.png` | `near right.png` | 备用近景素材，当前未接入 |

当前 Scene4 不实例化 `NearCenter`、`NearLeft`、`NearRight`，避免近景再次抢占构图；底部由
`BackgroundBottomLeaves` 的远景树冠与低强度 `ForegroundFog` 承接空间。`LeftTree2`、`RightTree2` 是直接子节点，不使用 `*Slot`
包装层；旧 `LeftTree`、`RightTree` 与 `TopLeaves` 不再实例化。

主要环境动效：

- Scene4 的正式调色以 `ref34` 的色阶关系为准：近黑蓝绿阴影、青色空气光，以及只集中在平台受光边缘和少量叶片上的黄绿色高光；近景树保持深冷，避免全画面落入相近黄绿而显得脏。
- `CanopyLightShafts` 与 `CanopyMotes`：Scene4 专属林隙光和光尘。
- `RuinStone1`—`RuinStone4`：银灰蓝像素能量，使用错开的非等周期上行节奏。
- `ForegroundMotes`：复用 Scene1 近景粒子的空间结构，颜色改为森林青绿。
- `FarForest`：新 16:9 远景以全屏等比覆盖接入，使用冷青绿低饱和分级，并在下缘渐隐地表线索，避免形成“地面森林”的视觉锚点。
- `BackgroundBottomLeaves`：复用树冠素材作为静止、不透明的底部叶幕；保留 Eddy 手动取消垂直反转后的方向，并以低饱和、低对比的冷灰青表现平台下方的远景树冠。
- `BattlePlatformDepthShadow`：复用平台透明轮廓并向下偏移 1 个源像素，以窄幅深青环境阴影切开暖绿横木与底部树冠，不改变正式平台的位置和尺寸。
- `MidgroundMist`：人物后方的冷灰青薄雾，集中在平台下方的空气间隙中缓慢横移。
- `ForegroundFog`：仅保留为平台下缘与底部叶幕之间的极薄动态衔接雾，不作为底部主遮挡层或水面。
- `ClickInteraction`：左右近景树与顶部叶层均不捕获点击，鼠标左键只命中四座石碑的非透明像素；单次点击会用更高明暗差和更长衰减高亮当前正在爬行的冷银蓝能量，但不点亮休眠回路，也不改变流速、位置或尾迹。`AchievementLeafSpirits` 同时承载两种互斥事件：不点击时首次约 8 秒、之后每隔 22—38 秒随机出现 2—3 只环境小精灵；8 秒内按视觉高度从低到高点击 `RuinStone4 → RuinStone2 → RuinStone3 → RuinStone1` 会完成 Scene4 场景成就，四碑能量短暂同步并发光，随后严格恢复普通爬行状态，同时一次性放出 18—24 只小精灵。成就演出会优先接管并清除当时的环境精灵，结束后再恢复随机刷新。错误顺序或超时会重置进度；演出有 30 秒冷却，冷却期间普通单击仍生效但不累计顺序，结束后可再次触发。所有反馈均不改节点位置。
- `BackgroundTree2`：使用较低雾化和更清晰的冷青绿对比，与 `FarForest` 保持景深关系但不再粘连。
- `LeftTree2`、`RightTree2` 的树干主体保持静止；左右分别覆盖约 4—5 根与约 4 根垂藤，以更可读的摆幅、约 7.2 秒与 10.8 秒的独立主周期及错开相位摆动；`BackgroundTopLeaves` 保留独立缓慢摆动。

角色环境光、接触阴影与 PostFX 在 `battle_screen4.tscn` 中独立覆盖；基础 Battle Screen 的月夜粒子
在 Scene4 入口中关闭。
