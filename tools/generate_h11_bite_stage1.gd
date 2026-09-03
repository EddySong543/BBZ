extends SceneTree

## H11 静态形状锚点：直接复刻 open_pixel / bite_pixel 的原生像素坐标。
## 不切缝、不拉直、不重排牙齿，不做缩放或运行时像素化。

const OPEN_REFERENCE_PATH := "res://assets/effects/h11_bite/open_pixel.png"
const CLOSED_REFERENCE_PATH := "res://assets/effects/h11_bite/bite_pixel.png"
const OUTPUT_PATH := "res://assets/effects/h11_bite/h11_bite_stage1_sheet.png"
const CELL_SIZE := Vector2i(208, 208)
const FRAME_COUNT := 2
const FOREGROUND_DISTANCE := 0.14
const OPEN_BACKGROUND := Color.BLACK
const CLOSED_BACKGROUND := Color("0e0c1e")
const ENERGY_LUMA_MIN := 0.84
const ENERGY_LUMA_MAX := 0.90

const CORE_BLACK := Color("08070b")
const SHADOW_BODY := Color("17131d")
const ENERGY_CLUSTER := Color("5b4968")


func _init() -> void:
	var error: Error = _generate()
	if error != OK:
		push_error("h11 bite stage1 generation failed: %s" % error_string(error))
		quit(1)
		return
	print("H11_BITE_STAGE1_OK frames=%d cell=%s native_open=true native_closed=true output=%s" % [
		FRAME_COUNT, CELL_SIZE, OUTPUT_PATH])
	quit()


func _generate() -> Error:
	var open_reference := Image.new()
	var error: Error = open_reference.load(OPEN_REFERENCE_PATH)
	if error != OK:
		return error
	var closed_reference := Image.new()
	error = closed_reference.load(CLOSED_REFERENCE_PATH)
	if error != OK:
		return error

	var open_frame: Image = _build_native_frame(open_reference, OPEN_BACKGROUND)
	var closed_frame: Image = _build_native_frame(closed_reference, CLOSED_BACKGROUND)
	var sheet := Image.create(CELL_SIZE.x * FRAME_COUNT, CELL_SIZE.y,
			false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	sheet.blit_rect(open_frame, Rect2i(Vector2i.ZERO, CELL_SIZE), Vector2i.ZERO)
	sheet.blit_rect(closed_frame, Rect2i(Vector2i.ZERO, CELL_SIZE),
			Vector2i(CELL_SIZE.x, 0))
	return sheet.save_png(OUTPUT_PATH)


func _build_native_frame(source: Image, background: Color) -> Image:
	var source_used: Rect2i = _source_foreground_rect(source, background)
	var mask := Image.create(CELL_SIZE.x, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	var origin := Vector2i((CELL_SIZE.x - source_used.size.x) / 2,
			(CELL_SIZE.y - source_used.size.y) / 2)
	for source_y in range(source_used.position.y, source_used.end.y):
		for source_x in range(source_used.position.x, source_used.end.x):
			var source_color: Color = source.get_pixel(source_x, source_y)
			if not _is_source_foreground(source_color, background):
				continue
			var luma: float = source_color.r * 0.2126 \
					+ source_color.g * 0.7152 + source_color.b * 0.0722
			mask.set_pixelv(origin + Vector2i(source_x, source_y)
					- source_used.position, Color(luma, luma, luma, 1.0))
	return _colorize_native_mask(mask)


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


func _colorize_native_mask(mask: Image) -> Image:
	var result := Image.create(CELL_SIZE.x, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in CELL_SIZE.y:
		for x in CELL_SIZE.x:
			var source: Color = mask.get_pixel(x, y)
			if source.a <= 0.5:
				continue
			var color := SHADOW_BODY
			if _touches_transparency(mask, x, y):
				color = CORE_BLACK
			elif source.r >= ENERGY_LUMA_MIN and source.r < ENERGY_LUMA_MAX:
				color = ENERGY_CLUSTER
			result.set_pixel(x, y, color)
	return result


func _touches_transparency(mask: Image, x: int, y: int) -> bool:
	const OFFSETS: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	]
	for offset: Vector2i in OFFSETS:
		var point: Vector2i = Vector2i(x, y) + offset
		if point.x < 0 or point.y < 0 \
				or point.x >= mask.get_width() or point.y >= mask.get_height():
			return true
		if mask.get_pixelv(point).a <= 0.5:
			return true
	return false
