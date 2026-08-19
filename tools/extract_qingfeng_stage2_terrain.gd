extends SceneTree

## 将 imagegen 的预览候选表拆成可逐格验收的 60x60 真像素候选。
## 先缩到 30x30 逻辑像素、限制色板，再以 Nearest 精确放大 2 倍。

const SOURCE := "res://design/previews/stage2_qingfeng_terrain/terrain_bundle_raw_v1.png"
const OUTPUT_DIR := "res://design/previews/stage2_qingfeng_terrain/candidates"
const TILE_NAMES: Array[String] = [
	"grass_variant_a", "grass_variant_b", "grass_variant_c", "grass_dirt_edge_lr",
	"dirt_variant_a", "dirt_variant_b", "grass_dirt_outer_corner", "dirt_patch",
	"wheat_interior", "wheat_edge_right", "wheat_outer_corner", "wheat_patch",
	"ridge_horizontal", "ridge_vertical", "ditch_horizontal", "ditch_vertical",
]
const PALETTE: Array[Color] = [
	Color("203a33"), Color("2b4826"), Color("365d29"), Color("4a7130"),
	Color("5f8738"), Color("76a044"), Color("8db14d"), Color("a1bf59"),
	Color("70431f"), Color("8c5423"), Color("a96629"), Color("c07931"),
	Color("d88d3a"), Color("e9a44a"), Color("f0b65b"),
	Color("8a6319"), Color("a9781f"), Color("c18d25"), Color("daa32e"),
	Color("efbd3d"), Color("ffd557"), Color("fff07a"),
	Color("6f4d24"), Color("98703a"), Color("c09553"), Color("ddb66c"),
	Color("173846"), Color("245367"), Color("2f6d82"), Color("3c8298"),
]


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if source == null or source.is_empty():
		push_error("Cannot load stage-2 terrain sheet: %s" % SOURCE)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var x_spans := _content_spans(source, true)
	var y_spans := _content_spans(source, false)
	if x_spans.size() != 4 or y_spans.size() != 4:
		push_error("Expected 4x4 tile regions, got %dx%d" % [x_spans.size(), y_spans.size()])
		quit(1)
		return

	var manifest_tiles: Array[Dictionary] = []
	for row: int in 4:
		for column: int in 4:
			var index := row * 4 + column
			var x_span: Vector2i = x_spans[column]
			var y_span: Vector2i = y_spans[row]
			var region := Rect2i(
				x_span.x, y_span.x,
				x_span.y - x_span.x + 1,
				y_span.y - y_span.x + 1)
			var tile := source.get_region(region)
			tile.resize(30, 30, Image.INTERPOLATE_NEAREST)
			_quantize_to_palette(tile)
			tile.resize(60, 60, Image.INTERPOLATE_NEAREST)
			var relative_path := "%s/%s.png" % [OUTPUT_DIR, TILE_NAMES[index]]
			var error := tile.save_png(ProjectSettings.globalize_path(relative_path))
			if error != OK:
				push_error("Could not save %s: %s" % [relative_path, error_string(error)])
				quit(1)
				return
			manifest_tiles.append({
				"id": TILE_NAMES[index],
				"path": relative_path,
				"sheet_row": row,
				"sheet_column": column,
				"size": [60, 60],
				"logical_pixel": 2,
			})

	var manifest := {
		"format": "bbz.qingfeng.stage2_terrain_preview.v1",
		"source": SOURCE,
		"preview_only": true,
		"tile_size": [60, 60],
		"logical_pixel": 2,
		"tiles": manifest_tiles,
	}
	var manifest_path := "%s/manifest.json" % OUTPUT_DIR
	var file := FileAccess.open(ProjectSettings.globalize_path(manifest_path), FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % manifest_path)
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("stage2 terrain candidates: ", manifest_tiles.size(), " -> ", OUTPUT_DIR)
	quit()


func _content_spans(image: Image, vertical_projection: bool) -> Array[Vector2i]:
	var axis_length := image.get_width() if vertical_projection else image.get_height()
	var cross_length := image.get_height() if vertical_projection else image.get_width()
	var active: Array[bool] = []
	active.resize(axis_length)
	for axis: int in axis_length:
		var content_count := 0
		for cross: int in cross_length:
			var color := image.get_pixel(axis, cross) if vertical_projection else image.get_pixel(cross, axis)
			if not _is_magenta(color):
				content_count += 1
		active[axis] = content_count > cross_length / 10

	var spans: Array[Vector2i] = []
	var start := -1
	for axis: int in axis_length:
		if active[axis] and start < 0:
			start = axis
		elif not active[axis] and start >= 0:
			spans.append(Vector2i(start, axis - 1))
			start = -1
	if start >= 0:
		spans.append(Vector2i(start, axis_length - 1))
	return spans


func _is_magenta(color: Color) -> bool:
	return color.r > 0.78 and color.g < 0.22 and color.b > 0.70


func _quantize_to_palette(image: Image) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var source := image.get_pixel(x, y)
			var best := PALETTE[0]
			var best_distance := INF
			for candidate: Color in PALETTE:
				var distance := (
					pow(source.r - candidate.r, 2.0)
					+ pow(source.g - candidate.g, 2.0)
					+ pow(source.b - candidate.b, 2.0))
				if distance < best_distance:
					best_distance = distance
					best = candidate
			image.set_pixel(x, y, Color(best, 1.0))
