extends GutTest

## ============================================================================
## BattleEval —— v1 基础评估（AI 现役默认·battle_screen profile 0）权重项锁定测试。
##   对称态 == 0 ｜ 存活/HP/护盾/出战位 各权重 ｜ 能量边际递减 ｜ 终局胜负 ｜ 反对称 ｜ 溢杀保护 ｜ 权重覆盖
##   半点制：1 HP = 2 半点。setup 后 max_hp 翻倍（5HP → 10 半点）。
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


## 完全对称局面：双方各 3 名 5HP·能量 6。
func _neutral() -> BattleCore:
	return _battle2([["t00", 5], ["t01", 5], ["t02", 5]], [["t10", 5], ["t11", 5], ["t12", 5]])


# ---- 对称态 → 0 分 ----

func test_v1_symmetric_state_scores_zero() -> void:
	var b := _neutral()
	assert_almost_eq(BattleEval.score(b, 0), 0.0, 0.001, "完全对称局面 → 0 分")


# ---- HP 差（替补位·隔离 W_HP）----

func test_v1_reserve_hp_diff_weighted_by_w_hp() -> void:
	var b := _neutral()
	b.hp[1][1] = 8   # 对手替补 10→8·差 2 半点（不涉出战位加权）
	assert_almost_eq(BattleEval.score(b, 0), BattleEval.W_HP * 2.0, 0.001)


# ---- 出战位 HP 差（W_HP + W_ACTIVE_HP 双重加权）----

func test_v1_active_hp_diff_double_weighted() -> void:
	var b := _neutral()
	b.hp[1][0] = 8   # 对手出战 10→8·差 2 半点
	assert_almost_eq(BattleEval.score(b, 0), (BattleEval.W_HP + BattleEval.W_ACTIVE_HP) * 2.0, 0.001,
		"出战位 HP 差 = 基础 W_HP + 前线额外 W_ACTIVE_HP")


# ---- 护盾差 ----

func test_v1_shield_diff_weighted_by_w_shield() -> void:
	var b := _neutral()
	b.shield[0][1] = 3   # 我方 +3 半点护盾
	assert_almost_eq(BattleEval.score(b, 0), BattleEval.W_SHIELD * 3.0, 0.001)


# ---- 存活数领先（W_ALIVE·与被杀英雄的残血耦合）----

func test_v1_alive_lead_adds_w_alive() -> void:
	var b := _neutral()
	b.hp[1][2] = 0   # 对手一名替补阵亡：存活 -1 + 该英雄 10 半点血归零
	assert_almost_eq(BattleEval.score(b, 0), BattleEval.W_ALIVE + BattleEval.W_HP * 10.0, 0.001,
		"存活领先 = W_ALIVE + 其残血 W_HP×10")


# ---- 能量：前 2 能满价 ----

func test_v1_energy_full_value_within_cap() -> void:
	var b := _neutral()
	b.energy = [1, 0]   # 我方 1 能 vs 0（都在满价区）
	assert_almost_eq(BattleEval.score(b, 0), BattleEval.W_ENERGY * 1.0, 0.001)


# ---- 能量：超过 2 能后边际递减 ----

func test_v1_energy_marginal_decay_beyond_cap() -> void:
	var b := _neutral()
	b.energy = [3, 2]   # 我方第 3 能 vs 对手 2 能（前 2 能对称抵消）
	assert_almost_eq(BattleEval.score(b, 0), BattleEval.W_ENERGY_EXTRA * 1.0, 0.001,
		"第 3 能只值 W_ENERGY_EXTRA（抑制无意义屯能）")


# ---- 终局：胜/负/平 ----

func test_v1_terminal_win_loss_draw() -> void:
	var b := _neutral()
	b.game_over = true
	b.winner = 1   # winner == player+1 → player 0 胜
	assert_eq(BattleEval.score(b, 0), BattleEval.W_WIN)
	assert_eq(BattleEval.score(b, 1), -BattleEval.W_WIN)   # 对手视角 = 负
	b.winner = 0   # 平局
	assert_eq(BattleEval.score(b, 0), 0.0)


# ---- 反对称（零和自洽）----

func test_v1_is_antisymmetric() -> void:
	var b := _neutral()
	b.hp[1][0] = 6
	b.shield[0][1] = 4
	b.energy = [5, 2]
	assert_almost_eq(BattleEval.score(b, 0), -BattleEval.score(b, 1), 0.001,
		"score(0) ≈ -score(1)")


# ---- 溢杀负血不放大对方亏空 ----

func test_v1_overkill_negative_hp_not_amplified() -> void:
	var b := _neutral()
	b.hp[1][0] = 0
	var s_zero := BattleEval.score(b, 0)
	b.hp[1][0] = -10   # 溢杀到负血
	var s_neg := BattleEval.score(b, 0)
	assert_almost_eq(s_neg, s_zero, 0.001, "负血按 0 计·不额外放大")


# ---- 权重覆盖透传（T1 校准地基）----

func test_v1_weight_override_changes_score() -> void:
	var b := _neutral()
	b.hp[1][2] = 0   # 存活领先局面
	var s_default := BattleEval.score(b, 0)
	var s_override := BattleEval.score(b, 0, {"W_ALIVE": 2000.0})
	assert_gt(s_override, s_default, "提高 W_ALIVE → 存活领先局面分更高")
