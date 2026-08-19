# GPT Image 2 — 版本参考＋全线美术 prompt 规则（美术出图工具）

> **用途**：**全项目美术出图的唯一真相源**。
> **分工硬规（2026-07-12 Eddy 定·当晚二次扩围）**：**全部美术出图一律用 GPT Image 2**——像素资产（idle 帧/图标/怪物/像素 UI 件）＋手绘 UI 件（木骨纸芯 A1-A7）＋英雄高清厚涂立绘，全线。**MJ 整线退役**（design/midjourney-reference.md 已标弃用·仅溯源）。
> **最后验证**：2026-07-12（WebSearch + 官方 API 文档/公告）。隔 1-2 个月大批出图前建议重验（模型迭代快）。

| 字段 | 值 |
|------|-----|
| **当前模型** | **gpt-image-2**（2026-04-21 发布·快照 `gpt-image-2-2026-04-21`·消费端名"ChatGPT Images 2.0"） |
| **版本时间线** | DALL-E 3 → gpt-image-1（2025-04）→ gpt-image-1.5（支持透明底）→ **gpt-image-2**（2026-04·思考模式·文字渲染 >99%·原生最高 2K） |
| **LLM 知识截止** | 2026-01 —— 模型训练数据只到 gpt-image-1。image-2 全部在截止之后 |
| **风险等级** | 中 — prompt 范式与 gpt-image-1 一脉（自然语言），但参数增删（⚠透明底被砍）模型默认不知道 |

## ⚠ 三个与 MJ 不同的地基认知

1. **范式换了**：MJ=关键词堆＋`--参数`尾巴；GPT=**自然语言完整句、没有任何 -- 参数**。指令遵循极强——约束直接写成明确的句子（"the background must be a single flat mid-gray color"），不要写关键词碎片。
2. **✅ 透明底可直出（Eddy 实测 2026-07-12·以实测为准）**：在 prompt 里明确要求 "fully transparent background (PNG with alpha)" 即可直出透明 PNG——**省掉整个抠底工序**（MJ 做不到的关键优势）。⚠ 注：部分三方 API 文档称 `background:"transparent"` 参数在 gpt-image-2 被移除——与实测矛盾，按实测走；若某次直出透明失败/被拒 → 兜底退回纯 mid-gray 平底出图后期抠。
3. **多轮编辑是它的杀手锏**：对话式改图（"把左侧火把去掉，其余不动"）替代 MJ 的 Vary 抽卡。⚠ 流程改定（2026-07-13 Eddy）：**出图一律 high 一步到位**——prompt 写透（尺寸/材质/装饰预算全给清），⛔ 不再走"草稿 low 海选"；对话增量改图只用于出图后纠偏。

## 参数速查（API·2026-07 验证）

| 参数 | 值 | 说明 |
|------|-----|------|
| `size` | 1024×1024 / 1792×1024 / 1024×1792 | 另有实验性 2K（最高 2560×1440）·比例范围 3:1～1:3 |
| `quality` | low / medium / high | 1024² 单图约 $0.006 / $0.053 / $0.211 —— **一律 high 一步到位**（2026-07-13 Eddy 改定·⛔草稿海选） |
| `n` | 1-8 | 批量出图；多图角色一致需思考模式（Plus/Pro） |
| `output_format` | png（默认）/ jpeg / webp | 像素资产恒 PNG（jpeg 压缩毁像素边） |
| `background` / 透明底 | ✅ 可直出（实测） | prompt 写明 "fully transparent background (PNG with alpha)"；三方文档称 API 参数被砍=与实测矛盾·以实测为准（见地基认知 2） |
| 参考图输入 | ✅ 多图 | 恒按最高保真处理（**编辑/参考流比纯生成贵**）·跨批锁风格用 |
| 思考模式 | Plus/Pro | 出图前推理自查·延迟 15-30s·多面板/多图一致性场景才开 |

ChatGPT 网页端＝同一模型（Images 2.0）：对话框直接贴 prompt；免费档=即时模式，思考模式要 Plus/Pro。

## ⛔ 硬规：提示词纪律（分三线·风格锚不同，管线纪律共用）

