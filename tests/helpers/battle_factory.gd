class_name BattleFactory
extends RefCounted

## ============================================================================
## 测试用 BattleCore 工厂
##
## 目标：让每个测试只用 1-2 行就能拿到一个干净的 BattleCore 实例，
##       把 Arrange 段的体积压到最小，让 Act / Assert 一目了然。
##
## 设计原则：
##   1. helper 不调 assert — 校验是测试本体的责任，helper 只搬数据。
##   2. helper 不修改 BattleCore 的代码路径 — 只通过公开字段/方法操作。
##   3. helper 自身**不**注入英雄技能 — `plain_battle()` 返回的英雄
##      全部 passive_id="" 且 hero_id 以 "test_" 开头，确保 BattleCore
##      里所有 `if hero_id == "hXX"` / `if passive_id == "xxx"` 分支都
##      不会被命中。这样基础动作测试结果不会被英雄技能污染。
## ============================================================================


## 返回 3v3 plain heroes 的 BattleCore，双方初始 HP 都为 [p1_hp]/[p2_hp]，
## 双方能量都为 0（与 BattleCore.setup 默认一致）。
##
## 测试要测 BASE 动作时用这个 — 保证零英雄技能干扰。
static func plain_battle(p1_hp: int = 10, p2_hp: int = 10) -> BattleCore:
	var p1: Array[HeroData] = []
	var p2: Array[HeroData] = []
	for i in range(3):
		p1.append(_make_plain_hero("test_p1_h%d" % i, "P1英雄%d" % (i + 1), p1_hp))
		p2.append(_make_plain_hero("test_p2_h%d" % i, "P2英雄%d" % (i + 1), p2_hp))
	var battle := BattleCore.new()
	battle.setup(p1, p2)
	return battle


## 直接设置某玩家当前能量（绕过攒回合）。
## 用于把战场推到测试想要的起点（例如想测 BIG_ATTACK 就先 set_energy(.., 5)）。
static func set_energy(battle: BattleCore, player: int, amount: int) -> void:
	battle.energy[player] = amount


## 让双方各 select 一个动作并立即结算一回合。
## 返回 resolve() 的结果 dict，供 assertion 用。
##
## 注意：如果某动作因能量不足被 select_action 拒绝（返回 false），
## selected_action 会保持 -1，导致 resolve() 内 _get_action_cost(p, -1)
## 抛 KeyError。这是 BattleCore 当前行为的一部分 — 测试要确保事前已
## set_energy 到足够支付动作成本。
static func choose_and_resolve(battle: BattleCore, p1_action: int, p2_action: int) -> Dictionary:
	battle.select_action(0, p1_action)
	battle.select_action(1, p2_action)
	return battle.resolve()


# --- internal ---


static func _make_plain_hero(id: String, hero_name: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id  # 以 "test_" 开头，避开 BattleCore 里所有 hero_id 字面量分支
	h.hero_name = hero_name
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	h.passive_id = ""  # 空 passive_id → 不触发 chenlong/xugou/haizhu/sichen/wuma 任一被动
	h.extra_action_id = -1
	return h
