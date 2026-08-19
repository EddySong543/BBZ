extends GutTest

## 远征背包拼图状态 行为锁定测试（规则源：design/expedition-backpack.md）。
## 覆盖：放置合法性 / 旋转 / 整件取回 / 扩容封顶 / 保险槽尺寸门 / 装备类型门 / 撤离与死亡双结算 / 掉落表件数带。

const Backpack := preload("res://src/expedition/expedition_backpack_state.gd")
const Loot := preload("res://src/expedition/expedition_loot.gd")


func _item(item_name: String, cat: String, shape: Array, gold: int = 0) -> Dictionary:
	return {"id": item_name, "name": item_name, "cat": cat, "tier": 1, "shape": shape, "gold": gold, "note": ""}


func test_backpack_place_valid_succeeds() -> void:
	# Arrange
	var bp: Backpack = Backpack.new()
	# Act
	var ok: bool = bp.place(_item("古瓮", "gold", Loot.SHAPE_2X2, 120), Loot.SHAPE_2X2, Vector2i(0, 0))
	# Assert
	assert_true(ok)
	assert_eq(bp.placements.size(), 1)


func test_backpack_place_overlap_rejected() -> void:
	# Arrange
	var bp: Backpack = Backpack.new()
	bp.place(_item("古瓮", "gold", Loot.SHAPE_2X2, 120), Loot.SHAPE_2X2, Vector2i(0, 0))
	# Act + Assert
	assert_false(bp.can_place(Loot.SHAPE_1X1, Vector2i(1, 1)))


func test_backpack_place_out_of_bounds_rejected() -> void:
	# Arrange
	var bp: Backpack = Backpack.new()
	# Act + Assert：4×4 包 (3,3) 放 1×2 越界
	assert_false(bp.can_place(Loot.SHAPE_1X2, Vector2i(3, 3)))
	assert_true(bp.can_place(Loot.SHAPE_1X1, Vector2i(3, 3)))


func test_loot_rotate_shapes_cycle_correctly() -> void:
	# Arrange + Act
	var r1: Array = Loot.rotate_shape(Loot.SHAPE_1X2)
	var l: Array = Loot.SHAPE_L
	for i: int in 4:
		l = Loot.rotate_shape(l)
	# Assert：1×2 转一次成 2×1；L 形转 4 次回原尺寸
	assert_eq(Loot.shape_size(r1), Vector2i(1, 2))
	assert_eq(Loot.shape_size(l), Loot.shape_size(Loot.SHAPE_L))
	assert_eq(l.size(), 3)


func test_backpack_remove_at_returns_whole_item() -> void:
	# Arrange
	var bp: Backpack = Backpack.new()
	bp.place(_item("古瓮", "gold", Loot.SHAPE_2X2, 120), Loot.SHAPE_2X2, Vector2i(0, 0))
	# Act：点 (1,1)（占用格之一）取回整件
	var p: Dictionary = bp.remove_at(Vector2i(1, 1))
	# Assert
	assert_eq(String(p["item"]["name"]), "古瓮")
	assert_eq(bp.placements.size(), 0)


func test_backpack_auto_place_returns_transaction_result() -> void:
	var bp: Backpack = Backpack.new()
	var item: Dictionary = _item("金锭", "gold", Loot.SHAPE_1X2, 50)
	var result: Dictionary = bp.auto_place(item)

	assert_true(bool(result["ok"]))
	assert_eq(Vector2i(result["anchor"]), Vector2i.ZERO)
	assert_eq(int(result["rotations"]), 0)
	assert_eq(bp.placements.size(), 1)
	item["name"] = "外部篡改"
	assert_eq(String(bp.placements[0]["item"]["name"]), "金锭",
			"背包必须持有深拷贝，容器/UI 不能从外部污染已放入物品")


func test_backpack_failed_move_restores_original_placement() -> void:
	var bp: Backpack = Backpack.new()
	bp.place(_item("古瓮", "gold", Loot.SHAPE_2X2, 120), Loot.SHAPE_2X2, Vector2i(0, 0))
	bp.place(_item("碎宝石", "gold", Loot.SHAPE_1X1, 20), Loot.SHAPE_1X1, Vector2i(2, 0))

	assert_false(bp.move_at(Vector2i(0, 0), Vector2i(1, 0)))
	assert_eq(bp.placements.size(), 2)
	assert_eq(Vector2i(bp.placements[0]["anchor"]), Vector2i.ZERO)
	assert_eq(String(bp.remove_at(Vector2i(1, 1))["item"]["name"]), "古瓮")


