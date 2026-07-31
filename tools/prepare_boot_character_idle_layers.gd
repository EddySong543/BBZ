extends SceneTree

const SOURCE_PATH := "res://assets/import/bootchar.png"
const OUTPUT_DIR := "res://assets/ui/boot/character"
const ATLAS_PATH := "D:/Game/BoBoZan/boot_character_layer_atlas.png"
const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

var _layer_specs: Array[Dictionary] = [
	{
		"name": "hair_left_tips",
		"polygons": [
			PackedVector2Array([
				Vector2(116, 7), Vector2(139, 7), Vector2(142, 30),
				Vector2(136, 34), Vector2(121, 34), Vector2(110, 28),
				Vector2(116, 20),
			]),
		],
		"overlap": Rect2i(121, 28, 21, 7),
	},
	{
		"name": "hair_right_tips",
		"polygons": [
			PackedVector2Array([
				Vector2(139, 7), Vector2(157, 10), Vector2(160, 19),
				Vector2(170, 23), Vector2(166, 31), Vector2(159, 35),
				Vector2(140, 34),
			]),
		],
		"overlap": Rect2i(139, 28, 27, 8),
	},
	{
		"name": "hair_front_tips",
		"polygons": [
			PackedVector2Array([
				Vector2(111, 27), Vector2(128, 26), Vector2(134, 31),
				Vector2(131, 43), Vector2(119, 45), Vector2(116, 38),
			]),
			PackedVector2Array([
				Vector2(151, 25), Vector2(168, 22), Vector2(169, 34),
				Vector2(162, 44), Vector2(152, 40),
			]),
		],
		"overlap": Rect2i(121, 29, 41, 8),
	},
	{
		"name": "fur_right_tips",
		"polygons": [
			PackedVector2Array([
				Vector2(158, 30), Vector2(177, 27), Vector2(185, 36),
				Vector2(185, 46), Vector2(175, 53), Vector2(160, 55),
				Vector2(153, 43),
			]),
		],
		"overlap": Rect2i(157, 39, 24, 15),
	},
	{
		"name": "waist_screen_right",
		"polygons": [
			PackedVector2Array([
				Vector2(173, 88), Vector2(190, 88), Vector2(195, 97),
				Vector2(194, 109), Vector2(191, 120), Vector2(184, 126),
				Vector2(176, 119), Vector2(172, 104),
			]),
		],
		"overlap": Rect2i(173, 88, 21, 14),
	},
	{
		"name": "waist_screen_left",
		"polygons": [
			PackedVector2Array([
				Vector2(108, 89), Vector2(126, 86), Vector2(138, 88),
				Vector2(143, 92), Vector2(141, 98), Vector2(137, 106),
				Vector2(132, 108), Vector2(127, 103), Vector2(123, 99),
				Vector2(108, 96),
			]),
		],
		"overlap": Rect2i(133, 88, 10, 12),
	},
]


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if source == null:
		push_error("Boot idle source could not be loaded: %s" % SOURCE_PATH)
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)

	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	if directory_error != OK:
		push_error("Boot idle output directory could not be created: %s" % directory_error)
		quit(1)
		return

	var base := source.duplicate()
	var layers: Array[Image] = []
	var owned := PackedInt32Array()
	owned.resize(source.get_width() * source.get_height())
	owned.fill(-1)

	for layer_index: int in _layer_specs.size():
		var spec: Dictionary = _layer_specs[layer_index]
		var layer := Image.create(
				source.get_width(),
				source.get_height(),
				false,
				Image.FORMAT_RGBA8)
		layer.fill(TRANSPARENT)
		var polygons: Array = spec["polygons"]
		var overlap: Rect2i = spec["overlap"]
		var copied := 0

		for y: int in source.get_height():
			for x: int in source.get_width():
				var owner_index := y * source.get_width() + x
				if owned[owner_index] >= 0:
					continue
				if not _point_in_any_polygon(Vector2(x + 0.5, y + 0.5), polygons):
					continue
				var source_color := source.get_pixel(x, y)
				if source_color.a <= 0.0:
					continue

				layer.set_pixel(x, y, source_color)
				owned[owner_index] = layer_index
				copied += 1

				var opaque_underpaint := (
						source_color.a >= 0.999
						and (
							overlap.has_point(Vector2i(x, y))
							or _is_interior_pixel(source, x, y)
						))
				if not opaque_underpaint:
					base.set_pixel(x, y, TRANSPARENT)

		if copied == 0:
			push_error("Boot idle layer is empty: %s" % String(spec["name"]))
			quit(1)
			return

		var layer_path := "%s/boot_char_%s.png" % [OUTPUT_DIR, spec["name"]]
		var layer_error := layer.save_png(ProjectSettings.globalize_path(layer_path))
		if layer_error != OK:
			push_error("Boot idle layer could not be saved: %s" % layer_path)
			quit(1)
			return
		print("BOOT_IDLE_LAYER: %s pixels=%d" % [layer_path, copied])
		layers.append(layer)

	var base_path := "%s/boot_char_base.png" % OUTPUT_DIR
	if base.save_png(ProjectSettings.globalize_path(base_path)) != OK:
		push_error("Boot idle base could not be saved.")
		quit(1)
		return

	var changed_pixels := _count_neutral_composite_changes(source, base, layers)
	if changed_pixels != 0:
		push_error("Boot idle neutral composite differs from source: %d pixels" % changed_pixels)
		quit(1)
		return
	print("BOOT_IDLE_RECONSTRUCTION_OK: changed_pixels=0")

	if not _save_atlas(source, base, layers):
		quit(1)
		return
	print("BOOT_IDLE_ATLAS_OK: %s" % ATLAS_PATH)
	quit()


