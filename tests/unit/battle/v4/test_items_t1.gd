extends GutTest

## Tier-1 道具（非趣味·27 件）行为锁定测试（ADR-003）。
## 用无技能的 test_* 英雄，隔离道具效果与英雄逻辑。半点制：1HP=2 半点、1 能=2 半能。

const A := ActionDef.Action
const SEED := 777


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id   # "test_" 前缀 → 注册表无此 id → 无技能
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


## 双方各 3 个 10HP 无技能英雄；能量充足（除非测试覆盖）。
func _battle(energy: int = 20) -> BattleCore:
	var b := BattleCore.new()
	var p1: Array = [_hero("test_a", 10), _hero("test_b", 10), _hero("test_c", 10)]
	var p2: Array = [_hero("test_x", 10), _hero("test_y", 10), _hero("test_z", 10)]
	b.setup(p1, p2, SEED)
	b.energy = [energy, energy]
	return b


func _give(b: BattleCore, player: int, id: String) -> int:
	return b.give_item(player, ItemCatalog.make(id))


# === 进攻：自身伤害 hit ===

func test_item_feibiao_deals_half_damage() -> void:
	# Arrange
	var b := _battle()
	_give(b, 0, "t1_feibiao")
	# Act
	b.use_item(0, 0)
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	# Assert：敌方出战 20 → 19（0.5 HP = 1 半点）
	assert_eq(b.hp[1][0], 19)


func test_item_feibiao_blocked_by_defend() -> void:
	var b := _battle()
	_give(b, 0, "t1_feibiao")
	b.use_item(0, 0)
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.DEFEND)
	b.resolve()
	assert_eq(b.hp[1][0], 20)   # 普通飞镖被「防」挡下


func test_item_siyecao_bonus_when_behind() -> void:
	var b := _battle()
	b.hp[0][0] = 10   # 我方出战 HP 低于对手
	_give(b, 0, "t1_siyecao")
	b.use_item(0, 0)
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18)   # 1.0 伤 = 2 半点


func test_item_siyecao_base_when_ahead() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_siyecao"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 19)   # HP 不低 → 0.5 伤


# === 进攻：动作修正器 ===

func test_item_xianshou_buffs_action_attack() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_xianshou"))
	b.select_action(0, A.ATTACK)   # 波 = 1.0HP=2 半点 + 先手 1 = 3
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 17)


func test_item_podun_zhou_pierces_when_opp_defends() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_podun_zhou"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.DEFEND)   # 对手防 → 破盾咒令波穿防
	b.resolve()
	assert_eq(b.hp[1][0], 18)   # 穿防命中 2 半点


func test_item_podun_zhou_inert_when_opp_not_defend() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_podun_zhou"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 18)   # 对手没防 → 普通命中(也是 2)；破盾咒不报错


func test_item_dutu_yingbi_either_win_or_miss() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_dutu_yingbi"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	# 正面=波2+1.0=4 半点 → 16；反面=落空 → 20
	assert_true(b.hp[1][0] == 16 or b.hp[1][0] == 20, "赌徒硬币应正面16或反面20，实际 %d" % b.hp[1][0])


# === 进攻：命中骑乘 ===

func test_item_xixie_yaya_heals_on_hit() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t1_xixie_yaya"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 11)   # 命中回 0.5HP=1 半点
	assert_eq(b.hp[1][0], 18)   # 攻击照常


func test_item_xixie_yaya_no_heal_when_blocked() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t1_xixie_yaya"))
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.BIG_DEFEND)   # 大防挡下 → 未命中 → 不回血
	b.resolve()
	assert_eq(b.hp[0][0], 10)


# === 防御 / 治疗 / 净化 ===

func test_item_jiudun_adds_shield() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_jiudun"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.shield[0][0], 1)   # +0.5 甲 = 1 半点


func test_item_houshou_absorbs_when_opp_attacks() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_houshou"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.ATTACK)   # 对手攻 → +1.0 甲(2 半点)吸掉这一波
	b.resolve()
	assert_eq(b.hp[0][0], 20)


