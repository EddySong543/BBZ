extends SceneTree

const LOGICAL_SIZE := Vector2i(28, 28)
const CELL_SIZE := 9
const IMAGE_SIZE := LOGICAL_SIZE * CELL_SIZE
const BASE_SIZE := Vector2i(12, 12)
const BASE_OFFSET := Vector2i(2, 2)
const BASE_STRIDE := 2
const STROKE_FOOTPRINT := 3
const FAULT_SLOPE := -0.32
const FAULT_TOLERANCE := 0.55

const FAULT_INTERCEPTS: Dictionary = {
	"传": 8.8,
	"说": 10.0,
}

# Keep the identifying skeleton and its straight, stable edges intact. The
# approved main title is orderly first and hand-cut second, so contour changes
# are limited to paired rows at a few terminals. A two-row step reads as one
# deliberate cap; isolated row shifts and chipped corners read as noise.
const CONTOUR_LEFT_EXTENSIONS: Dictionary = {
	"传": [14, 15],
	"说": [4, 5, 14, 15],
}

const CONTOUR_RIGHT_EXTENSIONS: Dictionary = {
	"传": [7, 8],
	"说": [9, 10, 21, 22],
}

# User-marked micro correction: close the isolated one-cell counter beside the
# lower-left 说 stroke. It changes neither the outer silhouette nor stroke flow.
const CONTOUR_FILL_CELLS: Dictionary = {
	"传": [],
	"说": [Vector2i(9, 21)],
}

const SOURCE_STRUCTURE := Color8(15, 27, 38, 255)
const SOURCE_FACE := Color8(245, 232, 209, 255)
const SOURCE_ENERGY := Color8(221, 86, 57, 255)

const OUTPUT_PATHS: Dictionary = {
	"传": "res://assets/ui/boot/title_chuan.png",
	"说": "res://assets/ui/boot/title_shuo.png",
}

# Ark Pixel 12px supplies the identifying CJK skeleton. Each source cell is
# rebuilt as a 3x3 stroke footprint on the main title's exact 28x28 grid,
# with a 2-cell stride. This matches the approved title's 18-27 px strokes
# without collapsing the counters that distinguish 传 and 说.
const GLYPHS: Dictionary = {
	"传": [
		"..#....#....",
		"..#.######..",
		".#....#.....",
		".#....#.....",
		"##.########.",
		".#...#......",
		".#..######..",
		".#.......#..",
		".#...#..#...",
		".#....##....",
		".#......#...",
		"............",
	],
	"说": [
		"#...#....#..",
		".#...#..#...",
		"....######..",
		"....#....#..",
		"##..#....#..",
		".#..#....#..",
		".#..######..",
		".#...#..#...",
		".#.#.#..#.#.",
		".##.#...#.#.",
		".#.#....###.",
		"............",
	],
}


func _init() -> void:
	for glyph_name: String in ["传", "说"]:
		var base := _decode_base(GLYPHS[glyph_name] as Array)
		var source := _expand_base(base)
		source = _apply_authored_contour(source, glyph_name)
		var fault_intercept := float(FAULT_INTERCEPTS[glyph_name])
		var fracture := _build_fracture(source, fault_intercept)
		var source_count := _count_mask(source)
		var fracture_count := _count_mask(fracture)
		var retention := 1.0 - float(fracture_count) / float(source_count)
		if source_count < 260 or fracture_count < 8 or retention < 0.94:
			push_error(
				("Boot legend title %s has invalid stroke retention: "
				+ "source=%d fracture=%d retention=%.3f")
				% [glyph_name, source_count, fracture_count, retention])
			quit(1)
			return

		var output := _render_glyph(source, fracture, fault_intercept)
		if not _validate_glyph(output, glyph_name, retention):
			quit(1)
			return
		var output_path := String(OUTPUT_PATHS[glyph_name])
		var save_error := output.save_png(
			ProjectSettings.globalize_path(output_path))
		if save_error != OK:
			push_error(
				"Failed to save Boot legend title %s: %s"
				% [glyph_name, error_string(save_error)])
			quit(1)
			return
		print(
			"BOOT_LEGEND_TITLE_OK: %s %s %dx%d grid=%dx%d cell=%d"
			% [
				glyph_name,
				output_path,
				IMAGE_SIZE.x,
				IMAGE_SIZE.y,
				LOGICAL_SIZE.x,
				LOGICAL_SIZE.y,
				CELL_SIZE,
			])
	quit()


