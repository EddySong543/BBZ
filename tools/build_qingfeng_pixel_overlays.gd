extends SceneTree

## Deterministic Godot-side twin of build_qingfeng_pixel_overlays.py.
## Kept because the production workspace does not assume a system Python.

const CANVAS_SIZE: int = 60
const LOGICAL_PIXEL: int = 2
const OVERLAY_DIR: String = "res://assets/tilesets/qingfeng_ricefield/overlays/"
const PREVIEW_DIR: String = "res://design/previews/"
const GRASS_PATH: String = "res://assets/tilesets/qingfeng_ricefield/grass_ref37_ref39_plain_v1.png"
const DIRT_PATH: String = "res://assets/tilesets/qingfeng_ricefield/dirt_ref37_ref39_plain_v1.png"


func _init() -> void:
	var plant_names: Array[String] = [
		"overlay_flower_white_v1.png",
		"overlay_flower_yellow_v1.png",
		"overlay_flower_pink_v1.png",
		"overlay_short_grass_v1.png",
		"overlay_clover_v1.png",
	]
	var plants: Array[Image] = _load_overlays(plant_names)
	var detail_names: Array[String] = [
		"overlay_stone_chips_pale_v1.png",
		"overlay_straw_fragments_v1.png",
		"overlay_green_leaves_v1.png",
		"overlay_dirt_crack_v1.png",
	]
	var details: Array[Image] = _load_overlays(detail_names)
	_make_previews(plants, details)
	print("Preserved five plant overlays and four approved ground details.")
	quit()


func _load_overlays(names: Array[String]) -> Array[Image]:
	var images: Array[Image] = []
	for name: String in names:
		images.append(Image.load_from_file(OVERLAY_DIR + name))
	return images


