# 场景 1 — 午夜·武侠屋顶对决（Scene 1: Midnight Wuxia Rooftop Duel）

> Godot 场景：`src/ui/scenes/scene1.tscn`（复用 `src/ui/components/battle_stage.gd` 视差引擎）。
> 画布 **1920×1080**，像素画。本目录存放本场景的所有美术，命名 **`Scene1_<部分>`**。
> 新美术做好后丢进本目录，在编辑器里拖到对应 TextureRect 节点的 `texture` 即可替换占位，无需改脚本。
> 工程默认纹理过滤 = Nearest（`project.godot` 已设），像素画自动清晰，无需逐节点设置。

## 分层清单（由远及近）

| 节点 | 文件名 | 视差强度 | 内容 | 状态 |
|------|--------|---------|------|------|
| `Sky` | `Scene1_Sky.png` | 0.0 静止 | 夜空渐变（顶深靛→底近黑），可烘微弱星点 | 🟡 渐变占位 |
| `Stars`(可选) | `Scene1_Stars.png` | 0.06 | 稀疏星点 / 淡淡星座连线（呼应星座组英雄） | ⬜ 未做 |
| `Moon` | `Scene1_Moon.png` | 0.08 | 一轮明月（高悬偏右），可带柔光环 | 🟡 渐变占位 |
| `FarRooftops` | `Scene1_FarRooftops.png` | 0.18 | 远处屋脊/塔尖剪影，雾化 | ⬜ 未做 |
| `MidRooftops` | `Scene1_MidRooftops.png` | 0.32 | 近一层飞檐/灯笼/旗幡剪影（越近越暗） | ⬜ 未做 |
| `Rooftop` | `Scene1_Rooftop.png` | 1.0 同步 | **两人脚下的瓦屋脊台面**（角色站其上） | ✅ 已接入（400×160） |
| `Foreground`(可选) | `Scene1_Foreground.png` | 1.15 | 飘叶/浮尘/近景檐角虚焦（少量即可） | ⬜ 未做 |

> 加新层 = 在 `scene1.tscn` 里加一个 TextureRect 子节点、设 `metadata/parallax_factor`、拖图。

## 调色铁律

- 整台**冷调、中性、低饱和**（靛蓝午夜）。双方是 **蓝(P1) vs 红(P2)** 阵营色，背景掺大面积暖红/亮蓝会和英雄抢读。
- 明月可作小面积冷白/淡金暖点，OK。
- 不必在出图阶段把各层色调调到完美一致 —— 最终由场景里的 `MoonGrade`（CanvasModulate）统一拉进同一夜色。专注构图与内容即可。

## 当前对齐说明（待你目视微调）

`Scene1_Rooftop.png` 的**屋脊顶线 = 角色站立线**。`scene1.tscn` 里 `Rooftop` 暂放在
`offset_top=720`、5× 放大（2000×800，保持 2.5:1 不变形）。接入战斗后请在编辑器里
上下微调 `Rooftop.offset_top`，让屋脊正好接住两位角色的脚（角色脚底约 y≈850）。

## 生成提示词（像素画，喂 Retro Diffusion / Pixellab / Midjourney）

**整图氛围参考**（出概念图再拆层）：
> `pixel art, side-view fighting stage, two-fighter duel arena, east-asian tiled rooftop ridge as the floor, deep indigo midnight sky, large luminous full moon high to the right, faint constellation lines, distant rooftops silhouette in haze, cool desaturated moonlight palette, layered for parallax, no characters, wide 16:9`

**分层时**：把要的那层留 prompt、其余进 negative，强调 `transparent background, isolated, no characters`。例：
- 天空：`only midnight sky gradient deep indigo to black, subtle stars, no buildings, no moon, seamless`
- 明月：`only a full moon with soft glow, transparent background, isolated`
- 屋脊台面：`only east-asian tiled roof ridge top surface, side view, transparent background, no sky`

## 生成器去处

- **像素优先**：Retro Diffusion ｜ Pixellab.ai（可控尺寸+调色板，逐层出）｜ Aseprite（精修）
- **现成分层包**：CraftPix.net 搜 `parallax background pixel night/asian`｜itch.io 搜 `parallax pixel night rooftop`
- **拆整图为透明层**：Photopea（免费网页 PS）/ Krita / Photoshop
