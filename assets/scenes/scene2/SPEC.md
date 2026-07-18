# 场景 2 — 层山峻岭中的桃花源（Scene 2: Hidden Blossom Vale）

> Godot 场景：`src/ui/scenes/scene2.tscn`（复用 `src/ui/components/battle_stage.gd` 视差引擎·metadata `parallax_factor` 声明层深）。
> 画布 **1920×1080**，像素画。本目录存放本场景美术，命名 **`scene2_<部分>`**（小写下划线）。
> 立项（2026-07-18 Eddy）：scene2 同时为 **boot screen / main menu 重制**供层——山、雾、河、瓣四族件都可拆去复用。
> 当前状态 = **河流（程序定稿）+ 岸台（美术已入）+ 其余代码占位**，后续逐层换美术（编辑器拖 texture 即可，脚本零改）。

## 构图锚点（与 scene1 对齐·角色/镜头零改动直接换景）

| 锚点 | 值 | 说明 |
|------|-----|------|
| 角色站立线 | y ≈ 850 | 与 scene1 屋脊线同高（GroundBank 顶缘 832 + 草唇） |
| 构图焦点 | (960, ~430-600) | scene1=巨月 → scene2=**谷口**（三层山脊中央山口叠出纵深·谷中暖光） |
| 镜头对焦点 | (960, 600) | battle_stage `focus_point` 默认·不改 |
| 远景带 | y 260-760 | 山脊层视差 0.15-0.42（scene1 山带 0.18-0.35 同档） |
| 近前景 | y 800+ | 河 1.18 / 前雾 1.5 / 近瓣 1.45（scene1 近景 1.4-1.65 同档） |

## 分层清单（由远及近 = 树序 = 绘制序）

| 节点 | 视差 | 内容 | 状态 |
|------|------|------|------|
| `Sky` | 0 | 晨昏青玉渐变+桃色地平晕（night_sky shader 换参） | 🟡 程序占位 |
| `RidgeFar/Mid/Near` | 0.15/0.26/0.42 | **层山峻岭**：程序化 ridged 脊线剪影（`canvas_env_ridge`）·三层同心**中央山口**=谷口构图·山脚融雾 | 🟡 程序占位（可整层换贴图） |
| `ValleyGlow` | — | 谷中暖光（moon_halo shader 暖参·"桃源在谷里"的光信号） | 🟡 程序占位 |
| `HorizonHaze` | 0.5 | 暖雾横带（云雾锁山） | 🟡 复用件 |
| `PetalFar/Near` | 0.55/1.45 | 桃瓣飘落（远小密/近大疏·⚠占位=圆点粒子，待换花瓣贴图） | 🟡 程序占位 |
| `GroundBank`+`GroundBankMirror` | 1.0 | **岸台美术已入**（角色站立层）：`scene2_ground.png` 1254×783 草顶+泥身，顶缘钉 832=站立线不变。⚠ 原图**左右不接缝**（实测边列差 17.6 vs 图内基准 2.5）→ 用**镜像平铺**（第二块 `flip_h`）而非 STRETCH_TILE；⚠ 镜像必须用 `flip_h`，**不可用 scale.x=-1**（battle_stage 每帧改写 scale 会冲掉）。`self_modulate (0.6,0.55,0.54)` = 原图日光调压进本场暮色（见下方调色纪律） | ✅ 已实装 |
| `River` | 1.18 | **近景像素河流（招牌件·程序定稿）**：`canvas_env_pixel_river`——屏幕空间倒影+波纹扰动+色阶化+错相闪点+岸线亮边（Kingdom Two Crowns 水面技法方向的自研实现） | ✅ 程序定稿 |
| `FogFront` | 1.5 | 近前暖雾薄带 | 🟡 复用件 |

> 加新层 = 加 TextureRect/ColorRect 子节点 + 设 `metadata/parallax_factor` + 拖图（scene1 同规）。
> ⚠ 河流倒影只反射**树序在它之前**的层；角色在 stage 之后绘制=不入倒影（刻意：画面静、开销省）。

## 调色纪律

- 全台**低饱和**：青玉群山 + 暖纸光 + 灰粉桃瓣。**桃粉压灰压淡**——大面积艳粉/艳红会抢 P2 阵营红，艳蓝同理抢 P1（scene1 铁律延续）。
- 谷口暖光是全场唯一高亮暖点（对位 scene1 明月的冷白）。

## 快照自检

`godot --path . res://tools/scene2_shot_runner.tscn` → `D:/Game/BoBoZan/scene2_shot_a/b.png`（两帧 0.6s 距·验波光在动+零爬缝）。终审 Eddy F6。
