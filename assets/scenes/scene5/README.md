# Scene5 素材接入契约

Scene5 是独立的 1920×1080 金黄稻田战斗场景变体。当前已经接入正式天空、天空叠层、程序化像素云、远处麦穗、中景稻田、战斗地面与近景麦穗；
后续素材继续在现有直编节点上替换或补充，不要复制 UI、人物或战斗逻辑。

## 正式素材槽

| Scene5 节点 | 建议正式文件 | 内容与透明要求 | 视差系数 |
|---|---|---|---:|
| `Sky` | `scene5_sky.png` | 576×324 不透明像素天空；nearest 整屏放大 | 0.10 |
| `SkyOverlay` | `scene5_sky_overlay.png` | 576×324 透明天空色雾叠层；与天空同画幅 | 0.12 |
| `UpperCloud/CloudMain` | 程序化像素云 | 单层慢速左向右云带；保留轮廓并做相邻像素时间混合 | 0.16 |
| `HorizonHaze` | 程序化渐变 | 天空与远田之间的低对比空气透视 | 0.22 |
| `DistantWheat` | `scene5_distant_field.png` | `farbg.png` 正式化后的透明极远稻田；按原透明画布整层接入，不再裁切重复 | 0.25 |
| `MidFarWheat` | `scene5_far_wheat.png` 派生层 | 中远景压缩轮廓；独立调色、相位和弱风场响应 | 0.32 |
| `FarWheat` | `scene5_far_wheat.png` | 267×174 透明中景麦穗带；保留用户手调构图 | 0.40 |
| `FarWheatCoverBack` | `scene5_far_wheat.png` 派生层 | 保留的后侧覆盖层；已删除的 `FarWheatCoverFront` 不得恢复 | 0.46 |
| `MidFieldHaze` | 程序化渐变 | 分隔远田、人物平面与前景麦穗 | 0.56 |
| `Atmosphere` | 程序化渐变 | 1920×1080 暖色空气透视与底部压暗 | 0.65 |
| `BattlePlatform` | `scene5_ground.png` | 211×161 透明地表；2× nearest 横向铺展，有效地面顶缘对齐人物脚底 Y=748 | 1.00 |
| `NearWheatLeft` | `scene5_near_wheat.png` | 228×152 近景麦穗；保留用户手调位置与 3×/2.5× 比例 | 1.22 |

所有主层必须保持同一画布、同一左上原点和相同相机构图，禁止在背景图中烘焙人物、HUD 或按钮。
PNG 导入后使用 nearest、无 mipmap；透明层保留 alpha，并检查边缘无黑边。

## UI 与人物流程

- `battle_screen5.tscn` 直接继承 `battle_screen_base.tscn`。
- P1/P2 人物继续由 `BattleSetup`、英雄 `.tres` 与 `CharacterDisplay` 自动加载，不在 Scene5 内复制人物节点。
- HUD、操作按钮、计时器、替补切换、受击和战斗输入继续使用成熟 Battle Screen 行为。
- P1/P2 保持 `CharacterDisplay` 的统一待机循环公式，不为 Scene5 单独覆盖动画速度。
- Scene5 的暖色人物光照、暖褐接触阴影与 PostFX 仅在 `battle_screen5.tscn` 局部覆盖。
- `WorldForegroundOccluder` 在运行时进入 `WorldGroup` 并排在人物之后；它只绘制近景麦穗下半段，负责遮住脚部接触阴影，同时持续同步 `NearWheatLeft` 的视差变换。

## 风场与战斗响应

- `MidFarWheat`、`FarWheat`、`FarWheatCoverBack` 与 `NearWheatLeft` 使用同一像素取样风场，但拥有不同摆幅、速度和相位；近景更明显，远中景更慢。
- `AmbientChaff` 常态维持 12 组可读麦芒，位于人物后方，不覆盖 HUD。
- `BattleStage.battle_response_requested` 复用既有 `stage.shake()` 节拍；命中、重击和格挡会让 `WindField` 提高麦穗弯折并触发一次定向 `GustChaff`，随后按真实时间在 1.35 秒内以先快后慢曲线恢复，不被命中顿帧拖长。
- `WorldForegroundOccluder` 注册到同一风场控制器，遮挡层和原近景麦穗共享相同风向与响应强度，避免人物脚边出现静止复制层。

## 导入步骤

1. 将新的正式 PNG 放入本目录，并采用上表文件名；天空、天空叠层、极远稻田、麦穗、地面、近景和麦芒图集均已正式化。旧道路、旧极远稻田和旧云图片保留但不再被 Scene5 引用。
2. 等待 Godot 生成对应 `.import` 文件。
3. 在 `src/ui/scenes/scene5.tscn` 中直接替换同名节点纹理；不要恢复已经移除的草图前景占位层。
4. 保留节点名、层级、`parallax_factor`、anchors、nearest 过滤和 1920×1080 对齐。
5. 运行 `tools/scene5_framework_probe.tscn` 检查静态构图与视差同步，再运行 `tools/scene5_wind_probe.tscn` 检查常态风、命中强风和恢复阶段的分时截图。
