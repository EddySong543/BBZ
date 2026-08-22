extends Control
class_name BackpackScreen

## 主界面内嵌战备背包。生命周期与战斗图鉴浮层一致：打开时压在原场景上，关闭后停用整棵节点。

signal closed

const BackpackState := preload("res://src/expedition/expedition_backpack_state.gd")
const Loot := preload("res://src/expedition/expedition_loot.gd")
const ItemCatalogScript := preload("res://src/battle/item_catalog.gd")
const GRID_DIM := 6
const PAPER := Color("E8D8B8")

var backpack_state: RefCounted

@onready var grid: BackpackGridView = $Panel/Grid
@onready var back_button: Button = $Panel/BackButton


func _ready() -> void:
	backpack_state = BackpackState.new()
	backpack_state.rows = GRID_DIM
	backpack_state.cols = GRID_DIM
	_style_static_text()
	back_button.pressed.connect(close)
	$Backdrop.gui_input.connect(_on_backdrop_input)
	_refresh_runtime_items()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func open() -> void:
	_refresh_runtime_items()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	move_to_front()
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	closed.emit()


func _refresh_runtime_items() -> void:
	var runtime_items: Array[String] = []
	var battle_setup := get_node_or_null("/root/BattleSetup")
	if battle_setup != null:
		runtime_items.assign(battle_setup.get("p1_item_backpack"))
	backpack_state.placements.clear()
	for item_id: String in runtime_items:
		var data: ItemData = ItemCatalogScript.make(item_id)
		if data == null:
			continue
		var shape: Array = _shape_for_tier(data.tier)
		var payload := {
			"id": item_id,
			"combat_id": item_id,
			"name": tr(data.item_name),
			"tier": data.tier,
			"cat": "combat",
			"shape": shape,
		}
		backpack_state.auto_place(payload, false)
	grid.set_backpack_state(backpack_state)


func _shape_for_tier(tier: int) -> Array:
	match tier:
		2:
			return Loot.SHAPE_1X2.duplicate()
		3:
			return Loot.SHAPE_2X2.duplicate()
		_:
			return Loot.SHAPE_1X1.duplicate()


func _style_static_text() -> void:
	var fonts := get_node("/root/FontManager")
	fonts.call("apply_btn", back_button, 18)
	back_button.add_theme_color_override("font_color", PAPER)
	back_button.add_theme_color_override("font_hover_color", Color("F4C969"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


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
