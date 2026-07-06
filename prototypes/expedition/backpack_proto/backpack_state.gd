## 背包拼图逻辑层（无 UI·可 headless 自检）——子文档 C 规则
## 原型代码·可丢弃。
extends RefCounted

const LootGen := preload("res://prototypes/expedition/loot_gen.gd")

const MAX_DIM: int = 6
const DEATH_GOLD_RATE: float = 0.3
const INSURANCE_MAX: Vector2i = Vector2i(2, 2)

var rows: int = 4
var cols: int = 4
## 已放置：Array[Dictionary] {item, anchor:Vector2i, shape:Array[Vector2i]}
var placements: Array = []
var insurance: Dictionary = {}   # 空 {} = 无
var equipment: Array = []        # 装备栏（上限解开·仅战斗道具）
var achievements: int = 0        # 成就不占格

func occupied_cells() -> Dictionary:
	var occ: Dictionary = {}
	for p: Dictionary in placements:
		for off: Vector2i in p["shape"]:
			occ[Vector2i(p["anchor"]) + off] = p
	return occ

func can_place(shape: Array, anchor: Vector2i) -> bool:
	var occ := occupied_cells()
	for off: Vector2i in shape:
		var c: Vector2i = anchor + off
		if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
			return false
		if occ.has(c):
			return false
	return true

func place(item: Dictionary, shape: Array, anchor: Vector2i) -> bool:
	if not can_place(shape, anchor):
		return false
	placements.append({"item": item, "anchor": anchor, "shape": shape.duplicate()})
	return true

## 取走 cell 上的物品；返回 placement 或 {}
func remove_at(cell: Vector2i) -> Dictionary:
	var occ := occupied_cells()
	if not occ.has(cell):
		return {}
	var p: Dictionary = occ[cell]
	placements.erase(p)
	return p

func expand_row() -> bool:
	if rows >= MAX_DIM:
		return false
	rows += 1
	return true

func expand_col() -> bool:
	if cols >= MAX_DIM:
		return false
	cols += 1
	return true

## 保险槽：≤2×2 单件
func can_insure(item: Dictionary) -> bool:
	if not insurance.is_empty():
		return false
	var size: Vector2i = LootGen.shape_size(item["shape"])
	return size.x <= INSURANCE_MAX.x and size.y <= INSURANCE_MAX.y

func insure(item: Dictionary) -> bool:
	if not can_insure(item):
		return false
	insurance = item
	return true

func pop_insurance() -> Dictionary:
	var it := insurance
	insurance = {}
	return it

func equip(item: Dictionary) -> bool:
	if String(item.get("cat", "")) != "combat":
		return false
	equipment.append(item)
	return true

func gold_total() -> int:
	var sum: int = 0
	for p: Dictionary in placements:
		sum += int(p["item"].get("gold", 0))
	return sum

## 撤离结算：背包+保险槽全带出；装备栏=本局租用不带出（T3 不进 PvP 格1候选=标注层）
func settle_extract() -> Dictionary:
	var items: Array = []
	for p: Dictionary in placements:
		items.append(p["item"])
	if not insurance.is_empty():
		items.append(insurance)
	var gold: int = 0
	var goods: Array = []
	for it: Dictionary in items:
		if String(it["cat"]) == "gold":
			gold += int(it["gold"])
		else:
			goods.append(it)
	return {"gold": gold, "goods": goods, "achievements": achievements, "equipment_lost": equipment.size()}

## 死亡结算：仅保险槽+成就保留；金币类 30% 折算；其余消失；装备栏全灭
func settle_death() -> Dictionary:
	var gold: int = int(floor(float(gold_total()) * DEATH_GOLD_RATE))
	var kept: Array = []
	if not insurance.is_empty():
		kept.append(insurance)
	var lost_count: int = placements.size() + equipment.size()
	return {"gold": gold, "kept": kept, "achievements": achievements, "lost_count": lost_count}
