# 传说道具整体优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use the available multi-agent workflow to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 Eddy 已确认的 17 件传说道具机制一次性更新正式数据、结算、联机、AI、UI、测试与设计文档。

**Architecture:** 保留 `ItemCatalog -> ItemEffect -> BattleCore` 的成熟分层。一次性效果继续进入 `item_uses`；跨回合效果统一登记到 `relics`，同名件通过状态合并延长次数而不在同一次触发中重复乘算。所有“攻击”只认一次完整的基础「波/大波」，持久状态由权威快照同步并复用英雄头像悬停提示。

**Tech Stack:** Godot 4.x、GDScript、GUT、现有 MatchRoom 权威联机协议、`tools/run_godot.ps1`。

## Global Constraints

- 严格采用用户确认的玩家文案、数值与条件，不追加平衡条件。
- 半点制：1 点生命/伤害/护盾/能量 = 2 个内部单位。
- “攻击”仅指基础「波/大波」；攻击型主动技、道具伤害、追击不冒充攻击。
- h13 拆分「大波」仍是一整次攻击；整次总伤害、成功防御和附加效果次数只结算一次。
- 梦蝶只交换当前能量和三格道具栏，不交换生命、能量上限、英雄状态或遗物。
- 不关闭任何既有 Godot 进程；所有 Godot 自动化只走 `tools/run_godot.ps1`。
- 不覆盖工作区中英雄、场景、远征等其他任务改动；不 commit、不 push。

---

### Task 1: 固定 T3 正式目录与真相源

**Files:**
- Modify: `src/battle/item_catalog.gd`
- Modify: `assets/i18n/strings_zh.csv`
- Modify: `design/items-firstrelease.md`
- Modify: `design/items-list.md`
- Modify: `design/items.md`
- Modify: `design/build-design-framework.md`
- Test: `tests/unit/battle/v4/test_items_t1.gd`
- Test: `tests/unit/battle/v4/test_items_economy.gd`

**Interfaces:**
- Produces: 17 个 T3 `ItemData` 的唯一正式文案、`params`、`ev=6` 与 relic 合并策略参数。
- Consumes: 现有 57 件正式池和既定拼音展示顺序，不改名称、图标或数量。

- [ ] 将确认文案写入 `_DEF`：不动明王甲 3 次防御转甲；鹤顶红下一次毒爆逐层 +0.5；聚鼎三花下 3 次攻击命中额外触发附加效果；梦蝶交换能量/道具栏；末日火种永久残局增益；青元宝莲 3 回合每回合 +1.5 能；噬心钉攻击 +1、断攻失去 3 生命并结束；续命香 3 回合每回合回复 1.5；至臻剑意波命中后下回合首个大波免费；周天罡气“本回合无敌。”。
- [ ] 将上等生命药水改为回复 3 点、上等法力药水改为立即获得 4 点；龙息、不死鸟羽毛、停龙剑保留已通过主体机制并校正文案边界。
- [ ] 将 T3 估值统一提升到新层级基准，保持 57=19/21/17 与 `DISPLAY_ORDER` 不变。
- [ ] 同步首发真相源、审批全集、历史快照状态、构筑框架和中文 i18n；不新建关键词。
- [ ] 更新目录断言，锁定所有最终玩家文案、数值、数量和顺序。

### Task 2: 建立可追踪的遗物触发接口

**Files:**
- Modify: `src/battle/item_effect.gd`
- Modify: `src/battle/battle_core.gd`
- Test: `tests/unit/battle/v4/test_items_relics.gd`
- Create: `tests/unit/battle/v4/test_items_t3_rebase_core.gd`

**Interfaces:**
- Produces: `relic_on_activate(...)`、`relic_on_defense_resolved(...)`、带毒层参数的 `relic_poison_detonate_bonus(...)`，以及同名遗物登记/合并入口。
- Produces: 基础攻击 `context` 新增 `raw_damage_total`、`blocked`、`blocked_by_big_defend`，供一次完整攻击结束后消费。

- [ ] 先写失败测试，覆盖同名不重复乘算、h13 两段只触发一次、被挡/落空/取消的次数消费和 clone/snapshot 独立。
- [ ] 在 `ItemEffect` 增加无状态默认 hook：