func _new_sprite() -> Image:
	var image := Image.create(CANVAS_SIZE, CANVAS_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image


func _paint_block(image: Image, x: int, y: int, color: Color) -> void:
	for offset_y: int in LOGICAL_PIXEL:
		for offset_x: int in LOGICAL_PIXEL:
			image.set_pixel(x + offset_x, y + offset_y, color)


func _paint_blocks(image: Image, points: Array[Vector2i], color: Color) -> void:
	for point: Vector2i in points:
		_paint_block(image, point.x, point.y, color)


func _paint_map(image: Image, origin: Vector2i, rows: Array[String], palette: Dictionary) -> void:
	for row_index: int in rows.size():
		for column_index: int in rows[row_index].length():
			var key: String = rows[row_index].substr(column_index, 1)
			if key == ".":
				continue
			_paint_block(
				image,
				origin.x + column_index * LOGICAL_PIXEL,
				origin.y + row_index * LOGICAL_PIXEL,
				palette[key] as Color)


func _flower(petal: Color, centre: Color) -> Image:
	var image := _new_sprite()
	_paint_blocks(image, [Vector2i(28, 26), Vector2i(26, 28), Vector2i(30, 28), Vector2i(28, 30)], petal)
	_paint_block(image, 28, 28, centre)
	return image


func _short_grass() -> Image:
	var image := _new_sprite()
	_paint_map(image, Vector2i(22, 24), [
		"...d....", "..dm.d..", ".lmd.dm.", ".dmdld..",
		"dmddddm.", "ddddddd.", ".ddddd..",
	], {"d": Color8(36, 78, 34), "m": Color8(54, 104, 40), "l": Color8(84, 130, 49)})
	return image


func _clover() -> Image:
	var image := _new_sprite()
	var palette := {
		"d": Color8(42, 72, 31), "m": Color8(94, 136, 55),
		"l": Color8(130, 164, 69), "h": Color8(150, 181, 78),
	}
	_paint_blocks(image, [Vector2i(30, 26), Vector2i(30, 28), Vector2i(30, 30), Vector2i(30, 32), Vector2i(30, 34), Vector2i(30, 36), Vector2i(30, 38)], palette["d"])
	var leaf: Array[String] = [".dd.", "dmmd", "dmld", ".dd."]
	_paint_map(image, Vector2i(26, 20), leaf, palette)
	_paint_map(image, Vector2i(22, 28), leaf, palette)
	_paint_map(image, Vector2i(32, 28), leaf, palette)
	_paint_blocks(image, [Vector2i(28, 28), Vector2i(30, 28)], palette["d"])
	return image


func _stone_chips() -> Image:
	var image := _new_sprite()
	var palette := {
		"d": Color8(92, 95, 69), "m": Color8(151, 149, 115),
		"l": Color8(193, 187, 145), "h": Color8(224, 216, 174),
	}
	_paint_map(image, Vector2i(24, 22), ["..d..", ".dmh.", "dmhld", ".ddd."], palette)
	_paint_map(image, Vector2i(34, 30), ["..d..", ".dml.", "dlhmd", ".ddd."], palette)
	_paint_map(image, Vector2i(20, 36), ["..d..", ".dmh.", "dmlmd", ".ddd."], palette)
	return image


func _straw_fragments() -> Image:
	var image := _new_sprite()
	var shadow := Color8(132, 87, 24)
	var gold := Color8(220, 157, 38)
	var light := Color8(244, 190, 62)
	_paint_blocks(image, [Vector2i(22, 24), Vector2i(24, 26), Vector2i(26, 26), Vector2i(28, 28)], gold)
	_paint_block(image, 22, 24, light)
	_paint_block(image, 28, 28, shadow)
	_paint_blocks(image, [Vector2i(34, 22), Vector2i(36, 22), Vector2i(38, 20)], gold)
	_paint_block(image, 34, 22, light)
	_paint_block(image, 38, 20, shadow)
	_paint_blocks(image, [Vector2i(38, 28), Vector2i(36, 30), Vector2i(34, 32)], gold)
	_paint_block(image, 38, 28, light)
	_paint_block(image, 34, 32, shadow)
	_paint_blocks(image, [Vector2i(26, 36), Vector2i(28, 38), Vector2i(30, 38)], gold)
	_paint_block(image, 26, 36, light)
	_paint_block(image, 30, 38, shadow)
	return image


func _green_leaves() -> Image:
	var image := _new_sprite()
	var palette := {
		"d": Color8(33, 76, 34), "m": Color8(62, 128, 48),
		"l": Color8(99, 164, 63), "h": Color8(143, 194, 77),
	}
	_paint_map(image, Vector2i(22, 22), ["...dd", ".ddmd", "dmhmd", ".dddd"], palette)
	_paint_map(image, Vector2i(32, 32), ["dd...", "dmddd", "dmlmd", ".ddd."], palette)
	return image


func _save_image(image: Image, path: String) -> void:
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])


func _composite_panel(base: Image, overlay: Image) -> Image:
	var panel := base.duplicate()
	panel.blend_rect(overlay, Rect2i(Vector2i.ZERO, overlay.get_size()), Vector2i.ZERO)
	panel.resize(240, 240, Image.INTERPOLATE_NEAREST)
	return panel


func _make_previews(plants: Array[Image], details: Array[Image]) -> void:
	var grass := Image.load_from_file(GRASS_PATH)
	var dirt := Image.load_from_file(DIRT_PATH)
	var plant_preview := Image.create(240 * plants.size(), 240, false, Image.FORMAT_RGBA8)
	plant_preview.fill(Color.BLACK)
	for index: int in plants.size():
		var panel := _composite_panel(grass, plants[index])
		plant_preview.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i(index * 240, 0))
	_save_image(plant_preview, PREVIEW_DIR + "qingfeng_small_overlays_formal_preview_v4.png")

	var detail_preview := Image.create(720, 480, false, Image.FORMAT_RGBA8)
	detail_preview.fill(Color.BLACK)
	for index: int in details.size():
		var base: Image = grass if index < 3 else dirt
		var panel := _composite_panel(base, details[index])
		detail_preview.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i(index % 3 * 240, index / 3 * 240))
	_save_image(detail_preview, PREVIEW_DIR + "qingfeng_ground_details_formal_preview_v4.png")
