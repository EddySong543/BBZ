extends GutTest

## 道具经济状态机（M1·ADR-003 §2）行为锁定测试。
## 开局带1(slot0即用) / 三步部署锁(开格→抽→可用) / 一次性用后 EMPTY / refill / 解锁回合门 / 能量成本。

const A := ActionDef.Action
const SEED := 777
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
	b.setup([_hero("test_a", 10), _hero("test_b", 10), _hero("test_c", 10)],
		[_hero("test_x", 10), _hero("test_y", 10), _hero("test_z", 10)], SEED)
	b.energy = [energy, energy]
	b.econ_init()
	return b


func _advance(b: BattleCore, n: int = 1) -> void:
	for _i in range(n):
		b.select_action(0, A.CHARGE)
		b.select_action(1, A.CHARGE)
		b.resolve()


# === 开局带 1 ===

func test_starter_slot_ready_at_turn_zero() -> void:
	var b := _battle()
	assert_eq(b.slot_state(0, 0), SS.CHARGING, "slot0 开局带件")
	assert_true(b.slot_ready(0, 0), "开局带 1 立即可用")
	assert_not_null(b.slot_item(0, 0))


func test_other_slots_sealed_and_locked_early() -> void:
	var b := _battle()
	assert_eq(b.slot_state(0, 1), SS.SEALED)
	assert_false(b.can_open_slot(0, 1), "第 3 回合前 slot1 不可开格")


# === 三步部署锁：开格 → 抽 → 可用 ===

func test_open_costs_energy_and_locks() -> void:
	var b := _battle(20)
	_advance(b, 2)                       # → turn_number = 2（第 3 回合）
	assert_true(b.can_open_slot(0, 1), "第 3 回合 slot1 可开格")
	var e0 := b.energy[0]
	assert_true(b.open_slot(0, 1))
	assert_eq(e0 - b.energy[0], 2, "开格花 1 能")
	assert_eq(b.slot_state(0, 1), SS.OPENED)
	assert_false(b.can_draw_slot(0, 1), "开格当回合不能抽（锁）")


func test_draw_next_turn_then_charging() -> void:
	var b := _battle(20)
	_advance(b, 2)
	b.open_slot(0, 1)
	_advance(b, 1)                       # 下一回合
	assert_true(b.can_draw_slot(0, 1), "下回合可抽")
	var opts: Array = b.begin_draft(0, 1)
	assert_eq(opts.size(), 3, "3 选 1")
	assert_true(b.pick_draft(0, 1, 0))
	assert_eq(b.slot_state(0, 1), SS.CHARGING)
	assert_false(b.slot_ready(0, 1), "抽道具当回合仍锁（电报）")


func test_usable_turn_after_draw() -> void:
	var b := _battle(20)
	_advance(b, 2)
	b.open_slot(0, 1)
	_advance(b, 1)
	b.pick_draft(0, 1, 0)
	_advance(b, 1)                       # 抽后下回合
	assert_true(b.slot_ready(0, 1), "抽道具下回合可用")


# === 一次性用后 EMPTY + refill ===

func test_use_slot_commits_and_empties() -> void:
	var b := _battle(20)
	# 用开局带的 slot0
	assert_true(b.use_slot(0, 0))
	assert_eq(b.item_uses[0].size(), 1, "提交到盲选 item_uses")
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.slot_state(0, 0), SS.EMPTY, "用后置空（一次性）")
	assert_null(b.slot_item(0, 0))


func test_refill_after_empty() -> void:
	var b := _battle(20)
	b.use_slot(0, 0)
	_advance(b, 1)                       # slot0 → EMPTY
	assert_eq(b.slot_state(0, 0), SS.EMPTY)
	assert_true(b.can_refill(0, 0))
	var e0 := b.energy[0]
	var opts: Array = b.start_refill(0, 0)
	assert_eq(e0 - b.energy[0], 2, "refill 花 1 能")
	assert_eq(opts.size(), 3)
	assert_true(b.pick_draft(0, 0, 0))
	assert_eq(b.slot_state(0, 0), SS.CHARGING)


# === 不影响既有结算 / clone ===

func test_use_slot_item_resolves() -> void:
	var b := _battle(20)
	# 强制 slot0 = 飞镖以验证结算（绕过随机起手）
	b.slots[0][0]["item"] = ItemCatalog.make("t1_feibiao")
	b.use_slot(0, 0)
	b.select_action(0, A.CHARGE)
	b.select_action(1, A.CHARGE)
	b.resolve()
	assert_eq(b.hp[1][0], 19, "槽内飞镖照常 0.5 伤")


func test_clone_copies_slots_independently() -> void:
	var b := _battle(20)
	var c := b.clone()
	assert_eq(c.slots[0].size(), 3)
	c.slots[0][0]["state"] = SS.EMPTY
	assert_eq(b.slot_state(0, 0), SS.CHARGING, "改 clone 槽态不动原局")