```gdscript
func relic_on_activate(_battle: BattleCore, _player: int, _data: ItemData,
		_state: Dictionary, _events: Array) -> void:
	pass

func relic_on_defense_resolved(_battle: BattleCore, _player: int,
		_context: Dictionary, _data: ItemData, _state: Dictionary,
		_events: Array) -> void:
	pass
```

- [ ] 用 `_register_relic(player, data, events)` 合并同 ID 状态；次数型追加 `charges`，回合型追加 `turns`，唯一型不制造第二个并行乘区。
- [ ] 在 `_apply_damage` 只记录防御结果，在 Phase 4.7 对整次基础攻击汇总后调用防守方遗物 hook，保证不动明王甲按防御门前整次总伤害只加一次护盾。
- [ ] 遗物回合末效果在死亡替补完成后作用于真实出战英雄；`_heal` 禁止治疗 0HP 英雄，噬心钉反噬致死后再走一次统一死亡链。
- [ ] 运行 T3 核心定向 GUT，确认 RED 后实现 GREEN。

### Task 3: 实现 17 件最终机制

**Files:**
- Modify: `src/battle/items/t3_budongmingwang.gd`
- Modify: `src/battle/items/t3_fali.gd`
- Modify: `src/battle/items/t3_hedinghong.gd`
- Modify: `src/battle/items/t3_jianyi.gd`
- Modify: `src/battle/items/t3_judingsanhua.gd`
- Modify: `src/battle/items/t3_longxi.gd`
- Modify: `src/battle/items/t3_mengdie.gd`
- Modify: `src/battle/items/t3_morihuozhong.gd`
- Modify: `src/battle/items/t3_qingyuanbaolian.gd`
- Modify: `src/battle/items/t3_shengming.gd`
- Modify: `src/battle/items/t3_shixinding.gd`
- Modify: `src/battle/items/t3_tianluodiwang.gd`
- Modify: `src/battle/items/t3_xumingxiang.gd`
- Modify: `src/battle/items/t3_yemingzhu.gd`
- Modify: `src/battle/items/t3_yiqi.gd`
- Modify: `src/battle/items/t3_yujin.gd`
- Keep behavior: `src/battle/items/t3_tinglong.gd`

**Interfaces:**
- Consumes: Task 2 遗物 hook 与整次攻击 context。
- Produces: 每件脚本只实现自身规则，不在 `BattleCore` 用 ID 硬编码常规效果。

- [ ] 不动明王甲登记 3 次；成功防御整次基础攻击后获得 `raw_damage_total` 护盾并减 1 次。
- [ ] 鹤顶红登记 1 次毒爆；首次毒爆追加 `layers` 个半点并消费。
- [ ] 聚鼎三花登记 3 次攻击；每回合只给整次基础攻击追加 1 次命中附加效果，攻击行动无论命中与否都消费本次。
- [ ] 噬心钉存续时给每次基础攻击总伤 +2 半点；当回合未攻击则当前出战失去 6 半点并移除。
- [ ] 末日火种改为永久唯一遗物；仅剩一名英雄时基础攻击总伤 +2 半点，选择防/大防即给出战 +2 半盾。
- [ ] 青元宝莲激活立刻获得 3 半能，之后两回合各获得 3 半能；续命香从激活回合末起连续三回合给当时存活出战回复 3 半血。
- [ ] 夜明珠登记 3 次玩家主动/星日免费切换；每次对敌方当前出战造成 2 半点普通伤害并给新出战 2 半盾，不响应追击、强制换位或死亡补位。
- [ ] 至臻剑意只在本回合原选招为「波」且整次攻击命中时武装 `free_big_attack_until_turn = turn + 1`；下一回合第一次实际「大波」费用为 0 并消费，逾期清除。
- [ ] 龙息只在整次「大波」确实被有效「大防」挡下时设置下回合力竭；防御降级、穿透或未真正挡下不触发。
- [ ] 梦蝶原子交换双方当前能量与完整 `slots`，不碰 HP/death/status/max energy/relics；上等药水、周天罡气和停龙剑按确认数值/既有机制运行。

