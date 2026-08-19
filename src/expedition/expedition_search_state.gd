## 远征搜索会话（纯逻辑·无 UI）。
##
## 管理打开容器、显式开始下一件搜索、逐回合推进、敌人提示暂停、主动/战斗
## 中断以及战斗交接序列化。敌人行动和背包摆放由上层依据返回的 turn_cost
## 统一结算；远征不再存在探索能量。
extends RefCounted

const ContainerState := preload("res://src/expedition/expedition_container_state.gd")
const SCHEMA_VERSION: int = 1

signal container_opened(snapshot: Dictionary)
signal search_started(status: Dictionary)
signal search_progressed(result: Dictionary)
signal search_interrupted(reason: String, status: Dictionary)
signal enemy_pause_requested(payload: Dictionary)
signal container_changed(snapshot: Dictionary)

var _containers: Dictionary = {}
var _open_container_id: String = ""
var _active_entry_id: String = ""
var _paused_enemy_id: String = ""
var _paused_enemy_distance: int = -1
var _acknowledged_enemies: Dictionary = {}


func register_container(container_id: String, hidden_items: Array) -> bool:
	if container_id.is_empty() or _containers.has(container_id):
		return false
	var container: ContainerState = ContainerState.new()
	container.setup(container_id, hidden_items.duplicate(true))
	_containers[container_id] = container
	return true


func has_container(container_id: String) -> bool:
	return _containers.has(container_id)


## 打开容器本身不消耗回合；已揭示物品会立即包含在返回快照中。
func open_container(container_id: String) -> Dictionary:
	if not _containers.has(container_id):
		return {"ok": false, "reason": "container_not_found", "turn_cost": 0}
	if not _active_entry_id.is_empty() or not _paused_enemy_id.is_empty():
		interrupt("switched_container")
	_open_container_id = container_id
	var result: Dictionary = {
		"ok": true,
		"action": "open_container",
		"turn_cost": 0,
		"container": _container_snapshot(container_id),
	}.duplicate(true)
	container_opened.emit(result.duplicate(true))
	return result


func close_container(reason: String = "left_container") -> Dictionary:
	var interrupted: Dictionary = interrupt(reason)
	var previous_id: String = _open_container_id
	_open_container_id = ""
	return {
		"ok": not previous_id.is_empty(),
		"action": "close_container",
		"turn_cost": 0,
		"container_id": previous_id,
		"interrupted": bool(interrupted.get("ok", false)),
	}.duplicate(true)


func open_snapshot() -> Dictionary:
	if _open_container_id.is_empty():
		return {}
	return _container_snapshot(_open_container_id)


## 必须显式调用，完成一件物品后不会自动接续下一件。
func start_next_item() -> Dictionary:
	if _open_container_id.is_empty():
		return {"ok": false, "reason": "no_open_container", "turn_cost": 0}
	if not _active_entry_id.is_empty():
		return {"ok": false, "reason": "search_already_active", "turn_cost": 0}

	var container: ContainerState = _containers[_open_container_id]
	var status: Dictionary = container.next_hidden_status()
	if status.is_empty():
		return {"ok": false, "reason": "container_exhausted", "turn_cost": 0}
	_active_entry_id = String(status["entry_id"])
	_paused_enemy_id = ""
	_paused_enemy_distance = -1
	var result: Dictionary = {
		"ok": true,
		"action": "start_search",
		"turn_cost": 0,
		"container_id": _open_container_id,
		"search": status,
	}.duplicate(true)
	search_started.emit(result.duplicate(true))
	return result


## 推进当前物品 1 回合；返回 turn_cost=1 供地图层同步敌人行动。
func advance_turn() -> Dictionary:
	if _active_entry_id.is_empty():
		return {"ok": false, "reason": "no_active_search", "turn_cost": 0}
	if not _paused_enemy_id.is_empty():
		return {"ok": false, "reason": "enemy_pause_pending", "turn_cost": 0}
	var container: ContainerState = _containers[_open_container_id]
	var result: Dictionary = container.advance_search(_active_entry_id)
	result["container_id"] = _open_container_id
	if bool(result.get("completed", false)):
		_active_entry_id = ""
	search_progressed.emit(result.duplicate(true))
	if bool(result.get("completed", false)):
		container_changed.emit(_container_snapshot(_open_container_id))
	return result.duplicate(true)


## 新敌人首次进入视野时暂停。玩家强行继续后，同一敌人不会重复打断。
func notify_new_enemy(enemy_id: String, distance: int) -> Dictionary:
	if enemy_id.is_empty() or _active_entry_id.is_empty():
		return {"ok": false, "reason": "no_active_search", "paused": false, "turn_cost": 0}
	if _acknowledged_enemies.has(enemy_id) or _paused_enemy_id == enemy_id:
		return {"ok": true, "paused": false, "reason": "enemy_already_acknowledged", "turn_cost": 0}
	if not _paused_enemy_id.is_empty():
		return {"ok": false, "paused": true, "reason": "another_enemy_pause_pending", "turn_cost": 0}

	_paused_enemy_id = enemy_id
	_paused_enemy_distance = maxi(0, distance)
	var status: Dictionary = _current_search_status()
	var result: Dictionary = {
		"ok": true,
		"action": "pause_for_new_enemy",
		"paused": true,
		"turn_cost": 0,
		"enemy_id": enemy_id,
		"enemy_distance": _paused_enemy_distance,
		"remaining_turns": int(status.get("remaining_turns", 0)),
	}.duplicate(true)
	enemy_pause_requested.emit(result.duplicate(true))
	return result


