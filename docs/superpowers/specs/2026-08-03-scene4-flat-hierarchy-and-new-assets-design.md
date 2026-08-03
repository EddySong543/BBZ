# Scene4 扁平层级与新增素材设计

## 目标

在保留 Eddy 已手动调整的四张 Scene4 素材位置和成熟鼠标视差的前提下，删除全部
`*Slot` 包装节点，接入 `sky.png`、`bgtree2.png` 和 `leaves.png`，并移除当前
程序化深绿色天空。

## 范围

- 只处理 `assets/import/sky.png`、`bgtree2.png`、`leaves.png` 及对应 sidecar；
- 其余 `assets/import` 文件不移动、不改名、不修改；
- 不改 Scene1–3、`battle_screen_base.tscn` 或成熟战斗交互；
- 不移动 Eddy 已手调的 BackgroundTree、BattlePlatform、LeftTree、RightTree。

## 扁平场景树

Scene4 的实际美术和环境节点全部成为根节点直属子项。`BattleStage` 直接读取这些节点
的 `parallax_factor`，不需要全屏 TextureRect Slot：

1. `PreviewBackdrop`：中性兜底底色；
2. `Sky`：正式天空，视差 `0.0`；
3. `BackgroundTree`：现有背景树，视差 `0.15`；
4. `BackgroundTree2`：第二棵背景树，视差 `0.18`；
5. `CanopyMotes`：Scene4 森林微尘，视差 `0.58`；
6. `BattlePlatform`：战斗平台，视差 `1.0`；
7. `LeftTree`、`RightTree`：左右近景，视差 `1.2`；
8. `TopLeaves`：顶部垂叶装饰，视差 `1.25`，绘制在其他场景素材上方，但仍位于人物
   和战斗 UI 下方；
9. `CompositionGuides`：不可见构图标记。

## 天空调色

新天空保留源图的横向分层和明度关系，通过 Scene4 专属 Shader 映射为低饱和
鼠尾草灰、雾蓝绿和柔和浅灰绿。颜色不得回到深墨绿或高饱和荧光绿。BattleScreen4
的全屏 PostFX 同时恢复为接近中性的轻量调色，避免再次把整场染绿。

## 素材落位

- `sky.png` → `assets/scenes/scene4/scene4_sky.png`
- `bgtree2.png` → `assets/scenes/scene4/scene4_background_tree_2.png`
- `leaves.png` → `assets/scenes/scene4/scene4_top_leaves.png`

第二棵背景树先放在右侧战斗区后方；顶部垂叶按原始宽度约四倍铺满 1920 宽画面。
这些只是可直接在编辑器中继续拖拽的初始位置，不新增锁定 metadata。

## 验收

- Scene4 根节点下不存在名称以 `Slot` 结尾的节点；
- 三张新素材使用正式路径，最近邻显示并可在编辑器直接选择；
- 原四张素材的视觉位置保持不变；
- Scene4 专项 GUT 通过；
- Godot Import 无 Scene4 资源或 Shader 解析错误；
- 实机截图没有程序化深绿背景残留，人物、平台和 UI 保持清晰；
- 指针视差探针中平台与人物同步误差为 `0.0`。
