extends GutTest

## ============================================================================
## BattleAI —— 同时博弈短时最优 AI
##   解算器：matching pennies → 50/50；占优行 → 近纯策略
##   决策：返回合法动作；必杀局面选大波；死亡换人选高血替补
## ============================================================================

const ATTACK := ActionDef.Action.ATTACK
const BIG := ActionDef.Action.BIG_ATTACK
const CHARGE := ActionDef.Action.CHARGE
const DEFEND := ActionDef.Action.DEFEND
const SWITCH := ActionDef.Action.SWITCH


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _team(specs: Array) -> Array:
	var t: Array = []
	for s in specs:
		t.append(_hero(s[0], s[1]))
	return t


func _battle2(p0: Array, p1: Array, e: int = 6) -> BattleCore:
	var b := BattleCore.new()
	b.setup(_team(p0), _team(p1), 555)
	b.energy = [e, e]
	return b


# ---- 解算器：纳什混合策略 ----

func test_solver_matching_pennies_is_uniform() -> void:
	# Arrange：matching pennies，唯一纳什 = 行 [0.5, 0.5]
	var ai := BattleAI.new(1)
	var payoff: Array = [[1.0, -1.0], [-1.0, 1.0]]

	# Act
	var strat: Array = ai._solve_mixed(payoff, 2, 2, 600)

	# Assert
	assert_almost_eq(strat[0], 0.5, 0.05, "matching pennies 行策略应 ≈ 0.5")
	assert_almost_eq(strat[1], 0.5, 0.05, "matching pennies 行策略应 ≈ 0.5")


func test_solver_dominant_row_is_near_pure() -> void:
	# Arrange：行 0 严格占优（任何列都 ≥ 行 1）
	var ai := BattleAI.new(1)
	var payoff: Array = [[5.0, 5.0], [0.0, 0.0]]

	# Act
	var strat: Array = ai._solve_mixed(payoff, 2, 2, 600)

	# Assert
	assert_gt(strat[0], 0.9, "占优行应吃下绝大部分概率")


# ---- 决策：合法性 ----

