# 波波攒之王 — 文档索引

> 全项目文档的**统一入口**。文档分散在 `design/`（游戏设计）、`docs/`（技术/流程）、`docs/engine-reference/`（引擎参考）三处，本页按系统 + 分类编目，便于一眼看全。
>
> **项目阶段**：轻量个人项目，文档从简、随玩法迭代更新（不为治理冻结开发）。
>
> **当前快照**：v4 战斗核心已收官 —— 单一 `BattleCore`，主流程「标题 → 2 步同时盲选选人 → 战斗」完整可玩；24 英雄（h01–h24）+ 221 测试全绿（668 断言）；h01–h24 美术已导入。

---

## 按系统导航

| 系统 | 代码位置 | 设计文档 | 架构/技术文档 |
|------|---------|---------|--------------|
| **战斗核心** | `src/battle/battle_core.gd` | `design/gdd/game-concept.md` §3-5（规则/公式/边界） | `ADR-002`（v4 架构）· `ADR-001`（边界·v3 史）· `battlecore-risk-notes.md` |
| **英雄技能** | `src/battle/skills/*.gd`（24）· `hero_skill.gd` | `design/heroes.md`（逐英雄）· `design/heroes-schools.md`（框架/原语） | — |
| **英雄数据** | `assets/data/heroes/hXX.tres`（24） | `design/heroes.md` | — |
| **选人（BP）** | `src/ui/bp_screen.{gd,tscn}` | `game-concept.md` §3.4 · `heroes-schools.md` §8.3 | — |
| **战斗 UI / juice** | `src/ui/battle_screen.*` · `src/ui/components/` | `game-concept.md` §3 | `prototypes/juice_test/README.md`（juice 来源） |
| **美术管线** | `tools/import_hero_art.gd` · `assets/sprites/heroes/` | `design/art-pipeline-hero-animation.md`（A 方案） | — |
| **数值框架** | `assets/data/heroes/` · `battle_core.gd` 常量 | `heroes-schools.md` §8 · `game-concept.md` §4/§7 | — |
| **道具系统** | `src/battle/item_*.gd` · `src/battle/items/*.gd`（57 件） | `items-firstrelease.md`（首发真相源）· `build-design-framework.md` §2 | 图标管线 `tools/import_item_art.gd` |

---

## 全部文档编目

### 设计文档（`design/`）

| 文档 | 定位 |
|------|------|
| [`gdd/game-concept.md`](../design/gdd/game-concept.md) | **GDD 主文档** — 8 章节（概述/玩家幻想/规则/公式/边界/依赖/旋钮/验收），已对齐 v4 |
| [`heroes.md`](../design/heroes.md) | 24 英雄（h01–h24）逐英雄技能文案（HP / 技能类型 / 技能说明），玩家可见真相源（详值取自各 `.tres`） |
| [`heroes-schools.md`](../design/heroes-schools.md) | 英雄设计框架：流派 / 原语表 §5 / 流派子型空槽 §3.1 / 命名规范 §6.1 / 数值框架 §8 |
| [`art-pipeline-hero-animation.md`](../design/art-pipeline-hero-animation.md) | 美术管线 A 方案（静态立绘 + 代码 juice + idle + 武器分类斩击），剪纸绑定已否决 |
| [`build-design-framework.md`](../design/build-design-framework.md) | **设计纲领** — 资源三层 / 道具骨架 §2 / 标准值 §4 / 连携主定理 §6 / 元件类型 §7 / 反固化 §8 / 判据 §14 / 系统操作层 §15 |
| [`items-firstrelease.md`](../design/items-firstrelease.md) | **首发道具真相源** — 96 件（T1 31/T2 39/T3 26），与代码对齐 |
| [`items-list.md`](../design/items-list.md) | **后续已审批全集池**（首发见 items-firstrelease.md）— 含系统操作层（按 tier → 维度） |
| [`items.md`](../design/items.md) | **历史快照 · 已被取代**（2026-06-17 旧奇幻命名版·仅溯源；首发真相源见 `items-firstrelease.md`、审批全集见 `items-list.md`） |

### 技术 / 架构（`docs/architecture/`）

| 文档 | 定位 |
|------|------|
| [`ADR-002-battle-core-v4-architecture.md`](architecture/ADR-002-battle-core-v4-architecture.md) | **v4 战斗核心架构决议**（英雄重写，已全部落地） |
| [`ADR-001-battlecore-boundary.md`](architecture/ADR-001-battlecore-boundary.md) | BattleCore 职责边界（v3 时代历史决策，边界原则由 v4 延续） |
| [`ADR-003-item-system.md`](architecture/ADR-003-item-system.md) | 道具系统架构（槽位状态机 / 经济 / 结算序） |
| [`ADR-004-online-pvp-readiness.md`](architecture/ADR-004-online-pvp-readiness.md) | **联机 PvP 真相源**（权威模型 / 里程碑 M1-M2f / 迁移路线） |
| [`battlecore-risk-notes.md`](architecture/battlecore-risk-notes.md) | 短文档 — 关键隐式规则与未来重构原则 |

### 流程 / 协作（`docs/`）

| 文档 | 定位 |
|------|------|
| [`COLLABORATIVE-DESIGN-PRINCIPLE.md`](COLLABORATIVE-DESIGN-PRINCIPLE.md) | 协作设计协议（提问→选项→决定→草稿→审批→批量执行） |
| [`WORKFLOW-GUIDE.md`](WORKFLOW-GUIDE.md) | 完整工作流指南（代理架构从零到发布） |

### 引擎参考（`docs/engine-reference/`）

| 文档 | 定位 |
|------|------|
| [`godot/VERSION.md`](engine-reference/godot/VERSION.md) | Godot 4.7 版本锁定 + 知识缺口警告 + 迁移来源 |

### 测试真相源（`tests/`）

| 位置 | 定位 |
|------|------|
| `tests/unit/{battle,net,core,ui,expedition}/**/*.gd` | **当前行为的真相源**（GUT·精确数以实跑为准） |
| `tests/BEHAVIOR_NOTES.md` | 行为锁定笔记（含 v3 历史溯源） |

---

## 其他状态文件

- `production/session-state/active.md` — 活跃会话检查点（gitignored；中断后先读它恢复）。
- `~/.claude/.../memory/MEMORY.md` — 跨会话记忆索引（用户偏好 / 设计纪律 / 项目方向）。
- `CLAUDE.md` — 主配置（技术栈 / 目录结构 / 协调规则 / 编码标准）。
