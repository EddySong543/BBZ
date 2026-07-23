# Scene2 新环境素材接入设计

日期：2026-07-23
状态：设计已由 Eddy 口头批准，待书面规格复核

## 目标

以 `assets/import/` 中新导入的四张图为新的独立环境素材，替换被否定的 P1 桃树、石桥和三层远山方案：

- `blossomtree.png`
- `stone bridge.png`
- `midmountain.png`
- `farmountain.png`

Scene2 继续使用独立的 `battle_screen_scene2.tscn`。角色素材、角色尺寸、战斗逻辑、UI、P0 角色倒影与 Scene2 专属角色环境光不变；默认 Scene1 不变。

## 素材清理

四张输入图当前均为不透明 PNG，白色或白灰棋盘格已经烘进 RGB。输入文件保留在 `assets/import/`，运行时使用清底后的正式资产：

| 输入 | 清底裁切后的预期尺寸 | 正式资产 |
|---|---:|---|
| `blossomtree.png` | 208×125 | `scene2_blossom_tree.png` |
| `stone bridge.png` | 262×64 | `scene2_stone_bridge.png` |
| `midmountain.png` | 1672×752 | `scene2_mid_mountain.png` |
| `farmountain.png` | 1608×508 | `scene2_far_mountain.png` |

使用项目既有的白底/棋盘格转 Alpha 工具完成清底与裁切；正式文件必须具备真 Alpha，不得残留白框或棋盘格。Godot 使用 Lossless、无 mipmap、Nearest。

## 尺寸与位置

### 石桥

- 统一放大 7×，显示尺寸 `1834×448`，禁止横向单独拉伸。
- 初始矩形：`(67,647)-(1901,1095)`。
- 该位置使 P1、P2 的脚底分别落在原图两段高度接近的草石桥面上。
- 运行时截图后只允许以整数屏幕像素微调位置；不改变角色位置。

### 桃树

- 统一放大 3×，显示尺寸 `624×375`。
- 初始矩形：`(1240,370)-(1864,745)`。
- 树根落在桥面附近；树冠保持在右侧中景，不修改角色或武器轮廓。
- 新素材先按自身轮廓接入，不要求匹配旧桃树矩形。

### Far Mountain

- 原生 1×显示，尺寸 `1608×508`。
- 初始矩形：`(156,212)-(1764,720)`。
- 作为天空之后的最远山层，视差系数 `0.04`。

### Mid Mountain

- 原生 1×显示，尺寸 `1672×752`。
- 初始矩形：`(124,98)-(1796,850)`。
- 位于 Far Mountain 之后、山门和瀑布之前，视差系数 `0.08`。

所有矩形均为首轮运行时基线，而不是必须匹配旧版素材的兼容框。最终只根据 1920×1080 实机画面微调。

## 分层

Scene2 相关顺序调整为：

1. Sky / ValleyGlow
2. FarMountain
3. MidMountain
4. WaterfallUpper
5. MountainGate
6. WaterfallMiddle / MountainLeft / HorizonHaze
7. BlossomTree
8. WaterfallLower / DistantWater
9. StoneBridge
10. River / 角色倒影 / 前景效果

新 Far/Mid Mountain 替换上一版 `FarMountainBack/Mid/Near` 三张 `*_px2` 远山，不与其叠成五层。山体通过透明度、色值和视差建立深度，禁止对新像素轮廓施加模糊。

## 被否定 P1 的清理边界

- 删除不再引用的三张旧远山 `*_px2` 衍生件。
- 删除不再引用的旧桃树、旧石桥 `*_px2` 衍生件。
- 更新或移除只服务于这些衍生件的清单和归一脚本。
- P0 的角色倒影、角色专属环境光、阴影色和补光不得回退。
- 其他现有 Scene2 山门、左山、三段瀑布、河面和 UI 不在本次替换范围内。

## 验收

1. Scene2 实机截图中不存在白底、棋盘格或白边。
2. 双方角色脚底均与新石桥桥面接触，不悬空、不明显陷入。
3. 桃树根部不悬空，角色头部、身体和武器主轮廓可辨。
4. Far/Mid Mountain 是两个独立节点，层级和视差正确，不遮盖 UI 或角色。
5. 新山体中央谷口继续给三段瀑布留出通道。
6. Scene2 的角色几何与既有测试契约不变。
7. 默认 `battle_screen.tscn` 仍加载 Scene1；Scene2 独立入口运行正常。
8. Godot 全量测试通过，并分别生成 Scene1、Scene2 运行时截图。
