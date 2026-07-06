## 背包逻辑 headless 自检：
## godot --headless --path <项目根> --script res://prototypes/expedition/backpack_proto/selfcheck_backpack.gd
extends SceneTree

const BackpackState := preload("res://prototypes/expedition/backpack_proto/backpack_state.gd")
const LootGen := preload("res://prototypes/expedition/loot_gen.gd")

var fails: int = 0

func _check(name: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + name)
	if not ok:
		fails += 1

func _item(name: String, cat: String, shape: Array, gold: int) -> Dictionary:
	return {"id": name, "name": name, "cat": cat, "tier": 1, "shape": shape, "gold": gold, "note": ""}

func _init() -> void:
	print("=== 背包原型自检 ===")
	var s: BackpackState = BackpackState.new()
	# 放置/越界/重叠
	_check("放 2×2 于 (0,0)", s.place(_item("古瓮", "gold", LootGen.SHAPE_2X2, 120), LootGen.SHAPE_2X2, Vector2i(0, 0)))
	_check("重叠被拒：(1,1) 放 1×1", not s.can_place(LootGen.SHAPE_1X1, Vector2i(1, 1)))
	_check("越界被拒：(3,3) 放 1×2（4×4 包）", not s.can_place(LootGen.SHAPE_1X2, Vector2i(3, 3)))
	_check("合法放置：(3,3) 放 1×1", s.place(_item("碎宝石", "gold", LootGen.SHAPE_1X1, 20), LootGen.SHAPE_1X1, Vector2i(3, 3)))
	# 旋转：1×2 横 → 竖 → 横（周期 2）；L 形周期 4
	var r1: Array = LootGen.rotate_shape(LootGen.SHAPE_1X2)
	_check("旋转 1×2 → 2×1", LootGen.shape_size(r1) == Vector2i(1, 2))
	var l: Array = LootGen.SHAPE_L
	for i: int in 4:
		l = LootGen.rotate_shape(l)
	_check("L 形转 4 次回原形", LootGen.shape_size(l) == LootGen.shape_size(LootGen.SHAPE_L) and l.size() == 3)
	# 取回
	var p: Dictionary = s.remove_at(Vector2i(1, 0))
	_check("点 (1,0) 取回整件古瓮", not p.is_empty() and String(p["item"]["name"]) == "古瓮" and s.placements.size() == 1)
	# 扩容
	var g: BackpackState = BackpackState.new()
	var grew: int = 0
	for i: int in 5:
		if g.expand_row():
			grew += 1
	_check("扩行封顶：4→6 只成功 2 次（第 3 次起拒绝）", grew == 2 and g.rows == 6)
	# 保险槽
	var ins: BackpackState = BackpackState.new()
	_check("保险槽收 2×2", ins.insure(_item("宠物蛋", "rare", LootGen.SHAPE_2X2, 0)))
	_check("保险槽已满再收被拒", not ins.insure(_item("碎宝石", "gold", LootGen.SHAPE_1X1, 20)))
	var ins2: BackpackState = BackpackState.new()
	_check("保险槽拒 2×3（超尺寸）", not ins2.insure(_item("屏风", "gold", LootGen.SHAPE_2X3, 210)))
	# 装备栏
	var eq: BackpackState = BackpackState.new()
	_check("装备战斗道具 OK", eq.equip(_item("T1 道具", "combat", LootGen.SHAPE_1X1, 0)))
	_check("装备金币类被拒", not eq.equip(_item("金锭", "gold", LootGen.SHAPE_1X2, 50)))
	# 结算
	var st: BackpackState = BackpackState.new()
	st.place(_item("金锭", "gold", LootGen.SHAPE_1X2, 50), LootGen.SHAPE_1X2, Vector2i(0, 0))
	st.place(_item("碎宝石", "gold", LootGen.SHAPE_1X1, 20), LootGen.SHAPE_1X1, Vector2i(0, 1))
	st.place(_item("T2 道具", "combat", LootGen.SHAPE_1X2, 0), LootGen.SHAPE_1X2, Vector2i(0, 2))
	st.equip(_item("T1 道具", "combat", LootGen.SHAPE_1X1, 0))
	st.insure(_item("英雄碎片", "rare", LootGen.SHAPE_1X1, 0))
	var ext: Dictionary = st.settle_extract()
	_check("撤离：金币 70·货 2 件（含保险槽）·装备 1 件不带出", int(ext["gold"]) == 70 and (ext["goods"] as Array).size() == 2 and int(ext["equipment_lost"]) == 1)
	var death: Dictionary = st.settle_death()
	_check("死亡：金币 21 = floor(70×0.3)·保住 1 件（保险槽）·丢 4 件", int(death["gold"]) == 21 and (death["kept"] as Array).size() == 1 and int(death["lost_count"]) == 4)
	# 掉落表冒烟：四种 kind 各滚 50 次不炸且件数在带内
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts_ok: bool = true
	for kind: String in ["t1", "t2", "t3", "chest"]:
		for i: int in 50:
			var drop: Array = LootGen.roll_drop(rng, kind)
			var n: int = drop.size()
			var lo: int = {"t1": 1, "t2": 2, "t3": 3, "chest": 2}[kind]
			var hi: int = {"t1": 2, "t2": 3, "t3": 4, "chest": 2}[kind]
			if n < lo or n > hi:
				counts_ok = false
	_check("掉落表：4 种来源×50 滚·件数全部落带", counts_ok)
	print("=== 自检结束：%s ===" % ("全部通过" if fails == 0 else "%d 项失败" % fails))
	quit(0 if fails == 0 else 1)
