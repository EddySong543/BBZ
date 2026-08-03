# Scene4 正式素材

本目录保存 Eddy 提供的 Scene4 正式素材。场景树已扁平化，所有实际素材节点都直接位于
`src/ui/scenes/scene4.tscn` 根节点下，方便在 Godot 编辑器中直接选择和调整。

| 正式文件 | 来源暂存文件 | 接入节点 |
|---|---|---|
| `scene4_sky.png` | `sky.png` | `Sky` |
| `scene4_background_top_leaves.png` | `backleaves.png` | `BackgroundTopLeaves` |
| `scene4_background_tree.png` | `bgtree.png` | `BackgroundTree` |
| `scene4_background_tree_2.png` | `bgtree2.png` | `BackgroundTree2` |
| `scene4_battle_platform.png` | `middletreeplatform.png` | `BattlePlatform` |
| `scene4_foreground_left_tree.png` | `lefttree.png` | `LeftTree` |
| `scene4_foreground_right_tree.png` | `righttree.png` | `RightTree` |
| `scene4_top_leaves.png` | `leaves.png` | `TopLeaves` |

各实际节点直接保存自己的视差参数：

| 节点 | 用途 | 默认视差 |
|---|---|---:|
| `Sky` | 调色后的正式天空 | `0.0` |
| `BackgroundTopLeaves` | 远景顶部树叶层 | `0.08` |
| `BackgroundTree` | 第一棵背景树 | `0.15` |
| `BackgroundTree2` | 第二棵背景树 | `0.18` |
| `CanopyMotes` | 森林微尘 | `0.58` |
| `BattlePlatform` | 人物站立平台 | `1.0` |
| `LeftTree`、`RightTree` | 左右近景 | `1.2` |
| `TopLeaves` | 顶部垂叶装饰 | `1.25` |

`P1Baseline`、`P2Baseline` 与 `PlatformBaseline` 是不可见构图标记。先让平台素材
贴合这些标记，不要移动 BattleScreen 中已经成熟的人物节点。

所有素材节点使用最近邻采样并忽略鼠标事件。可直接在 Inspector 中调整 TextureRect
的 offsets、scale、material 与 `parallax_factor`，没有 Slot 包装层或编辑锁。

Scene4 的环境效果与正式素材分离维护：

- `Sky` 使用 `canvas_env_scene4_sky_grade.gdshader` 调整正式天空颜色；
- 其余 PNG 环境层共享 `canvas_env_scene4_depth_grade.gdshader`，但各自保留独立
  ShaderMaterial；可以直接在 Inspector 中调整亮度、饱和度、对比度、森林染色、
  高光压缩和远景雾化；
- `CanopyMotes` 是 Scene4 专属森林微尘；
- 角色环境光、接触阴影与 PostFX 在 `battle_screen4.tscn` 中独立覆盖；
- 基础 Battle Screen 的月夜尘粒在 Scene4 入口中关闭。
