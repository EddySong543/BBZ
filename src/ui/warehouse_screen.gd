extends Control
class_name WarehouseScreen

## 主界面仓库浮层：左侧复用战备背包资产，右侧为持久仓库。
## 单击自动转移；拖动可精确落位。任一失败都保持来源物品不变。

signal closed

const WarehouseStoreScript := preload("res://src/core/warehouse_store.gd")
const BackpackState := preload("res://src/expedition/expedition_backpack_state.gd")
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const BACKPACK_ROWS := 10
const BACKPACK_COLUMNS := 7
const OPEN_OFFSET := Vector2(0.0, 14.0)
const CLOSE_OFFSET := Vector2(0.0, 10.0)
const OPEN_DURATION := 0.20
const CLOSE_DURATION := 0.15
const CLOSE_IDLE := Color("E7C78D")
const CLOSE_HOVER := Color("F4D77B")
const CLOSE_PRESSED := Color("FFF0A8")

var warehouse_store: WarehouseStore
var backpack_state: RefCounted
var _rest_positions: Dictionary = {}
var _open_tween: Tween
var _close_tween: Tween
var _message_tween: Tween
var _closing: bool = false

@onready var backdrop: ColorRect = $Backdrop
@onready var backpack_panel: Control = $BackpackPanel
@onready var backpack_shadow: TextureRect = $BackpackShadow
@onready var backpack_grid: BackpackGridView = $BackpackPanel/Grid
@onready var warehouse_panel: Panel = $WarehousePanel
@onready var warehouse_grid: BackpackGridView = $WarehousePanel/Grid
@onready var warehouse_empty: Label = $WarehousePanel/Grid/EmptyLabel
@onready var warehouse_count: Label = $WarehousePanel/Count
@onready var backpack_count: Label = $BackpackPanel/Count
@onready var message_label: Label = $WarehousePanel/Message
@onready var close_button: Button = $WarehousePanel/CloseButton


func _ready() -> void:
	warehouse_store = WarehouseStoreScript.new()
	backpack_state = BackpackState.new()
	backpack_state.rows = BACKPACK_ROWS
	backpack_state.cols = BACKPACK_COLUMNS
	_rest_positions = {
		backpack_panel: backpack_panel.position,
		backpack_shadow: backpack_shadow.position,
		warehouse_panel: warehouse_panel.position,
	}
	backpack_grid.container_id = "backpack"
	warehouse_grid.container_id = "warehouse"
	backpack_grid.cell_pressed.connect(_on_cell_pressed.bind("backpack"))
	warehouse_grid.cell_pressed.connect(_on_cell_pressed.bind("warehouse"))
	backpack_grid.item_drop_requested.connect(_on_item_drop_requested)
	warehouse_grid.item_drop_requested.connect(_on_item_drop_requested)
	backdrop.gui_input.connect(_on_backdrop_input)
	_setup_close_button()
	FontManager.apply($WarehousePanel/Title as Label, 32)
	FontManager.apply(warehouse_count, 18)
	FontManager.apply(backpack_count, 18)
	FontManager.apply(warehouse_empty, 22)
	FontManager.apply(message_label, 18)
	_refresh_backpack_state()
	_refresh_views()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func set_store(store: WarehouseStore) -> void:
	warehouse_store = store
	if is_node_ready():
		_refresh_views()


func open() -> void:
	_refresh_backpack_state()
	_refresh_views()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	if _close_tween != null and _close_tween.is_valid():
		_close_tween.kill()
	_closing = false
	close_button.disabled = false
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	move_to_front()
	backdrop.modulate.a = 0.0
	for node_variant: Variant in _rest_positions.keys():
		var node := node_variant as Control
		node.position = Vector2(_rest_positions[node_variant]) + OPEN_OFFSET
		node.modulate.a = 0.0
	_open_tween = create_tween().bind_node(self).set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(backdrop, "modulate:a", 1.0, OPEN_DURATION)
	for node_variant: Variant in _rest_positions.keys():
		var node := node_variant as Control
		_open_tween.tween_property(
				node, "position", Vector2(_rest_positions[node_variant]), OPEN_DURATION)
		_open_tween.tween_property(node, "modulate:a", 1.0, OPEN_DURATION)


func close() -> void:
	if not visible or _closing:
		return
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_closing = true
	close_button.disabled = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_tween = create_tween().bind_node(self).set_parallel(true)
	_close_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_close_tween.tween_property(backdrop, "modulate:a", 0.0, CLOSE_DURATION)
	for node_variant: Variant in _rest_positions.keys():
		var node := node_variant as Control
		_close_tween.tween_property(
				node, "position",
				Vector2(_rest_positions[node_variant]) + CLOSE_OFFSET, CLOSE_DURATION)
		_close_tween.tween_property(node, "modulate:a", 0.0, CLOSE_DURATION)
	await _close_tween.finished
	if not is_instance_valid(self):
		return
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	for node_variant: Variant in _rest_positions.keys():
		var node := node_variant as Control
		node.position = Vector2(_rest_positions[node_variant])
		node.modulate.a = 1.0
	backdrop.modulate.a = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.disabled = false
	_closing = false
	closed.emit()


