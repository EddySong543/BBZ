extends SceneTree

const OUTPUT_PATH := "res://assets/ui/boot/title_plus.png"
const CELL_SIZE := 9
const CANVAS_CELLS := Vector2i(12, 12)
const IMAGE_SIZE := CANVAS_CELLS * CELL_SIZE

const SOURCE_STRUCTURE := Color8(15, 27, 38, 255)
const SOURCE_FACE := Color8(245, 232, 209, 255)
const SOURCE_ENERGY := Color8(221, 86, 57, 255)

const PLUS_GLYPH: Array[String] = [
	"............",
	"....####....",
	"....####....",
	"....####....",
	".##########.",
	".##########.",
	".##########.",
	".##########.",
	"....####....",
	"....####....",
	"....####....",
	"............",
]


func _init() -> void:
	var face_cells := _decode_glyph()
	if face_cells.is_empty():
		push_error("Boot title plus glyph is invalid.")
		quit(1)
		return

	var fracture := _fault_cells(face_cells)
	var styled_cells := face_cells.duplicate()
	for cell_variant: Variant in fracture.keys():
		styled_cells.erase(cell_variant)
	var energy := _fault_lip_cells(styled_cells, fracture, true)
	var structure_lip := _fault_lip_cells(styled_cells, fracture, false)
	if fracture.is_empty() or energy.is_empty() or structure_lip.is_empty():
		push_error("Boot title plus requires the same three-part title fault.")
		quit(1)
		return

	var logical := Image.create(
		CANVAS_CELLS.x,
		CANVAS_CELLS.y,
		false,
		Image.FORMAT_RGBA8)
	logical.fill(Color.TRANSPARENT)

	# 与标题字共用同一套结构：右下深色厚度、象牙面、下缘结构唇、上缘能量唇。
	for cell_variant: Variant in styled_cells.keys():
		var cell := cell_variant as Vector2i
		var depth := cell + Vector2i.ONE
		if (
			depth.x >= 0
			and depth.y >= 0
			and depth.x < CANVAS_CELLS.x
			and depth.y < CANVAS_CELLS.y
		):
			logical.set_pixelv(depth, SOURCE_STRUCTURE)
	for cell_variant: Variant in styled_cells.keys():
		logical.set_pixelv(cell_variant as Vector2i, SOURCE_FACE)
	for cell_variant: Variant in structure_lip.keys():
		logical.set_pixelv(cell_variant as Vector2i, SOURCE_STRUCTURE)
	for cell_variant: Variant in energy.keys():
		logical.set_pixelv(cell_variant as Vector2i, SOURCE_ENERGY)
	for cell_variant: Variant in fracture.keys():
		logical.set_pixelv(cell_variant as Vector2i, Color.TRANSPARENT)

	var output: Image = logical.duplicate() as Image
	output.resize(
		IMAGE_SIZE.x,
		IMAGE_SIZE.y,
		Image.INTERPOLATE_NEAREST)
	var save_error: Error = output.save_png(
		ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		push_error(
			"Failed to save Boot title plus: %s"
			% error_string(save_error))
		quit(1)
		return

	print(
		"BOOT_TITLE_PLUS_OK: %s %dx%d"
		% [OUTPUT_PATH, IMAGE_SIZE.x, IMAGE_SIZE.y])
	quit()


func _decode_glyph() -> Dictionary:
	var cells: Dictionary = {}
	if PLUS_GLYPH.size() != CANVAS_CELLS.y:
		return cells
	for y: int in CANVAS_CELLS.y:
		var row := PLUS_GLYPH[y]
		if row.length() != CANVAS_CELLS.x:
			cells.clear()
			return cells
		for x: int in CANVAS_CELLS.x:
			if row.substr(x, 1) == "#":
				cells[Vector2i(x, y)] = true
	return cells


func _fault_cells(glyph: Dictionary) -> Dictionary:
	var fracture: Dictionary = {}
	for cell_variant: Variant in glyph.keys():
		var cell := cell_variant as Vector2i
		# 缺口只落在右侧横臂，完整保留十字中心与纵轴。标题式裂口仍然清楚，
		# 但不会再把“+”切成四块而损害中英文小尺寸下的第一眼识别。
		if cell.x < 8:
			continue
		if absf(float(cell.y) - _fault_y(float(cell.x))) <= 0.55:
			fracture[cell] = true
	return fracture


func _fault_lip_cells(
		styled: Dictionary,
		fracture: Dictionary,
		energy_side: bool) -> Dictionary:
	var lip: Dictionary = {}
	for cell_variant: Variant in styled.keys():
		var cell := cell_variant as Vector2i
		var delta := float(cell.y) - _fault_y(float(cell.x))
		var in_band := (-1.65 <= delta and delta < -0.55) if energy_side \
			else (0.55 < delta and delta <= 1.65)
		if in_band and _touches_fault(cell, fracture):
			lip[cell] = true
	return lip


func _touches_fault(cell: Vector2i, fracture: Dictionary) -> bool:
	for y_offset: int in range(-1, 2):
		for x_offset: int in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			if fracture.has(cell + Vector2i(x_offset, y_offset)):
				return true
	return false


func _fault_y(x: float) -> float:
	return 6.0 - (x - 8.0)
