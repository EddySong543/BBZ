extends GutTest

## Tier-3 遗物（持久·每回合 tick·Phase 2）行为锁定测试（ADR-003）。
## 无技能 test_* 英雄隔离。半点制：1HP=2 半点、1 能=2 半能。基线出战 HP=20。

const A := ActionDef.Action
const SEED := 777


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(energy: int = 20) -> BattleCore:
	var b := BattleCore.new()
	var p1: Array = [_hero("test_a", 10), _hero("test_b", 10), _hero("test_c", 10)]
	var p2: Array = [_hero("test_x", 10), _hero("test_y", 10), _hero("test_z", 10)]
	b.setup(p1, p2, SEED)
	b.energy = [energy, energy]
	return b


func _give(b: BattleCore, player: int, id: String) -> int:
	return b.give_item(player, ItemCatalog.make(id))


func _cc(b: BattleCore) -> void:
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()


func _aa(b: BattleCore, a0: int, a1: int) -> void:
	b.select_action(0, a0)
	b.select_action(1, a1)
	b.resolve()


# === 续命香：每回合 +0.5 HP × 3 后到期 ===

func test_relic_xumingxiang_heals_three_turns_then_expires() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t3_xumingxiang"))
	_cc(b)
	assert_eq(b.hp[0][0], 11)   # turn1
	_cc(b)
	assert_eq(b.hp[0][0], 12)   # turn2
	_cc(b)
	assert_eq(b.hp[0][0], 13)   # turn3
	assert_eq(b.relics[0].size(), 0, "3 回合后遗物到期移除")
	_cc(b)
	assert_eq(b.hp[0][0], 13)   # 已到期 → 不再回血


# === 青元宝莲：每回合 +0.5 能，3 回合后消失 ===

func test_relic_qingyuanbaolian_gains_energy() -> void:
	var b := _battle(4)
	b.use_item(0, _give(b, 0, "t3_qingyuanbaolian"))
	_aa(b, A.DEFEND, A.DEFEND)   # 无动作能量变化
	var got := b.energy[0]       # 4 + 遗物 1 = 5（被动已去除）；下方用相对差值，与被动无关
	var base := _battle(4)
	base.select_action(0, A.DEFEND)
	base.select_action(1, A.DEFEND)
	base.resolve()
	assert_eq(got - base.energy[0], 1, "遗物每回合 +0.5 能 = 1 半能")


func test_relic_qingyuanbaolian_expires_after_three() -> void:
	var b := _battle(4)
	b.use_item(0, _give(b, 0, "t3_qingyuanbaolian"))
	_aa(b, A.DEFEND, A.DEFEND)
	assert_eq(b.relics[0].size(), 1)
	_aa(b, A.DEFEND, A.DEFEND)
	_aa(b, A.DEFEND, A.DEFEND)
	assert_eq(b.relics[0].size(), 0)


# === 噬心钉：攻击 +1.0 伤 + 无法防御 ===

func test_relic_shixinding_attack_bonus() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_shixinding"))
	_aa(b, A.ATTACK, A.CHARGE)
	assert_eq(b.hp[1][0], 16)   # 波 2 + 1.0 = 4


func test_relic_shixinding_cannot_defend() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_shixinding"))
	_aa(b, A.DEFEND, A.ATTACK)   # 防失效 → 对手波命中
	assert_eq(b.hp[0][0], 18)


func test_control_skilless_defend_blocks_attack() -> void:
	var b := _battle()
	_aa(b, A.DEFEND, A.ATTACK)
	assert_eq(b.hp[0][0], 20)   # 对照：正常防挡下波


# === 不动明王甲：防御得益 + 攻击惩罚 ===

func test_relic_budongmingwang_block_heals() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t3_budongmingwang"))
	_aa(b, A.DEFEND, A.ATTACK)   # 防挡下波 → 成功 → 回 0.5 HP
	assert_eq(b.hp[0][0], 11)


func test_relic_budongmingwang_attack_penalty() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_budongmingwang"))
	_aa(b, A.ATTACK, A.CHARGE)
	assert_eq(b.hp[1][0], 19)   # 波 2 − 0.5 = 1


# === 聚鼎三花：3 次攻击后散（extra_hits 行为需英雄 on-hit，本测仅锁充能/不自伤）===

func test_relic_judingsanhua_expires_after_three_attacks() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_judingsanhua"))
	_aa(b, A.ATTACK, A.CHARGE)
	_aa(b, A.ATTACK, A.CHARGE)
	assert_eq(b.relics[0].size(), 1, "2 次攻击后仍在")
	_aa(b, A.ATTACK, A.CHARGE)
	assert_eq(b.relics[0].size(), 0, "3 次攻击后散")
	assert_eq(b.hp[1][0], 14, "无技能英雄下 extra_hits 不自带伤害（仅 波 ×3=6）")


# === 基建：持久 + clone 独立 + 全遗物可跑 ===

func test_relic_persists_across_turns() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_shixinding"))
	_cc(b)
	assert_eq(b.relics[0].size(), 1, "永久遗物跨回合存活")
	_cc(b)
	assert_eq(b.relics[0].size(), 1)


func test_clone_copies_relics_independently() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t3_qingyuanbaolian"))
	_cc(b)   # tick 一次 → state.used→1
	var c := b.clone()
	assert_eq(c.relics[0].size(), 1)
	c.relics[0][0]["state"]["used"] = 99
	assert_ne(int(b.relics[0][0]["state"].get("used", 0)), 99, "改 clone 的遗物状态不影响原局")


func test_all_relics_run_many_turns() -> void:
	for id in ItemCatalog.ids():
		var data: ItemData = ItemCatalog.make(id)
		if data == null or not bool(data.params.get("relic", false)):
			continue
		var b := _battle()
		b.use_item(0, _give(b, 0, id))
		for _t in range(5):
			b.select_action(0, A.ATTACK)
			b.select_action(1, A.DEFEND)
			b.resolve()
		assert_true(true, "%s 跑 5 回合不崩" % id)
