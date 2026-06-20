extends GutTest

## BattleAI.run_item_economy（任务 B·AI 基础道具经济）行为锁定。
## 用就绪 / 抽可抽 / 富余开格-refill / reserve 不饿死动作 / 未 init 安全。

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

func test_uses_ready_starter() -> void:
	# 能量紧（< 升级投资线）→ AI 把就绪开局件直接用掉、不投资升级（升级择时见 test_upgrades_*）。
	# 用 _battle_ready：开局件按设计首回合锁住，这里要测"就绪→用"，故夹具置就绪。
	var b := _battle_ready(BattleAI.AI_ITEM_ENERGY_RESERVE)
	assert_true(b.slot_ready(1, 0), "AI 开局件就绪（夹具）")
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.item_uses[1].size(), 1, "能量紧 → AI 用掉就绪开局带件（提交盲选）")


# === 抽取已开槽 ===

func test_draws_from_opened_slot() -> void:
	var b := _battle(20)
	_advance(b, 2)
	b.open_slot(1, 1)                    # 手动开格（锁本回合）
	_advance(b, 1)                       # 下回合可抽
	assert_true(b.can_draw_slot(1, 1))
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 1), SS.CHARGING, "AI 抽取已开槽 → CHARGING")
	assert_not_null(b.slot_item(1, 1))


# === 富余能量开格 ===

func test_opens_sealed_slot_with_surplus() -> void:
	var b := _battle(20)
	_advance(b, 2)                       # 第 3 回合：slot1 可开
	b.slots[1][0]["item"] = ItemCatalog.make("t3_shengming")   # 开局件换不可升 T3 → AI 只用不升·隔离开格能耗
	var e0 := b.energy[1]
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 1), SS.OPENED, "富余能量开 slot1")
	assert_eq(e0 - b.energy[1], BattleCore.ITEM_OPEN_COST, "仅开格扣 1 能（用/抽免费·升级被隔离）")


func test_opens_at_most_one_slot_per_turn() -> void:
	var b := _battle(40)
	_advance(b, 3)                       # 第 4 回合：slot1 + slot2 均可开
	BattleAI.run_item_economy(b, 1, _rng())
	var opened := 0
	for s in range(BattleCore.SLOT_COUNT):
		if b.slot_state(1, s) == SS.OPENED:
			opened += 1
	assert_eq(opened, 1, "每回合最多开 1 槽（电报渐进）")


# === reserve 不饿死动作 ===

func test_no_open_when_energy_below_reserve() -> void:
	var b := _battle(20)
	_advance(b, 2)                       # turn 2，slot1 可解锁
	b.energy[1] = BattleCore.ITEM_OPEN_COST + BattleAI.AI_ITEM_ENERGY_RESERVE - 1   # 差 1 半能
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 1), SS.SEALED, "能量不足 reserve → 不开格（留行动预算）")


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
	b.slots[1][0]["item"] = ItemCatalog.make("t1_feibiao")
	# 差 1 半能够不到「升级成本 + reserve + buffer」投资线 → 应直接用掉、不投资升级。
	b.energy[1] = BattleCore.UPGRADE_COST_T1 + BattleAI.AI_ITEM_ENERGY_RESERVE + BattleAI.AI_ITEM_UPGRADE_BUFFER - 1
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_item(1, 0).item_id, "t1_feibiao", "能量不够投资 → 不升级")
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


# === 安全：未 init 经济 ===

func test_safe_when_econ_not_init() -> void:
	var b := BattleCore.new()
	b.setup([_hero("a", 10), _hero("b", 10), _hero("c", 10)],
		[_hero("x", 10), _hero("y", 10), _hero("z", 10)], SEED)
	BattleAI.run_item_economy(b, 1, _rng())   # slots=[[],[]] → 守卫早退、不崩
	assert_eq(b.item_uses[1].size(), 0, "未启用经济：AI 无道具操作")