func _decode_base(rows: Array) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(BASE_SIZE.x * BASE_SIZE.y)
	if rows.size() != BASE_SIZE.y:
		push_error("Boot legend title base glyph must have 12 rows.")
		return PackedByteArray()
	for y: int in BASE_SIZE.y:
		var row := String(rows[y])
		if row.length() != BASE_SIZE.x:
			push_error("Boot legend title base row must have 12 cells.")
			return PackedByteArray()
		for x: int in BASE_SIZE.x:
			if row.substr(x, 1) == "#":
				mask[y * BASE_SIZE.x + x] = 1
	return mask


func _expand_base(base: PackedByteArray) -> PackedByteArray:
	var expanded := PackedByteArray()
	expanded.resize(LOGICAL_SIZE.x * LOGICAL_SIZE.y)
	for base_y: int in BASE_SIZE.y:
		for base_x: int in BASE_SIZE.x:
			if base[base_y * BASE_SIZE.x + base_x] == 0:
				continue
			var origin := BASE_OFFSET + Vector2i(
				base_x * BASE_STRIDE,
				base_y * BASE_STRIDE)
			for offset_y: int in STROKE_FOOTPRINT:
				for offset_x: int in STROKE_FOOTPRINT:
					var cell := origin + Vector2i(offset_x, offset_y)
					if (
						cell.x >= 0
						and cell.y >= 0
						and cell.x < LOGICAL_SIZE.x
						and cell.y < LOGICAL_SIZE.y
					):
						expanded[_mask_index(cell.x, cell.y)] = 1
	return expanded


func _apply_authored_contour(
	source: PackedByteArray,
	glyph_name: String,
) -> PackedByteArray:
	var shaped := source.duplicate()
	_apply_row_extensions(
		shaped,
		CONTOUR_LEFT_EXTENSIONS[glyph_name] as Array,
		-1)
	_apply_row_extensions(
		shaped,
		CONTOUR_RIGHT_EXTENSIONS[glyph_name] as Array,
		1)
	for cell_variant: Variant in CONTOUR_FILL_CELLS[glyph_name] as Array:
		var cell := Vector2i(cell_variant)
		shaped[_mask_index(cell.x, cell.y)] = 1
	return shaped


func _apply_row_extensions(
	mask: PackedByteArray,
	rows: Array,
	direction: int,
) -> void:
	for y_variant: Variant in rows:
		var y := int(y_variant)
		var bounds := _row_bounds(mask, y)
		if bounds.x < 0:
			continue
		var target_x := bounds.x - 1 if direction < 0 else bounds.y + 1
		if target_x >= 2 and target_x <= 24:
			mask[_mask_index(target_x, y)] = 1

func _row_bounds(mask: PackedByteArray, y: int) -> Vector2i:
	var left := -1
	var right := -1
	for x: int in LOGICAL_SIZE.x:
		if mask[_mask_index(x, y)] == 0:
			continue
		if left < 0:
			left = x
		right = x
	return Vector2i(left, right)


func _build_fracture(
	source: PackedByteArray,
	fault_intercept: float,
) -> PackedByteArray:
	var fracture := PackedByteArray()
	fracture.resize(LOGICAL_SIZE.x * LOGICAL_SIZE.y)
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var index := _mask_index(x, y)
			if (
				source[index] != 0
				and absf(float(y) - _fault_y(x, fault_intercept)) <= FAULT_TOLERANCE
			):
				fracture[index] = 1
	return fracture