func _refresh_backpack_state() -> void:
	backpack_state.placements.clear()
	var battle_setup := get_node_or_null("/root/BattleSetup")
	if battle_setup == null:
		return
	var item_ids: Array[String] = []
	item_ids.assign(battle_setup.get("p1_item_backpack"))
	for item_id: String in item_ids:
		var item := WarehouseStoreScript.make_item_payload(item_id)
		if not item.is_empty():
			backpack_state.auto_place(item, false)


func _refresh_views() -> void:
	if warehouse_store == null or backpack_state == null:
		return
	backpack_grid.set_backpack_state(backpack_state)
	warehouse_grid.set_backpack_state(warehouse_store.state)
	var warehouse_items: int = (warehouse_store.state.get("placements") as Array).size()
	var backpack_items: int = (backpack_state.get("placements") as Array).size()
	warehouse_empty.visible = warehouse_items == 0
	warehouse_count.text = "%d 件" % warehouse_items
	backpack_count.text = "%d 件" % backpack_items


func _on_cell_pressed(index: int, source_container: String) -> void:
	var destination := "warehouse" if source_container == "backpack" else "backpack"
	_transfer_auto(source_container, index, destination)


func _transfer_auto(source_id: String, source_index: int, target_id: String) -> void:
	var source: RefCounted = _state_for(source_id)
	var target: RefCounted = _state_for(target_id)
	if source == null or target == null:
		return
	var source_cell := _cell_for_index(source, source_index)
	var placement: Dictionary = source.call("_placement_at", source_cell)
	if placement.is_empty():
		return
	var item := (placement.get("item", {}) as Dictionary).duplicate(true)
	item["shape"] = (placement.get("shape", []) as Array).duplicate()
	var result: Dictionary = target.call("auto_place", item, false)
	if not bool(result.get("ok", false)):
		_show_message("没有足够空间")
		return
	var removed: Dictionary = source.call("remove_at", source_cell)
	if removed.is_empty():
		target.call("remove_at", Vector2i(result.get("anchor", Vector2i.ZERO)))
		return
	_after_transfer()


func _on_item_drop_requested(
		source_id: String, source_index: int,
		target_id: String, target_index: int, grab_offset: Vector2i) -> void:
	var source: RefCounted = _state_for(source_id)
	var target: RefCounted = _state_for(target_id)
	if source == null or target == null:
		return
	var source_cell := _cell_for_index(source, source_index)
	var target_cell := _cell_for_index(target, target_index)
	if source_cell.x < 0 or target_cell.x < 0:
		return
	var target_anchor := target_cell - grab_offset
	if source == target:
		if bool(source.call("move_at", source_cell, target_anchor)):
			_after_transfer()
		else:
			_show_message("该位置放不下")
		return
	var placement: Dictionary = source.call("_placement_at", source_cell)
	if placement.is_empty():
		return
	var shape := (placement.get("shape", []) as Array).duplicate()
	if not bool(target.call("can_place", shape, target_anchor)):
		_show_message("该位置放不下")
		return
	var item := (placement.get("item", {}) as Dictionary).duplicate(true)
	if not bool(target.call("place", item, shape, target_anchor)):
		return
	source.call("remove_at", source_cell)
	_after_transfer()


func _state_for(container: String) -> RefCounted:
	match container:
		"backpack":
			return backpack_state
		"warehouse":
			return warehouse_store.state if warehouse_store != null else null
		_:
			return null


func _cell_for_index(state: RefCounted, index: int) -> Vector2i:
	var columns: int = int(state.get("cols"))
	var rows: int = int(state.get("rows"))
	if index < 0 or index >= columns * rows:
		return Vector2i(-1, -1)
	return Vector2i(index % columns, index / columns)


func _after_transfer() -> void:
	warehouse_store.save_to_disk()
	_sync_battle_setup()
	_refresh_views()


func _sync_battle_setup() -> void:
	var battle_setup := get_node_or_null("/root/BattleSetup")
	if battle_setup == null:
		return
	var item_ids: Array[String] = []
	for value: Variant in backpack_state.placements:
		var placement := value as Dictionary
		var item := placement.get("item", {}) as Dictionary
		var item_id := String(item.get("combat_id", item.get("id", "")))
		if not item_id.is_empty():
			item_ids.append(item_id)
	battle_setup.set("p1_item_backpack", item_ids)


func _show_message(text: String) -> void:
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	message_label.text = text
	message_label.modulate.a = 1.0
	_message_tween = create_tween().bind_node(self)
	_message_tween.tween_interval(0.8)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.25)


func _setup_close_button() -> void:
	close_button.pressed.connect(close)
	close_button.mouse_entered.connect(_on_close_hover.bind(true))
	close_button.mouse_exited.connect(_on_close_hover.bind(false))
	close_button.button_down.connect(_on_close_down)
	close_button.button_up.connect(_on_close_up)
	_on_close_hover(false)


func _on_close_hover(hovered: bool) -> void:
	var color := CLOSE_HOVER if hovered else CLOSE_IDLE
	(close_button.get_node("StrokeA") as Line2D).default_color = color
	(close_button.get_node("StrokeB") as Line2D).default_color = color


func _on_close_down() -> void:
	(close_button.get_node("StrokeA") as Line2D).default_color = CLOSE_PRESSED
	(close_button.get_node("StrokeB") as Line2D).default_color = CLOSE_PRESSED


func _on_close_up() -> void:
	_on_close_hover(close_button.is_hovered())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			close()
			accept_event()