func _point_in_any_polygon(point: Vector2, polygons: Array) -> bool:
	for polygon_variant: Variant in polygons:
		var polygon: PackedVector2Array = polygon_variant
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func _is_interior_pixel(image: Image, x: int, y: int) -> bool:
	var neighbors := [
		Vector2i(x - 1, y),
		Vector2i(x + 1, y),
		Vector2i(x, y - 1),
		Vector2i(x, y + 1),
	]
	for neighbor: Vector2i in neighbors:
		if (
				neighbor.x < 0
				or neighbor.y < 0
				or neighbor.x >= image.get_width()
				or neighbor.y >= image.get_height()
				or image.get_pixelv(neighbor).a <= 0.0
		):
			return false
	return true


func _count_neutral_composite_changes(
		source: Image,
		base: Image,
		layers: Array[Image]) -> int:
	var changed := 0
	for y: int in source.get_height():
		for x: int in source.get_width():
			var reconstructed := base.get_pixel(x, y)
			for layer: Image in layers:
				var layer_color := layer.get_pixel(x, y)
				if layer_color.a > 0.0:
					reconstructed = layer_color
			if reconstructed != source.get_pixel(x, y):
				changed += 1
	return changed


func _save_atlas(source: Image, base: Image, layers: Array[Image]) -> bool:
	var images: Array[Image] = [source, base]
	images.append_array(layers)
	var columns := 2
	var rows := ceili(float(images.size()) / float(columns))
	var atlas := Image.create(
			source.get_width() * columns,
			source.get_height() * rows,
			false,
			Image.FORMAT_RGBA8)
	atlas.fill(Color(0.03, 0.03, 0.04, 1.0))

	for index: int in images.size():
		var cell := Vector2i(
			(index % columns) * source.get_width(),
			(index / columns) * source.get_height())
		atlas.blend_rect(
			images[index],
			Rect2i(Vector2i.ZERO, source.get_size()),
			cell)

	atlas.resize(
		atlas.get_width() * 2,
		atlas.get_height() * 2,
		Image.INTERPOLATE_NEAREST)
	var atlas_error := atlas.save_png(ATLAS_PATH)
	if atlas_error != OK:
		push_error("Boot idle atlas could not be saved: %s" % atlas_error)
		return false
	return true