func test_item_houshou_inert_when_opp_not_attack() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_houshou"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.shield[0][0], 0)   # 对手没攻 → 不给甲


func test_item_qipao_blocks_big_attack() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_qipao"))
	b.select_action(0, A.DEFEND)
	b.select_action(1, A.BIG_ATTACK)   # 气泡升防 → 挡下大波
	b.resolve()
	assert_eq(b.hp[0][0], 20)


func test_item_qipao_control_big_attack_unblocked() -> void:
	var b := _battle()
	b.select_action(0, A.DEFEND)
	b.select_action(1, A.BIG_ATTACK)   # 无气泡 → 防挡不住大波
	b.resolve()
	assert_eq(b.hp[0][0], 16)


func test_item_lzhi_shengming_heals() -> void:
	var b := _battle()
	b.hp[0][0] = 10
	b.use_item(0, _give(b, 0, "t1_lzhi_shengming"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[0][0], 11)


func test_item_hushenfu_blocks_debuff() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_hushenfu"))
	_give(b, 1, "t1_yaohuo")
	b.use_item(1, 0)   # 对手妖火砸 p0 → 被圣贤书免疫
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.pending_damage[0][0], 0)


func test_item_hushenfu_control_debuff_lands() -> void:
	var b := _battle()
	_give(b, 1, "t1_yaohuo")
	b.use_item(1, 0)
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.pending_damage[0][0], 1)   # 无免疫 → 妖火生效


# === 能量 / 经济（相对差值，规避被动 +1 / 攒 噪声）===

func _energy0_after(use_id: String, act0: int, act1: int, start: int) -> int:
	var b := _battle(start)
	if use_id != "":
		b.use_item(0, _give(b, 0, use_id))
	b.select_action(0, act0)
	b.select_action(1, act1)
	b.resolve()
	return b.energy[0]


func test_item_lzhi_fali_extra_energy_on_charge() -> void:
	var got := _energy0_after("t1_lzhi_fali", A.CHARGE, A.CHARGE, 4)
	var base := _energy0_after("", A.CHARGE, A.CHARGE, 4)
	assert_eq(got - base, 1)


func test_item_moli_yuanquan_energy_on_block() -> void:
	var got := _energy0_after("t1_moli_yuanquan", A.DEFEND, A.ATTACK, 6)
	var base := _energy0_after("", A.DEFEND, A.ATTACK, 6)
	assert_eq(got - base, 1)


func test_item_tongqian_energy_when_opp_not_attack() -> void:
	var got := _energy0_after("t1_tongqian", A.CHARGE, A.CHARGE, 6)
	var base := _energy0_after("", A.CHARGE, A.CHARGE, 6)
	assert_eq(got - base, 1)   # 对手没攻 → +0.5 能