func _render_glyph(
	source: PackedByteArray,
	fracture: PackedByteArray,
	fault_intercept: float,
) -> Image:
	var styled := source.duplicate()
	for index: int in fracture.size():
		if fracture[index] != 0:
			styled[index] = 0

	var energy := PackedByteArray()
	energy.resize(LOGICAL_SIZE.x * LOGICAL_SIZE.y)
	var structure_lip := PackedByteArray()
	structure_lip.resize(LOGICAL_SIZE.x * LOGICAL_SIZE.y)
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var index := _mask_index(x, y)
			if styled[index] == 0 or not _touches_fracture(x, y, fracture):
				continue
			var fault_distance := float(y) - _fault_y(x, fault_intercept)
			if fault_distance >= -1.65 and fault_distance < -0.55:
				energy[index] = 1
			elif fault_distance > 0.55 and fault_distance <= 1.65:
				structure_lip[index] = 1

	var logical := Image.create(
		LOGICAL_SIZE.x,
		LOGICAL_SIZE.y,
		false,
		Image.FORMAT_RGBA8)
	logical.fill(Color.TRANSPARENT)
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var index := _mask_index(x, y)
			if styled[index] == 0:
				continue
			var depth := Vector2i(x + 1, y + 1)
			if (
				depth.x < LOGICAL_SIZE.x
				and depth.y < LOGICAL_SIZE.y
				and fracture[_mask_index(depth.x, depth.y)] == 0
			):
				logical.set_pixelv(depth, SOURCE_STRUCTURE)
	for y: int in LOGICAL_SIZE.y:
		for x: int in LOGICAL_SIZE.x:
			var index := _mask_index(x, y)
			if styled[index] != 0:
				logical.set_pixel(x, y, SOURCE_FACE)
			if structure_lip[index] != 0:
				logical.set_pixel(x, y, SOURCE_STRUCTURE)
			if energy[index] != 0:
				logical.set_pixel(x, y, SOURCE_ENERGY)
			if fracture[index] != 0:
				logical.set_pixel(x, y, Color.TRANSPARENT)

	logical.resize(IMAGE_SIZE.x, IMAGE_SIZE.y, Image.INTERPOLATE_NEAREST)
	return logical


func _touches_fracture(
	x: int,
	y: int,
	fracture: PackedByteArray,
) -> bool:
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var target := Vector2i(x + offset_x, y + offset_y)
			if (
				target.x < 0
				or target.y < 0
				or target.x >= LOGICAL_SIZE.x
				or target.y >= LOGICAL_SIZE.y
			):
				continue
			if fracture[_mask_index(target.x, target.y)] != 0:
				return true
	return false


func _validate_glyph(
	image: Image,
	glyph_name: String,
	retention: float,
) -> bool:
	var used_rect := image.get_used_rect()
	if image.get_size() != IMAGE_SIZE:
		push_error("Boot legend title must be 252x252.")
		return false
	var aspect := float(used_rect.size.x) / float(used_rect.size.y)
	var opaque_count := 0
	var energy_rows: Array[int] = []
	for y: int in used_rect.size.y:
		for x: int in used_rect.size.x:
			var color := image.get_pixelv(used_rect.position + Vector2i(x, y))
			if color.a <= 0.5:
				continue
			opaque_count += 1
			if color.is_equal_approx(SOURCE_ENERGY):
				energy_rows.append(y)
	if energy_rows.is_empty():
		push_error("Boot legend title %s has no energy fracture." % glyph_name)
		return false
	energy_rows.sort()
	var energy_y := (
		float(energy_rows[energy_rows.size() / 2])
		/ float(used_rect.size.y))
	var fill := float(opaque_count) / float(used_rect.size.x * used_rect.size.y)
	if aspect < 0.98 or aspect > 1.02:
		push_error("Boot legend title %s is not square." % glyph_name)
		return false
	if used_rect.size.x < 207 or used_rect.size.x > 225:
		push_error("Boot legend title %s does not match main-title occupancy." % glyph_name)
		return false
	if energy_y < 0.24 or energy_y > 0.40:
		push_error("Boot legend title %s energy fracture is misplaced." % glyph_name)
		return false
	if fill < 0.56 or fill > 0.72:
		push_error("Boot legend title %s density %.3f is out of range." % [glyph_name, fill])
		return false
	print(
		("BOOT_LEGEND_TITLE_METRICS: %s bbox=%dx%d aspect=%.3f "
		+ "energy_y=%.3f fill=%.3f retention=%.3f")
		% [
			glyph_name,
			used_rect.size.x,
			used_rect.size.y,
			aspect,
			energy_y,
			fill,
			retention,
		])
	return true


func _fault_y(x: int, fault_intercept: float) -> float:
	var center_x := float(LOGICAL_SIZE.x - 1) * 0.5
	return fault_intercept + FAULT_SLOPE * (float(x) - center_x)


func _count_mask(mask: PackedByteArray) -> int:
	var count := 0
	for value: int in mask:
		if value != 0:
			count += 1
	return count


func _mask_index(x: int, y: int) -> int:
	return y * LOGICAL_SIZE.x + x
