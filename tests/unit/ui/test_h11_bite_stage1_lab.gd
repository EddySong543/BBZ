extends GutTest

const SHEET_PATH := "res://assets/effects/h11_bite/h11_bite_stage1_sheet.png"
const LAB_SCENE_PATH := "res://tools/h11_bite_stage1_lab.tscn"
const OPEN_REFERENCE_PATH := "res://assets/effects/h11_bite/open_pixel.png"
const CLOSED_REFERENCE_PATH := "res://assets/effects/h11_bite/bite_pixel.png"
const CELL_SIZE := Vector2i(208, 208)
const FOREGROUND_DISTANCE := 0.14
const CORE_BLACK := Color("08070b")
const SHADOW_BODY := Color("17131d")
const ENERGY_CLUSTER := Color("5b4968")


func _load_sheet() -> Image:
	var texture: Texture2D = load(SHEET_PATH) as Texture2D
	assert_not_null(texture, "静态验收图集必须包含张开与闭合两格")
	return texture.get_image() if texture != null else Image.new()


func test_stage1_sheet_has_two_native_cells() -> void:
	var sheet: Image = _load_sheet()
	if sheet.is_empty():
		return
	assert_eq(sheet.get_size(), Vector2i(416, 208))
	assert_eq(_frame(sheet, 0).get_used_rect().size, Vector2i(190, 203),
			"张开帧必须保持open_pixel原生有效尺寸")
	assert_eq(_frame(sheet, 1).get_used_rect().size, Vector2i(142, 85),
			"闭合帧必须保持bite_pixel原生有效尺寸")


func test_palette_is_flat_shadow_energy_without_specular_bands() -> void:
	var sheet: Image = _load_sheet()
	if sheet.is_empty():
		return
	var colors: Dictionary = {}
	var opaque_pixels := 0
	var energy_pixels := 0
	for y in sheet.get_height():
		for x in sheet.get_width():
			var color: Color = sheet.get_pixel(x, y)
			if color.a <= 0.01:
				continue
			opaque_pixels += 1
			colors[color.to_html(false)] = true
			if color.is_equal_approx(ENERGY_CLUSTER):
				energy_pixels += 1
	assert_eq(colors.size(), 3)
	assert_true(colors.has(CORE_BLACK.to_html(false)))
	assert_true(colors.has(SHADOW_BODY.to_html(false)))
	assert_true(colors.has(ENERGY_CLUSTER.to_html(false)))
	var energy_ratio: float = float(energy_pixels) / maxf(float(opaque_pixels), 1.0)
	assert_gte(energy_ratio, 0.005, "保留少量内部能量纹理以免黑色主体糊死")
	assert_lte(energy_ratio, 0.08, "能量色必须克制，禁止重现金属高光")


func test_open_frame_is_native_pixel_replica_of_open_pixel() -> void:
	var sheet: Image = _load_sheet()
	var reference: Image = _load_reference(OPEN_REFERENCE_PATH)
	if sheet.is_empty() or reference.is_empty():
		return
	_assert_native_replica(_frame(sheet, 0), reference, Color.BLACK,
			"open_pixel张开帧")
	var components: Array[int] = _opaque_component_areas(_frame(sheet, 0))
	assert_eq(components.size(), 14,
			"十四颗现成牙齿必须保持独立，但沿用open_pixel中的并拢位置")
	assert_gt(components.min(), 100,
			"禁止通过孤立碎点或补画像素伪造牙齿组件")


func test_closed_frame_is_native_pixel_replica_of_bite_pixel() -> void:
	var sheet: Image = _load_sheet()
	var reference: Image = _load_reference(CLOSED_REFERENCE_PATH)
	if sheet.is_empty() or reference.is_empty():
		return
	_assert_native_replica(_frame(sheet, 1), reference, Color("0e0c1e"),
			"bite_pixel闭合帧")


func test_native_frames_do_not_invent_dark_interior_divisions() -> void:
	var sheet: Image = _load_sheet()
	if sheet.is_empty():
		return
	for frame_index in 2:
		var frame: Image = _frame(sheet, frame_index)
		var interior_core_pixels := 0
		for y in frame.get_height():
			for x in frame.get_width():
				if frame.get_pixel(x, y).is_equal_approx(CORE_BLACK) \
						and not _touches_transparency(frame, x, y):
					interior_core_pixels += 1
		assert_lte(interior_core_pixels, 4,
				"原生母版以透明负形分牙，不得人为画入深色牙缝")


