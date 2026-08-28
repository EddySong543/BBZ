class_name WarehouseStore
extends RefCounted

## 本地仓库存档。首开为空；仅保存稳定道具 id 与格位，不把运行时 Resource 写入配置。

const BackpackState := preload("res://src/expedition/expedition_backpack_state.gd")
const Loot := preload("res://src/expedition/expedition_loot.gd")
const ItemCatalogScript := preload("res://src/battle/item_catalog.gd")

const SAVE_PATH := "user://warehouse.cfg"
const ROWS := 10
const COLUMNS := 12
const SECTION := "warehouse"
const PLACEMENTS_KEY := "placements"

static var save_enabled: bool = true

var storage_path: String
var state: RefCounted


func _init(path: String = SAVE_PATH) -> void:
	storage_path = path
	state = BackpackState.new()
	state.rows = ROWS
	state.cols = COLUMNS
	load_from_disk()


func load_from_disk() -> void:
	state.placements.clear()
	var config := ConfigFile.new()
	if config.load(storage_path) != OK:
		return
	var saved: Variant = config.get_value(SECTION, PLACEMENTS_KEY, [])
	if not saved is Array:
		return
	for value: Variant in saved:
		if not value is Dictionary:
			continue
		var record := value as Dictionary
		var item := make_item_payload(String(record.get("item_id", "")))
		if item.is_empty():
			continue
		var shape := _sanitize_shape(record.get("shape", []))
		if shape.is_empty():
			shape = (item.get("shape", []) as Array).duplicate()
		var anchor := Vector2i(record.get("anchor", Vector2i(-1, -1)))
		state.place(item, shape, anchor)


func save_to_disk() -> Error:
	if not save_enabled:
		return OK
	var records: Array = []
	for value: Variant in state.placements:
		var placement := value as Dictionary
		var item := placement.get("item", {}) as Dictionary
		records.append({
			"item_id": String(item.get("combat_id", item.get("id", ""))),
			"anchor": Vector2i(placement.get("anchor", Vector2i.ZERO)),
			"shape": (placement.get("shape", []) as Array).duplicate(),
		})
	var config := ConfigFile.new()
	config.set_value(SECTION, PLACEMENTS_KEY, records)
	var error := config.save(storage_path)
	if error != OK:
		push_warning("WarehouseStore: 仓库保存失败（%s，错误码 %d）" % [storage_path, error])
	return error


func add_item(item_id: String) -> bool:
	var item := make_item_payload(item_id)
	if item.is_empty():
		return false
	var result: Dictionary = state.auto_place(item, false)
	if not bool(result.get("ok", false)):
		return false
	save_to_disk()
	return true


static func make_item_payload(item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {}
	var data: ItemData = ItemCatalogScript.make(item_id)
	if data == null:
		return {}
	var shape := shape_for_tier(data.tier)
	return {
		"id": item_id,
		"combat_id": item_id,
		"name": String(data.item_name),
		"tier": data.tier,
		"cat": "combat",
		"shape": shape,
	}


static func shape_for_tier(tier: int) -> Array:
	match tier:
		2:
			return Loot.SHAPE_1X2.duplicate()
		3:
			return Loot.SHAPE_2X2.duplicate()
		_:
			return Loot.SHAPE_1X1.duplicate()


func _sanitize_shape(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for cell: Variant in value:
		if cell is Vector2i:
			result.append(cell)
	return result
