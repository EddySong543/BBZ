extends RefCounted

## 多格物品美术的统一布局计算。初始形状决定0度朝向，当前占格决定显示旋转。


static func shape_rotation_quarters(base_shape: Array, current_shape: Array) -> int:
	if base_shape.is_empty() or current_shape.is_empty():
		return 0
	var target_key: String = _shape_key(current_shape)
	var candidate: Array[Vector2i] = _typed_shape(base_shape)
	for quarter_turns: int in 4:
		if _shape_key(candidate) == target_key:
			return quarter_turns
		candidate = _rotate_shape(candidate)
	return 0


static func item_art_layout(
		texture_size: Vector2, bounds: Rect2, quarter_turns: int) -> Dictionary:
	var safe_texture_size := Vector2(maxf(texture_size.x, 1.0), maxf(texture_size.y, 1.0))
	var turns: int = posmod(quarter_turns, 4)
	var oriented_source_size: Vector2 = safe_texture_size
	if turns % 2 == 1:
		oriented_source_size = Vector2(safe_texture_size.y, safe_texture_size.x)
	var scale_factor: float = minf(
			bounds.size.x / oriented_source_size.x,
			bounds.size.y / oriented_source_size.y)
	var oriented_size: Vector2 = (oriented_source_size * maxf(scale_factor, 0.0)).floor()
	var draw_size: Vector2 = oriented_size
	if turns % 2 == 1:
		draw_size = Vector2(oriented_size.y, oriented_size.x)
	return {
		"center": bounds.get_center(),
		"draw_size": draw_size,
		"oriented_size": oriented_size,
		"rotation": float(turns) * PI * 0.5,
		"quarter_turns": turns,
	}


static func draw_item_art(
		canvas: CanvasItem, texture: Texture2D,
		base_shape: Array, current_shape: Array, bounds: Rect2,
		shadow_offset: Vector2, shadow_color: Color) -> void:
	if texture == null or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var turns: int = shape_rotation_quarters(base_shape, current_shape)
	var layout: Dictionary = item_art_layout(texture.get_size(), bounds, turns)
	var center: Vector2 = layout["center"]
	var draw_size: Vector2 = layout["draw_size"]
	var rotation: float = layout["rotation"]
	var local_rect := Rect2(-draw_size * 0.5, draw_size)
	canvas.draw_set_transform(center + shadow_offset, rotation, Vector2.ONE)
	canvas.draw_texture_rect(texture, local_rect, false, shadow_color)
	canvas.draw_set_transform(center, rotation, Vector2.ONE)
	canvas.draw_texture_rect(texture, local_rect, false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _shape_key(shape: Array) -> String:
	var typed: Array[Vector2i] = _typed_shape(shape)
	if typed.is_empty():
		return ""
	var minimum: Vector2i = typed[0]
	for cell: Vector2i in typed:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
	var cells: Array[String] = []
	for cell: Vector2i in typed:
		var normalized: Vector2i = cell - minimum
		cells.append("%d,%d" % [normalized.x, normalized.y])
	cells.sort()
	return ";".join(cells)


static func _typed_shape(shape: Array) -> Array[Vector2i]:
	var typed: Array[Vector2i] = []
	for value: Variant in shape:
		if value is Vector2i:
			typed.append(Vector2i(value))
	return typed


static func _rotate_shape(shape: Array[Vector2i]) -> Array[Vector2i]:
	if shape.is_empty():
		return []
	var rotated: Array[Vector2i] = []
	var minimum := Vector2i(1_000_000, 1_000_000)
	for cell: Vector2i in shape:
		var rotated_cell := Vector2i(-cell.y, cell.x)
		rotated.append(rotated_cell)
		minimum.x = mini(minimum.x, rotated_cell.x)
		minimum.y = mini(minimum.y, rotated_cell.y)
	for index: int in rotated.size():
		rotated[index] -= minimum
	return rotated