func test_backpack_rotation_is_atomic_when_new_shape_would_overflow() -> void:
	var bp: Backpack = Backpack.new()
	bp.place(_item("金锭", "gold", Loot.SHAPE_1X2, 50), Loot.SHAPE_1X2, Vector2i(2, 3))

	assert_false(bp.rotate_at(Vector2i(2, 3)))
	assert_eq(bp.placements[0]["shape"], Loot.SHAPE_1X2)


func test_backpack_expand_caps_at_six() -> void:
	# Arrange
	var bp: Backpack = Backpack.new()
	# Act
	var grew: int = 0
	for i: int in 5:
		if bp.expand_row():
			grew += 1
	# Assert：4→6 只成功 2 次
	assert_eq(grew, 2)
	assert_eq(bp.rows, 6)


func test_insurance_accepts_2x2_rejects_larger_and_second() -> void:
	# Arrange
	var bp: Backpack = Backpack.new()
	# Act + Assert
	assert_true(bp.insure(_item("宠物蛋", "rare", Loot.SHAPE_2X2)))
	assert_false(bp.insure(_item("碎宝石", "gold", Loot.SHAPE_1X1, 20)), "已有物品应拒绝")
	var bp2: Backpack = Backpack.new()
	assert_false(bp2.insure(_item("鎏金屏风", "gold", Loot.SHAPE_2X3, 210)), "2×3 超尺寸应拒绝")


func test_equip_combat_only() -> void:
	# Arrange
	var bp: Backpack = Backpack.new()
	# Act + Assert
	assert_true(bp.equip(_item("T1 道具", "combat", Loot.SHAPE_1X1)))
	assert_false(bp.equip(_item("金锭", "gold", Loot.SHAPE_1X2, 50)))


func test_settle_extract_counts_backpack_and_insurance_not_equipment() -> void:
	# Arrange
	var bp: Backpack = Backpack.new()
	bp.place(_item("金锭", "gold", Loot.SHAPE_1X2, 50), Loot.SHAPE_1X2, Vector2i(0, 0))
	bp.place(_item("碎宝石", "gold", Loot.SHAPE_1X1, 20), Loot.SHAPE_1X1, Vector2i(0, 1))
	bp.place(_item("T2 道具", "combat", Loot.SHAPE_1X2), Loot.SHAPE_1X2, Vector2i(0, 2))
	bp.equip(_item("T1 道具", "combat", Loot.SHAPE_1X1))
	bp.insure(_item("英雄碎片", "rare", Loot.SHAPE_1X1))
	# Act
	var r: Dictionary = bp.settle_extract()
	# Assert：金币 70·货 2 件（T2 道具+保险槽碎片）·装备 1 件不带出
	assert_eq(int(r["gold"]), 70)
	assert_eq((r["goods"] as Array).size(), 2)
	assert_eq(int(r["equipment_lost"]), 1)


func test_settle_death_keeps_only_insurance_and_loses_all_gold() -> void:
	# Arrange
	var bp: Backpack = Backpack.new()
	bp.place(_item("金锭", "gold", Loot.SHAPE_1X2, 50), Loot.SHAPE_1X2, Vector2i(0, 0))
	bp.place(_item("碎宝石", "gold", Loot.SHAPE_1X1, 20), Loot.SHAPE_1X1, Vector2i(0, 1))
	bp.place(_item("T2 道具", "combat", Loot.SHAPE_1X2), Loot.SHAPE_1X2, Vector2i(0, 2))
	bp.equip(_item("T1 道具", "combat", Loot.SHAPE_1X1))
	bp.insure(_item("英雄碎片", "rare", Loot.SHAPE_1X1))
	# Act
	var r: Dictionary = bp.settle_death()
	# Assert：金币不保底·保住保险槽 1 件·背包 3+装备 1 = 4 件消失
	assert_eq(int(r["gold"]), 0)
	assert_eq((r["kept"] as Array).size(), 1)
	assert_eq(int(r["lost_count"]), 4)


func test_loot_drop_counts_stay_in_band() -> void:
	# Arrange：种子固定 → 确定性
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bands: Dictionary = {"t1": [1, 2], "t2": [2, 3], "t3": [3, 4], "chest": [2, 2]}
	# Act + Assert：四种来源各滚 50 次件数全落带
	for kind: String in bands:
		for i: int in 50:
			var n: int = Loot.roll_drop(rng, kind).size()
			assert_between(n, int(bands[kind][0]), int(bands[kind][1]), "kind=%s 件数出带" % kind)
