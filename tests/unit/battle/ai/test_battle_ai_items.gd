extends GutTest

## BattleAI.run_item_economy（任务 B·AI 基础道具经济）行为锁定。
## 用就绪 / 抽可抽（含自动解锁格）/ 富余补充 / reserve 不饿死动作 / 未 init 安全。
## （2026-07-03 经济重做：格自动解锁免费、无开格步骤 → 原开格相关用例移除。）

const A := ActionDef.Action
const SEED := 4242
const SS := BattleCore.SlotState


func _hero(id: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = id
	h.hero_name = id
	h.max_hp = hp
	h.skill_type = HeroData.SkillType.PASSIVE
	return h


func _battle(energy: int = 20) -> BattleCore:
	var b := BattleCore.new()
	b.setup([_hero("a", 10), _hero("b", 10), _hero("c", 10)],
		[_hero("x", 10), _hero("y", 10), _hero("z", 10)], SEED)
	b.energy = [energy, energy]
	b.econ_init()
	return b


## P1(AI·side 1) 开局件已就绪的 battle（绕开「部署延迟」便于测机制；真实首回合开局件是锁住的）。
func _battle_ready(energy: int = 20) -> BattleCore:
	var b := _battle(energy)
	b.slots[1][0]["since"] = b.turn_number - 1
	return b


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	return r


func _advance(b: BattleCore, n: int = 1) -> void:
	for _i in range(n):
		b.select_action(0, A.CHARGE)
		b.select_action(1, A.CHARGE)
		b.resolve()


# === 用就绪道具 ===

func test_uses_ready_non_attack_item() -> void:
	# 能量紧（< 升级投资线）→ AI 把就绪的非进攻件直接用掉、不投资升级（升级择时见 test_upgrades_*）。
	# 用 _battle_ready：自带件按设计解锁前锁住，这里要测"就绪→用"，故夹具置就绪。
	var b := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_jiudun")   # 防御件（进攻件按兵不动，见 test_holds_attack_item*）
	assert_true(b.slot_ready(1, 0), "AI 自带件就绪（夹具）")
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.item_uses[1].size(), 1, "能量紧 → AI 用掉就绪非进攻件（提交盲选）")


# === 进攻向道具按兵不动 → 攻击回合一并甩出（2026-07-03 死龟锁修复）===

func test_holds_attack_item_in_economy() -> void:
	var b := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_feibiao")   # 进攻 chip
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.item_uses[1].size(), 0, "经济阶段进攻件按兵不动（不白扔喂对方免费防）")
	assert_true(b.slot_ready(1, 0), "进攻件保持就绪（留给攻击回合）")


func test_commits_attack_item_on_attack_turn_only() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_feibiao")
	BattleAI.commit_attack_items(b, 1, ActionDef.Action.CHARGE)
	assert_eq(b.item_uses[1].size(), 0, "攒回合不甩进攻件")
	BattleAI.commit_attack_items(b, 1, ActionDef.Action.ATTACK)
	assert_eq(b.item_uses[1].size(), 1, "攻击回合甩出进攻件（与波同吃防御门）")


# === 抽取自动解锁的格 ===

func test_draws_from_auto_opened_slot() -> void:
	var b := _battle(20)
	_advance(b, 3)                       # 显示回合 4：slot1 自动解锁（免费）
	assert_true(b.can_draw_slot(1, 1))
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 1), SS.CHARGING, "AI 抽取自动解锁格 → CHARGING")
	assert_not_null(b.slot_item(1, 1))


# === 富余能量补充 / reserve 不饿死动作 ===

func test_refills_empty_slot_with_surplus() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t3_shengming")   # 不可升 T3 → AI 直接用（隔离升级能耗）
	BattleAI.run_item_economy(b, 1, _rng())
	_advance(b, 1)                       # 用掉 → EMPTY
	assert_eq(b.slot_state(1, 0), SS.EMPTY)
	var e0 := b.energy[1]
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 0), SS.CHARGING, "富余能量补充空槽（3 选 1 已抽）")
	assert_eq(e0 - b.energy[1], BattleCore.ITEM_REFILL_COST, "补充扣 1 能")


func test_no_refill_when_energy_below_reserve() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t3_shengming")
	BattleAI.run_item_economy(b, 1, _rng())
	_advance(b, 1)                       # 用掉 → EMPTY
	b.energy[1] = BattleCore.ITEM_REFILL_COST + BattleAI.AI_ITEM_ENERGY_RESERVE - 1   # 差 1 半能
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 0), SS.EMPTY, "能量不足 reserve → 不补充（留行动预算）")


# === 升级择时（任务 C）===