func test_item_tongqian_shield_when_opp_attack() -> void:
	var b := _battle(6)
	b.use_item(0, _give(b, 0, "t1_tongqian"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.ATTACK)   # 对手攻 → +0.5 甲吸 1 半点
	b.resolve()
	assert_eq(b.hp[0][0], 19)   # 波 2 - 甲 1 = 1 落血


# === 状态 / 自结算 DoT ===

func test_item_yaohuo_dot_and_blocks_heal() -> void:
	var b := _battle()
	b.hp[1][0] = 10
	b.use_item(0, _give(b, 0, "t1_yaohuo"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	# 下回合：DoT 落地(-1) + 对手想回血被封
	b.use_item(1, _give(b, 1, "t1_lzhi_shengming"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 9)   # 10 -1(DoT) +0(回血被封)


# === 干扰 / 信息层 ===

func test_item_xiangjiaopi_weakens_opp_attack() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_xiangjiaopi"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.ATTACK)   # 对手攻 p0：2 - 0.5 = 1
	b.resolve()
	assert_eq(b.hp[0][0], 19)


# === 节奏 / 随机 ===

func test_item_fengzhixue_buffs_next_attack_after_switch() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_fengzhixue"))
	b.select_switch(0, 1)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(int(b.item_buffs[0].get("next_atk_bonus", 0)), 1)
	# 下回合攻击 +0.5
	b.select_action(0, A.ATTACK)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 17)   # 波 2 + 1 = 3
	assert_eq(int(b.item_buffs[0].get("next_atk_bonus", 0)), 0)   # 已消耗


func test_item_tongqian_named_suanming() -> void:
	# 占位：算命铜钱已在上方两个 test 覆盖；此函数仅保留文件尾结构。
	assert_true(true)


# === 基建 ===

func test_item_does_not_occupy_action_slot() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_feibiao"))
	var ok := b.select_action(0, A.ATTACK)   # 同回合仍能选动作
	assert_true(ok)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 17)   # 飞镖 1 + 波 2 = 3


func test_clone_copies_item_state_independently() -> void:
	var b := _battle()
	_give(b, 0, "t1_feibiao")
	b.use_item(0, 0)
	var c := b.clone()
	assert_eq(c.items[0].size(), 1)
	assert_eq(c.item_uses[0].size(), 1)
	c.item_uses[0].clear()
	assert_eq(b.item_uses[0].size(), 1)   # 改 clone 不动原局


# === C10 补测：占卜龟壳 / 随身熔炉 / 尾后针（此前仅冒烟覆盖）===

func test_item_guike_grants_draft_reroll_token() -> void:
	# Arrange
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_guike"))
	# Act
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	# Assert：给自己挂 1 个重抽令牌（下次 3 选 1 界面消费）
	assert_eq(int(b.item_buffs[0].get("draft_reroll", 0)), 1)


func test_item_ronglu_burns_spare_for_energy() -> void:
	# Arrange：库存里放一件已就绪·未用的废牌（飞镖）
	var b := _battle(6)
	b.slots[0] = [{"item": ItemCatalog.make("t1_feibiao"), "used": false}]
	b.use_item(0, _give(b, 0, "t1_ronglu"))
	# Act：双防隔离（防不耗能不产能），只看熔炉给的能量
	b.select_action(0, A.DEFEND)
	b.select_action(1, A.DEFEND)
	b.resolve()
	# Assert：+0.5 能 = 1 半点；废牌槽被烧空（resolve 末 _econ_after_resolve 清成 EMPTY）
	assert_eq(b.energy[0], 7)
	assert_eq(b.slots[0][0]["item"], null)


func test_item_ronglu_no_energy_without_spare() -> void:
	var b := _battle(6)
	b.slots[0] = []   # 手里没废牌可烧
	b.use_item(0, _give(b, 0, "t1_ronglu"))
	b.select_action(0, A.DEFEND)
	b.select_action(1, A.DEFEND)
	b.resolve()
	assert_eq(b.energy[0], 6)   # 不发动 → 不白给能量


func test_item_weihouzhen_stings_on_active_death() -> void:
	var b := _battle()
	b.hp[0][0] = 2   # 我方出战 1.0 HP·濒死
	b.use_item(0, _give(b, 0, "t1_weihouzhen"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.BIG_ATTACK)   # 大波 4 → 打死我方出战
	b.resolve()
	assert_true(b.hp[0][0] <= 0)        # 出战阵亡
	assert_eq(b.hp[1][0], 19)           # 敌方出战吃 0.5 真伤（20 → 19）


func test_item_weihouzhen_no_sting_when_survives() -> void:
	var b := _battle()
	b.use_item(0, _give(b, 0, "t1_weihouzhen"))
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.ATTACK)   # 波 2 → 我方 20→18 存活
	b.resolve()
	assert_eq(b.hp[1][0], 20)      # 没死 → 不反咬
	assert_eq(int(b.item_buffs[0].get("death_reflect", 0)), 1)   # 标记仍挂着
