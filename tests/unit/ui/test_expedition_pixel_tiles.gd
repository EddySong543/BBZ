extends GutTest

const EXPEDITION_SCENE_PATH := "res://src/expedition/expedition_screen.tscn"
const TERRAIN_SHADER_PATH := "res://assets/shaders/canvas_ui_expedition_terrain.gdshader"
const HeroDataScript := preload("res://src/battle/hero_data.gd")
const GROUND_PATHS: Array[String] = [
	"res://assets/tilesets/qingfeng_ricefield/grass_01.png",
	"res://assets/tilesets/qingfeng_ricefield/rice_01.png",
	"res://assets/tilesets/qingfeng_ricefield/dirt_path_01.png",
]
const OBJECT_PATHS: Array[String] = [
	"res://assets/tilesets/qingfeng_ricefield/field_boundary_01.png",
	"res://assets/tilesets/qingfeng_ricefield/search_supply_01.png",
]


func test_qingfeng_tile_assets_are_square_rgba_textures() -> void:
	for path: String in GROUND_PATHS + OBJECT_PATHS:
		var texture := load(path) as Texture2D
		assert_not_null(texture, "正式单格资产必须可读取：%s" % path)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		assert_eq(image.get_size(), Vector2i(128, 128), "正式单格资产必须为正方形：%s" % path)
		assert_ne(image.detect_alpha(), Image.ALPHA_NONE, "正式单格资产必须保留透明切角：%s" % path)


func test_ground_tiles_fill_the_cell_while_objects_keep_transparent_space() -> void:
	for path: String in GROUND_PATHS:
		var image: Image = (load(path) as Texture2D).get_image()
		assert_gt(_visible_ratio(image), 0.80, "Ground must fill most of its square: %s" % path)
	for path: String in OBJECT_PATHS:
		var image: Image = (load(path) as Texture2D).get_image()
		var ratio := _visible_ratio(image)
		assert_gt(ratio, 0.04, "Object layer cannot be empty: %s" % path)
		assert_lt(ratio, 0.45, "Object layer must not contain a baked ground tile: %s" % path)


func test_expedition_terrain_material_exposes_asset_overlay_contract() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var ground_art := screen.get_node("MapView/MapWorld/GroundArtLayer") as Control
	var object_art := screen.get_node("MapView/MapWorld/ObjectArtLayer") as Control
	var marker_art := screen.get_node("MapView/MapWorld/MarkerArtLayer") as Control
	var terrain := screen.get_node("MapView/MapWorld/TerrainLayer") as ColorRect
	var material := terrain.material as ShaderMaterial
	assert_not_null(ground_art)
	assert_not_null(object_art)
	assert_not_null(marker_art)
	assert_not_null(terrain)
	assert_not_null(material)
	assert_eq(ground_art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(object_art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(marker_art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(terrain.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_lt(ground_art.get_index(), terrain.get_index())
	assert_lt(terrain.get_index(), object_art.get_index())
	assert_lt(object_art.get_index(), marker_art.get_index())
	assert_eq(material.shader.resource_path, TERRAIN_SHADER_PATH)
	assert_eq(float(material.get_shader_parameter("tile_inset_px")), 4.0)
	assert_eq(float(material.get_shader_parameter("corner_cut_px")), 16.0)
	assert_eq(Vector2(material.get_shader_parameter("grid_size")), Vector2(18, 14))
	BattleSetup.reset()


func test_search_object_can_disappear_without_changing_its_ground() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.seed_value = 777
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var chest_cell: Vector2i = screen.map.chests.keys()[0]
	var ground_before: Texture2D = screen._ground_texture_for(chest_cell)
	assert_not_null(screen._object_texture_for(screen.map.grid[chest_cell.y][chest_cell.x]))
	screen.map.open_chest(chest_cell)
	var ground_after: Texture2D = screen._ground_texture_for(chest_cell)
	assert_eq(ground_after, ground_before)
	assert_null(screen._object_texture_for(screen.map.grid[chest_cell.y][chest_cell.x]))
	BattleSetup.reset()


func test_expedition_run_keeps_pixel_map_data_and_token_in_sync() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var terrain := screen.get_node("MapView/MapWorld/TerrainLayer") as ColorRect
	var material := terrain.material as ShaderMaterial
	assert_not_null(material.get_shader_parameter("map_data"))
	assert_not_null(screen.map)
	assert_gt(screen.map.revealed.size(), 0)
	assert_true(screen.player_token.visible)
	assert_eq(screen.player_token.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(screen.canvas.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	BattleSetup.reset()


func test_expedition_run_has_no_legacy_corner_hud() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var visible_copy: Array[String] = []
	_collect_visible_copy(screen, visible_copy)
	for legacy_text: String in [
			"―― 行军 ――",
			"―― 撤离窗 ――",
			"―― 队伍 ――",
			"―― 行囊手记 ――",
			"移动 WASD/方向键",
			"踏入迷雾",
	]:
		assert_false(
				_copy_contains(visible_copy, legacy_text),
				"进图后不应继续显示旧 HUD 文案：%s" % legacy_text)
	BattleSetup.reset()


func test_expedition_world_uses_nine_by_five_square_cell_view() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var map_view := screen.get_node("MapView") as Control
	var map_world := screen.get_node("MapView/MapWorld") as Control
	assert_true(map_view.clip_contents)
	assert_eq(map_view.position, Vector2(-12, 0))
	assert_eq(map_view.size, Vector2(1944, 1080))
	assert_eq(map_world.size, Vector2(3888, 3024))
	assert_eq(screen.canvas.get_parent(), map_world)
	assert_eq(screen.player_token.get_parent(), map_world)

	screen.map.player = Vector2i(6, 6)
	screen._refresh()
	assert_eq(map_world.position, Vector2(-432, -864))
	BattleSetup.reset()


func test_backpack_draw_canvas_stays_in_screen_space() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame
	screen._toggle_backpack(true)
	await get_tree().process_frame

	assert_true(screen.bp_overlay.visible)
	assert_eq(screen.bp_canvas.get_parent(), screen.bp_overlay)
	assert_eq(screen.bp_canvas.position, Vector2.ZERO)
	assert_eq(screen.bp_canvas.size, Vector2(1920, 1080))
	BattleSetup.reset()


func test_discovered_extraction_waits_for_active_interaction() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.seed_value = 777
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var exit_cell: Vector2i = screen.map.ext_pos.values()[0]
	screen.map.player = exit_cell
	screen.map.revealed[exit_cell] = true
	screen._refresh()
	assert_false(screen.dialog.visible, "发现撤离点本身不应自动弹窗")
	screen._try_interact_current_cell()
	await get_tree().process_frame
	assert_true(screen.dialog.visible, "玩家主动交互后才出现撤离确认")
	BattleSetup.reset()


func _collect_visible_copy(node: Node, result: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Label:
		result.append((node as Label).text)
	elif node is Button:
		result.append((node as Button).text)
	for child: Node in node.get_children():
		_collect_visible_copy(child, result)


func _copy_contains(lines: Array[String], needle: String) -> bool:
	for line: String in lines:
		if needle in line:
			return true
	return false


func _visible_ratio(image: Image) -> float:
	var visible: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a >= 0.0625:
				visible += 1
	return float(visible) / float(image.get_width() * image.get_height())