**共用纪律（三线全适用）**：
1. **风格锚（style anchor）置顶**——一段固定文字描述画风/调色板/禁止项，**每次出图原样贴在 prompt 最前**（一致性最有效手段）。三线各有锚文=模板 §A/§D/§E。
2. **背景默认直出透明底**：`rendered alone on a fully transparent background (PNG with alpha), nothing else in frame`——免抠底。失败/被拒才兜底退纯 mid-gray 平底后抠。
3. **调色板直接钉 hex**：指令遵循强，hex 写进句子里管用（"use only this palette: #2E1D12, #E0D1AD, #D4A94E"）。项目令牌以 `design/ui-design-system.md` 为准。
4. **资产铁律**：⛔ 资产上禁画任何文字（哪怕 image-2 文字渲染 99% 准——像素字永远是引擎渲的 Ark Pixel）；反花哨（无宝石/铆钉阵列/复杂浮雕）；统一顶光中性偏暖；投影不画进资产（引擎加）。
5. **一致性阶梯**：同批一致 → `n` 多图＋思考模式；跨批一致 → 已定稿资产当参考图喂回（注意高保真计费）；风格漂移 → 回查风格锚有没有被改动。
6. **迭代用对话不用重抽**：构图对了细节不对 → 直接说改哪（增量指令），别整段重写 prompt 重抽。
7. **色彩纪律（2026-07-13 Eddy）**：暖色自然系为基调；**慎用深色**——大面积深色禁、深色只留描边/勾线；⛔科幻冷色全禁（深蓝/靛紫/霓虹等）。UI 衬底禁深靛（[[ui-backdrop-no-deep-indigo]]）是先例，此条扩到全部出图。
8. **尺寸必须写进 prompt（2026-07-13 Eddy）**：正文写明目标像素网格（"designed on a strict N×M pixel grid"）＋游戏内实际使用尺寸（"final in-game size ≈ W×H px"）——防止产出无谓的高清大图（头像框教训）。出图画布仍选 1024/1792 档位，落位由管线（img_checker_to_alpha→img_crop→img_resize）规格化到目标档。
9. **小件笔画纪律（2026-07-13 悬停框/导航钮"糊"教训）**：装饰笔画粗细按**最终显示尺寸**算——**任何笔画 <2 成品像素必糊**。prompt 必带 "every stroke must be at least 2 (小件) / 3 (按钮) grid pixels thick — no hairline details anywhere"；设计网格直接声明为成品尺寸（如 224×56），别让模型在大网格上画出缩不下去的细节。角部装饰预算=**每角一个粗笔元素**（包角 L 括 / 回纹钩·头像框已验证形制），⛔ 细线回纹折（双转折细纹=糊源头）。
10. **调色板从家族定稿取色·⛔灰调中性色（2026-07-13 "厕纸"教训）**：UI 件面色必须继承已定稿资产——**奶油纸 #F0E2B4**（卷轴纸/悬停框"纸"）／**暖茶 #E8D2A0**（头像框骨面/按钮"板"）／**胡桃木深棕 #3A2B1E**（描边/轴杆）／**巧克力棕 #5C3A22**（装饰线）／**平头金 #D4A94E**（轴帽点睛）。⛔"中性灰调方便后期染色"（#B8AC96 之流）——灰+无纹=厕纸。染色需求不牺牲质感：稀有度优先走**文字墨色/局部定向换色**，⛔整图染（会毁木头和金）。同色系纹样（tone-on-tone 祥云/纸纹颗粒）是资产的价值，不许为管线方便砍掉。
11. **9-slice 平铺件面上禁渐变**：中段要横/竖平铺的件，面上严禁上下、左右渐变（平铺一次渐变重复一次=百叶窗接缝·导航钮方钮实测）——prompt 明写 "ABSOLUTELY NO top-to-bottom / left-to-right gradient"。管线兜底=`tools/img_flatten_rows.gd`（内部区逐行**逐通道**乘性归一·亮度+色相漂移一起拉平·边带不动）。
12. **满宽出图+整数倍降采样**：prompt 结尾写 "spanning the entire canvas width edge to edge"（贴满全宽）；落位=量边界→裁到整除区→NEAREST **整数倍**降采样。⚠ 非整数倍 NEAREST=边缘采样错位（导航钮右缘双线暗带实测）。
13. **写 prompt 前先回看同族定稿原图**：新 UI 件动笔前必 Read 已定稿资产原图（卷轴/头像框/牌匾/祥云签）对齐材质语言与纹样密度；构图控制复用 **"Composition lock (CRITICAL)"** 段式（卷轴 prompt 已验证的锁构图写法）。**形制/纹理漂移的终极解=参考图喂回**（2026-07-13 导航钮 v3 实证）：文字描述装饰形状容易被自由发挥（"粗逗号卷"→简笔画），改为**附已定稿资产当参考图**+逐图点名要什么（"image 1 锁纹理密度·image 2 锁回纹钩形制"）+禁形句（NOT a doodle, no curved strokes）一次通过。源档在 `assets/art_src/`（文件名=成品名·专供重跑管线与参考图喂回）。⚠ 反面：**参考图会泄漏特征**（2026-07-14 实证：小卷轴当材质参考→金轴帽被"借"进导航钮）——挂参考必逐图写明"只取什么、忽略什么"（"ignore its rollers and gold caps entirely"），或干脆不挂。
14. **修伪影必保丰富度（2026-07-14 悬停框三翻车·Eddy 点名硬教训）**：负面禁令会连带压死装饰与纹理——只堆 "NO…" 出图直接退化成**纯色图形、不再是 UI 组件**（末尾挂纯负面 doom-list 最致命：结尾位置权重最高=最后一句是"都别画"）。写法纪律：①**必备件编号枚举**——"This panel has exactly N visible features, all REQUIRED"，逐件成段写 "must be clearly present"；②**禁令就地配对**——负面约束写进对应正面段落内（"line work only — 周围纸色不变"），⛔ 全局禁令清单；③**结尾检查单必须双向**——must-have（各件齐且清晰可见）+ must-not（伪影），并明写 **"a bare flat rectangle is JUST AS WRONG as an over-decorated one"**；④物理关系动词也是伪影源——"held in a wooden frame" 之类实物语义会引来交界阴影，框要写成 "painted flat on the same plane"（§D 实物木工词禁令的延伸）。悬停框 v10 实证通过。
15. **小件出图范式=在役资产单参考+族语归位（2026-07-14 悬停框 v11/导航钮 v12 双件一次过·定为默认）**：新 UI 小件 ⛔纯文字自含 prompt（悬停框 v6-v10 两轮马拉松实证=只会出"泛 JRPG 面板"、对不齐家族）→ 默认**挂一张在役资产当参考图**（选"一张图带全所需要素"的·两件都用了牌匾）＋正文逐条点名 "From image 1 take ONLY: …／IGNORE: …" 防特征泄漏（§13 的默认化）。**对齐资产而非文档（Eddy 点名）**：①设计元素必须能指到一件在役资产（凭文档臆造=必翻车）；②调色板 hex 从资产**实测取**（取色扫描线 RLE）——实测：悬停框近黑框 `#130C08`／牌匾木棕带 `#7B4728`／纹线深巧克力 `#4F2B14`／茶金纸 `#F0D7A2`，与 §10 所记 `#3A2B1E`/`#5C3A22` 有偏差，**出图取色以资产实测为准**；③纸纹校准：资产真实纸纹=细而匀、近看有远看静，⛔"clearly present 5–8% mottling"式写法（往脏推），改写 "fine, quiet tone-on-tone grain … visible up close but calm at a glance"。