## force_continue=true：继续当前物品；false：停止搜索但保留已经推进的回合。
func resolve_enemy_pause(force_continue: bool) -> Dictionary:
	if _paused_enemy_id.is_empty():
		return {"ok": false, "reason": "no_enemy_pause", "turn_cost": 0}
	var enemy_id: String = _paused_enemy_id
	_acknowledged_enemies[enemy_id] = true
	_paused_enemy_id = ""
	_paused_enemy_distance = -1
	if force_continue:
		return {
			"ok": true,
			"action": "force_continue_search",
			"turn_cost": 0,
			"enemy_id": enemy_id,
			"search": _current_search_status(),
		}.duplicate(true)
	var interrupted: Dictionary = interrupt("enemy_spotted")
	interrupted["enemy_id"] = enemy_id
	return interrupted.duplicate(true)


## 主动离开与战斗接触均调用本口；容器中的逐件进度不会被清空。
func interrupt(reason: String) -> Dictionary:
	if _active_entry_id.is_empty() and _paused_enemy_id.is_empty():
		return {"ok": false, "reason": "no_active_search", "turn_cost": 0}
	if not _paused_enemy_id.is_empty():
		_acknowledged_enemies[_paused_enemy_id] = true
	var status: Dictionary = _current_search_status()
	_active_entry_id = ""
	_paused_enemy_id = ""
	_paused_enemy_distance = -1
	var result: Dictionary = {
		"ok": true,
		"action": "interrupt_search",
		"turn_cost": 0,
		"reason": reason,
		"search": status,
	}.duplicate(true)
	search_interrupted.emit(reason, result.duplicate(true))
	return result


func take_revealed(entry_id: String) -> Dictionary:
	if _open_container_id.is_empty():
		return {"ok": false, "reason": "no_open_container", "turn_cost": 0}
	var container: ContainerState = _containers[_open_container_id]
	var result: Dictionary = container.take_revealed(entry_id)
	result["container_id"] = _open_container_id
	if bool(result.get("ok", false)):
		container_changed.emit(_container_snapshot(_open_container_id))
	return result.duplicate(true)


func return_from_backpack(item: Dictionary) -> Dictionary:
	if _open_container_id.is_empty():
		return {"ok": false, "reason": "no_open_container", "turn_cost": 0}
	var container: ContainerState = _containers[_open_container_id]
	var result: Dictionary = container.return_from_backpack(item.duplicate(true))
	result["container_id"] = _open_container_id
	if bool(result.get("ok", false)):
		container_changed.emit(_container_snapshot(_open_container_id))
	return result.duplicate(true)


func serialize() -> Dictionary:
	var saved_containers: Dictionary = {}
	for key: Variant in _containers:
		var id: String = String(key)
		var container: ContainerState = _containers[id]
		saved_containers[id] = container.serialize()
	return {
		"schema_version": SCHEMA_VERSION,
		"containers": saved_containers,
		"open_container_id": _open_container_id,
		"active_entry_id": _active_entry_id,
		"paused_enemy_id": _paused_enemy_id,
		"paused_enemy_distance": _paused_enemy_distance,
		"acknowledged_enemies": _acknowledged_enemies.duplicate(true),
	}.duplicate(true)


func restore(data: Dictionary) -> bool:
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	var raw_containers: Variant = data.get("containers", {})
	if not raw_containers is Dictionary:
		return false

	var restored_containers: Dictionary = {}
	for key: Variant in raw_containers as Dictionary:
		var id: String = String(key)
		var raw_container: Variant = (raw_containers as Dictionary)[key]
		if not raw_container is Dictionary:
			return false
		var container: ContainerState = ContainerState.new()
		if not container.restore((raw_container as Dictionary).duplicate(true)):
			return false
		if container.container_id != id:
			return false
		restored_containers[id] = container

	var restored_open_id: String = String(data.get("open_container_id", ""))
	if not restored_open_id.is_empty() and not restored_containers.has(restored_open_id):
		return false
	var restored_active_id: String = String(data.get("active_entry_id", ""))
	if not restored_active_id.is_empty():
		if restored_open_id.is_empty():
			return false
		var open_container: ContainerState = restored_containers[restored_open_id]
		if open_container.search_status(restored_active_id).is_empty():
			return false
	var raw_acknowledged: Variant = data.get("acknowledged_enemies", {})
	if not raw_acknowledged is Dictionary:
		return false
	var restored_paused_enemy_id: String = String(data.get("paused_enemy_id", ""))
	if not restored_paused_enemy_id.is_empty() and restored_active_id.is_empty():
		return false

	_containers = restored_containers
	_open_container_id = restored_open_id
	_active_entry_id = restored_active_id
	_paused_enemy_id = restored_paused_enemy_id
	_paused_enemy_distance = int(data.get("paused_enemy_distance", -1))
	_acknowledged_enemies = (raw_acknowledged as Dictionary).duplicate(true)
	return true


func _container_snapshot(container_id: String) -> Dictionary:
	var container: ContainerState = _containers[container_id]
	return container.snapshot()


func _current_search_status() -> Dictionary:
	if _active_entry_id.is_empty() or _open_container_id.is_empty():
		return {}
	var container: ContainerState = _containers[_open_container_id]
	return container.search_status(_active_entry_id)
