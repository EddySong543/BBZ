extends GutTest

## ============================================================================
## 任务G 异步预想等价性契约（2026-07-09）
##   承诺：AI 异步预想（克隆上想 → 真局重放）与原同步直算【逐位一致】——不改判断/智慧。
##   ①plan_economy == decide + apply（拆分零语义变化）
##   ②克隆预想选招 == 同步直算选招（同 rng 起点）
##   ③真局重放经济落子 == 同步直算经济落子（同 rng 起点）
## ============================================================================

const HERO_DIR := "res://assets/data/heroes/"


func _team(ids: Array) -> Array:
	var t: Array = []
	for id in ids:
		t.append(load(HERO_DIR + str(id) + ".tres"))
	return t


## 推进到道具解锁后的中期局面（经济决策空间打开 = plan_economy 走完整候选搜索）。
func _mid_battle() -> BattleCore:
	var b := BattleCore.new()
	b.setup(_team(["h01", "h05", "h06"]), _team(["h02", "h09", "h12"]), 4242)
	b.econ_init()
	for i in range(6):
		b.select_action(0, ActionDef.Action.CHARGE)
		b.select_action(1, ActionDef.Action.CHARGE)
		b.resolve()
	return b


func test_ai_async_split_econ_matches_plan_economy() -> void:
	# Arrange：同一局面两份克隆 + 两个同种子 AI + 两个同种子经济 rng
	var base := _mid_battle()
	var ai1 := BattleAI.new(99, 2, 0, {})
	var ai2 := BattleAI.new(99, 2, 0, {})
	var r1 := RandomNumberGenerator.new()
	r1.seed = 7
	var r2 := RandomNumberGenerator.new()
	r2.seed = 7
	var b1: BattleCore = base.clone()
	var b2: BattleCore = base.clone()
	# Act：老整体路径 vs 新拆分路径
	ai1.plan_economy(b1, 1, r1)
	var up: int = ai2.plan_economy_decide(b2, 1)
	ai2.plan_economy_apply(b2, 1, r2, up)
	# Assert：经济落子逐位一致
	assert_eq(var_to_str(b1.slots[1]), var_to_str(b2.slots[1]), "槽状态逐位一致")
	assert_eq(b1.energy[1], b2.energy[1], "能量一致")


func test_ai_async_clone_think_replay_matches_sync() -> void:
	# Arrange：同步世界（当场直算）与异步世界（克隆预想+真局重放）从同一局面同一 rng 出发
	var base := _mid_battle()
	var ai_sync := BattleAI.new(99, 2, 0, {})
	var r_sync := RandomNumberGenerator.new()
	r_sync.seed = 7
	var b_sync: BattleCore = base.clone()
	# Act①同步世界：plan_economy → choose_action（原 _ai_pick 序）
	ai_sync.plan_economy(b_sync, 1, r_sync)
	var c_sync: Dictionary = ai_sync.choose_action(b_sync, 1)
	# Act②异步世界：预想 AI 从真 AI 快照起步·在克隆上想
	var ai_live := BattleAI.new(99, 2, 0, {})
	var ai_think := BattleAI.new(123456, 2, 0, {})   # 故意异种子·靠快照对齐
	ai_think.rng_restore(ai_live.rng_snapshot())
	var r_think := RandomNumberGenerator.new()
	r_think.seed = 7
	var think_clone: BattleCore = base.clone()
	var up: int = ai_think.plan_economy_decide(think_clone, 1)
	ai_think.plan_economy_apply(think_clone, 1, r_think, up)
	var c_think: Dictionary = ai_think.choose_action(think_clone, 1)
	# Act③确认时重放：真局只跑廉价 apply（同 rng 起点）
	var b_live: BattleCore = base.clone()
	var r_live := RandomNumberGenerator.new()
	r_live.seed = 7
	ai_live.plan_economy_apply(b_live, 1, r_live, up)
	# Assert：选招逐位一致 + 真局经济状态逐位一致
	assert_eq(var_to_str(c_think), var_to_str(c_sync), "克隆预想选招 == 同步直算选招")
	assert_eq(var_to_str(b_live.slots[1]), var_to_str(b_sync.slots[1]), "真局重放槽状态 == 同步直算")
	assert_eq(b_live.energy[1], b_sync.energy[1], "真局重放能量 == 同步直算")
	assert_eq(var_to_str(ai_think.rng_snapshot()), var_to_str(ai_sync.rng_snapshot()),
			"预想 AI rng 终态 == 同步 AI rng 终态（采纳后整局随机流一致）")
