extends Node

## 第二阶段地形区域化预览。
## 运行时复用正式 ExpeditionScreen、方案A圆角材质、相机、角色和光影；
## 只在探针进程中接管 GroundArtLayer 的绘制，不写回正式 TileSet。

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const MapState := preload("res://src/expedition/expedition_map_state.gd")
const ProbeOutput := preload("res://tools/probe_output.gd")

const CANDIDATE_DIR := "res://design/previews/stage2_qingfeng_terrain/candidates"
const TELEPORT_PATH := "res://assets/tilesets/qingfeng_ricefield/qingfeng_teleport_v1.png"
const OUTPUT_FILE := "exped_stage2_terrain_regions_preview.png"

var _screen: Control
var _textures: Dictionary = {}
var _dirt_cells: Dictionary = {}
var _wheat_cells: Dictionary = {}
var _ridge_cells: Dictionary = {}
var _ditch_cells: Dictionary = {}


func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_load_candidate_textures()
	_build_region_layout()

	_screen = (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(_screen)
	await get_tree().create_timer(0.35).timeout
	_screen.seed_value = 777
	_screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().create_timer(0.45).timeout

	var original_draw := Callable(_screen, "_draw_ground_art")
	if _screen.ground_art.draw.is_connected(original_draw):
		_screen.ground_art.draw.disconnect(original_draw)
	_screen.ground_art.draw.connect(_draw_stage2_ground)

	# 第二阶段只验收地形与角色。将完整地图置为可见，并隐藏物体/标识层。
	for y: int in MapState.HEIGHT:
		for x: int in MapState.WIDTH:
			var cell := Vector2i(x, y)
			_screen.map.revealed[cell] = true
			_screen.map.visible[cell] = true
	_screen.map.player = Vector2i(9, 7)
	_screen.foliage_art.visible = false
	_screen.object_art.visible = false
	_screen.marker_art.visible = false
	_screen.canvas.visible = false
	_screen.teleport_fx.visible = false
	_screen._camera_initialized = false
	_screen._refresh()
	await get_tree().create_timer(0.25).timeout
	_screen.set_process(false)
	_screen.ground_art.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await _shot()
	get_tree().quit()


func _load_candidate_textures() -> void:
	for tile_id: String in [
		"grass_variant_a", "grass_variant_b", "grass_variant_c",
		"dirt_variant_a", "dirt_variant_b", "grass_dirt_edge_lr",
		"grass_dirt_outer_corner", "wheat_interior", "wheat_edge_right",
		"wheat_outer_corner", "ridge_horizontal", "ditch_horizontal",
	]:
		var path := "%s/%s.png" % [CANDIDATE_DIR, tile_id]
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert(image != null and image.get_size() == Vector2i(60, 60), path)
		for turns: int in 4:
			var rotated := _rotate_image(image, turns)
			_textures[_texture_key(tile_id, turns)] = ImageTexture.create_from_image(rotated)
	var teleport := load(TELEPORT_PATH) as Texture2D
	assert(teleport != null)
	_textures["teleport"] = teleport


func _build_region_layout() -> void:
	# 两格宽、缓慢折转的主路；不再使用贯穿整屏的十字条带。
	var main_centers: Array[int] = [11, 11, 10, 10, 9, 9, 8, 8, 7, 7, 8, 8, 9, 9]
	for y: int in MapState.HEIGHT:
		var center: int = main_centers[y]
		_mark(_dirt_cells, Vector2i(center - 1, y))
		_mark(_dirt_cells, Vector2i(center, y))
	# 一条向东北田区延伸的短支路，保持局部而非横贯地图。
	for point: Vector2i in [
		Vector2i(8, 8), Vector2i(9, 8), Vector2i(9, 7), Vector2i(10, 7),
		Vector2i(10, 6), Vector2i(11, 6), Vector2i(11, 5), Vector2i(12, 5),
		Vector2i(12, 4), Vector2i(13, 4),
	]:
		_mark(_dirt_cells, point)

	_mark_wheat_region(Rect2i(1, 1, 5, 4), [Vector2i(1, 1), Vector2i(5, 1)])
	_mark_wheat_region(Rect2i(13, 1, 4, 5), [Vector2i(13, 1), Vector2i(16, 5)])
	_mark_wheat_region(Rect2i(1, 9, 6, 4), [Vector2i(1, 9), Vector2i(6, 12)])
	# 路优先于田块，保证连续通行视觉。
	for cell: Vector2i in _dirt_cells:
		_wheat_cells.erase(cell)

	# 田埂与浅沟作为地面结构层：短段、成组、服务于田区边界。
	for x: int in range(2, 6):
		_mark(_ridge_cells, Vector2i(x, 8))
	for y: int in range(1, 5):
		_mark(_ditch_cells, Vector2i(12, y))
	for cell: Vector2i in _dirt_cells:
		_ridge_cells.erase(cell)
		_ditch_cells.erase(cell)
	for cell: Vector2i in _wheat_cells:
		_ridge_cells.erase(cell)
		_ditch_cells.erase(cell)


func _mark_wheat_region(region: Rect2i, cutouts: Array[Vector2i]) -> void:
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			_mark(_wheat_cells, Vector2i(x, y))
	for cell: Vector2i in cutouts:
		_wheat_cells.erase(cell)


func _mark(target: Dictionary, cell: Vector2i) -> void:
	if cell.x >= 0 and cell.y >= 0 and cell.x < MapState.WIDTH and cell.y < MapState.HEIGHT:
		target[cell] = true


func _draw_stage2_ground() -> void:
	_screen._draw_camera_fog_extension()
	_screen.ground_art.draw_rect(Rect2(Vector2.ZERO, _screen.MAP_WORLD_SIZE), _screen.GROUND_GAP_COLOR)
	for y: int in MapState.HEIGHT:
		for x: int in MapState.WIDTH:
			var cell := Vector2i(x, y)
			var rect: Rect2 = _screen._ground_cell_rect(cell)
			var texture := _texture_for_cell(cell)
			_screen.ground_art.draw_texture_rect(texture, rect, false, Color.WHITE)
			if cell == Vector2i(9, 13):
				_screen._draw_teleport_gold_glow(rect)


func _texture_for_cell(cell: Vector2i) -> Texture2D:
	if cell == Vector2i(9, 13):
		return _textures["teleport"]
	if _ridge_cells.has(cell):
		return _textures[_texture_key("ridge_horizontal", 0)]
	if _ditch_cells.has(cell):
		return _textures[_texture_key("ditch_horizontal", 1)]
	if _dirt_cells.has(cell):
		return _dirt_texture_for(cell)
	if _wheat_cells.has(cell):
		return _wheat_texture_for(cell)
	var variant := posmod(cell.x * 5 + cell.y * 7 + cell.x * cell.y, 9)
	var grass_id := "grass_variant_a"
	if variant in [2, 6]:
		grass_id = "grass_variant_b"
	elif variant in [4, 7, 8]:
		grass_id = "grass_variant_c"
	return _textures[_texture_key(grass_id, 0)]


func _dirt_texture_for(cell: Vector2i) -> Texture2D:
	var left := _dirt_cells.has(cell + Vector2i.LEFT)
	var right := _dirt_cells.has(cell + Vector2i.RIGHT)
	var up := _dirt_cells.has(cell + Vector2i.UP)
	var down := _dirt_cells.has(cell + Vector2i.DOWN)
	if not left and right:
		return _textures[_texture_key("grass_dirt_edge_lr", 0)]
	if left and not right:
		return _textures[_texture_key("grass_dirt_edge_lr", 2)]
	if not up and down:
		return _textures[_texture_key("grass_dirt_edge_lr", 1)]
	if up and not down:
		return _textures[_texture_key("grass_dirt_edge_lr", 3)]
	var dirt_id := "dirt_variant_a" if posmod(cell.x + cell.y * 3, 5) < 3 else "dirt_variant_b"
	return _textures[_texture_key(dirt_id, 0)]


func _wheat_texture_for(cell: Vector2i) -> Texture2D:
	var missing_left := not _wheat_cells.has(cell + Vector2i.LEFT)
	var missing_right := not _wheat_cells.has(cell + Vector2i.RIGHT)
	var missing_up := not _wheat_cells.has(cell + Vector2i.UP)
	var missing_down := not _wheat_cells.has(cell + Vector2i.DOWN)
	if missing_right and missing_down:
		return _textures[_texture_key("wheat_outer_corner", 0)]
	if missing_left and missing_down:
		return _textures[_texture_key("wheat_outer_corner", 1)]
	if missing_left and missing_up:
		return _textures[_texture_key("wheat_outer_corner", 2)]
	if missing_right and missing_up:
		return _textures[_texture_key("wheat_outer_corner", 3)]
	if missing_right:
		return _textures[_texture_key("wheat_edge_right", 0)]
	if missing_down:
		return _textures[_texture_key("wheat_edge_right", 1)]
	if missing_left:
		return _textures[_texture_key("wheat_edge_right", 2)]
	if missing_up:
		return _textures[_texture_key("wheat_edge_right", 3)]
	return _textures[_texture_key("wheat_interior", 0)]


func _texture_key(tile_id: String, turns: int) -> String:
	return "%s:%d" % [tile_id, posmod(turns, 4)]


func _rotate_image(source: Image, quarter_turns: int) -> Image:
	var result := source.duplicate()
	for _turn: int in posmod(quarter_turns, 4):
		var rotated := Image.create(result.get_height(), result.get_width(), false, Image.FORMAT_RGBA8)
		for y: int in result.get_height():
			for x: int in result.get_width():
				rotated.set_pixel(result.get_height() - 1 - y, x, result.get_pixel(x, y))
		result = rotated
	return result


func _shot() -> void:
	var output_path := ProbeOutput.path(OUTPUT_FILE)
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print("saved: ", output_path)
