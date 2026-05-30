extends GutTest

## ============================================================================
## BattleEvalV3 —— v3「熟练玩家」牌感评估
##   中性态 == 基础评估 ｜ 铺垫状态加分 ｜ 斩杀威胁加分 ｜ 反对称(零和)
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


# ---- 中性态：无铺垫/威胁/形态 → 与基础评估相同 ----

func test_v3_equals_base_in_neutral_state() -> void:
	var b := _neutral()
	assert_almost_eq(BattleEvalV3.score(b, 0), BattleEval.score(b, 0), 0.001, "中性态 v3 == 基础")


# ---- 铺垫状态加分 ----

func test_v3_credits_own_setup_status() -> void:
	# Arrange：己方出战英雄获蓄势(charge_up)
	var b := _neutral()
	var base := BattleEval.score(b, 0)

	# Act
	b.set_status(0, 0, "charge_up", true)

	# Assert：v3 应比基础高出 charge_up 权重
	assert_almost_eq(BattleEvalV3.score(b, 0) - base, BattleEvalV3.SETUP_W["charge_up"], 0.001,
		"己方蓄势铺垫应加 charge_up 权重")


# ---- 斩杀威胁加分 ----

func test_v3_credits_lethal_threat() -> void:
	# Arrange：对手出战 1 HP（≤2HP 斩杀线），我有 2+ 能
	var b := _neutral()
	b.hp[1][0] = 2          # 对手出战 1 HP（2 半点）
	var base := BattleEval.score(b, 0)

	# Act + Assert：v3 比基础高出 THREAT_W（基础已含 HP 差，威胁是额外非线性加分）
	assert_almost_eq(BattleEvalV3.score(b, 0) - base, BattleEvalV3.THREAT_W, 0.001,
		"对手在斩杀线内应加致命威胁分")


# ---- 反对称（零和自洽）----

func test_v3_is_antisymmetric() -> void:
	# Arrange：双方各有不同铺垫
	var b := _neutral()
	b.set_status(0, 0, "charge_up", true)
	b.set_status(1, 0, "combo", 2)

	# Assert：score(0) ≈ -score(1)
	assert_almost_eq(BattleEvalV3.score(b, 0), -BattleEvalV3.score(b, 1), 0.001,
		"v3 应反对称（双方各解同一矩阵自洽）")