### 像素线专属（idle 帧/图标/怪物/像素 UI 件）

- **像素三件套正文必带**：`pixel art` ＋ 目标网格（"designed on a strict N×N pixel grid"）＋ `crisp hard-edged square pixels, no anti-aliasing, no blur, no gradient dithering`。
- **⛔ 别信"直出真像素"**：出图是"像素风"大画布，像素并不严格对齐网格——**真像素靠管线**：high 档 1024² 出图 → pixellab **整数倍降采样**到目标格（如 1024→256=÷4）＋调色板量化＋清边。⚠ 降采样倍数必须整数，目标尺寸定了再倒推出图构图占比。

### 手绘 UI 件线专属（木骨纸芯 A1-A7）

- **flat 2D 措辞纪律沿用 MJ 线教训**（[[mj-ui-asset-flat-2d-lessons]] 仍有效）：正文必带 "completely flat, seen perfectly straight-on like a flat scan, no perspective, no 3D depth, no bevels"；⛔ 禁实物木工词（cabinet/box/sill/plank/thickness——"厚"用毛边+叠页表达）。
- **拆件到"最小成立画面"**：合成图=原料采集田，纸区/木区切片重拼，坐标接缝不依赖模型。GPT 指令遵循比 MJ 强，可先试整件直出（负面约束写成句子），跑偏再退回拆件。
- 生产规格（尺寸/构图/验收）仍以 `design/ui-asset-spec-wood-paper.md` 为准；现役 GPT 版 prompt 也在该文件 A4 段。

### 立绘线专属（英雄高清厚涂）

