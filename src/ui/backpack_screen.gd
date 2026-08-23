extends Control
class_name BackpackScreen

## 主界面内嵌战备背包。生命周期与战斗图鉴浮层一致：打开时压在原场景上，关闭后停用整棵节点。

signal closed

const BackpackState := preload("res://src/expedition/expedition_backpack_state.gd")
const Loot := preload("res://src/expedition/expedition_loot.gd")
const ItemCatalogScript := preload("res://src/battle/item_catalog.gd")
const GRID_ROWS := 10
const GRID_COLUMNS := 7
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const PANEL_SHADOW_OFFSET := Vector2(12.0, 12.0)
const OPEN_LIFT := Vector2(0.0, 14.0)
const OPEN_DURATION := 0.18
const CLOSE_DROP := Vector2(0.0, 10.0)
const CLOSE_DURATION := 0.14
const CLOSE_IDLE_COLOR := Color("E7C78D")
const CLOSE_HOVER_COLOR := Color("F4D77B")
const CLOSE_PRESSED_COLOR := Color("FFF0A8")
const CLOSE_PATCH_IDLE := Color("4B2412")
const CLOSE_PATCH_HOVER := Color("63391E")
const CLOSE_STYLE_STATES: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled",
	&"normal_mirrored", &"hover_mirrored", &"pressed_mirrored",
	&"hover_pressed_mirrored", &"disabled_mirrored",
]

var backpack_state: RefCounted
var _dragging := false
var _panel_rest_position := Vector2.ZERO
var _open_tween: Tween
var _close_tween: Tween
var _closing := false

@onready var grid: BackpackGridView = $Panel/Grid
@onready var backdrop: ColorRect = $Backdrop
@onready var panel_shadow: TextureRect = $PanelShadow
@onready var panel: Control = $Panel
@onready var close_button: Button = $Panel/CloseButton


func _ready() -> void:
	backpack_state = BackpackState.new()
	backpack_state.rows = GRID_ROWS
	backpack_state.cols = GRID_COLUMNS
	_panel_rest_position = panel.position
	_setup_close_button()
	panel.gui_input.connect(_on_panel_gui_input)
	backdrop.gui_input.connect(_on_backdrop_input)
	_refresh_runtime_items()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func open() -> void:
	_refresh_runtime_items()
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
	_dragging = false
	backdrop.modulate.a = 0.0
	panel.position = _panel_rest_position + OPEN_LIFT
	panel_shadow.position = panel.position + PANEL_SHADOW_OFFSET
	panel.modulate.a = 0.0
	panel_shadow.modulate.a = 0.0
	_open_tween = create_tween().bind_node(self).set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(backdrop, "modulate:a", 1.0, OPEN_DURATION)
	_open_tween.tween_property(panel, "position", _panel_rest_position, OPEN_DURATION)
	_open_tween.tween_property(panel, "modulate:a", 1.0, OPEN_DURATION)
	_open_tween.tween_property(
		panel_shadow, "position", _panel_rest_position + PANEL_SHADOW_OFFSET, OPEN_DURATION)
	_open_tween.tween_property(panel_shadow, "modulate:a", 1.0, OPEN_DURATION)


func close() -> void:
	if not visible or _closing:
		return
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_dragging = false
	_closing = true
	close_button.disabled = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_tween = create_tween().bind_node(self).set_parallel(true)
	_close_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_close_tween.tween_property(backdrop, "modulate:a", 0.0, CLOSE_DURATION)
	_close_tween.tween_property(
			panel, "position", _panel_rest_position + CLOSE_DROP, CLOSE_DURATION)
	_close_tween.tween_property(panel, "modulate:a", 0.0, CLOSE_DURATION)
	_close_tween.tween_property(
			panel_shadow,
			"position",
			_panel_rest_position + PANEL_SHADOW_OFFSET + CLOSE_DROP,
			CLOSE_DURATION)
	_close_tween.tween_property(panel_shadow, "modulate:a", 0.0, CLOSE_DURATION)
	await _close_tween.finished
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	panel.position = _panel_rest_position
	panel_shadow.position = _panel_rest_position + PANEL_SHADOW_OFFSET
	panel.modulate.a = 1.0
	panel_shadow.modulate.a = 1.0
	backdrop.modulate.a = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.disabled = false
	_closing = false
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


func _setup_close_button() -> void:
	close_button.flat = true
	for state: StringName in CLOSE_STYLE_STATES:
		close_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close_button.pressed.connect(close)
	close_button.mouse_entered.connect(_on_close_hover.bind(true))
	close_button.mouse_exited.connect(_on_close_hover.bind(false))
	close_button.button_down.connect(_on_close_down)
	close_button.button_up.connect(_on_close_up)
	_on_close_hover(false)


func _on_close_hover(hovered: bool) -> void:
	var color := CLOSE_HOVER_COLOR if hovered else CLOSE_IDLE_COLOR
	(close_button.get_node("StrokeA") as Line2D).default_color = color
	(close_button.get_node("StrokeB") as Line2D).default_color = color
	(close_button.get_node("Patch") as Polygon2D).color = \
			CLOSE_PATCH_HOVER if hovered else CLOSE_PATCH_IDLE


func _on_close_down() -> void:
	(close_button.get_node("StrokeA") as Line2D).default_color = CLOSE_PRESSED_COLOR
	(close_button.get_node("StrokeB") as Line2D).default_color = CLOSE_PRESSED_COLOR


func _on_close_up() -> void:
	_on_close_hover(close_button.is_hovered())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible or not _dragging:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_set_panel_position(panel.position + motion.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_dragging = false
			get_viewport().set_input_as_handled()


func _on_panel_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_dragging = mouse_event.pressed
	accept_event()


func _set_panel_position(target: Vector2) -> void:
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	# 项目 UI 以 1920×1080 逻辑画布布局；headless 探针的可见矩形可能只有 1×1。
	viewport_size.x = maxf(viewport_size.x, DESIGN_SIZE.x)
	viewport_size.y = maxf(viewport_size.y, DESIGN_SIZE.y)
	var close_rect := Rect2(close_button.position, close_button.size)
	var minimum := Vector2(-close_rect.position.x, -close_rect.position.y)
	var maximum := Vector2(
		viewport_size.x - close_rect.end.x,
		viewport_size.y - close_rect.end.y)
	_panel_rest_position = Vector2(
		clampf(target.x, minimum.x, maximum.x),
		clampf(target.y, minimum.y, maximum.y))
	panel.position = _panel_rest_position
	panel_shadow.position = _panel_rest_position + PANEL_SHADOW_OFFSET


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			close()
			accept_event()
