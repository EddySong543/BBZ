## 远征模式 — 战利品目录与掉落生成（数据源：design/expedition-backpack.md §3/§7 草稿）。
##
## 物品字典 schema：
##   {id:String, name:String, cat:String(gold|consumable|combat|rare),
##    tier:int(战斗道具 1-3·其余 0), shape:Array[Vector2i], gold:int, note:String,
##    icon:String(expedition_pixel_art 图签 id), combat_id:String(仅战斗道具·=PvP ItemCatalog id)}
##
## 战斗道具 = 真 PvP 道具（按 tier 随机抽 ItemCatalog·名字图标同源·为局外闭环 F 铺路）。
##
## 用法示例：
##   const Loot := preload("res://src/expedition/expedition_loot.gd")
##   var drop: Array = Loot.roll_drop(rng, "t2")   # 击杀 T2 怪的掉落
##
## ⚠「鎏金屏风 2×3」「1×3 战斗道具」= 补齐形状库的占位物品（非正典·转正待 Eddy）。
extends RefCounted

const ItemCatalog := preload("res://src/battle/item_catalog.gd")

# ── 形状库（子文档 C §1 首发 7 形）──
const SHAPE_1X1: Array = [Vector2i(0, 0)]
const SHAPE_1X2: Array = [Vector2i(0, 0), Vector2i(1, 0)]
const SHAPE_1X3: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
const SHAPE_2X1: Array = [Vector2i(0, 0), Vector2i(0, 1)]
const SHAPE_2X2: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const SHAPE_L: Array = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
const SHAPE_2X3: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]

# ── 目录（调优旋钮：价值密度随体积递增·1×1=20 → 蟠龙冠 67/格）──
const GOLD_DEFS: Array = [
	{"id": "gem", "name": "碎宝石", "shape": SHAPE_1X1, "gold": 20, "w": 40, "icon": "gem"},
	{"id": "ingot", "name": "金锭", "shape": SHAPE_1X2, "gold": 50, "w": 30, "icon": "ingot"},
	{"id": "urn", "name": "古瓮", "shape": SHAPE_2X2, "gold": 120, "w": 15, "icon": "urn"},
	{"id": "crown", "name": "蟠龙冠", "shape": SHAPE_L, "gold": 200, "w": 10, "icon": "crown"},
	{"id": "screen", "name": "鎏金屏风", "shape": SHAPE_2X3, "gold": 210, "w": 5, "icon": "screen"},
]
const CONSUMABLE_DEFS: Array = [
	{"id": "potion", "name": "药瓶", "shape": SHAPE_1X1, "w": 60, "note": "单英雄 +1 HP", "icon": "potion"},
	{"id": "soup", "name": "大补汤", "shape": SHAPE_2X1, "w": 40, "note": "全队 +0.5 HP", "icon": "soup"},
]
const RARE_DEFS: Array = [
	{"id": "shard", "name": "英雄碎片", "shape": SHAPE_1X1, "w": 50, "icon": "shard"},
	{"id": "skin", "name": "皮肤卷轴", "shape": SHAPE_1X2, "w": 35, "icon": "scroll"},
	{"id": "egg", "name": "宠物蛋", "shape": SHAPE_2X2, "w": 15, "icon": "egg"},
]


## 生成一件金币类物品（体积权重偏小件）。
static func make_gold(rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = _weighted_pick(rng, GOLD_DEFS)
	return {"id": d["id"], "name": d["name"], "cat": "gold", "tier": 0,
		"shape": d["shape"], "gold": int(d["gold"]), "note": "%d金" % int(d["gold"]), "icon": d["icon"]}


## 生成一件消耗品。
static func make_consumable(rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = _weighted_pick(rng, CONSUMABLE_DEFS)
	return {"id": d["id"], "name": d["name"], "cat": "consumable", "tier": 0,
		"shape": d["shape"], "gold": 0, "note": String(d.get("note", "")), "icon": d["icon"]}


## 生成一件战斗道具 = 按 tier 随机抽一件真 PvP 道具（名字/图标同源·撤离带出即入 PvP 池的伏笔）。
static func make_combat(rng: RandomNumberGenerator, tier: int) -> Dictionary:
	var shape: Array = SHAPE_1X1
	if tier == 2:
		shape = SHAPE_1X2 if rng.randf() < 0.8 else SHAPE_1X3
	elif tier == 3:
		shape = SHAPE_2X2
	var pool: Array[ItemData] = ItemCatalog.all_for_tier(tier)
	var combat_id: String = ""
	var display: String = "T%d 战斗道具" % tier
	if not pool.is_empty():
		var pick: ItemData = pool[rng.randi_range(0, pool.size() - 1)]
		combat_id = String(pick.item_id)
		display = String(pick.item_name)
	return {"id": "combat_t%d" % tier, "name": display, "cat": "combat",
		"tier": tier, "shape": shape, "gold": 0, "note": "T%d·可装备或入包带出" % tier,
		"icon": "sword", "combat_id": combat_id}


## 生成一件稀有层物品。
static func make_rare(rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = _weighted_pick(rng, RARE_DEFS)
	return {"id": d["id"], "name": d["name"], "cat": "rare", "tier": 0,
		"shape": d["shape"], "gold": 0, "note": "极稀有", "icon": d["icon"]}


## 掉落表（子文档 C §7 草稿）。kind: "t1"|"t2"|"t3"|"chest"。
## 返回物品字典数组：t1=1-2 件 / t2=2-3 件(战斗道具权重×2) / t3=3-4 件+必 1 战斗道具 / chest=2 件(稀有 ~2%)。
static func roll_drop(rng: RandomNumberGenerator, kind: String) -> Array:
	var out: Array = []
	match kind:
		"t1":
			for i: int in rng.randi_range(1, 2):
				out.append(_roll_one(rng, 70, 20, 10, 0, 1))
		"t2":
			for i: int in rng.randi_range(2, 3):
				out.append(_roll_one(rng, 70, 20, 20, 0, 2))
		"t3":
			out.append(make_combat(rng, 3 if rng.randf() < 0.4 else 2))
			for i: int in rng.randi_range(2, 3):
				out.append(_roll_one(rng, 70, 20, 20, 0, 2))
		"chest":
			for i: int in 2:
				out.append(_roll_one(rng, 65, 15, 18, 2, 1))
	return out


## 形状顺时针旋转 90°：(x,y) → (-y,x)，平移归零。
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


## 形状包围盒尺寸（宽,高）。
static func shape_size(shape: Array) -> Vector2i:
	var mx: int = 0
	var my: int = 0
	for c: Vector2i in shape:
		mx = maxi(mx, c.x)
		my = maxi(my, c.y)
	return Vector2i(mx + 1, my + 1)


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
			tier = 1
		return make_combat(rng, tier)
	return make_rare(rng)
