## 远征原型共享：掉落生成器（占位数值=子文档 C §7 草稿掉落表）
## 原型代码·可丢弃。物品 = Dictionary：
##   {id, name, cat(gold|consumable|combat|rare), tier(战斗道具用), shape:Array[Vector2i], gold(折算价值), note}
extends RefCounted

const SHAPE_1X1: Array = [Vector2i(0, 0)]
const SHAPE_1X2: Array = [Vector2i(0, 0), Vector2i(1, 0)]
const SHAPE_1X3: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const SHAPE_2X1: Array = [Vector2i(0, 0), Vector2i(0, 1)]
const SHAPE_2X2: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const SHAPE_L: Array = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
const SHAPE_2X3: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]

## 金币类（价值密度随体积递增·子文档 C §3）＋屏风=原型占位补 2×3 形状
static func _gold_defs() -> Array:
	return [
		{"id": "gem", "name": "碎宝石", "shape": SHAPE_1X1, "gold": 20, "w": 40},
		{"id": "ingot", "name": "金锭", "shape": SHAPE_1X2, "gold": 50, "w": 30},
		{"id": "urn", "name": "古瓮", "shape": SHAPE_2X2, "gold": 120, "w": 15},
		{"id": "crown", "name": "蟠龙冠", "shape": SHAPE_L, "gold": 200, "w": 10},
		{"id": "screen", "name": "鎏金屏风·占位", "shape": SHAPE_2X3, "gold": 210, "w": 5},
	]

static func _consumable_defs() -> Array:
	return [
		{"id": "ration", "name": "干粮", "shape": SHAPE_1X1, "gold": 0, "w": 50, "note": "+10 补给"},
		{"id": "potion", "name": "药瓶", "shape": SHAPE_1X1, "gold": 0, "w": 30, "note": "单英雄 +1 HP"},
		{"id": "soup", "name": "大补汤", "shape": SHAPE_2X1, "gold": 0, "w": 20, "note": "全队 +0.5 HP"},
	]

static func _rare_defs() -> Array:
	return [
		{"id": "shard", "name": "英雄碎片", "shape": SHAPE_1X1, "gold": 0, "w": 50},
		{"id": "skin", "name": "皮肤卷轴", "shape": SHAPE_1X2, "gold": 0, "w": 35},
		{"id": "egg", "name": "宠物蛋", "shape": SHAPE_2X2, "gold": 0, "w": 15},
	]

static func _weighted_pick(rng: RandomNumberGenerator, defs: Array) -> Dictionary:
	var total: int = 0
	for d: Dictionary in defs:
		total += int(d["w"])
	var roll: int = rng.randi_range(1, total)
	for d: Dictionary in defs:
		roll -= int(d["w"])
		if roll <= 0:
			return d
	return defs[0]

static func make_gold(rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = _weighted_pick(rng, _gold_defs())
	return {"id": d["id"], "name": d["name"], "cat": "gold", "tier": 0, "shape": d["shape"], "gold": d["gold"], "note": "%d金" % int(d["gold"])}

static func make_consumable(rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = _weighted_pick(rng, _consumable_defs())
	return {"id": d["id"], "name": d["name"], "cat": "consumable", "tier": 0, "shape": d["shape"], "gold": 0, "note": d.get("note", "")}

static func make_combat(rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var shape: Array = SHAPE_1X1
	if tier == 2:
		shape = SHAPE_1X2 if rng.randf() < 0.8 else SHAPE_1X3  # 1×3=原型占位补形状
	elif tier == 3:
		shape = SHAPE_2X2
	return {"id": "combat_t%d" % tier, "name": "T%d 战斗道具·占位" % tier, "cat": "combat", "tier": tier, "shape": shape, "gold": 0, "note": "可装备/入包带出"}

static func make_rare(rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = _weighted_pick(rng, _rare_defs())
	return {"id": d["id"], "name": d["name"], "cat": "rare", "tier": 0, "shape": d["shape"], "gold": 0, "note": "极稀有"}

## 掉落表（子文档 C §7 草稿）：kind = t1 | t2 | t3 | chest
static func roll_drop(rng: RandomNumberGenerator, kind: String) -> Array:
	var out: Array = []
	match kind:
		"t1":
			for i: int in rng.randi_range(1, 2):
				out.append(_roll_one(rng, 70, 20, 10, 0, 1))
		"t2":
			for i: int in rng.randi_range(2, 3):
				out.append(_roll_one(rng, 70, 20, 20, 0, 2))  # 战斗道具权重 ×2
		"t3":
			out.append(make_combat(rng, 3 if rng.randf() < 0.4 else 2))  # 必 1 战斗道具
			for i: int in rng.randi_range(2, 3):
				out.append(_roll_one(rng, 70, 20, 20, 0, 2))
		"chest":
			for i: int in 2:
				out.append(_roll_one(rng, 65, 15, 18, 2, 1))
	return out

static func _roll_one(rng: RandomNumberGenerator, w_gold: int, w_cons: int, w_combat: int, w_rare: int, combat_tier: int) -> Dictionary:
	var roll: int = rng.randi_range(1, w_gold + w_cons + w_combat + w_rare)
	if roll <= w_gold:
		return make_gold(rng)
	roll -= w_gold
	if roll <= w_cons:
		return make_consumable(rng)
	roll -= w_cons
	if roll <= w_combat:
		var tier: int = combat_tier
		if combat_tier == 2 and rng.randf() < 0.8:
			tier = 1  # T2 掉落里战斗道具 80% 仍为 T1
		return make_combat(rng, tier)
	return make_rare(rng)

## 形状顺时针旋转 90°：(x,y) -> (-y,x)，再平移归零
static func rotate_shape(shape: Array) -> Array:
	var rotated: Array = []
	var min_x: int = 99
	var min_y: int = 99
	for c: Vector2i in shape:
		var nc := Vector2i(-c.y, c.x)
		rotated.append(nc)
		min_x = mini(min_x, nc.x)
		min_y = mini(min_y, nc.y)
	var out: Array = []
	for c: Vector2i in rotated:
		out.append(Vector2i(c.x - min_x, c.y - min_y))
	return out

static func shape_size(shape: Array) -> Vector2i:
	var mx: int = 0
	var my: int = 0
	for c: Vector2i in shape:
		mx = maxi(mx, c.x)
		my = maxi(my, c.y)
	return Vector2i(mx + 1, my + 1)
