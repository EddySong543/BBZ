# Midjourney — 版本参考（美术出图工具）

> ## ⛔ 已弃用（2026-07-12 Eddy 定·仅溯源）
> **全部美术出图已转 GPT Image 2**（同日先收窄为"仅立绘线"，当晚扩为全线转）。现行真相源=`design/gpt-image-reference.md`。本文保留作历史溯源，⛔ 不再据此生成新 prompt。
>
> **用途（历史）**：本项目所有 MJ 提示词生成前必读的版本真相源（模式同 `docs/engine-reference/godot/VERSION.md`）。
> **最后验证**：2026-07-12（WebSearch + 官方 updates 页）。

| 字段 | 值 |
|------|-----|
| **当前默认版本** | **V8.1**（2026-06-10 起成为默认；V8.0 将退役） |
| **版本时间线** | V7（2025-06 默认）→ V8 Alpha（2026-03-17）→ V8.1（2026-04-30 上线 web）→ V8.2 开发中（`--preview` 可试） |
| **LLM 知识截止** | 2026-01 —— **模型训练数据只覆盖到 V7**。V8/V8.1 全部在截止之后 |
| **风险等级** | 中 — 美学"承袭 V7 精神"，参数大体延续，但新旋钮与写法建议模型默认不知道 |

## ⛔ 硬规：提示词版本纪律

1. **所有新生成的 MJ 提示词一律按 V8.1 写**，句尾显式带 `--v 8.1`（防止账号设置漂移到旧版）。⛔ 不再按 V7 习惯默认输出。
2. 生成前若距"最后验证"超过约 2 个月，先 WebSearch 确认默认版本有没有再变（V8.2 随时可能转正）。

## V8.1 相对 V7 的关键差异（写 prompt 时用得上的）

- **指令遵循强得多，官方鼓励写长、写具体**——V7 时代"短词堆砌"的省字习惯可以放开，直接写完整描述句。
- **美学延续 V7**（"in the spirit of V7"），不必因换版本重调已验收的风格词。
- **文字渲染大幅变好**（对本项目无用——资产铁律=资产上禁止画字，见 ui-asset-spec §0.1）。
- **速度 4-5 倍**；标准档质量≈V7 draft 档。
- **raw 模式**：V8 写法 `--raw`（V7 旧写 `--style raw`；首次实操以实测为准，两种写法都试一下）。照片感/精确控制场景官方建议直接上 `--raw` 或参考图。

## 参数速查（2026-07 验证状态）

| 参数 | 状态 | 说明 |
|------|------|------|
| `--v 8.1` | ✅ | 显式锁版本，硬规必带 |
| `--ar` | ✅ | 画幅比，用法不变 |
| `--hd` / `--sd` | 🆕 | HD ≈2K 原生出图（免 upscale·UI 资产/海报立绘建议用）；SD=标准档 |
| `--q 4` | 🆕 | 复杂多元素构图的连贯性增强，**4 倍成本**，仅复杂场景图用 |
| `--draft` | 🆕 | 一次出 24 张低清草图（半价快时）→ 选中 Vary 出全清。**探方向/概念稿海选神器** |
| `--preview` | 🆕 | 路由到开发中的 V8.2，尝鲜用 |
| `--sref` + `--sw` | ✅ | 风格参考，V8.1 头牌稳定性改进之一（moodboard 同） |
| `--oref` + `--ow` | ✅ | 全能参考（V7 引入）。`--ow` 0-1000 默认≈100；**400-600 强锁角色长相**（英雄立绘系列一致性用）；25-75 只借氛围不锁脸 |
| 图像提示词 + 图像权重 | ✅ | V8.1 已恢复；超长提示自动触发官方 Prompt Shortener |
| `--raw` / `--chaos` / `--weird` / `--exp` / `--stylize` | ✅ | 延续可用 |
| `--niji` | ❓ | 未查到 niji 对应 V8 的更新，niji 线现状**待查证**（本项目暂未用 niji，不阻塞） |

## 本项目的 prompt 落点（生成时同步遵守）

- **木骨纸芯 UI 资产**：公共前缀见 `design/ui-asset-spec-wood-paper.md` §0.5（已更新为 V8.1）。
- **英雄高清厚涂立绘**：系列一致性用 `--oref`（ow 400-600 锁角色）+ `--sref` 锁画风；出图上 `--hd`。
- **远征怪物**：挂点=monsters.json `art` 字段（见 design/expedition-monsters.md）。
- **概念稿海选**：先 `--draft` 24 连抽探方向，选中再 Vary 出全清——省额度（规格书"F6 两连否即停产"的判断点前多一层保险）。

## 验证来源

- 官方更新日志：https://updates.midjourney.com/v8-alpha/ ｜ https://updates.midjourney.com/v8-1-alpha/
- 官方文档（Version 页·2026-07-12 访问 403，走缓存/第三方转述）：https://docs.midjourney.com/hc/en-us/articles/32199405667853-Version
- 第三方整理：https://felloai.com/midjourney-v8-1-review/ ｜ https://wavespeed.ai/blog/posts/what-is-midjourney-v8-features-pricing-how-to-use-2026/ ｜ https://www.ud.hk/en/blogs/insight/article/2026-05-13-midjourney-v81-power-guide ｜ https://evolink.ai/midjourney-v8-1