func test_upgrades_ready_item_with_ample_energy() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_feibiao")   # 就绪可升（T1）
	assert_true(b.can_upgrade(1, 0))
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_item(1, 0).tier, 2, "能量富余 → AI 升级就绪件（换 T2）")
	assert_false(b.slot_ready(1, 0), "升级后重新锁本回合（电报）")
	assert_eq(b.item_uses[1].size(), 0, "升级的槽不提交使用")


func test_uses_instead_of_upgrade_when_energy_tight() -> void:
	var b := _battle_ready(20)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_jiudun")   # 防御件（进攻件不走"直接用"路径）
	# 差 1 半能够不到「升级成本 + reserve + buffer」投资线 → 应直接用掉、不投资升级。
	b.energy[1] = BattleCore.UPGRADE_COST + BattleAI.AI_ITEM_ENERGY_RESERVE + BattleAI.AI_ITEM_UPGRADE_BUFFER - 1
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_item(1, 0).item_id, "t1_jiudun", "能量不够投资 → 不升级")
	assert_eq(b.item_uses[1].size(), 1, "改为直接用掉就绪件")


func test_upgrades_at_most_one_per_turn() -> void:
	var b := _battle_ready(30)
	b.slots[1][0]["item"] = ItemCatalog.make("t1_feibiao")
	b.slots[1][1] = {state = SS.CHARGING, item = ItemCatalog.make("t1_jiudun"),
		since = -1, used = false, draft = [], upg_draft = []}   # 第二个就绪可升槽
	assert_true(b.slot_ready(1, 0) and b.slot_ready(1, 1), "两槽都就绪可升")
	BattleAI.run_item_economy(b, 1, _rng())
	var upgraded := 0
	for s in range(BattleCore.SLOT_COUNT):
		if b.slot_item(1, s) != null and b.slot_item(1, s).tier == 2:
			upgraded += 1
	assert_eq(upgraded, 1, "每回合最多升 1 个")
	assert_eq(b.item_uses[1].size(), 1, "另一个就绪件被用掉")


# === 3 选 1 智能选牌（任务#6·2026-07-03）===

func test_smart_pick_heal_scales_with_missing_hp() -> void:
	# 治疗件随掉血增值；满血不倒扣（首版倒扣被 A/B 证伪·见 score_item_option 校准记录）。
	var full := _battle(20)
	var hurt := _battle(20)
	hurt.hp[1][0] = 4   # AI 出战重伤（满 20 半点）
	var heal := ItemCatalog.make("t1_lzhi_shengming")
	assert_gt(BattleAI.score_item_option(hurt, 1, heal), BattleAI.score_item_option(full, 1, heal),
		"掉血时治疗分 > 满血时治疗分")


func test_smart_pick_prefers_heal_when_damaged() -> void:
	var b := _battle(20)
	b.hp[1][0] = 4   # AI 出战重伤（满 20 半点）
	var dart := ItemCatalog.make("t1_feibiao")
	var heal := ItemCatalog.make("t1_lzhi_shengming")
	assert_gt(BattleAI.score_item_option(b, 1, heal), BattleAI.score_item_option(b, 1, dart),
		"重伤：治疗 > 飞镖")


func test_smart_pick_prefers_attack_at_kill_range() -> void:
	var b := _battle(20)
	b.hp[0][0] = 2   # 敌方出战进斩杀圈（≤2HP=4 半点）
	var dart := ItemCatalog.make("t1_feibiao")
	var shield := ItemCatalog.make("t1_jiudun")
	assert_gt(BattleAI.score_item_option(b, 1, dart), BattleAI.score_item_option(b, 1, shield),
		"敌进斩杀圈：进攻件 > 护盾件（收割票）")


func test_smart_pick_values_energy_when_starved() -> void:
	var b := _battle(20)
	b.energy[1] = 2   # 缺能（1.0 能）
	var mana := ItemCatalog.make("t1_lzhi_fali")
	var b2 := _battle(20)
	b2.energy[1] = 12  # 能量富余
	assert_gt(BattleAI.score_item_option(b, 1, mana), BattleAI.score_item_option(b2, 1, mana),
		"缺能时能量件比富余时更值钱")


# === 安全：未 init 经济 ===

func test_safe_when_econ_not_init() -> void:
	var b := BattleCore.new()
	b.setup([_hero("a", 10), _hero("b", 10), _hero("c", 10)],
		[_hero("x", 10), _hero("y", 10), _hero("z", 10)], SEED)
	BattleAI.run_item_economy(b, 1, _rng())   # slots=[[],[]] → 守卫早退、不崩
	assert_eq(b.item_uses[1].size(), 0, "未启用经济：AI 无道具操作")
