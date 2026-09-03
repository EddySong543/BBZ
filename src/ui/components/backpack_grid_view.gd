extends Control
class_name BackpackGridView

## ref43 规则的背包格面：背包本体就是容器，物品稀有度底色只填充实际占格。

signal cell_pressed(index: int)
signal item_drop_requested(
		source_container: String, source_index: int,
		target_container: String, target_index: int, grab_offset: Vector2i)

const ItemCatalogScript := preload("res://src/battle/item_catalog.gd")
const ItemGridArtLayoutScript := preload("res://src/ui/components/item_grid_art_layout.gd")
const GRID_FILL := Color("211713")
const GRID_CELL := Color("4B352B")
const GRID_CELL_LINE := Color("6A5042")
const GRID_OUTLINE := Color("120C0A")
const GRID_HOVER := Color("D3A94F")
const GRID_FIBER_LIGHT := Color(0.67, 0.49, 0.36, 0.13)
const GRID_FIBER_DARK := Color(0.10, 0.055, 0.035, 0.16)
const ITEM_SHADOW := Color(0.02, 0.01, 0.0, 0.68)

@export_range(1, 12, 1) var rows: int = 6
@export_range(1, 12, 1) var columns: int = 6
@export var container_id: String = ""

var item_ids: Array[String] = []
var placements: Array = []
var _cell_to_placement: Dictionary = {}
var _hovered_cell: int = -1
var _pressed_cell: int = -1
var _drag_started: bool = false
var _suppress_click_release: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_exited.connect(_clear_hover)
	queue_redraw()


func set_backpack_state(state: RefCounted) -> void:
	rows = int(state.get("rows"))
	columns = int(state.get("cols"))
	placements = (state.get("placements") as Array).duplicate(true)
	item_ids.clear()
	_cell_to_placement.clear()
	for placement_index: int in placements.size():
		var placement: Dictionary = placements[placement_index]
		var item: Dictionary = placement.get("item", {})
		item_ids.append(String(item.get("combat_id", item.get("id", ""))))
		var anchor := Vector2i(placement.get("anchor", Vector2i.ZERO))
		for offset: Vector2i in placement.get("shape", []):
			var cell := anchor + offset
			_cell_to_placement[cell.y * columns + cell.x] = placement_index
	queue_redraw()


func item_name_at(index: int) -> String:
	var placement := _placement_at_index(index)
	if placement.is_empty():
		return "空格"
	return String((placement.get("item", {}) as Dictionary).get("name", "空格"))


func placement_at_index(index: int) -> Dictionary:
	return _placement_at_index(index)


func cell_vector(index: int) -> Vector2i:
	if index < 0 or index >= rows * columns:
		return Vector2i(-1, -1)
	return Vector2i(index % columns, index / columns)


func occupied_cell_count() -> int:
	return _cell_to_placement.size()


func cell_rect(index: int) -> Rect2:
	if index < 0 or index >= rows * columns:
		return Rect2()
	var cell_size := Vector2(size.x / float(columns), size.y / float(rows))
	return Rect2(Vector2(index % columns, index / columns) * cell_size, cell_size)


func _draw() -> void:
	if rows <= 0 or columns <= 0:
		return
	# ref43 的格面关系：深咖分隔缝包住低饱和栗木棕槽面，不模拟受光或凹凸。
	draw_rect(Rect2(Vector2.ZERO, size), GRID_FILL, true)
	var cell_size := Vector2(size.x / float(columns), size.y / float(rows))
	for row: int in rows:
		for column: int in columns:
			var cell := Rect2(Vector2(column, row) * cell_size, cell_size)
			var slot := cell.grow(-2.0)
			draw_rect(slot, GRID_CELL, true)
			draw_rect(slot, GRID_CELL_LINE, false, 1.0)
			_draw_cell_fibers(slot, row, column)
	# 外缘与内部格缝使用同一暗色体系，避免形成另一层装饰边框。
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), GRID_OUTLINE, false, 2.0)
	for placement_value: Variant in placements:
		var placement := placement_value as Dictionary
		var item := placement.get("item", {}) as Dictionary
		var tier := int(item.get("tier", 1))
		var rarity := ItemCatalogScript.rarity_color(tier)
		var anchor := Vector2i(placement.get("anchor", Vector2i.ZERO))
		var shape := placement.get("shape", []) as Array
		for offset: Vector2i in shape:
			var cell := anchor + offset
			var occupied_rect := cell_rect(cell.y * columns + cell.x).grow(-2.0)
			draw_rect(occupied_rect, Color(rarity, 0.90), true)
			draw_rect(occupied_rect, Color(rarity.lightened(0.18), 0.88), false, 2.0)
		var item_id := String(item.get("combat_id", item.get("id", "")))
		var texture := ItemCatalogScript.load_icon(item_id)
		if texture == null or shape.is_empty():
			continue
		var base_shape_value: Variant = item.get("shape", shape)
		var base_shape: Array = base_shape_value as Array \
				if base_shape_value is Array else shape
		if base_shape.is_empty():
			base_shape = shape
		var raw_bounds := _placement_bounds(anchor, shape)
		var padding: float = minf(10.0,
				floorf(minf(raw_bounds.size.x, raw_bounds.size.y) * 0.12))
		var bounds: Rect2 = raw_bounds.grow(-padding)
		ItemGridArtLayoutScript.draw_item_art(
				self, texture, base_shape, shape, bounds,
				Vector2(3.0, 4.0), ITEM_SHADOW)
	if _hovered_cell >= 0:
		var hovered := _placement_at_index(_hovered_cell)
		if hovered.is_empty():
			_draw_hover_cell(_hovered_cell)
		else:
			var anchor := Vector2i(hovered.get("anchor", Vector2i.ZERO))
			for offset: Vector2i in hovered.get("shape", []):
				_draw_hover_cell((anchor.y + offset.y) * columns + anchor.x + offset.x)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_hover := _cell_at(event.position)
		if next_hover != _hovered_cell:
			_hovered_cell = next_hover
			tooltip_text = item_name_at(_hovered_cell)
			queue_redraw()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		var index := _cell_at(mouse_event.position)
		if mouse_event.pressed:
			_pressed_cell = index
			_drag_started = false
			_suppress_click_release = false
		elif index >= 0 and index == _pressed_cell and not _suppress_click_release:
			cell_pressed.emit(index)
			accept_event()
		_pressed_cell = -1