func test_stage1_lab_scene_is_f6_runnable_and_does_not_replace_battle() -> void:
	var packed: PackedScene = load(LAB_SCENE_PATH) as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var lab: Node = packed.instantiate()
	add_child_autofree(lab)
	assert_not_null(lab.get_node_or_null("OpenFrame"))
	assert_not_null(lab.get_node_or_null("ClosedFrame"))
	assert_eq(lab.get_meta("formal_battle_integration", true), false)


func _frame(sheet: Image, frame_index: int) -> Image:
	return sheet.get_region(Rect2i(frame_index * CELL_SIZE.x, 0,
			CELL_SIZE.x, CELL_SIZE.y))


func _load_reference(path: String) -> Image:
	var texture: Texture2D = load(path) as Texture2D
	assert_not_null(texture, "像素母版必须复制到正式H11资源目录：%s" % path)
	return texture.get_image() if texture != null else Image.new()


func _assert_native_replica(actual: Image, source: Image,
		background: Color, label: String) -> void:
	var source_used: Rect2i = _source_foreground_rect(source, background)
	var expected_origin := Vector2i((CELL_SIZE.x - source_used.size.x) / 2,
			(CELL_SIZE.y - source_used.size.y) / 2)
	var intersection := 0
	var union := 0
	for y in CELL_SIZE.y:
		for x in CELL_SIZE.x:
			var source_point := Vector2i(x, y) - expected_origin + source_used.position
			var expected_opaque := source_used.has_point(source_point) \
					and _is_source_foreground(source.get_pixelv(source_point), background)
			var actual_opaque: bool = actual.get_pixel(x, y).a > 0.01
			if expected_opaque or actual_opaque:
				union += 1
			if expected_opaque and actual_opaque:
				intersection += 1
	var overlap_ratio: float = float(intersection) / maxf(float(union), 1.0)
	assert_gte(overlap_ratio, 0.995,
			"%s必须逐个原生像素复刻，不允许缩放、切缝或重排" % label)
	assert_eq(actual.get_used_rect().size, source_used.size,
			"%s必须保持母版原生有效尺寸" % label)
	assert_lte(absf(actual.get_used_rect().get_center().x - CELL_SIZE.x * 0.5),
			1.0, "%s只能按有效范围整体居中" % label)


func _source_foreground_rect(source: Image, background: Color) -> Rect2i:
	var result := Rect2i()
	var has_pixel := false
	for y in source.get_height():
		for x in source.get_width():
			if not _is_source_foreground(source.get_pixel(x, y), background):
				continue
			var cell := Rect2i(x, y, 1, 1)
			result = cell if not has_pixel else result.merge(cell)
			has_pixel = true
	return result


func _is_source_foreground(color: Color, background: Color) -> bool:
	var delta := Vector3(color.r - background.r, color.g - background.g,
			color.b - background.b)
	return delta.length() >= FOREGROUND_DISTANCE


func _opaque_component_areas(image: Image) -> Array[int]:
	var visited := PackedByteArray()
	visited.resize(image.get_width() * image.get_height())
	var areas: Array[int] = []
	const OFFSETS: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	]
	for start_y in image.get_height():
		for start_x in image.get_width():
			var start_index: int = start_y * image.get_width() + start_x
			if visited[start_index] != 0 \
					or image.get_pixel(start_x, start_y).a <= 0.01:
				continue
			var queue: Array[Vector2i] = [Vector2i(start_x, start_y)]
			var queue_index := 0
			var area := 0
			visited[start_index] = 1
			while queue_index < queue.size():
				var point: Vector2i = queue[queue_index]
				queue_index += 1
				area += 1
				for offset: Vector2i in OFFSETS:
					var next: Vector2i = point + offset
					if next.x < 0 or next.y < 0 \
							or next.x >= image.get_width() or next.y >= image.get_height():
						continue
					var next_index: int = next.y * image.get_width() + next.x
					if visited[next_index] != 0 \
							or image.get_pixelv(next).a <= 0.01:
						continue
					visited[next_index] = 1
					queue.append(next)
			areas.append(area)
	return areas


func _touches_transparency(image: Image, x: int, y: int) -> bool:
	const OFFSETS: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	]
	for offset: Vector2i in OFFSETS:
		var point: Vector2i = Vector2i(x, y) + offset
		if point.x < 0 or point.y < 0 \
				or point.x >= image.get_width() or point.y >= image.get_height():
			return true
		if image.get_pixelv(point).a <= 0.01:
			return true
	return false