### Task 4: 天罗地网的同回合权威结算

**Files:**
- Modify: `src/battle/battle_core.gd`
- Modify: `src/battle/items/t3_tianluodiwang.gd`
- Modify: `src/net/match_room.gd`
- Test: `tests/unit/battle/v4/test_items_t3_rebase_core.gd`
- Test: `tests/unit/net/test_match_room.gd`

**Interfaces:**
- Produces: 同回合道具提交事务快照与 `_resolve_tianluo_requests(events)`；对手已提交道具照常消耗，但所有效果（即时能量、燃料、升级、遗物登记、排队 hit）均回滚。
- Consumes: 圣贤书的“第一个非伤害道具效果无效”必须能够抵消天罗地网。

- [ ] 首件道具提交前保存本方能量、item_buffs、slots、relics、item_uses；记录本回合提交来源槽。
- [ ] 天罗在 `setup_pre` 只登记请求；双方保护性 setup 完成后统一解析，避免玩家序号决定胜负。
- [ ] 未被圣贤书抵消时恢复受害者提交前快照，再把其所有来源槽标为已使用，并锁死本回合主动、免费、强制切换；不留下未来 `item_lock`。
- [ ] 若取消的即时资源使已选行动不再付得起，权威核心将该行动回退为「攒」，且本地与联机走相同分支。
- [ ] MatchRoom 测试覆盖两种提交顺序、双方同时天罗、天罗对即时上等法力药水/点金石/熔炉/遗物、圣贤书反制和快照无污染。

### Task 5: AI、模拟、联机快照与玩家可见状态

**Files:**
- Modify: `src/battle/ai/battle_ai.gd`
- Modify: `src/battle/ai/battle_eval.gd`
- Modify: `src/battle/ai/battle_eval_v2.gd`
- Modify: `tools/sim/run_sim.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/unit/battle/ai/test_battle_ai_items.gd`
- Test: `tests/unit/battle/ai/test_battle_eval_v1.gd`
- Test: `tests/unit/battle/ai/test_battle_eval_v2.gd`
- Test: `tests/unit/battle/v4/test_battle_snapshot.gd`
- Test: `tests/unit/ui/test_battle_item_target_selection.gd`

**Interfaces:**
- Consumes: `relics[].state`、至臻剑意跨回合免耗、天罗/梦蝶的权威快照。
- Produces: 头像悬停中可查询的遗物名称、剩余次数/回合、噬心钉反噬警告、免费大波窗口；不新增常驻 HUD。

- [ ] AI 不在条件明显不成立时浪费一次性 T3，并正确估算残局火种、噬心钉断攻成本、防御转甲、免费大波、能量/回血遗物和天罗干扰价值。
- [ ] 模拟器分别统计一次性道具和遗物触发，而不是只统计 `item_uses`。
- [ ] 快照 round-trip 锁定 relic state、梦蝶交换后的槽内容和跨回合免费大波；私有道具候选仍不泄露。
- [ ] 扩展 `_hero_status_tip`，团队级持续效果只显示在实时出战头像；保留成熟战斗布局与交互。

### Task 6: 自检、导入、测试与 1920x1080 验证

**Files:**
- Modify as needed: 本计划中的测试/探针文件
- Create if needed: `tools/t3_item_rebase_probe.gd`
- Create if needed: `tools/t3_item_rebase_probe.gd.uid`
- Create if needed: `tools/t3_item_rebase_probe.tscn`

- [ ] 逐件自检：新基准、真实英雄 combo、反制、失败成本、三复制最坏情况、UI 负担、术语边界、历史撞车。
- [ ] 运行 `& .\tools\run_godot.ps1 -Mode Import`，要求无 SCRIPT/Parse 错误。
- [ ] 运行 T3/AI/网络/UI 定向 GUT，再运行 `& .\tools\run_godot.ps1 -Mode Test`，记录新鲜通过数与日志。
- [ ] 用 wrapper 运行 1920×1080 Battle Screen probe，实际检查悬停状态、三格道具、切换和结算后刷新，不修改已通过布局。
- [ ] 运行 `git diff --check` 并复核仅报告本批道具相关改动；确认无仍在运行的子智能体。
