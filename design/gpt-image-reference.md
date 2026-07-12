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
3. **多轮编辑是它的杀手锏**：对话式改图（"把左侧火把去掉，其余不动"）替代 MJ 的 Vary 抽卡——**先草稿档抽方向，再对话微调，最后 high 档定稿**，比重抽省得多。

## 参数速查（API·2026-07 验证）

| 参数 | 值 | 说明 |
|------|-----|------|
| `size` | 1024×1024 / 1792×1024 / 1024×1792 | 另有实验性 2K（最高 2560×1440）·比例范围 3:1～1:3 |
| `quality` | low / medium / high | 1024² 单图约 $0.006 / $0.053 / $0.211 —— **草稿 low·定稿 high** |
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
- **远征怪物**：挂点=monsters.json `art` 字段。
- **英雄高清立绘**：GPT §E 锚＋已定稿立绘当参考图锁角色（h01-h34 已导入的现役立绘就是参考源）。
- **木骨纸芯 UI 件（A1-A7）**：GPT §D 锚＋规格书 `design/ui-asset-spec-wood-paper.md`（现役 A4 GPT 版 prompt 在该文件 A4 段·尺寸/验收不变）。

## 验证来源

- 官方模型页：https://developers.openai.com/api/docs/models/gpt-image-2
- 官方公告（社区帖）：https://community.openai.com/t/introducing-gpt-image-2-available-today-in-the-api-and-codex/1379479
- ChatGPT Images 2.0 官宣：https://openai.com/index/introducing-chatgpt-images-2-0/
- 透明底"不支持"三方说法（⚠与 Eddy 2026-07-12 实测直出透明矛盾·以实测为准）：https://help.apiyi.com/en/gpt-image-2-transparent-background-not-supported-en.html
- 参数/定价第三方整理：https://www.buildfastwithai.com/blogs/chatgpt-images-2-0-gpt-image-2-2026 ｜ https://wavespeed.ai/blog/posts/gpt-image-2-api-guide/
- 游戏资产实践：https://www.seagames.com/blog/gpt-image-2-game-assets-seagames ｜ https://www.geniea.com/prompts/gpt-image-pixel-art-game-art