- **风格**：高清厚涂数字绘画（painterly, visible thick brushwork），奇幻调性——⛔ 不走像素、⛔ 不走 furry/兽化（[[animal-core-theme-pivot]] 铁律）。
- **角色一致性**：把该英雄已定稿立绘 1-3 张当参考图喂（替代 MJ 的 oref），并在句中写明 "keep exactly the same character design, costume and painting style as the reference"。⚠ 参考图按高保真计费。
- 交付高清原图（战斗内显示尺寸由引擎缩放·钉脚底公式见 [[animal-core-theme-pivot]]）。

## 模板

**§A 像素线风格锚（每次置顶·可按件微调调色板行）**
```
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels on a strict grid, no anti-aliasing, no blur, no dithering gradients.
Warm top-down neutral lighting, no cast shadows painted into the asset.
Restrained ornament: no gems, no rivet arrays, no heavy embossing. No text
or lettering anywhere. The asset is rendered alone on a fully transparent
background (PNG with alpha), nothing else in frame.
```

**§B 像素单体资产/图标（示例：技能图标）**
```
[§A 风格锚]
Subject: a single skill icon of a crescent wind blade, designed on a strict
64×64 pixel grid, readable silhouette at small size, 2px dark outline,
palette limited to #2E1D12, #5C3F26, #E0D1AD, #D4A94E.
Output: one centered icon filling ~80% of the canvas, front view, flat, no
perspective.
```

**§C 像素角色/怪物 idle 单帧（战斗挂点 256px）**
```
[§A 风格锚]
Subject: a full-body idle pose of [怪物/角色描述], side-facing battle stance,
designed as a 256×256 pixel sprite, strong readable silhouette, feet planted
on an invisible ground line at the bottom edge, palette anchored to
[hex 列表].
Output: single character only, whole body in frame, fully transparent
background (PNG with alpha).
```

**§D 手绘 UI 件风格锚（木骨纸芯线·置顶用）**
```
Style anchor: flat 2D game UI asset for an oriental fantasy game, hand-painted
storybook style with warm, restrained elegance. Completely flat, seen perfectly
straight-on like a flat scan of an illustration — no perspective, no 3D depth,
no bevels, no cast shadows, not a photograph, not a product render. Restrained
ornament: no gems, no metal rivets, no text or lettering anywhere. The asset
must be rendered alone on a fully transparent background (PNG with alpha),
nothing else in frame.
```

**§E 英雄立绘风格锚（厚涂线·置顶用·配已定稿立绘参考图）**
```
Style anchor: high-detail character portrait for an oriental fantasy game,
painterly digital painting with visible thick brushwork and rich layered
color. Oriental fantasy costume and mood; heroic, restrained, no cartoon
exaggeration. Keep exactly the same character design, costume and painting
style as the attached reference images. Full-body or waist-up as specified,
rendered alone on a fully transparent background (PNG with alpha), no text
anywhere.
```

## 项目落点

- **管线**：出图（直出透明底）→ `assets/import` 暂存 → pixellab 降采样/量化/清边（抠底仅作兜底工序）→ 正式目录挂点（⛔ 禁直接引用暂存区）。
- **战斗 idle**：单帧 256px 画布·scale 2.0 定稿（改 scale 必按钉脚底公式联动·见 memory [[animal-core-theme-pivot]]）。
- **远征敌人**：旧 `monsters.json` 挂点已退役；正式素材挂点待区域生态与敌人数据结构确认后建立。
- **英雄高清立绘**：GPT §E 锚＋已定稿立绘当参考图锁角色（h01-h34 已导入的现役立绘就是参考源）。
- **木骨纸芯 UI 件（A1-A7）**：GPT §D 锚＋规格书 `design/ui-asset-spec-wood-paper.md`（现役 A4 GPT 版 prompt 在该文件 A4 段·尺寸/验收不变）。

## 验证来源

- 官方模型页：https://developers.openai.com/api/docs/models/gpt-image-2
- 官方公告（社区帖）：https://community.openai.com/t/introducing-gpt-image-2-available-today-in-the-api-and-codex/1379479
- ChatGPT Images 2.0 官宣：https://openai.com/index/introducing-chatgpt-images-2-0/
- 透明底"不支持"三方说法（⚠与 Eddy 2026-07-12 实测直出透明矛盾·以实测为准）：https://help.apiyi.com/en/gpt-image-2-transparent-background-not-supported-en.html
- 参数/定价第三方整理：https://www.buildfastwithai.com/blogs/chatgpt-images-2-0-gpt-image-2-2026 ｜ https://wavespeed.ai/blog/posts/gpt-image-2-api-guide/
- 游戏资产实践：https://www.seagames.com/blog/gpt-image-2-game-assets-seagames ｜ https://www.geniea.com/prompts/gpt-image-pixel-art-game-art
