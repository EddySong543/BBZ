extends GutTest

## ============================================================================
## BattleEvalV2 —— v2 进阶「熟练玩家」牌感评估
##   中性态 == v1 基础评估 ｜ 斩杀威胁加分 ｜ 延迟伤害加分 ｜ 反对称(零和)
## ============================================================================

func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
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


func _neutral() -> BattleCore:
	return _battle2([["t00", 5], ["t01", 5], ["t02", 5]], [["t10", 5], ["t11", 5], ["t12", 5]])


# ---- 中性态：无威胁/延迟 → 与 v1 基础评估相同 ----

func test_v2_equals_base_in_neutral_state() -> void:
	var b := _neutral()
	assert_almost_eq(BattleEvalV2.score(b, 0), BattleEval.score(b, 0), 0.001, "中性态 v2 == v1 基础")


# ---- 斩杀威胁加分 ----

func test_v2_credits_lethal_threat() -> void:
	# Arrange：对手出战 1 HP（≤2HP 斩杀线），我有 2+ 能
	var b := _neutral()
	b.hp[1][0] = 2          # 对手出战 1 HP（2 半点）
	var base := BattleEval.score(b, 0)

	# Act + Assert：v2 比基础高出 THREAT_W（基础已含 HP 差，威胁是额外非线性加分）
	assert_almost_eq(BattleEvalV2.score(b, 0) - base, BattleEvalV2.THREAT_W, 0.001,
		"对手在斩杀线内应加致命威胁分")


# ---- 延迟伤害加分（道具妖火/藤蔓挂在对手头上的债）----

func test_v2_credits_pending_damage_on_opponent() -> void:
	# Arrange：对手出战挂着 1 点延迟伤害（2 半点）
	var b := _neutral()
	var base := BattleEval.score(b, 0)
	b.pending_damage[1][0] = 2

	# Assert：v2 比基础高出 PENDING_W × 2（对手将掉血 = 利好）
	assert_almost_eq(BattleEvalV2.score(b, 0) - base, BattleEvalV2.PENDING_W * 2.0, 0.001,
		"对手头上的延迟伤害应加分")


# ---- 反对称（零和自洽）----

func test_v2_is_antisymmetric() -> void:
	# Arrange：双方不对称态（己方挂延迟伤害 + 对手残血威胁）
	var b := _neutral()
	b.pending_damage[0][0] = 2   # 己方出战挂延迟伤害（不利）
	b.hp[1][0] = 2               # 对手出战残血（斩杀线内）

	# Assert：score(0) ≈ -score(1)
	assert_almost_eq(BattleEvalV2.score(b, 0), -BattleEvalV2.score(b, 1), 0.001,
		"v2 应反对称（双方各解同一矩阵自洽）")


# ---- 权重覆盖机制（T1 工具地基）----

func test_weight_override_changes_base_score() -> void:
	# Arrange：制造存活数领先（对手出战阵亡）
	var b := _neutral()
	b.hp[1][0] = 0
	# Act + Assert：提高 W_ALIVE → 存活领先局面分更高（仅该权重变）
	var s_default := BattleEval.score(b, 0)
	var s_override := BattleEval.score(b, 0, {"W_ALIVE": 1000.0})
	assert_gt(s_override, s_default, "提高 W_ALIVE → 存活领先局面分更高（权重覆盖生效）")


func test_v2_forwards_weight_override_to_base() -> void:
	var b := _neutral()
	b.hp[1][0] = 0
	var s_default := BattleEvalV2.score(b, 0)
	var s_override := BattleEvalV2.score(b, 0, {"W_ALIVE": 1000.0})
	assert_gt(s_override, s_default, "v2 应把权重覆盖透传给基础评估")
