# 战斗背包首批道具 Implementation Plan

> **历史实施计划，禁止作为现行规格继续执行。** 其中旧 1 能补充、抽后即用、免费使用与旧背包状态只描述迁移前版本；当前唯一入口见 [`2026-08-30-item-system-current-standard.md`](../specs/2026-08-30-item-system-current-standard.md)。

> **For agentic workers:** 本计划在当前会话内顺序执行，不启用子智能体。

**Goal:** 建立不破坏旧经济模式的最小战斗背包运行时，并完整实装寄存牌、押物票、回购券、保价封、应急箱、换签筒、听匣筒、承露盏和纳盈葫芦。

**Architecture:** `BattleCore` 持有双方背包物件、使用史和私有揭示记录；槽位保留物件唯一编号及临时标记。背包模式的普通抽取复用现有三选一流程，旧模式继续使用全局 T1 池并过滤背包专属道具。道具选择沿用 `item_slot_targets` 与 `item_slot_choices`，服务器生成所有私有候选。

**Tech Stack:** Godot 4、GDScript、GUT、现有 MatchRoom/MatchClient 权威联机结构。

## Global Constraints

- 新道具只操作自己的真实背包，不以全局道具池模拟背包。
- 未注入背包的旧战斗不得抽到 `requires_backpack` 道具。
- 玩家只能看到自己的完整背包；听匣筒揭示的数据只发给使用者。
- 新进入道具栏的普通抽取与换签结果锁定一回合；应急箱结果立即可用。
- 换签筒可以选择另一件任意非空道具，不要求其当前可用。
- 承露盏和纳盈葫芦均按半点精确 1:1 转换且不设上限。

---

### Task 1: 最小背包状态与核心行为

**Files:**
- Modify: `src/battle/battle_core.gd`
- Modify: `src/battle/item_effect.gd`
- Create: `tests/unit/battle/v4/test_items_backpack_batch.gd`
- Modify: `tests/unit/battle/v4/test_battle_snapshot.gd`

- [x] 写入九件道具的失败行为测试，以及背包抽取、放回、临时副本、私有揭示、clone/JSON 快照测试。
- [x] 在 `BattleCore` 增加背包初始化、实际物件三选一、返回、随机 T1 抽取、使用史与揭示接口。
- [x] 将天罗事务、回照镜反制、槽位消费和回合末清理统一接入物件返还与使用史。
- [x] 在 `_heal`、`_gain_energy` 增加本回合溢出转换钩子并阻止相互递归。
- [x] 运行定向 GUT，确认核心行为全部通过。

### Task 2: 目录、脚本、交互和联机

**Files:**
- Modify: `src/battle/item_catalog.gd`
- Create: `src/battle/items/t1_jicun_pai.gd`
- Create: `src/battle/items/t1_tingxia_tong.gd`
- Create: `src/battle/items/t2_yawu_piao.gd`
- Create: `src/battle/items/t2_huigou_quan.gd`
- Create: `src/battle/items/t2_baojia_feng.gd`
- Create: `src/battle/items/t2_yingji_xiang.gd`
- Create: `src/battle/items/t2_huanqian_tong.gd`
- Create: `src/battle/items/t2_chenglu_zhan.gd`
- Create: `src/battle/items/t2_naying_hulu.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/battle/ai/battle_ai.gd`
- Modify: `src/net/net_protocol.gd`
- Modify: `src/net/match_client.gd`
- Modify: `src/net/match_room.gd`

- [x] 将九件正式数据加入目录并按完整无声调拼音排序。
- [x] 编写无状态 ItemEffect 脚本，只通过 BattleCore 公共接口结算。
- [x] 扩展己方槽、敌方槽和私有三选一目标流程；取消时不得污染真实战局。
- [x] 让联机服务器权威生成回购和换签候选，快照按接收者隐藏对方背包真相。
- [x] 为 AI 增加目标、候选与防浪费规则，并运行 UI/AI/网络定向测试。

### Task 3: 真相源、资产与验证

**Files:**
- Modify: `design/items-firstrelease.md`
- Modify: `design/items-list.md`
- Modify: `design/items.md`
- Modify: `design/reference-game-item-predesign.md`
- Modify: `design/pvp-backpack-run.md`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `assets/sprites/items/_name_id_map.md`
- Create: `assets/sprites/items/<九件占位图>.png`

- [x] 同步正式文案、计数、通过状态、运行边界和存疑项评审结论。
- [x] 生成九张独立可替换的占位图并执行 Godot Import。
- [x] 运行目录、核心、AI、UI、联机定向 GUT，再运行全量 GUT。
- [x] 对涉及三选一与槽目标的 UI 做 1920×1080 实际交互验证。
- [x] 执行 `git diff --check`，确认不覆盖当前工作区其他任务改动且不 commit/push。
