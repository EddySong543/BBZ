# Godot 引擎 — 版本参考

| 字段 | 值 |
|------|-----|
| **引擎版本** | Godot 4.7（本机 Steam 版已升级·2026-06-19） |
| **发布日期** | 2026 年（具体待查证·超出 LLM 知识截止） |
| **项目锁定版本** | 2026-06-19（从 4.6.2 升级） |
| **文档最后验证** | 2026-06-19（仅更新版本号；4.7 具体 API 变更待查证） |
| **LLM 知识截止** | 2026 年 1 月 |
| **风险等级** | 高 — 4.7 在知识截止后发布，具体变更模型不了解；目录内参考快照仍为 4.6 |

## 知识缺口警告

LLM 训练数据仅覆盖到 Godot ~4.3。4.4 / 4.5 / 4.6 / **4.7** 均在知识截止之后、引入重大变更，模型不了解这些内容。⚠ **本目录下的 API 参考快照基于 4.6、尚未针对 4.7 验证** —— 建议 Godot API 调用前先查官方 4.7 文档 / 迁移指南（或跑 `/setup-engine godot 4.7` 重新拉取参考快照）。

## 版本时间线

| 版本 | 发布 | 关键变更 |
|------|------|----------|
| 4.4 | 2025 年中 | Jolt 物理选项、FileAccess 返回类型、着色器纹理类型变更 |
| 4.5 | 2025 年末 | AccessKit 无障碍、可变参数、@abstract、着色器烘焙器、SMAA |
| 4.6 | 2026 年 1 月 | Jolt 默认物理、辉光重做、D3D12 默认、IK 回归、LibGodot |
| 4.6.2 | 2026 年 4 月 | 维护版本，稳定性修复 |
| **4.7** | 2026 年（待查证） | ⚠ 关键变更**待查证**（超出知识截止；见官方发布说明 / 4.6→4.7 迁移指南） |

## 验证来源

- 官方文档：https://docs.godotengine.org/en/stable/
- 4.6→4.7 迁移指南：https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html
- 4.5→4.6 迁移指南：https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 迁移指南：https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 更新日志：https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- 发布说明：https://godotengine.org/releases/4.7/
