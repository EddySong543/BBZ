# Scene4 正式素材

本目录保存 Eddy 提供的 Scene4 正式素材。场景树已经扁平化，实际使用的素材节点均直接位于
`src/ui/scenes/scene4.tscn` 根节点下，方便在 Godot 编辑器中直接选择和调整。

| 正式文件 | 来源暂存文件 | 当前用途 |
|---|---|---|
| `scene4_sky.png` | `sky.png` | `Sky` |
| `scene4_far_forest.png` | `forestbg.png` | `FarForest` |
| `scene4_background_top_leaves.png` | `backleaves.png` | `BackgroundTopLeaves` |
| `scene4_background_tree.png` | `bgtree.png` | `BackgroundTree` |
| `scene4_background_tree_2.png` | `bgtree2.png` | `BackgroundTree2` |
| `scene4_midground_ruin_stone_1.png` | `stone1.png` | `RuinStone1`、`RuinStone3`、`RuinStone4` |
| `scene4_midground_ruin_stone_2.png` | `stone2.png` | `RuinStone2` |
| `scene4_battle_platform.png` | `middletreeplatform.png` | `BattlePlatform` |
| `scene4_foreground_left_tree.png` | `lefttree.png` | `LeftTree` |
| `scene4_foreground_right_tree.png` | `righttree.png` | `RightTree` |
| `scene4_top_leaves.png` | `leaves.png` | `TopLeaves` |
| `scene4_foreground_near_center.png` | `front.png` | 备用近景素材，当前未接入 |
| `scene4_foreground_near_left.png` | `near left.png` | 备用近景素材，当前未接入 |
| `scene4_foreground_near_right.png` | `near right.png` | 备用近景素材，当前未接入 |

当前 Scene4 不实例化 `NearCenter`、`NearLeft`、`NearRight`，避免近景再次抢占构图；底部空洞由
`ForegroundFog` 的像素云雾承担遮挡。场景也不保留 `*Slot` 包装层或编辑锁。

主要环境动效：

- `CanopyLightShafts` 与 `CanopyMotes`：Scene4 专属林隙光和光尘。
- `RuinStone1`—`RuinStone4`：银灰蓝像素能量，使用错开的非等周期上行节奏。
- `ForegroundMotes`：复用 Scene1 近景粒子的空间结构，颜色改为森林青绿。
- `MidgroundMist`：人物后方薄雾。
- `ForegroundFog`：底部流动云雾，使用 Scene4 独立青灰配色和像素轮廓。
- `LeftTree`、`RightTree` 保持静止；两层顶部垂叶使用不同节奏摆动。

角色环境光、接触阴影与 PostFX 在 `battle_screen4.tscn` 中独立覆盖；基础 Battle Screen 的月夜粒子
在 Scene4 入口中关闭。
