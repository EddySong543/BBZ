# 波波攒之王 — 文档索引

> 全项目文档的**统一入口**。文档分散在 `design/`（游戏设计）、`docs/`（技术/流程）、`docs/engine-reference/`（引擎参考）三处，本页按系统 + 分类编目，便于一眼看全。
>
> **项目阶段**：轻量个人项目，文档从简、随玩法迭代更新（不为治理冻结开发）。
>
> **当前快照**：v4 战斗核心已收官 —— 单一 `BattleCore`，主流程「标题 → 2 步同时盲选选人 → 战斗」完整可玩；12 生肖 + 198 测试全绿（608 断言）；h01–h12 美术已导入。

---

## 按系统导航

| 系统 | 代码位置 | 设计文档 | 架构/技术文档 |
|------|---------|---------|--------------|
| **战斗核心** | `src/battle/battle_core.gd` | `design/gdd/game-concept.md` §3-5（规则/公式/边界） | `ADR-002`（v4 架构）· `ADR-001`（边界·v3 史）· `battlecore-risk-notes.md` |
| **英雄技能** | `src/battle/skills/*.gd`（12）· `hero_skill.gd` | `design/heroes.md`（逐英雄）· `design/heroes-schools.md`（框架/原语） | — |
| **英雄数据** | `assets/data/heroes/hXX.tres`（12） | `design/heroes.md` | — |
| **选人（BP）** | `src/ui/bp_screen.{gd,tscn}` | `game-concept.md` §3.4 · `heroes-schools.md` §8.3 | — |
| **战斗 UI / juice** | `src/ui/battle_screen.*` · `src/ui/components/` | `game-concept.md` §3 | `prototypes/juice_test/README.md`（juice 来源） |
| **美术管线** | `tools/import_hero_art.gd` · `assets/sprites/heroes/` | `design/art-pipeline-hero-animation.md`（A 方案） | — |
| **数值框架** | `assets/data/heroes/` · `battle_core.gd` 常量 | `heroes-schools.md` §8 · `game-concept.md` §4/§7 | — |
| **道具系统** | `src/battle/item_*.gd` · `src/battle/items/*.gd`（70 件） | `items-list.md`（清单真相源）· `build-design-framework.md` §2 | `items-reconciliation.md`（三方对账）· 图标管线 `tools/import_item_art.gd` |

---

## 全部文档编目

### 设计文档（`design/`）

| 文档 | 定位 |
|------|------|
| [`gdd/game-concept.md`](../design/gdd/game-concept.md) | **GDD 主文档** — 8 章节（概述/玩家幻想/规则/公式/边界/依赖/旋钮/验收），已对齐 v4 |
| [`heroes.md`](../design/heroes.md) | 12 生肖 8 字段决议 |
| [`heroes-schools.md`](../design/heroes-schools.md) | 英雄设计框架：流派 / 原语表 §5 / 流派子型空槽 §3.1 / 命名规范 §6.1 / 数值框架 §8 |
| [`art-pipeline-hero-animation.md`](../design/art-pipeline-hero-animation.md) | 美术管线 A 方案（静态立绘 + 代码 juice + idle + 武器分类斩击），剪纸绑定已否决 |
| [`build-design-framework.md`](../design/build-design-framework.md) | **设计纲领** — 资源三层 / 道具骨架 §2 / 标准值 §4 / 连携主定理 §6 / 元件类型 §7 / 反固化 §8 / 判据 §14 / 系统操作层 §15 |
| [`items-list.md`](../design/items-list.md) | **道具清单当前真相源** — 98 件 + 系统操作层（按 tier → 维度） |
| [`items-reconciliation.md`](../design/items-reconciliation.md) | 道具三方对账（items.md / items-list / 代码 分叉 + 归一建议） |
| [`items.md`](../design/items.md) | ⚠ 历史快照 · 已被 items-list 取代（2026-06-17 旧奇幻命名版，仅溯源） |

### 技术 / 架构（`docs/architecture/`）

| 文档 | 定位 |
|------|------|
| [`ADR-002-battle-core-v4-architecture.md`](architecture/ADR-002-battle-core-v4-architecture.md) | **v4 战斗核心架构决议**（英雄重写，已全部落地） |
| [`ADR-001-battlecore-boundary.md`](architecture/ADR-001-battlecore-boundary.md) | BattleCore 职责边界（v3 时代历史决策，边界原则由 v4 延续） |
| [`battlecore-risk-notes.md`](architecture/battlecore-risk-notes.md) | 短文档 — 关键隐式规则与未来重构原则 |

### 流程 / 协作（`docs/`）

| 文档 | 定位 |
|------|------|
| [`COLLABORATIVE-DESIGN-PRINCIPLE.md`](COLLABORATIVE-DESIGN-PRINCIPLE.md) | 协作设计协议（提问→选项→决定→草稿→审批→批量执行） |
| [`WORKFLOW-GUIDE.md`](WORKFLOW-GUIDE.md) | 完整工作流指南（代理架构从零到发布） |
| [`examples/`](examples/README.md) | 端到端协作会话示例 |

### 引擎参考（`docs/engine-reference/`）

| 文档 | 定位 |
|------|------|
| [`godot/VERSION.md`](engine-reference/godot/VERSION.md) | Godot 4.6.2 版本锁定 + 知识缺口警告 + 迁移来源 |

### 测试真相源（`tests/`）

| 位置 | 定位 |
|------|------|
| `tests/unit/battle/{v4,ai}/*.gd`（13 文件） | **当前 v4 行为的真相源**（GUT，198 测试 / 608 断言全绿） |
| `tests/BEHAVIOR_NOTES.md` | 行为锁定笔记（含 v3 历史溯源） |

---

## 其他状态文件

- `production/session-state/active.md` — 活跃会话检查点（gitignored；中断后先读它恢复）。
- `~/.claude/.../memory/MEMORY.md` — 跨会话记忆索引（用户偏好 / 设计纪律 / 项目方向）。
- `CLAUDE.md` — 主配置（技术栈 / 目录结构 / 协调规则 / 编码标准）。
