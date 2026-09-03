extends SceneTree

## H11 第二阶段正式七帧：复用已通过的静态张开/闭合锚点，
## 只以最近邻缩放和完整上下颌位移补出中间帧。

const APPROVED_STATIC_SHEET_PATH := \
		"res://assets/effects/h11_bite/h11_bite_stage1_sheet.png"
const OUTPUT_PATH := "res://assets/effects/h11_bite/h11_bite_sheet.png"
const CELL_SIZE := Vector2i(208, 208)
const FRAME_COUNT := 8
const STRUCTURAL_FRAME_COUNT := 7
const APPEAR_SCALE_RATIOS: Array[float] = [0.84, 0.94]
const JAW_CLOSE_OFFSETS: Array[int] = [6, 12, 18]


func _init() -> void:
	var error: Error = _generate()
	if error != OK:
		push_error("h11 bite sheet generation failed: %s" % error_string(error))
		quit(1)
		return
	print("H11_BITE_SHEET_OK visible_frames=%d cells=%d static_anchors=locked output=%s" % [
		STRUCTURAL_FRAME_COUNT, FRAME_COUNT, OUTPUT_PATH])
	quit()


func _generate() -> Error:
	var approved_sheet := Image.new()
	var error: Error = approved_sheet.load(APPROVED_STATIC_SHEET_PATH)
	if error != OK:
		return error
	if approved_sheet.get_size() != Vector2i(CELL_SIZE.x * 2, CELL_SIZE.y):
		push_error("approved H11 static sheet must contain exactly two 208px cells")
		return ERR_INVALID_DATA

	var approved_open: Image = approved_sheet.get_region(Rect2i(
			Vector2i.ZERO, CELL_SIZE))
	var approved_closed: Image = approved_sheet.get_region(Rect2i(
			Vector2i(CELL_SIZE.x, 0), CELL_SIZE))
	var blank := Image.create(CELL_SIZE.x, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	blank.fill(Color.TRANSPARENT)

	var frames: Array[Image] = [
		_scale_inside_cell(approved_open, APPEAR_SCALE_RATIOS[0]),
		_scale_inside_cell(approved_open, APPEAR_SCALE_RATIOS[1]),
		approved_open,
		_close_complete_jaws(approved_open, JAW_CLOSE_OFFSETS[0]),
		_close_complete_jaws(approved_open, JAW_CLOSE_OFFSETS[1]),
		_close_complete_jaws(approved_open, JAW_CLOSE_OFFSETS[2]),
		approved_closed,
		blank,
	]
	var sheet := Image.create(CELL_SIZE.x * FRAME_COUNT, CELL_SIZE.y,
			false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for frame_index in FRAME_COUNT:
		sheet.blit_rect(frames[frame_index], Rect2i(Vector2i.ZERO, CELL_SIZE),
				Vector2i(frame_index * CELL_SIZE.x, 0))
	return sheet.save_png(OUTPUT_PATH)


func _scale_inside_cell(source: Image, ratio: float) -> Image:
	var result := Image.create(CELL_SIZE.x, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var target_size := Vector2i(
			maxi(1, roundi(CELL_SIZE.x * ratio)),
			maxi(1, roundi(CELL_SIZE.y * ratio)))
	var scaled: Image = source.duplicate() as Image
	scaled.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	result.blit_rect(scaled, Rect2i(Vector2i.ZERO, target_size),
			(CELL_SIZE - target_size) / 2)
	return result


func _close_complete_jaws(source: Image, inward_offset: int) -> Image:
	var result := Image.create(CELL_SIZE.x, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var half_height: int = CELL_SIZE.y / 2
	var upper_rect := Rect2i(0, 0, CELL_SIZE.x, half_height)
	var lower_rect := Rect2i(0, half_height, CELL_SIZE.x, half_height)
	result.blend_rect(source, upper_rect, Vector2i(0, inward_offset))
	result.blend_rect(source, lower_rect, Vector2i(0, half_height - inward_offset))
	return result
