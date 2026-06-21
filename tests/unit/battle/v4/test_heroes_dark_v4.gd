extends GutTest

## ============================================================================
## 黑暗面英雄（h13 黑暗子鼠 / h14 黑暗丑牛）技能测试 —— 锁定【当前代码行为】。
##
## h13【封窟】= 干扰：出战时封敌方 0.5 能(=1 半能)不可动用（usable_energy 应用·下场即解）。
## h14【劈穿】= 进攻：击杀溢出穿透到敌方最高血替补（carry_overkill_to_next·on_kill 触发）。
##
## 经济基线（半能制）：1 能=2 半能；波 2 半能 / 大波 6 半能 / 大防 4 半能；HP 半点制(1.0=2 半点)。
## ============================================================================


func _hero(id: String, hp: int = 5) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


## P0 slot0 = 被测英雄；其余 plain（无技能）。e = 双方起手半能。
func _battle(hero_id: String, hp: int = 5, e: int = 8) -> BattleCore:
	var p1: Array = [_hero(hero_id, hp), _hero("test_p1_1"), _hero("test_p1_2")]
	var p2: Array = [_hero("test_p2_0"), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [e, e]
	return b


## 自定义 P0 队伍（被测英雄在指定槽，便于测出战 / 替补差异）。
func _battle_team(p0_ids: Array, hp: int = 5, e: int = 8) -> BattleCore:
	var p1: Array = []
	for id in p0_ids:
		p1.append(_hero(id, hp))
	var p2: Array = [_hero("test_p2_0"), _hero("test_p2_1"), _hero("test_p2_2")]
	var b := BattleCore.new()
	b.setup(p1, p2, 555)
	b.energy = [e, e]
	return b


# ---- h13 黑暗子鼠 封窟（出战时封敌方 0.5 能不可动用）----

func test_h13_fengku_locks_enemy_usable_energy() -> void:
	var b := _battle("h13", 4, 6)   # P0 slot0 = 暗鼠出战；双方 6 半能
	assert_eq(b.usable_energy(1), 5, "封窟 → 敌方(P1)可用 = 6 − 1 半能 = 5")
	assert_eq(b.usable_energy(0), 6, "暗鼠侧(P0)自己不受封")
	assert_eq(b.energy[1], 6, "封印不销毁能量（池仍 6，只是 0.5 不可动用）")
	assert_false(b.can_afford(1, ActionDef.Action.BIG_ATTACK), "敌方 5 可用 < 大波 6 → 买不起（差被封的 0.5）")
	assert_true(b.can_afford(0, ActionDef.Action.BIG_ATTACK), "暗鼠侧 6 可用够大波")
	assert_true(b.can_afford(1, ActionDef.Action.BIG_DEFEND), "封窟下 5 可用仍买得起大防(4)")
	assert_true(b.can_afford(1, ActionDef.Action.ATTACK), "封窟下仍买得起波(2)")


func test_h13_fengku_releases_when_off_field() -> void:
	# 暗鼠在替补席(slot1)、出战是 plain → 不封印
	var b := _battle_team(["test_p0_0", "h13", "test_p0_2"], 4, 6)
	assert_eq(b.usable_energy(1), 6, "暗鼠在替补 → 敌方不受封")
	assert_true(b.can_afford(1, ActionDef.Action.BIG_ATTACK), "敌方 6 可用足额可大波")


# ---- h14 黑暗丑牛 劈穿（击杀溢出穿透到最高血替补）----

func test_h14_pichuan_cleaves_overkill_to_reserve() -> void:
	# P0 = 黑暗丑牛(出战)；P1 出战残血 0.5HP(1 半点)，两替补满血(HP5=10 半点)
	var b := _battle_team(["h14"], 6, 12)
	b.hp[1][0] = 1
	b.select_action(0, ActionDef.Action.BIG_ATTACK)   # 大波 4 半点劈死 slot0
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_true(b.hp[1][0] <= 0, "对手出战(残血)被大波劈死")
	# overkill = 4 − 1 = 3 半点 → 穿透到最高血替补(slot1)
	assert_eq(b.hp[1][1], 10 - 3, "溢出 3 半点劈穿到最高血替补(slot1)")
	assert_eq(b.hp[1][2], 10, "另一替补未受影响")
	assert_true(b.pending_death_switch[1], "出战阵亡 → 待玩家换人")


func test_h14_pichuan_no_carry_when_not_lethal() -> void:
	# 对手出战满血 → 大波 4 不致死 → 无溢出
	var b := _battle_team(["h14"], 6, 12)
	b.select_action(0, ActionDef.Action.BIG_ATTACK)
	b.select_action(1, ActionDef.Action.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 10 - 4, "大波 4 半点命中、未致死")
	assert_eq(b.hp[1][1], 10, "未击杀 → 替补无溢出")
	assert_eq(b.hp[1][2], 10, "未击杀 → 替补无溢出")
