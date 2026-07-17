# Boot 屏「对波者入景」美术资产规格书（草案 v1 · 2026-07-17）

> **状态**：方案 C 已定（Eddy 拍板）·本规格书=Eddy 出图生产清单。
> **场景一句话**：两位无名侠影在黎明前的山巅对波，能量波在两掌之间的天际撞出角力光墙。
> **风格锚**：全线 gpt-image-2（`design/gpt-image-reference.md` 为出图真相源）；像素密度与 battle 立绘同族（1 源像素 = 2 屏幕像素）；⛔ furry/动物图腾；剪影=匿名侠客原型，不指定英雄（冷+留白）。

## 1. 构图坐标（1920×1080 基准）

| 层 | 内容 | 关键坐标 | 来源 |
|---|---|---|---|
| L0 天幕 | 黎明前深空渐层+稀星+地平线一线暖 | 全屏 | 程序 |
| L1 远山 | 山影带·大气透视淡进天色 | 地平线 y≈820·山体 y 700-870 | 资产③ |
| L2 对波带 | 蓝红双波+角力光墙+火花电弧 | 带中心 y≈630·带高 ~140px | 程序（v3 shader 带状化） |
| L3 侠影 | 左蓝右红剪影·512px 高（256 源 ×2） | 脚线 y≈940·中心 x≈300 / 1620·掌高 y≈630 | 资产①② |
| L4 地台 | 近黑山岩檐带 | y 920-1080 | 资产④ |
| 标题 | 「波波攒」logo（任务 2 挂点） | 中心 y≈260·下方副标题 | 现有/任务 2 |
| 家具 | 版本号（左下）·©（右下） | Ark 12px 暗色 | 程序 |

## 2. 资产清单（4 件 · 全部透明底 PNG）

### ① 蓝方侠影 ×2 pose

| 字段 | 规格 |
|---|---|
| 画布 | 256×256 px·透明底 |
| 人高 | ~230 源像素·脚底贴画布底缘·左右居中 |
| 朝向 | 侧身**朝右** |
| pose A「攒」 | 马步/半弓步蓄力·双掌收于腰侧作抱球状（光团程序补） |
| pose B「波」 | 弓步前倾·双臂前伸双掌立推（对波发射姿） |
| 色 | **纯暗剪影单色**（近黑冷调如 `#0a0c12`）·允许少量布褶/发带镂空透光 |
| 命名 | `boot_duelist_blue_charge.png` / `boot_duelist_blue_cast.png` |

**验收标准**：① 缩到 50% 后轮廓仍一眼读出"人在蓄力/推掌"；② 两 pose 脚位同点、身形同高（程序切换不跳）；③ 剪影内部无灰阶渐变（rim light 程序上，资产不带光）。

**prompt 种子**（gpt-image-2·按 reference 惯例调整，**必备件**：飘动衣袂/束发或发带/清晰手掌姿态——只堆禁令会出素板）：
```
full-body pixel art silhouette sprite of a martial-arts cultivator, side profile
facing right, wide stance, both palms drawn back at the waist charging energy
(pose A) / lunging forward with both palms thrust out (pose B), flowing robe and
hair band in the wind, pure near-black solid silhouette, crisp readable outline,
a few small gaps for cloth folds, no face, no inner shading, flat 2D, no
perspective, transparent background, 256px retro JRPG pixel style
```

### ② 红方侠影 ×2 pose

同①规格，差异：朝向**朝左**；建议**不同剪影原型**（如斗笠+长袍 vs 蓝方束发披风——待 Eddy 定 A 问题）；命名 `boot_duelist_red_charge/cast.png`。

### ③ 远山剪影带

| 字段 | 规格 |
|---|---|
| 尺寸 | 1920×360·上缘透明 |
| 内容 | 连绵山影 2-3 重·单色深冷灰蓝（大气透视=程序再压对比） |
| 命名 | `boot_mountains_far.png` |
| 验收 | 山形错落不对称·无细节纹理（剪影即可）·可与 battle 远山并存不撞形 |

### ④ 地台山岩带

| 字段 | 规格 |
|---|---|
| 尺寸 | 1920×200·上缘透明 |
| 内容 | 近黑暖调山岩/崖沿·两侧微高中间平（站脚区 x 180-420 / 1500-1740 平整） |
| 命名 | `boot_ground_ledge.png` |
| 验收 | 上缘轮廓有石感起伏但不抢戏·侠影脚线 y≈940 处可自然踩实 |

## 3. 交付与落位

1. 原图入 `assets/import`（暂存区）→ 定稿改英文正式名入 `assets/art_src` 存档 + 正式目录（`assets/art/ui/boot/`，届时建）；
2. 程序侧挂点全部 Inspector 换资源即可（美术友好惯例·不回改 .gd）；
3. 远山/地台在资产到位前由程序剪影顶位（Eddy C 问题定夺）。

## 4. 程序侧配套（Claude 负责·资产无关可先行）

对波 shader 带状化（垂直包络+光墙/火花/电弧限高）；侠影挂点+阵营 rim light+推挤微动；攒蓄力光团（标题攒聚块同语言）；败方碎散演出（剪影打碎成像素块·攒的逆演出）；时间轴重编排（显形→攒→发波→撞击→僵持→连击→决堤）；标题上移 y≈260+版本号/© 家具字。转场波幕交棒零改。

## 5. 待 Eddy 拍板

- **A** 两侠影：两个不同剪影原型（荐）vs 同一剪影镜像；
- **B** 每人 pose：两张静帧（荐·微动程序补）vs 多帧动画；
- **C** 远山/地台：Eddy 出图 vs 程序顶位先看整体。
