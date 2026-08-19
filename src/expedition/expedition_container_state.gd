## 远征容器状态（纯逻辑·无 UI）。
##
## 容器只公开已经揭示的物品；隐藏物品按固定顺序逐件搜索。每件物品的
## required_turns 等于其形状占格数。所有跨边界数据都深拷贝，避免 UI 或
## 战斗交接层意外修改本局状态。
extends RefCounted

const SCHEMA_VERSION: int = 1

var container_id: String = ""
## 内部条目：{entry_id, item, required_turns, progress_turns, revealed}
var _entries: Array[Dictionary] = []
var _next_entry_serial: int = 0


func setup(p_container_id: String, hidden_items: Array) -> void:
	container_id = p_container_id
	_entries.clear()
	_next_entry_serial = 0
	for raw_item: Variant in hidden_items:
		if raw_item is Dictionary:
			_append_entry((raw_item as Dictionary).duplicate(true), false)


## UI 打开容器时只应读取该快照；未揭示物品不会泄漏名称或内容。
func snapshot() -> Dictionary:
	return {
		"container_id": container_id,
		"visible_items": visible_items(),
		"hidden_count": hidden_count(),
		"exhausted": hidden_count() == 0,
	}.duplicate(true)


func visible_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		if bool(entry["revealed"]):
			result.append({
				"entry_id": String(entry["entry_id"]),
				"item": (entry["item"] as Dictionary).duplicate(true),
			})
	return result


func hidden_count() -> int:
	var count: int = 0
	for entry: Dictionary in _entries:
		if not bool(entry["revealed"]):
			count += 1
	return count


## 返回下一件隐藏物品的搜索状态，不包含物品本身。没有隐藏物品时返回 {}。
func next_hidden_status() -> Dictionary:
	for entry: Dictionary in _entries:
		if not bool(entry["revealed"]):
			return _status_for_entry(entry)
	return {}


func search_status(entry_id: String) -> Dictionary:
	var entry: Dictionary = _find_entry(entry_id)
	if entry.is_empty() or bool(entry["revealed"]):
		return {}
	return _status_for_entry(entry)


## 推进指定隐藏物品 1 回合。调用者负责结算敌人行动。
func advance_search(entry_id: String) -> Dictionary:
	var entry: Dictionary = _find_entry(entry_id)
	if entry.is_empty():
		return {"ok": false, "reason": "entry_not_found", "turn_cost": 0}
	if bool(entry["revealed"]):
		return {"ok": false, "reason": "already_revealed", "turn_cost": 0}

	entry["progress_turns"] = mini(
		int(entry["progress_turns"]) + 1,
		int(entry["required_turns"])
	)
	var completed: bool = int(entry["progress_turns"]) >= int(entry["required_turns"])
	entry["revealed"] = completed
	var result: Dictionary = {
		"ok": true,
		"action": "search",
		"turn_cost": 1,
		"entry_id": entry_id,
		"progress_turns": int(entry["progress_turns"]),
		"required_turns": int(entry["required_turns"]),
		"remaining_turns": maxi(0, int(entry["required_turns"]) - int(entry["progress_turns"])),
		"completed": completed,
	}
	if completed:
		result["revealed_item"] = (entry["item"] as Dictionary).duplicate(true)
	return result.duplicate(true)


## 取走一件已揭示物品。成功即从容器移除，并返回地图行动的结算信息。
## 背包 UI 应先确认可放置，再调用本方法；状态层不直接依赖背包实现。
func take_revealed(entry_id: String) -> Dictionary:
	var entry: Dictionary = _find_entry(entry_id)
	if entry.is_empty():
		return {"ok": false, "reason": "entry_not_found", "turn_cost": 0}
	if not bool(entry["revealed"]):
		return {"ok": false, "reason": "item_hidden", "turn_cost": 0}

	var item: Dictionary = (entry["item"] as Dictionary).duplicate(true)
	_entries.erase(entry)
	return {
		"ok": true,
		"action": "take_to_backpack",
		"turn_cost": 1,
		"entry_id": entry_id,
		"item": item,
	}.duplicate(true)


## 将背包物品放回当前容器。玩家亲手放回的物品始终保持可见。
## 调用者负责结算丢入容器所需的地图行动。
func return_from_backpack(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {"ok": false, "reason": "empty_item", "turn_cost": 0}
	var entry_id: String = _append_entry(item.duplicate(true), true)
	return {
		"ok": true,
		"action": "return_to_container",
		"turn_cost": 1,
		"entry_id": entry_id,
		"item": item.duplicate(true),
	}.duplicate(true)


func serialize() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"container_id": container_id,
		"next_entry_serial": _next_entry_serial,
		"entries": _entries.duplicate(true),
	}.duplicate(true)


func restore(data: Dictionary) -> bool:
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	var restored_id: String = String(data.get("container_id", ""))
	var raw_entries: Variant = data.get("entries", [])
	if restored_id.is_empty() or not raw_entries is Array:
		return false

	var restored_entries: Array[Dictionary] = []
	for raw_entry: Variant in raw_entries as Array:
		if not raw_entry is Dictionary:
			return false
		var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
		if not _is_valid_serialized_entry(entry):
			return false
		restored_entries.append(entry)

	container_id = restored_id
	_entries = restored_entries
	_next_entry_serial = maxi(int(data.get("next_entry_serial", restored_entries.size())), restored_entries.size())
	return true


func _append_entry(item: Dictionary, revealed: bool) -> String:
	var entry_id: String = "%s:%d" % [container_id, _next_entry_serial]
	_next_entry_serial += 1
	var required_turns: int = _occupied_cell_count(item)
	_entries.append({
		"entry_id": entry_id,
		"item": item.duplicate(true),
		"required_turns": required_turns,
		"progress_turns": required_turns if revealed else 0,
		"revealed": revealed,
	})
	return entry_id


func _occupied_cell_count(item: Dictionary) -> int:
	var raw_shape: Variant = item.get("shape", [])
	if not raw_shape is Array:
		return 1
	return maxi(1, (raw_shape as Array).size())


func _find_entry(entry_id: String) -> Dictionary:
	for entry: Dictionary in _entries:
		if String(entry["entry_id"]) == entry_id:
			return entry
	return {}


func _status_for_entry(entry: Dictionary) -> Dictionary:
	return {
		"entry_id": String(entry["entry_id"]),
		"progress_turns": int(entry["progress_turns"]),
		"required_turns": int(entry["required_turns"]),
		"remaining_turns": maxi(0, int(entry["required_turns"]) - int(entry["progress_turns"])),
	}.duplicate(true)


func _is_valid_serialized_entry(entry: Dictionary) -> bool:
	for key: String in ["entry_id", "item", "required_turns", "progress_turns", "revealed"]:
		if not entry.has(key):
			return false
	if not entry["item"] is Dictionary:
		return false
	var required: int = int(entry["required_turns"])
	var progress: int = int(entry["progress_turns"])
	return required >= 1 and progress >= 0 and progress <= required
