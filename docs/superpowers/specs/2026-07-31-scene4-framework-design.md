# Scene4 空场景框架设计

## 目标

Scene4 的工程框架不设计主题、不生成素材。Eddy 提供的正式素材接入预留层，并沿用
成熟 Battle Screen 的 UI、人物、回合计时、输入、主动换人、死亡换人与鼠标视差。

## 独立入口

- `src/ui/scenes/scene4.tscn`：保存素材插槽、Eddy 提供的当前素材节点、构图标记和视差参数。
- `src/ui/battle_screen4.tscn`：直接实例化 `battle_screen_base.tscn`，静态挂接
  Scene4，不复制第二套 UI、人物或战斗脚本。
- Scene1、Scene2、Scene3 的入口和资源引用保持不变。

## 素材插槽

Scene4 根节点继续使用成熟 `BattleStage`。直接子层按远到近排列：

1. `SkySlot`，视差 `0.0`；
2. `FarBackdropSlot`，视差 `0.15`；
3. `AtmosphereBackSlot`，视差 `0.24`；
4. `MidBackdropSlot`，视差 `0.38`；
5. `AtmosphereFrontSlot`，视差 `0.58`；
6. `PlatformSlot`，视差 `1.0`，与人物 WorldGroup 同步；
7. `ForegroundSlot`，视差 `1.2`。

所有插槽默认最近邻采样、忽略鼠标。当前背景树、平台与左右近景作为插槽子节点接入，
不改变插槽本身的视差职责；初始空框架不预设美术调色或 shader。

## 2026-08-03 场景环境补充

Eddy 后续明确要求 Scene4 拥有“巨树森林、被叶片遮住的绿色天空”，并纠正新场景
不应继承 Scene1 月光与月夜粒子的规则。因此在不移动四张正式素材、不改 Scene1–3
及基础 Battle Screen 的前提下，Scene4 增加专属程序化树冠天空、稀疏森林微尘、
树冠方向角色光、根系接触阴影和克制的森林色 PostFX；基础场景的两层月夜尘粒在
BattleScreen4 中显式关闭。

## 构图标记

不可见 `Marker2D` 标出 P1、P2 脚底基线与战斗平台中心，避免导入素材时移动成熟人物：

- P1：`(480, 748)`
- P2：`(1440, 748)`
- 平台中心：`(960, 748)`

场景内保留一层可替换的深色 `PreviewBackdrop`，仅用于空框架运行时看清人物与 UI，
不代表 Scene4 美术方向。

## 验收

- Godot Import 无场景、脚本或资源解析错误。
- Scene4 专项 GUT 确认独立入口、正式素材引用、视差参数与构图标记。
- 完整 GUT 通过。
- 窗口探针确认 BattleScreen4 的 UI、人物和按钮真实出现。
- 指针探针确认 `PlatformSlot` 与 `WorldGroup` 的水平同步误差为 `0.0`。
- 项目中不存在 Codex 生成的 Scene4 场景美术，只接入 Eddy 提供的正式素材副本。
