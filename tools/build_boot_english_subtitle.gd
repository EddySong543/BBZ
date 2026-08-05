extends SceneTree

const OUTPUT_PATH := "res://assets/ui/boot/title_bobozan.png"
const IMAGE_SIZE := Vector2i(352, 80)
const CELL_SIZE := 8
const GLYPH_WIDTH := 5
const GLYPH_HEIGHT := 7
const LETTER_GAP := 8
const GLYPH_STRIDE := GLYPH_WIDTH * CELL_SIZE + LETTER_GAP
const ORIGIN := Vector2i(12, 12)
const OUTLINE_PIXELS := 3
const CUT_BASE_OFFSET := 37
const CUT_SLOPE_DIVISOR := 5.0
const CUT_GAP_PIXELS := 1
const ENERGY_EDGE_PIXELS := 3
const UPPER_HALF_OFFSET := Vector2i(1, -1)
const LOWER_HALF_OFFSET := Vector2i(-1, 1)
const WORD := "BOBOZAN"

const SOURCE_STRUCTURE := Color8(15, 27, 38, 255)
const SOURCE_FACE := Color8(245, 232, 209, 255)
const SOURCE_ENERGY := Color8(221, 86, 57, 255)

const GLYPHS: Dictionary = {
	"B": [
		"11110",
		"10001",
		"10001",
		"11110",
		"10001",
		"10001",
		"11110",
	],
	"O": [
		"01110",
		"10001",
		"10001",
		"10001",
		"10001",
		"10001",
		"01110",
	],
	"Z": [
		"11111",
		"00001",
		"00010",
		"00100",
		"01000",
		"10000",
		"11111",
	],
	"A": [
		"01110",
		"10001",
		"10001",
		"11111",
		"10001",
		"10001",
		"10001",
	],
	"N": [
		"10001",
		"11001",
		"11001",
		"10101",
		"10011",
		"10011",
		"10001",
	],
}


func _init() -> void:
	var image := Image.create(
		IMAGE_SIZE.x,
		IMAGE_SIZE.y,
		false,
		Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	var face_mask := PackedByteArray()
	face_mask.resize(IMAGE_SIZE.x * IMAGE_SIZE.y)
	_build_face_mask(face_mask)
	var split_mask := PackedByteArray()
	split_mask.resize(IMAGE_SIZE.x * IMAGE_SIZE.y)
	var energy_mask := PackedByteArray()
	energy_mask.resize(IMAGE_SIZE.x * IMAGE_SIZE.y)
	_build_split_masks(
		face_mask,
		split_mask,
		energy_mask)
	# Outline the displaced silhouette once, so the split reads as one
	# deliberate pressure fracture instead of several painted marks.
	_draw_structure(image, split_mask)
	_draw_face_and_energy(
		image,
		split_mask,
		energy_mask)

	var save_error := image.save_png(
		ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		push_error(
			"Failed to save Boot English subtitle: %s"
			% error_string(save_error))
		quit(1)
		return

	print(
		"BOOT_ENGLISH_SUBTITLE_OK: %s %dx%d"
		% [OUTPUT_PATH, IMAGE_SIZE.x, IMAGE_SIZE.y])
	quit()


func _build_face_mask(mask: PackedByteArray) -> void:
	var glyph_pixel_width := GLYPH_WIDTH * CELL_SIZE
	for glyph_index: int in WORD.length():
		var glyph_name: String = WORD.substr(glyph_index, 1)
		var rows: Array = GLYPHS[glyph_name] as Array
		var glyph_x := (
			ORIGIN.x
			+ glyph_index * (glyph_pixel_width + LETTER_GAP))
		for row_index: int in GLYPH_HEIGHT:
			var row: String = String(rows[row_index])
			for column_index: int in GLYPH_WIDTH:
				if row.substr(column_index, 1) != "1":
					continue
				var cell_origin := Vector2i(
					glyph_x + column_index * CELL_SIZE,
					ORIGIN.y + row_index * CELL_SIZE)
				for cell_y: int in CELL_SIZE:
					for cell_x: int in CELL_SIZE:
						var pixel := cell_origin + Vector2i(cell_x, cell_y)
						mask[_mask_index(pixel.x, pixel.y)] = 1


func _draw_structure(image: Image, mask: PackedByteArray) -> void:
	for y: int in IMAGE_SIZE.y:
		for x: int in IMAGE_SIZE.x:
			if mask[_mask_index(x, y)] == 0:
				continue
			for offset_y: int in range(-OUTLINE_PIXELS, OUTLINE_PIXELS + 1):
				for offset_x: int in range(-OUTLINE_PIXELS, OUTLINE_PIXELS + 1):
					var target := Vector2i(x + offset_x, y + offset_y)
					if (
						target.x < 0
						or target.y < 0
						or target.x >= IMAGE_SIZE.x
						or target.y >= IMAGE_SIZE.y
					):
						continue
					image.set_pixelv(target, SOURCE_STRUCTURE)


func _build_split_masks(
	source_mask: PackedByteArray,
	split_mask: PackedByteArray,
	energy_mask: PackedByteArray,
) -> void:
	for y: int in IMAGE_SIZE.y:
		for x: int in IMAGE_SIZE.x:
			if source_mask[_mask_index(x, y)] == 0:
				continue
			var glyph_local_x := posmod(
				x - ORIGIN.x,
				GLYPH_STRIDE)
			var cut_y := (
				ORIGIN.y
				+ CUT_BASE_OFFSET
				- floori(
					float(glyph_local_x)
					/ CUT_SLOPE_DIVISOR))
			var target := Vector2i(x, y)
			var lower_half := false
			if y <= cut_y:
				target += UPPER_HALF_OFFSET
			elif y >= cut_y + CUT_GAP_PIXELS + 1:
				target += LOWER_HALF_OFFSET
				lower_half = true
			else:
				continue
			if (
				target.x < 0
				or target.y < 0
				or target.x >= IMAGE_SIZE.x
				or target.y >= IMAGE_SIZE.y
			):
				continue
			var target_index := _mask_index(target.x, target.y)
			split_mask[target_index] = 1
			if (
				lower_half
				and y <= (
					cut_y
					+ CUT_GAP_PIXELS
					+ ENERGY_EDGE_PIXELS)
			):
				energy_mask[target_index] = 1


func _draw_face_and_energy(
	image: Image,
	split_mask: PackedByteArray,
	energy_mask: PackedByteArray,
) -> void:
	for y: int in IMAGE_SIZE.y:
		for x: int in IMAGE_SIZE.x:
			var index := _mask_index(x, y)
			if split_mask[index] == 0:
				continue
			image.set_pixel(
				x,
				y,
				SOURCE_ENERGY
					if energy_mask[index] != 0
					else SOURCE_FACE)


func _mask_index(x: int, y: int) -> int:
	return y * IMAGE_SIZE.x + x