func test_choose_action_returns_legal_action() -> void:
	# Arrange
	var b := _battle2([["h01", 4], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	var ai := BattleAI.new(7)

	# Act
	var choice: Dictionary = ai.choose_action(b, 0)

	# Assert：返回的动作必在合法集合内
	var legal: Array = b.legal_actions(0)
	var found := false
	for entry in legal:
		if int(entry["action"]) == int(choice["action"]) and int(entry.get("target", -1)) == int(choice.get("target", -1)):
			found = true
			break
	assert_true(found, "choose_action 必须返回合法动作")


# ---- 决策：必杀局面选大波 ----

func test_choose_action_takes_guaranteed_lethal() -> void:
	# Arrange：对手仅剩 1 名出战英雄、1 HP、0 能（无法大防）；我方有能量。
	#   大波(穿防、被大防挡)对 0 能对手是保证必杀 → 必胜终局。
	var b := _battle2([["t00", 5], ["t01", 10], ["t02", 10]], [["t10", 5], ["t11", 5], ["t12", 5]])
	b.hp[1] = [2, 0, 0]          # 对手出战 1 HP（2 半点），替补全亡
	b.energy = [6, 0]            # 我方能量足；对手 0 能（防不住大波）
	var ai := BattleAI.new(3)

	# Act + Assert：多次抽样应稳定选大波
	for _i in range(20):
		var choice: Dictionary = ai.choose_action(b, 0)
		assert_eq(int(choice["action"]), BIG, "保证必杀局面应选大波")


# ---- 死亡换人：选高血替补 ----

func test_choose_death_switch_picks_healthiest_reserve() -> void:
	# Arrange：出战阵亡，两替补血量不同
	var b := _battle2([["t00", 6], ["t01", 6], ["t02", 6]], [["t10", 5], ["t11", 5], ["t12", 5]])
	b.active_index[0] = 0
	b.hp[0] = [0, 12, 4]         # 出战亡；替补槽1=6HP，槽2=2HP
	b.pending_death_switch[0] = true
	var ai := BattleAI.new(1)

	# Act
	var slot: int = ai.choose_death_switch(b, 0)

	# Assert
	assert_eq(slot, 1, "应选血量更高的替补（槽 1）")


# 注（2026-06-19）：原 test_death_switch_is_matchup_aware（依赖 h33 审判·无视防御处决）
#   与 test_stochastic_multisample_reduces_variance（依赖 h13 孤注·随机翻倍主动技）已删 ——
#   两者所需的大阿卡那英雄已弃用，而 12 生肖均为被动、无"无视防御处决"或"随机主动技"
#   可作等价替身。AI 的对位前瞻 / 随机多样本能力仍在代码中（随机多样本的确定性侧由下方
#   test_deterministic_cell_not_multisampled 覆盖）；待出现随机/处决型当前内容时再补测。

func test_deterministic_cell_not_multisampled() -> void:
	# Arrange：纯基础英雄无随机
	var b := _battle2([["t00", 10], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	var ai := BattleAI.new(7, 1)
	var ca := {action = ATTACK, target = -1}
	var cb := {action = CHARGE, target = -1}

	# Assert：结算不消耗 rng → stochastic=false；多次评估值恒定
	assert_false(bool(ai._rollout_once(b, 0, 1, ca, cb, 0)["stochastic"]),
		"确定性英雄结算不消耗 rng → stochastic=false")
	assert_eq(ai._value_after(b, 0, 1, ca, cb, 0), ai._value_after(b, 0, 1, ca, cb, 0),
		"确定性格多次评估值恒定（无随机噪声）")


# ---- 深层短名单放宽（T4）----

func test_shortlist_includes_both_attack_and_defend_tiers() -> void:
	# Arrange：能量足以同时负担大波/大防（6 能）
	var b := _battle2([["t00", 10], ["t01", 10], ["t02", 10]], [["t10", 10], ["t11", 10], ["t12", 10]])
	b.energy = [6, 6]
	var ai := BattleAI.new(1, 2)

	# Act
	var acts: Array = []
	for e in ai._shortlist(b, 0):
		acts.append(int(e["action"]))

	# Assert：波 + 大波、防 + 大防 均在（捕捉攻防 RPS），不再只留最大档
	assert_true(ATTACK in acts, "短名单含波")
	assert_true(BIG in acts, "短名单含大波")
	assert_true(DEFEND in acts, "短名单含防")
	assert_true(ActionDef.Action.BIG_DEFEND in acts, "短名单含大防")


# ---- 权重覆盖透传到 AI 评估（T1 工具地基）----

func test_ai_applies_weight_override() -> void:
	# Arrange：存活领先局面
	var b := _battle2([["t00", 5], ["t01", 5], ["t02", 5]], [["t10", 5], ["t11", 5], ["t12", 5]])
	b.hp[1][0] = 0
	var ai_default := BattleAI.new(1, 1, 0, {})
	var ai_heavy := BattleAI.new(1, 1, 0, {"W_ALIVE": 1000.0})

	# Assert：重存活权重的 AI 给该局面更高分（覆盖透传到 _eval）
	assert_gt(ai_heavy._eval(b, 0), ai_default._eval(b, 0), "AI 应把权重覆盖用于评估")


# ---- 深度：depth-1 / depth-2 均返回合法动作 ----

func test_depth_variants_return_legal() -> void:
	# Arrange：常规多英雄局面（12 生肖均为被动）
	var b := _battle2([["h01", 5], ["h02", 4], ["t02", 10]], [["h03", 4], ["t11", 10], ["t12", 10]])

	for d in [1, 2]:
		var ai := BattleAI.new(9, d)
		var choice: Dictionary = ai.choose_action(b, 0)
		var legal: Array = b.legal_actions(0)
		var found := false
		for entry in legal:
			if int(entry["action"]) == int(choice["action"]) and int(entry.get("target", -1)) == int(choice.get("target", -1)):
				found = true
				break
		assert_true(found, "depth=%d 应返回合法动作" % d)
		assert_eq(ai.search_depth, d, "深度参数应被记录")


# ---- AI 配置默认档锁定（转正决策的回归锁·改默认必须走数据验证再来改这里）----

func test_ai_default_profile_locked() -> void:
	# Arrange/Act：默认构造
	var ai := BattleAI.new(1)

	# Assert：现役默认档（2026-07-04 状态：T3 转正 search_upgrade=true·
	# 依据 out_upgrade_ab_t3 新经济 100 局 decisive 64.0%）
	assert_true(ai.search_upgrade, "升级择时默认=价值搜索（T3 转正 2026-07-04）")
	assert_true(ai.smart_draft, "抽卡默认=智能选牌（任务#6 转正）")
	assert_true(ai.plan_items, "搜索推演默认带道具经济")
	assert_eq(ai.eval_profile, 0, "评估默认=v1 基础档")
