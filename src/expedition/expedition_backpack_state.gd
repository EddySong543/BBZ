## 远征模式 — 背包拼图状态（纯逻辑·无 UI·可单元测试）。规则源：design/expedition-backpack.md。
##
## 核心张力：装备栏（不占格·撤离不带出）vs 背包（占格·带得走）。
## 用法示例：
##   const Backpack := preload("res://src/expedition/expedition_backpack_state.gd")
##   var bp: Backpack = Backpack.new()
##   if bp.can_place(item["shape"], Vector2i(0, 0)): bp.place(item, item["shape"], Vector2i(0, 0))
extends RefCounted

const Loot := preload("res://src/expedition/expedition_loot.gd")

# ── 调优旋钮（子文档 C §9）──
const MAX_DIM: int = 6                       # 扩容上限 6×6
const INSURANCE_MAX: Vector2i = Vector2i(2, 2)  # 保险槽尺寸上限
const INVALID_CELL: Vector2i = Vector2i(-1, -1)

var rows: int = 4
var cols: int = 4
## 已放置物品：Array[Dictionary] {item, anchor:Vector2i, shape:Array[Vector2i]}
var placements: Array = []
## 保险槽（≤2×2 单件·死亡保留）。空 {} = 无。
var insurance: Dictionary = {}
## 装备栏（上限解开·仅战斗道具·撤离不带出=本局租用）。
var equipment: Array = []


## 返回 {Vector2i 格 -> placement} 占用表。
func occupied_cells() -> Dictionary:
	var occ: Dictionary = {}
	for p: Dictionary in placements:
		for off: Vector2i in p["shape"]:
			occ[Vector2i(p["anchor"]) + off] = p
	return occ


## 形状能否以 anchor 为左上放入（越界/重叠检查）。
func can_place(shape: Array, anchor: Vector2i) -> bool:
	var occ := occupied_cells()
	for off: Vector2i in shape:
		var c: Vector2i = anchor + off
		if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
			return false
		if occ.has(c):
			return false
	return true


## 放入物品（shape = 当前旋转态）。失败返回 false。
func place(item: Dictionary, shape: Array, anchor: Vector2i) -> bool:
	if not can_place(shape, anchor):
		return false
	placements.append({"item": item.duplicate(true), "anchor": anchor, "shape": shape.duplicate()})
	return true


## UI 无关的快捷放置事务。按当前朝向开始尝试四种旋转，行优先找到首个合法位置。
## 返回结构化结果供后续容器 UI 使用；失败绝不丢弃或修改传入物品。
func auto_place(item: Dictionary, allow_rotation: bool = true) -> Dictionary:
	var base_shape_value: Variant = item.get("shape", [])
	if not base_shape_value is Array or (base_shape_value as Array).is_empty():
		return {"ok": false, "reason": "INVALID_SHAPE"}
	var candidate: Array = (base_shape_value as Array).duplicate()
	var seen_shapes: Dictionary = {}
	var rotation_count: int = 4 if allow_rotation else 1
	for rotation: int in rotation_count:
		var shape_key: String = _shape_key(candidate)
		if not seen_shapes.has(shape_key):
			seen_shapes[shape_key] = true
			var anchor: Vector2i = first_fit(candidate)
			if anchor != INVALID_CELL:
				place(item, candidate, anchor)
				return {
					"ok": true,
					"anchor": anchor,
					"shape": candidate.duplicate(),
					"rotations": rotation,
				}
		candidate = Loot.rotate_shape(candidate)
	return {"ok": false, "reason": "NO_SPACE"}


## 给定朝向的第一个合法锚点；无位置返回 INVALID_CELL。
func first_fit(shape: Array) -> Vector2i:
	for y: int in rows:
		for x: int in cols:
			var anchor := Vector2i(x, y)
			if can_place(shape, anchor):
				return anchor
	return INVALID_CELL


## 原子移动：目标非法时完整恢复原 placement，不让 UI 拖拽造成物品丢失。
func move_at(from_cell: Vector2i, target_anchor: Vector2i) -> bool:
	var placement: Dictionary = _placement_at(from_cell)
	if placement.is_empty():
		return false
	var old_index: int = placements.find(placement)
	placements.remove_at(old_index)
	if can_place(placement["shape"], target_anchor):
		placement["anchor"] = target_anchor
		placements.insert(old_index, placement)
		return true
	placements.insert(old_index, placement)
	return false


## 原地旋转同样是事务；越界或碰撞时保持原朝向和位置。
func rotate_at(cell: Vector2i) -> bool:
	var placement: Dictionary = _placement_at(cell)
	if placement.is_empty():
		return false
	var old_index: int = placements.find(placement)
	var rotated: Array = Loot.rotate_shape(placement["shape"])
	placements.remove_at(old_index)
	if can_place(rotated, Vector2i(placement["anchor"])):
		placement["shape"] = rotated
		placements.insert(old_index, placement)
		return true
	placements.insert(old_index, placement)
	return false


## 取走覆盖 cell 的整件物品；返回 placement，无则 {}。
func remove_at(cell: Vector2i) -> Dictionary:
	var p: Dictionary = _placement_at(cell)
	if p.is_empty():
		return {}
	placements.erase(p)
	return p


func _placement_at(cell: Vector2i) -> Dictionary:
	return occupied_cells().get(cell, {})


func _shape_key(shape: Array) -> String:
	var cells: Array[String] = []
	for off: Vector2i in shape:
		cells.append("%d,%d" % [off.x, off.y])
	cells.sort()
	return ";".join(cells)


## 修补匠扩容 +1 行；到 6×6 上限返回 false。
func expand_row() -> bool:
	if rows >= MAX_DIM:
		return false
	rows += 1
	return true


## 修补匠扩容 +1 列；到 6×6 上限返回 false。
func expand_col() -> bool:
	if cols >= MAX_DIM:
		return false
	cols += 1
	return true


## 保险槽能否收下（空槽 + ≤2×2 单件）。
func can_insure(item: Dictionary) -> bool:
	if not insurance.is_empty():
		return false
	var s: Vector2i = Loot.shape_size(item["shape"])
	return s.x <= INSURANCE_MAX.x and s.y <= INSURANCE_MAX.y


## 放入保险槽。失败返回 false。
func insure(item: Dictionary) -> bool:
	if not can_insure(item):
		return false
	insurance = item
	return true


## 取出保险槽物品；空槽返回 {}。
func pop_insurance() -> Dictionary:
	var it := insurance
	insurance = {}
	return it


## 装备战斗道具（非 combat 类拒绝）。
func equip(item: Dictionary) -> bool:
	if String(item.get("cat", "")) != "combat":
		return false
	equipment.append(item)
	return true


## 背包内金币类物品总价值。
func gold_total() -> int:
	var sum: int = 0
	for p: Dictionary in placements:
		sum += int(p["item"].get("gold", 0))
	return sum


## 撤离结算：背包+保险槽全带出（金币折入钱包·其余为货品）；装备栏=本局租用不带出。
## 返回 {gold:int, goods:Array, equipment_lost:int}。
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
	return {"gold": gold, "goods": goods, "equipment_lost": equipment.size()}


## 死亡结算：仅保险槽保留；背包与装备栏（包括金币类）全部消失。
## 返回 {gold:int, kept:Array, lost_count:int}。
func settle_death() -> Dictionary:
	var kept: Array = []
	if not insurance.is_empty():
		kept.append(insurance)
	return {"gold": 0, "kept": kept, "lost_count": placements.size() + equipment.size()}