func _get_drag_data(local_position: Vector2) -> Variant:
	var source_index := _cell_at(local_position)
	var placement := _placement_at_index(source_index)
	if source_index < 0 or placement.is_empty():
		return null
	_drag_started = true
	_suppress_click_release = true
	var anchor := Vector2i(placement.get("anchor", Vector2i.ZERO))
	var source_cell := cell_vector(source_index)
	var item := placement.get("item", {}) as Dictionary
	var preview := Label.new()
	preview.text = String(item.get("name", "道具"))
	preview.add_theme_color_override("font_color", Color("F2D9A7"))
	preview.add_theme_color_override("font_outline_color", Color("24150E"))
	preview.add_theme_constant_override("outline_size", 4)
	FontManager.apply(preview, 18)
	set_drag_preview(preview)
	return {
		"kind": "inventory_item",
		"source_container": container_id,
		"source_index": source_index,
		"grab_offset": source_cell - anchor,
	}


func _can_drop_data(local_position: Vector2, data: Variant) -> bool:
	return data is Dictionary \
			and String((data as Dictionary).get("kind", "")) == "inventory_item" \
			and _cell_at(local_position) >= 0


func _drop_data(local_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(local_position, data):
		return
	var payload := data as Dictionary
	item_drop_requested.emit(
			String(payload.get("source_container", "")),
			int(payload.get("source_index", -1)),
			container_id,
			_cell_at(local_position),
			Vector2i(payload.get("grab_offset", Vector2i.ZERO)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_started = false
		_pressed_cell = -1


func _cell_at(local_position: Vector2) -> int:
	if not Rect2(Vector2.ZERO, size).has_point(local_position):
		return -1
	var column := mini(int(local_position.x / (size.x / float(columns))), columns - 1)
	var row := mini(int(local_position.y / (size.y / float(rows))), rows - 1)
	return row * columns + column


func _clear_hover() -> void:
	_hovered_cell = -1
	tooltip_text = ""
	queue_redraw()


func _placement_at_index(index: int) -> Dictionary:
	if not _cell_to_placement.has(index):
		return {}
	return placements[int(_cell_to_placement[index])] as Dictionary


func _placement_bounds(anchor: Vector2i, shape: Array) -> Rect2:
	var min_cell := anchor
	var max_cell := anchor
	for offset: Vector2i in shape:
		var cell := anchor + offset
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	var top_left := cell_rect(min_cell.y * columns + min_cell.x).position
	var bottom_right_rect := cell_rect(max_cell.y * columns + max_cell.x)
	return Rect2(top_left, bottom_right_rect.end - top_left)


func _shape_rotation_quarters(base_shape: Array, current_shape: Array) -> int:
	return ItemGridArtLayoutScript.shape_rotation_quarters(base_shape, current_shape)


func _item_art_layout(
		texture_size: Vector2, bounds: Rect2, quarter_turns: int) -> Dictionary:
	return ItemGridArtLayoutScript.item_art_layout(texture_size, bounds, quarter_turns)


## 只用两笔 1px 断续纤维打破纯色色块；位置由格坐标决定，不形成木板或凹槽错觉。
func _draw_cell_fibers(slot: Rect2, row: int, column: int) -> void:
	var seed := row * 37 + column * 19
	var usable_width := maxi(8, int(slot.size.x) - 18)
	var x0 := slot.position.x + 7.0 + float(seed % usable_width)
	var y0 := slot.position.y + 9.0 + float((seed * 3) % maxi(8, int(slot.size.y) - 18))
	var length0 := 7.0 + float(seed % 7)
	x0 = minf(x0, slot.end.x - length0 - 6.0)
	draw_line(Vector2(x0, y0), Vector2(x0 + length0, y0), GRID_FIBER_LIGHT, 1.0)

	var x1 := slot.position.x + 6.0 + float((seed * 5 + 3) % usable_width)
	var y1 := slot.position.y + 8.0 + float((seed * 7 + 5) % maxi(8, int(slot.size.y) - 16))
	var length1 := 5.0 + float((seed + 2) % 6)
	x1 = minf(x1, slot.end.x - length1 - 6.0)
	draw_line(Vector2(x1, y1), Vector2(x1 + length1, y1), GRID_FIBER_DARK, 1.0)


func _draw_hover_cell(index: int) -> void:
	var hover_rect := cell_rect(index).grow(-3.0)
	draw_rect(hover_rect, Color(GRID_HOVER, 0.09), true)
	draw_rect(hover_rect, GRID_HOVER, false, 2.0)
