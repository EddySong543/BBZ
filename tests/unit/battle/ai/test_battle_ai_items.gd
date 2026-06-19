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
	var b := _battle(20)
	assert_true(b.slot_ready(1, 0), "AI 开局带件就绪")
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.item_uses[1].size(), 1, "AI 用掉就绪开局带件（提交盲选）")


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
	var e0 := b.energy[1]
	BattleAI.run_item_economy(b, 1, _rng())
	assert_eq(b.slot_state(1, 1), SS.OPENED, "富余能量开 slot1")
	assert_eq(e0 - b.energy[1], BattleCore.ITEM_OPEN_COST, "仅开格扣 1 能（用/抽免费）")


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


# === 安全：未 init 经济 ===

func test_safe_when_econ_not_init() -> void:
	var b := BattleCore.new()
	b.setup([_hero("a", 10), _hero("b", 10), _hero("c", 10)],
		[_hero("x", 10), _hero("y", 10), _hero("z", 10)], SEED)
	BattleAI.run_item_economy(b, 1, _rng())   # slots=[[],[]] → 守卫早退、不崩
	assert_eq(b.item_uses[1].size(), 0, "未启用经济：AI 无道具操作")
