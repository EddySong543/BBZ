extends GutTest

const EXPEDITION_SCENE_PATH := "res://src/expedition/expedition_screen.tscn"
const TERRAIN_SHADER_PATH := "res://assets/shaders/canvas_ui_expedition_terrain.gdshader"
const GROUND_CELL_SHADER_PATH := "res://assets/shaders/canvas_ui_expedition_ground_cell.gdshader"
const ATMOSPHERE_SHADER_PATH := "res://assets/shaders/canvas_ui_qingfeng_atmosphere.gdshader"
const VISION_SHADOW_SHADER_PATH := "res://assets/shaders/canvas_ui_pve_vision_shadow.gdshader"
const VISUAL_MAP_PATH := "res://src/expedition/maps/qingfeng_ricefield_visual_map.tscn"
const CHAFF_ATLAS_PATH := "res://assets/tilesets/qingfeng_ricefield/wind_chaff_01.png"
const HeroDataScript := preload("res://src/battle/hero_data.gd")
const MapStateScript := preload("res://src/expedition/expedition_map_state.gd")
const QingfengLayoutScript := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")
const BackpackGridViewScript := preload("res://src/ui/components/backpack_grid_view.gd")
const GRASS_TILE_PATH := "res://assets/tilesets/qingfeng_ricefield/grass_ref37_ref39_plain_v1.png"
const GRASS_PLAIN_TILE_PATH := "res://assets/tilesets/qingfeng_ricefield/grass_ref37_ref39_plain_v1.png"
const TELEPORT_TILE_PATH := "res://assets/tilesets/qingfeng_ricefield/qingfeng_teleport_v1.png"
const WHEAT_WAVE_TILE_PATH := "res://assets/tilesets/qingfeng_ricefield/wheat_wave_c_v1.png"
const GOLDEN_WAVE_TILE_PATH := "res://assets/tilesets/qingfeng_ricefield/golden_wave_ground_v1.png"
const STONE_TILE_PATH := "res://assets/tilesets/qingfeng_ricefield/candidates/stone_scheme1_v1.png"
const STONE_TILE_VARIANT_PATH := "res://assets/tilesets/qingfeng_ricefield/candidates/stone_scheme1_v2.png"
const WHEAT_TILE_PATH := "res://assets/tilesets/qingfeng_ricefield/candidates/wheat_scheme1_v2.png"
const WHEAT_OBJECT_PATH := "res://assets/tilesets/qingfeng_ricefield/rice_01.png"
const DIRT_TILE_PATH := "res://assets/tilesets/qingfeng_ricefield/dirt_ref37_ref39_plain_v1.png"
const WHEAT_WAVE_SPRITESHEET_PATH := "res://assets/tilesets/qingfeng_ricefield/wheat_wave/wheat_wave_spritesheet_v1.png"
const OVERLAY_PATHS: Array[String] = [
	"res://assets/tilesets/qingfeng_ricefield/overlays/overlay_flower_white_v1.png",
	"res://assets/tilesets/qingfeng_ricefield/overlays/overlay_flower_yellow_v1.png",
	"res://assets/tilesets/qingfeng_ricefield/overlays/overlay_flower_pink_v1.png",
	"res://assets/tilesets/qingfeng_ricefield/overlays/overlay_short_grass_v1.png",
	"res://assets/tilesets/qingfeng_ricefield/overlays/overlay_clover_v1.png",
]
const GROUND_DETAIL_PATHS: Array[String] = [
	"res://assets/tilesets/qingfeng_ricefield/overlays/overlay_stone_chips_pale_v1.png",
	"res://assets/tilesets/qingfeng_ricefield/overlays/overlay_straw_fragments_v1.png",
	"res://assets/tilesets/qingfeng_ricefield/overlays/overlay_green_leaves_v1.png",
	"res://assets/tilesets/qingfeng_ricefield/overlays/overlay_dirt_crack_v1.png",
]
const AUTHORED_TERRAIN_PATHS: Array[String] = [
	TELEPORT_TILE_PATH,
	WHEAT_WAVE_TILE_PATH,
	GOLDEN_WAVE_TILE_PATH,
]
const PLAIN_FOUNDATION_PATHS: Array[String] = [
	GRASS_TILE_PATH,
	DIRT_TILE_PATH,
]
const GROUND_PATHS: Array[String] = [
	GRASS_TILE_PATH,
	DIRT_TILE_PATH,
	GOLDEN_WAVE_TILE_PATH,
	TELEPORT_TILE_PATH,
]
const OBJECT_PATHS: Array[String] = OVERLAY_PATHS + GROUND_DETAIL_PATHS


func test_backpack_item_art_orientation_follows_rotated_shape() -> void:
	var view := BackpackGridViewScript.new()
	add_child_autofree(view)
	var horizontal_two: Array = [Vector2i(0, 0), Vector2i(1, 0)]
	var vertical_two: Array = [Vector2i(0, 0), Vector2i(0, 1)]
	var horizontal_three: Array = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	]
	var vertical_three: Array = [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2),
	]
	assert_eq(int(view.call("_shape_rotation_quarters", horizontal_two, horizontal_two)), 0)
	assert_eq(int(view.call("_shape_rotation_quarters", horizontal_two, vertical_two)), 1,
			"横向初始形状转为纵向时，美术同步顺时针旋转90度")
	assert_eq(int(view.call("_shape_rotation_quarters", vertical_two, horizontal_two)), 1,
			"竖向初始形状转为横向时，美术同步顺时针旋转90度")
	assert_eq(int(view.call("_shape_rotation_quarters", horizontal_three, vertical_three)), 1)
	var layout: Dictionary = view.call("_item_art_layout",
			Vector2(64.0, 32.0), Rect2(Vector2.ZERO, Vector2(48.0, 108.0)), 1)
	assert_eq(layout["oriented_size"], Vector2(48.0, 96.0),
			"64×32图案旋转后按32×64比例利用纵向占格")
	assert_eq(layout["draw_size"], Vector2(96.0, 48.0),
			"绘制前保留源图比例，由Canvas变换负责旋转")
	assert_eq(layout["center"], Vector2(24.0, 54.0), "美术围绕整件道具占格中心旋转")


func test_qingfeng_tile_assets_are_square_textures_and_overlays_keep_alpha() -> void:
	for path: String in GROUND_PATHS:
		var texture := load(path) as Texture2D
		assert_not_null(texture, "正式地表资产必须可读取：%s" % path)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		assert_eq(image.get_size(), Vector2i(60, 60),
				"120px运行格使用60px原生像素地表并由Nearest精确放大两倍：%s" % path)
	for path: String in OBJECT_PATHS:
		var texture := load(path) as Texture2D
		assert_not_null(texture, "正式单格资产必须可读取：%s" % path)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		assert_eq(image.get_width(), image.get_height(), "正式单格资产必须为正方形：%s" % path)
	for path: String in AUTHORED_TERRAIN_PATHS + OBJECT_PATHS:
		var image: Image = (load(path) as Texture2D).get_image()
		assert_ne(image.detect_alpha(), Image.ALPHA_NONE, "带像素轮廓的单格资产必须保留透明角：%s" % path)
	for path: String in PLAIN_FOUNDATION_PATHS:
		var image: Image = (load(path) as Texture2D).get_image()
		assert_eq(image.detect_alpha(), Image.ALPHA_NONE,
				"纯地表源图保持完整方形，圆角统一由运行时格体材质提供：%s" % path)


func test_qingfeng_visual_map_is_editable_as_layered_tilemaps() -> void:
	var packed := load(VISUAL_MAP_PATH) as PackedScene
	assert_not_null(packed, "晴风稻田必须提供可在Godot 2D面板直接刷格的地图场景")
	if packed == null:
		return
	var visual_map := packed.instantiate()
	add_child_autofree(visual_map)
	var expected_layers: Array[String] = [
		"Ground", "GroundDetail", "LowDecoration",
		"BlockingObjects", "Containers", "MarkerGuides",
	]
	for layer_name: String in expected_layers:
		assert_true(visual_map.has_node(layer_name), "缺少可视化地图层：%s" % layer_name)
		assert_true(visual_map.get_node(layer_name) is TileMapLayer)
	var ground := visual_map.get_node("Ground") as TileMapLayer
	assert_eq(ground.get_used_cells().size(), QingfengLayoutScript.WIDTH * QingfengLayoutScript.HEIGHT,
			"Ground必须覆盖完整32x18地图，不能依赖字符表补漏")
	for cell: Vector2i in ground.get_used_cells():
		var tile_data := ground.get_cell_tile_data(cell)
		assert_not_null(tile_data)
		assert_true(String(tile_data.get_custom_data("asset_id")) != "")
		assert_true(int(tile_data.get_custom_data("ground_type")) in [0, 1, 2])
	assert_eq(ground.scale, Vector2(2.0, 2.0),
			"60px原生图块必须在地图场景中Nearest精确放大两倍")
	assert_eq(ground.tile_set.get_source_count(), 13,
			"TileSet只保留4种在用地表和9种已通过可手刷叠层")
	for layer_name: String in expected_layers.slice(1):
		assert_true((visual_map.get_node(layer_name) as TileMapLayer).get_used_cells().is_empty(),
				"当前地图只允许Ground有内容：%s" % layer_name)
	for source_id: int in range(4, 13):
		var source := ground.tile_set.get_source(source_id) as TileSetAtlasSource
		assert_not_null(source)
		if source == null:
			continue
		var tile_data := source.get_tile_data(Vector2i.ZERO, 0)
		assert_true(String(tile_data.get_custom_data("asset_id")).begins_with("overlay_"))
		assert_eq(int(tile_data.get_custom_data("ground_type")), -1)


func test_qingfeng_plant_overlays_are_native_transparent_pixel_sprites() -> void:
	for path: String in OVERLAY_PATHS:
		var texture := load(path) as Texture2D
		assert_not_null(texture, "正式叠层资产必须可读取：%s" % path)
		if texture == null:
			continue
		var image := texture.get_image()
		assert_eq(image.get_size(), Vector2i(60, 60))
		assert_eq(image.get_pixel(0, 0).a, 0.0)
		assert_eq(image.get_pixel(59, 59).a, 0.0)
		var visible_pixels := 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var alpha := image.get_pixel(x, y).a
				assert_true(is_equal_approx(alpha, 0.0) or is_equal_approx(alpha, 1.0),
						"叠层透明边必须为硬像素，不能残留半透明毛边：%s" % path)
				if alpha > 0.99:
					visible_pixels += 1
		assert_between(visible_pixels, 20, 360,
				"叠层应当是单个小型主体，不能为空也不能填满格子：%s" % path)


func test_rebuilt_flowers_are_exact_five_block_crosses() -> void:
	for path: String in OVERLAY_PATHS.slice(0, 3):
		var image: Image = (load(path) as Texture2D).get_image()
		var visible_pixels: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.99:
					visible_pixels += 1
		assert_eq(visible_pixels, 5 * 2 * 2,
				"Each flower must be exactly four petals plus one centre block: %s" % path)
		assert_eq(_alpha_bounds(image).size, Vector2i(6, 6),
				"A repeatable flower must stay much smaller than one terrain cell: %s" % path)


func test_ground_detail_overlays_are_transparent_60px_pixel_assets() -> void:
	for path: String in GROUND_DETAIL_PATHS:
		var image: Image = (load(path) as Texture2D).get_image()
		assert_eq(image.get_size(), Vector2i(60, 60))
		assert_eq(image.get_pixel(0, 0).a, 0.0)
		assert_eq(image.get_pixel(59, 59).a, 0.0)
		for y: int in image.get_height():
			for x: int in image.get_width():
				var alpha: float = image.get_pixel(x, y).a
				assert_true(is_equal_approx(alpha, 0.0) or is_equal_approx(alpha, 1.0),
						"Ground details must keep binary hard-pixel alpha: %s" % path)


func test_rebuilt_clover_and_ground_details_keep_an_exact_two_pixel_grid() -> void:
	var revised_paths: Array[String] = OBJECT_PATHS.duplicate()
	for path: String in revised_paths:
		var image: Image = (load(path) as Texture2D).get_image()
		for y: int in range(0, image.get_height(), 2):
			for x: int in range(0, image.get_width(), 2):
				var expected: Color = image.get_pixel(x, y)
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var compared: Color = image.get_pixelv(Vector2i(x, y) + offset)
					assert_eq(compared.a, expected.a,
							"Rebuilt overlays must stay on the 2px logical grid: %s" % path)
					if expected.a > 0.99:
						assert_eq(compared, expected,
								"Visible logical pixels must keep one flat color: %s" % path)


func test_rebuilt_clover_has_three_full_leaf_mass_and_limited_palette() -> void:
	var image: Image = (load(OVERLAY_PATHS[4]) as Texture2D).get_image()
	var bounds: Rect2i = _alpha_bounds(image)
	assert_between(bounds.size.x, 18, 22)
	assert_between(bounds.size.y, 18, 22)
	var colors: Dictionary = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.99:
				colors[color.to_html(false)] = true
	assert_between(colors.size(), 3, 4,
			"Clover needs readable flat leaf planes without noisy micro-colors")


func test_repeatable_overlays_leave_room_for_multiple_objects_on_one_cell() -> void:
	for path: String in OBJECT_PATHS:
		if path == GROUND_DETAIL_PATHS[3]:
			continue # The approved dirt crack keeps its existing long branching footprint.
		var bounds: Rect2i = _alpha_bounds((load(path) as Texture2D).get_image())
		assert_lte(bounds.size.x, 24, "Overlay is still too wide for repeated placement: %s" % path)
		assert_lte(bounds.size.y, 24, "Overlay is still too tall for repeated placement: %s" % path)


func test_adjusted_leaves_keep_requested_green_palette() -> void:
	var leaves: Image = (load(GROUND_DETAIL_PATHS[2]) as Texture2D).get_image()
	for y: int in leaves.get_height():
		for x: int in leaves.get_width():
			var color: Color = leaves.get_pixel(x, y)
			if color.a > 0.99:
				assert_gt(color.g, color.r, "Leaf overlay must stay green")
				assert_gt(color.g, color.b, "Leaf overlay must stay green")


func test_wheat_wave_spritesheet_and_runtime_frames_keep_full_tile_dimensions() -> void:
	var sheet := load(WHEAT_WAVE_SPRITESHEET_PATH) as Texture2D
	assert_not_null(sheet)
	if sheet != null:
		assert_eq(sheet.get_size(), Vector2(360, 60))
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq(screen._wheat_wave_runtime_frames.size(), 6)
	for frame: Texture2D in screen._wheat_wave_runtime_frames:
		assert_eq(frame.get_size(), Vector2(60, 60))
	assert_false(screen.has_method("_draw_wheat_wave_pulse"),
			"Wheat motion must replace the full tile frame, not add rectangle strips")


func test_authored_terrain_tiles_keep_transparent_pixel_cut_edges() -> void:
	for path: String in AUTHORED_TERRAIN_PATHS:
		var image: Image = (load(path) as Texture2D).get_image()
		assert_between(_visible_ratio(image), 0.97, 0.995,
				"新版正式格只保留圆角切口，主体必须几乎填满单格以大幅收紧间隙：%s" % path)
		var exact_two_x := true
		for y: int in range(0, image.get_height(), 2):
			for x: int in range(0, image.get_width(), 2):
				var pixel := image.get_pixel(x, y)
				for dy: int in 2:
					for dx: int in 2:
						var compared := image.get_pixel(x + dx, y + dy)
						var compared_visible := compared.a > 0.99
						var pixel_visible := pixel.a > 0.99
						if compared_visible != pixel_visible:
							exact_two_x = false
						elif pixel_visible and compared != pixel:
							exact_two_x = false
		assert_true(exact_two_x,
				"正式格必须由30x30逻辑像素最近邻精确放大，不得存在伪像素或平滑边：%s" % path)
		for corner: Vector2i in [
				Vector2i.ZERO,
				Vector2i(image.get_width() - 1, 0),
				Vector2i(0, image.get_height() - 1),
				Vector2i(image.get_width() - 1, image.get_height() - 1),
		]:
			assert_lt(image.get_pixelv(corner).a, 0.01,
					"正式格的像素轮廓必须在四角保留透明切口：%s" % path)
	for path: String in OBJECT_PATHS:
		var image: Image = (load(path) as Texture2D).get_image()
		var ratio := _visible_ratio(image)
		assert_gt(ratio, 0.004, "Object layer cannot be empty: %s" % path)
		assert_lt(ratio, 0.90, "Object layer must retain a readable cut edge: %s" % path)


func test_expedition_runtime_keeps_fog_overlay_disabled() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var ground_art := screen.get_node("MapView/MapWorld/GroundArtLayer") as Control
	var foliage_art := screen.get_node("MapView/MapWorld/RiceFoliageLayer") as Control
	var object_art := screen.get_node("MapView/MapWorld/ObjectArtLayer") as Control
	var marker_art := screen.get_node("MapView/MapWorld/MarkerArtLayer") as Control
	var terrain := screen.get_node("MapView/MapWorld/TerrainLayer") as ColorRect
	var material := terrain.material as ShaderMaterial
	assert_not_null(ground_art)
	assert_not_null(foliage_art)
	assert_not_null(object_art)
	assert_not_null(marker_art)
	assert_not_null(terrain)
	assert_not_null(material)
	assert_eq(ground_art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(foliage_art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(object_art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(marker_art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(terrain.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_lt(ground_art.get_index(), foliage_art.get_index())
	assert_lt(foliage_art.get_index(), object_art.get_index())
	assert_lt(object_art.get_index(), terrain.get_index())
	assert_lt(object_art.get_index(), marker_art.get_index())
	assert_eq(material.shader.resource_path, TERRAIN_SHADER_PATH)
	assert_false(screen.FOG_OF_WAR_ENABLED,
			"正式远征不再启用战争迷雾")
	assert_false(terrain.visible,
			"保留的兼容层不得再覆盖地图画面")
	BattleSetup.reset()


func test_environment_art_keeps_authored_pixels_without_coarse_mosaic_sampling() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var ground_art := screen.get_node("MapView/MapWorld/GroundArtLayer") as Control
	var foliage_art := screen.get_node("MapView/MapWorld/RiceFoliageLayer") as Control
	var object_art := screen.get_node("MapView/MapWorld/ObjectArtLayer") as Control
	var marker_art := screen.get_node("MapView/MapWorld/MarkerArtLayer") as Control
	var player_token := screen.get_node("MapView/MapWorld/PlayerToken") as TextureRect
	assert_not_null(ground_art.material,
			"地表只允许统一格体轮廓材质；该材质不得重采样或改写纹理内部")
	assert_eq((ground_art.material as ShaderMaterial).shader.resource_path, GROUND_CELL_SHADER_PATH)
	for layer: Control in [foliage_art, object_art]:
		assert_null(layer.material, "卡块与独立物件必须直接使用设计好的粗像素形状，不能再做马赛克重采样")
	assert_null(marker_art.material, "交互标识不应被环境粗像素材质模糊")
	assert_null(player_token.material, "角色 idle 帧必须保留原始战斗人物像素密度")
	BattleSetup.reset()


func test_player_token_has_no_four_corner_cell_marker_and_uses_pixel_foot_shadow() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var map_world := screen.get_node("MapView/MapWorld") as Control
	var backdrop := map_world.get_node("PlayerBackdrop") as Control
	var token := map_world.get_node("PlayerToken") as TextureRect
	var canvas := map_world.get_node("DrawCanvas") as Control
	assert_not_null(backdrop, "兼容锚点节点必须保留，避免改变镜头格心计算")
	if backdrop != null:
		assert_eq(backdrop.size, Vector2(120, 120))
		assert_lt(canvas.get_index(), backdrop.get_index())
		assert_lt(backdrop.get_index(), token.get_index())
	assert_false(screen.has_method("_draw_tile_contact_shadow"),
			"通用脚底阴影容易和正方形2D叠加资产冲突，应移除旧接口")
	assert_true(screen.has_method("_tile_uses_contact_shadow"))
	assert_false(screen.has_method("_draw_pixel_corner_frame"),
			"人物所在格不再使用四角强调")
	assert_true(screen.has_method("_player_shadow_width_at_lift"))
	var expedition_source: String = FileAccess.get_file_as_string(
			"res://src/expedition/expedition_screen.gd")
	assert_true("player_backdrop.draw_circle" in expedition_source,
			"人物脚影必须使用单一椭圆轮廓")
	assert_lt(screen._player_shadow_width_at_lift(1.0),
			screen._player_shadow_width_at_lift(0.0),
			"人物抬脚时脚影必须同步收窄，不能像硬矩形一样粘着移动")
	assert_eq(screen._player_shadow_width_at_lift(0.0), screen.PLAYER_SHADOW_BASE_WIDTH)
	if screen.has_method("_tile_uses_contact_shadow"):
		assert_false(screen._tile_uses_contact_shadow(MapStateScript.Tile.CHEST),
				"搜索目标不再绘制额外接触影")

	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame
	screen.map.player = Vector2i(9, 7)
	screen._camera_initialized = false
	screen._update_map_camera()
	assert_true(token.visible)
	if backdrop != null:
		assert_true(backdrop.visible, "人物出现时脚底影必须同步出现")
	assert_eq(token.position, screen._token_origin_for_cell(Vector2i(9, 7)))
	if backdrop != null:
		assert_eq(backdrop.position, Vector2(9, 7) * 120.0)
	BattleSetup.reset()


func test_player_token_uses_selected_hero_idle_frames_instead_of_portrait() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var hero: HeroData = HeroDataScript.create_launch_pool()[2]
	screen._on_hero_selected(hero)
	await get_tree().process_frame

	assert_eq(screen.hero_idle_frames_path, hero.sprite_frames_path)
	assert_ne(screen.player_token.texture.resource_path, hero.portrait_path,
			"地图人物不能继续使用 portrait 贴图")
	var frames := load(hero.sprite_frames_path) as SpriteFrames
	assert_not_null(frames)
	assert_true(screen.player_token.texture is ImageTexture)
	assert_eq(screen.player_token.texture.get_size(), Vector2(208, 208),
			"idle token 必须进入允许越格且不裁武器的208px脚部锚定画布")
	assert_eq(screen.player_token.pivot_offset, screen.TOKEN_FOOT_ANCHOR,
			"缩放、转身和跳步必须围绕真正脚部锚点")
	var later_index: int = screen._token_idle_frame_index_at(0.2)
	assert_gt(later_index, 0, "idle token 必须逐帧播放，不能只截第一帧")
	screen._update_token_idle_frame(0.2)
	assert_eq(screen.player_token.texture, screen._hero_idle_token_frames[later_index])
	BattleSetup.reset()


func test_all_hero_idle_tokens_reuse_h01_double_foot_coordinates_and_scale() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var reference_left: Vector2 = screen._token_canvas_point_for_source(
			screen.H01_SOURCE_LEFT_FOOT)
	var reference_right: Vector2 = screen._token_canvas_point_for_source(
			screen.H01_SOURCE_RIGHT_FOOT)
	assert_almost_eq((reference_left.x + reference_right.x) * 0.5,
			screen.TOKEN_FOOT_ANCHOR.x, 0.01)
	assert_almost_eq(reference_left.y, reference_right.y, 0.01)
	assert_almost_eq(reference_right.x - reference_left.x,
			(screen.H01_SOURCE_RIGHT_FOOT.x - screen.H01_SOURCE_LEFT_FOOT.x)
			* screen.TOKEN_CONTENT_SCALE, 0.01)
	assert_false(screen.has_method("_token_content_scale_for_current_art"),
			"不得再按英雄轮廓或特殊名单改变人物缩放")
	for hero: HeroData in HeroDataScript.create_launch_pool():
		var source_frames := load(hero.sprite_frames_path) as SpriteFrames
		assert_not_null(source_frames)
		for frame_index: int in source_frames.get_frame_count(&"idle"):
			var source_image: Image = source_frames.get_frame_texture(
					&"idle", frame_index).get_image()
			assert_eq(source_image.get_size(), Vector2i(256, 256),
					"全部英雄必须沿用h01的256px公共坐标系：%s" % hero.hero_id)
			assert_true(_rect_has_alpha(source_image, Rect2i(110, 176, 14, 6)),
					"左脚没有落在h01公共区域：%s frame %d" % [hero.hero_id, frame_index])
			assert_true(_rect_has_alpha(source_image, Rect2i(132, 176, 16, 6)),
					"右脚没有落在h01公共区域：%s frame %d" % [hero.hero_id, frame_index])
		screen.hero_idle_frames_path = hero.sprite_frames_path
		screen._apply_token_idle_art()
		assert_false(screen._hero_idle_token_frames.is_empty(),
				"每名英雄都必须生成h01基准idle token：%s" % hero.hero_id)
		for texture: Texture2D in screen._hero_idle_token_frames:
			assert_eq(texture.get_size(), Vector2(208, 208))
			var token_bounds: Rect2i = _alpha_bounds(texture.get_image())
			assert_gt(token_bounds.position.x, 0, "左侧资产被token画布裁切：%s" % hero.hero_id)
			assert_gt(token_bounds.position.y, 0, "顶部资产被token画布裁切：%s" % hero.hero_id)
			assert_lt(token_bounds.end.x, 208, "右侧资产被token画布裁切：%s" % hero.hero_id)
			assert_lt(token_bounds.end.y, 208, "底部资产被token画布裁切：%s" % hero.hero_id)
		assert_eq(screen._token_canvas_point_for_source(screen.H01_SOURCE_LEFT_FOOT),
				reference_left, "左脚坐标偏离h01：%s" % hero.hero_id)
		assert_eq(screen._token_canvas_point_for_source(screen.H01_SOURCE_RIGHT_FOOT),
				reference_right, "右脚坐标偏离h01：%s" % hero.hero_id)
	BattleSetup.reset()


func test_only_approved_ground_assets_are_connected_to_the_scene() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var grass_paths: Dictionary = {}
	var dirt_paths: Dictionary = {}
	var rice_paths: Dictionary = {}
	for y: int in QingfengLayoutScript.HEIGHT:
		for x: int in QingfengLayoutScript.WIDTH:
			var cell := Vector2i(x, y)
			if cell == QingfengLayoutScript.START:
				continue
			var path: String = screen._ground_texture_for(cell).resource_path
			match QingfengLayoutScript.ground_terrain_at(cell):
				QingfengLayoutScript.GroundTerrain.GRASS:
					grass_paths[path] = true
				QingfengLayoutScript.GroundTerrain.DIRT:
					dirt_paths[path] = true
				QingfengLayoutScript.GroundTerrain.RICE:
					rice_paths[path] = true
	assert_eq(grass_paths.keys(), [GRASS_TILE_PATH], "基础草地只能使用无草簇纯草地")
	assert_eq(dirt_paths.keys(), [DIRT_TILE_PATH], "基础泥土只能使用无裂纹纯泥土")
	assert_eq(rice_paths.keys(), [GOLDEN_WAVE_TILE_PATH], "无麦穗金色波浪格承接所有稻田语义格")
	assert_eq(screen._ground_texture_for(QingfengLayoutScript.START).resource_path, TELEPORT_TILE_PATH)
	assert_null(screen._terrain_object_texture_for(Vector2i(0, 0)),
			"未通过的石块资产不得继续接入场景")
	assert_null(screen._terrain_object_texture_for(Vector2i(1, 12)),
			"未通过的麦穗资产不得继续接入场景")
	assert_null(screen._object_texture_for(MapStateScript.Tile.CHEST),
			"未通过的宝箱资产不得继续接入场景")
	assert_null(screen.field_chaff, "未通过的稻壳粒子资产不得继续接入场景")
	BattleSetup.reset()


func test_ground_only_map_returns_no_blocking_terrain_art() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	for y: int in QingfengLayoutScript.HEIGHT:
		for x: int in QingfengLayoutScript.WIDTH:
			var cell := Vector2i(x, y)
			assert_false(screen._layout_is_wall(cell))
			assert_null(screen._terrain_object_texture_for(cell))
	BattleSetup.reset()


func test_ref39_grid_uses_small_gap_and_pixel_rounded_cells() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.GROUND_CELL_GAP, 0.0,
			"60px正式资产必须精确放大2倍，禁止缩到118px产生非整数采样")
	assert_eq(screen.GROUND_GAP_COLOR, Color("203a33"))
	assert_eq(screen.GROUND_BORDER_PX, 2.0,
			"方案A以2px世界描边保留圆角格可读性，同时降低表格感")
	assert_eq(screen.GROUND_MASK_INSET_PX, 1.0,
			"复用早期通过稿的克制内缩，资产仍保持120px整数2倍采样")
	assert_eq(screen.GROUND_CORNER_RADIUS_PX, 16.0)
	assert_eq(screen.GROUND_PIXEL_STEP_PX, 4.0,
			"圆角弧必须在4px粗像素网格上连续转向")
	assert_eq(screen.GROUND_BORDER_COLOR, Color("3b5233"))
	assert_eq((screen.ground_cell_mat.shader as Shader).resource_path, GROUND_CELL_SHADER_PATH)
	assert_eq(float(screen.ground_cell_mat.get_shader_parameter("cell_inset_px")), 1.0)
	assert_eq(float(screen.ground_cell_mat.get_shader_parameter("corner_radius_px")), 16.0)
	assert_eq(float(screen.ground_cell_mat.get_shader_parameter("pixel_step_px")), 4.0)
	assert_eq(float(screen.ground_cell_mat.get_shader_parameter("border_px")), 2.0)
	assert_eq(Color(screen.ground_cell_mat.get_shader_parameter("gap_color")), Color("203a33"))
	assert_eq(Color(screen.ground_cell_mat.get_shader_parameter("border_color")), Color("3b5233"))
	var ground_shader_source := FileAccess.get_file_as_string(GROUND_CELL_SHADER_PATH)
	assert_true(ground_shader_source.contains("vec2 raw_edge = min(p, size - p);"),
			"圆角必须从最近边缘向内量化，不能再把4px余数挤到右上与左下")
	assert_true(ground_shader_source.contains("corner_radius_px - border_px"),
			"内外圆角必须同心，避免四角描边厚薄不同")
	for y: int in QingfengLayoutScript.HEIGHT:
		for x: int in QingfengLayoutScript.WIDTH:
			assert_eq(screen._ground_cell_rect(Vector2i(x, y)).size, Vector2(120, 120),
					"所有地表类型必须使用同一运行时裁切尺寸")
	assert_eq(screen._ground_source_rect_for(null), Rect2())
	assert_eq(screen._ground_source_rect_for(screen._ground_texture_for(Vector2i(5, 14))),
			Rect2(0.0, 0.0, 60.0, 60.0))
	assert_false(screen.has_method("_ground_has_shared_seam"),
			"独立圆角格不再叠画共享直边")
	assert_false(screen.has_method("_ground_has_material_boundary"),
			"旧的材质簇锯齿边界必须移除")
	BattleSetup.reset()


func test_plain_grass_asset_keeps_true_pixel_contract_without_corner_tufts() -> void:
	var texture := load(GRASS_PLAIN_TILE_PATH) as Texture2D
	assert_not_null(texture)
	assert_eq(texture.get_size(), Vector2(60.0, 60.0))
	var image := texture.get_image()
	assert_not_null(image)
	assert_gt(image.get_pixel(0, 0).a, 0.99,
			"新草地PNG必须保持完整方形；圆角只能由统一运行时格体提供")
	assert_eq(_visible_ratio(image), 1.0)
	assert_gt(image.get_pixel(30, 30).a, 0.99)


func test_teleport_gold_breath_becomes_steady_when_player_is_on_the_cell() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	var low: float = screen._teleport_glow_strength_at(-PI * 0.5 / screen.TELEPORT_BREATH_SPEED, false)
	var high: float = screen._teleport_glow_strength_at(PI * 0.5 / screen.TELEPORT_BREATH_SPEED, false)
	assert_almost_eq(low, 0.24, 0.001)
	assert_almost_eq(high, 0.62, 0.001)
	for time_seconds: float in [0.0, 0.5, 1.0, 3.0]:
		assert_almost_eq(screen._teleport_glow_strength_at(time_seconds, true), 1.0, 0.001,
				"角色站在传送点时必须持续满亮，不再呼吸变暗")
	var world := screen.get_node("MapView/MapWorld") as Control
	var token := world.get_node("PlayerToken") as TextureRect
	var occupied_fx := world.get_node("TeleportOccupiedFxLayer") as Control
	assert_gt(occupied_fx.get_index(), token.get_index(),
			"兼容节点保留原场景顺序")
	assert_false(occupied_fx.visible, "角色站在传送格时不再显示四角巡游闪烁")
	assert_false(screen.has_method("_teleport_active_corner_at"))
	assert_false(screen.has_method("_draw_teleport_corner_beacon"))
	BattleSetup.reset()


func test_wheat_response_only_propagates_through_connected_rice_cells() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen._wheat_wave_cells_from(Vector2i(0, 12)), [])
	var cells: Array = screen._wheat_wave_cells_from(Vector2i(1, 11))
	assert_true(cells.any(func(entry: Dictionary) -> bool:
		return Vector2i(entry["cell"]) == Vector2i(1, 11) and int(entry["distance"]) == 0))
	assert_true(cells.any(func(entry: Dictionary) -> bool:
		return Vector2i(entry["cell"]) == Vector2i(2, 11) and int(entry["distance"]) == 1))
	assert_true(cells.any(func(entry: Dictionary) -> bool:
		return Vector2i(entry["cell"]) == Vector2i(3, 11) and int(entry["distance"]) == 2))
	assert_true(cells.any(func(entry: Dictionary) -> bool:
		return int(entry["distance"]) == screen.WHEAT_WAVE_RADIUS),
			"增强后的麦浪必须能明显传播到第三圈相连稻田")
	for entry: Dictionary in cells:
		assert_lte(int(entry["distance"]), screen.WHEAT_WAVE_RADIUS)
		assert_eq(screen._ground_terrain_at(Vector2i(entry["cell"])),
				QingfengLayoutScript.GroundTerrain.RICE)
	BattleSetup.reset()


func test_successful_step_into_rice_starts_a_short_directional_wave() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_gte(screen.WHEAT_WAVE_DURATION, 0.7)
	assert_gte(screen.WHEAT_WAVE_MAX_SHIFT_STEPS * screen.WHEAT_WAVE_SOURCE_PIXEL_STEP * 2, 12,
			"麦浪最大弯折至少12px，否则在实机雾层下不可读")
	screen._trigger_wheat_wave(Vector2i(1, 12), Vector2i(1, 11), Vector2i.UP)
	assert_gt(screen._wheat_wave_pulses.size(), 0)
	for pulse: Dictionary in screen._wheat_wave_pulses:
		assert_eq(Vector2i(pulse["direction"]), Vector2i.UP)
		assert_almost_eq(float(pulse["start_time"]),
				screen._anim_time + int(pulse["distance"]) * screen.WHEAT_WAVE_RING_DELAY, 0.001)
	screen._anim_time += screen.WHEAT_WAVE_DURATION \
			+ screen.WHEAT_WAVE_RING_DELAY * screen.WHEAT_WAVE_RADIUS + 0.01
	screen._prune_wheat_wave_pulses()
	assert_eq(screen._wheat_wave_pulses.size(), 0)
	BattleSetup.reset()


func test_approved_ground_tiles_keep_authored_colors_without_runtime_tint() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen._ground_texture_for(Vector2i(5, 14)).resource_path, GRASS_TILE_PATH)
	assert_eq(screen._ground_modulate_for(Vector2i(5, 14)), Color.WHITE,
			"通过稿的颜色不得在接入时再次乘色")
	for y: int in QingfengLayoutScript.HEIGHT:
		for x: int in QingfengLayoutScript.WIDTH:
			var cell := Vector2i(x, y)
			var texture_path: String = screen._ground_texture_for(cell).resource_path
			match QingfengLayoutScript.ground_terrain_at(cell):
				QingfengLayoutScript.GroundTerrain.GRASS:
					assert_eq(texture_path, GRASS_TILE_PATH)
				QingfengLayoutScript.GroundTerrain.DIRT:
					if cell != QingfengLayoutScript.START:
						assert_eq(texture_path, DIRT_TILE_PATH)
				_:
					pass
	assert_false(screen.has_method("_draw_grass_region_field"),
			"运行时不能再用30px程序色块代替地表图片")
	assert_false(screen.has_method("_draw_ground_card_motif"),
			"运行时不能再用程序草叶代替生图资产中的像素纹理")

	assert_eq(screen._ground_texture_for(Vector2i(1, 12)).resource_path, GOLDEN_WAVE_TILE_PATH)
	assert_eq(screen._ground_texture_for(QingfengLayoutScript.START).resource_path, TELEPORT_TILE_PATH)
	BattleSetup.reset()


func test_search_object_can_disappear_without_changing_its_ground() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.seed_value = 777
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var chest_cell := Vector2i(3, 15)
	screen.map.grid[chest_cell.y][chest_cell.x] = MapStateScript.Tile.CHEST
	screen.map.chests[chest_cell] = {"revealed_by_map": false, "egg": false}
	var ground_before: int = screen._ground_palette_index(chest_cell)
	assert_null(screen._object_texture_for(screen.map.grid[chest_cell.y][chest_cell.x]))
	screen.map.open_chest(chest_cell)
	var ground_after: int = screen._ground_palette_index(chest_cell)
	assert_eq(ground_after, ground_before)
	assert_null(screen._object_texture_for(screen.map.grid[chest_cell.y][chest_cell.x]))
	BattleSetup.reset()


func test_search_container_reveals_one_item_before_transferring_to_pickup_area() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.seed_value = 777
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var chest_cell := Vector2i(3, 15)
	screen.map.grid[chest_cell.y][chest_cell.x] = MapStateScript.Tile.CHEST
	screen.map.chests[chest_cell] = {"revealed_by_map": false, "egg": false}
	screen.map.player = chest_cell
	screen.map._reveal_around(chest_cell)
	var safety: int = 8
	while safety > 0:
		screen._try_interact_current_cell()
		var snapshot: Dictionary = screen.search_state.open_snapshot()
		if not (snapshot.get("visible_items", []) as Array).is_empty():
			break
		safety -= 1
	assert_gt(safety, 0, "单件搜索必须在其占格回合内揭示")
	assert_eq(screen.pending.size(), 0, "揭示与取出必须分开，不能继续沿用一次开箱全进拾取区")
	screen._try_interact_current_cell()
	assert_eq(screen.pending.size(), 1)
	assert_true(screen.search_state.has_container(screen._container_id_for_cell(chest_cell)))
	BattleSetup.reset()


func test_expedition_run_keeps_exploration_history_without_rendering_fog() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var terrain := screen.get_node("MapView/MapWorld/TerrainLayer") as ColorRect
	var material := terrain.material as ShaderMaterial
	assert_not_null(material.get_shader_parameter("map_data"))
	assert_false(terrain.visible)
	assert_not_null(screen.map)
	assert_gt(screen.map.revealed.size(), 0)
	assert_true(screen.player_token.visible)
	assert_true(screen.player_backdrop.visible,
			"人物所在格不绘制四角强调，但必须显示独立脚底接触影")
	assert_eq(screen.player_token.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(screen.canvas.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var start_cell: Vector2i = screen.map.player
	var revealed_before: Dictionary = screen.map.revealed.duplicate()
	var move_result: Dictionary = screen.map.try_move(Vector2i.UP)
	assert_true(bool(move_result.get("moved", false)))
	screen._refresh()
	assert_gt(screen.map.revealed.size(), revealed_before.size())
	assert_true(screen.map.revealed.has(start_cell), "离开后仍须保留探索历史")
	assert_true(screen._is_cell_visible(start_cell))
	assert_true(screen._is_cell_visible(screen.map.player))
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


func test_expedition_world_defaults_to_complete_twenty_three_by_thirteen_grid() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var map_view := screen.get_node("MapView") as Control
	var map_world := screen.get_node("MapView/MapWorld") as Control
	assert_true(map_view.clip_contents)
	assert_eq(map_view.position, Vector2.ZERO,
			"PVE地图必须从屏幕左上角开始，不得露出绿色或黑色外框")
	assert_lte(map_view.size.distance_to(Vector2(1920, 1080)), 0.001,
			"PVE地图必须完整铺满设计分辨率")
	assert_eq(map_world.size, Vector2(3840, 2160))
	assert_lte(map_world.scale.distance_to(Vector2(16.0 / 23.0, 9.0 / 13.0)), 0.0001)
	var rendered_cell_size: Vector2 = Vector2.ONE * float(screen.MAP_CELL) \
			* map_world.scale
	assert_lte((screen.MAP_VIEW_SIZE / rendered_cell_size)
			.distance_to(Vector2(23, 13)), 0.001,
			"上下左右必须都严格结束在完整方格边界")
	assert_eq(screen.MAP_VIEW_COLS, MainMenuWorld.VISIBLE_COLS,
			"主界面与远征界面必须显示相同列数")
	assert_eq(screen.MAP_VIEW_ROWS, MainMenuWorld.VISIBLE_ROWS,
			"主界面与远征界面必须显示相同行数")
	assert_eq(screen.MAP_VIEW_COLS % 2, 1)
	assert_eq(screen.MAP_VIEW_ROWS % 2, 1,
			"奇数行列保证视窗正中心始终是完整的中心3×3")
	assert_almost_eq(screen.player_token.size.x, 208.0, 0.01)
	assert_almost_eq(screen.player_token.size.y, 208.0, 0.01)
	var token_screen_size: Vector2 = (
			screen.player_token.size * screen.player_token.scale * map_world.scale)
	assert_lte(token_screen_size.distance_to(
			Vector2.ONE * 208.0 * 9.0 / 13.0), 0.01)
	assert_almost_eq(token_screen_size.x, token_screen_size.y, 0.001,
			"横纵独立地图缩放不得压扁人物")
	assert_gt(token_screen_size.x, rendered_cell_size.x,
			"人物画布必须允许武器、头发等越出格体")
	assert_gt(token_screen_size.y, rendered_cell_size.y)
	assert_eq(screen.canvas.get_parent(), map_world)
	assert_eq(screen.player_token.get_parent(), map_world)
	BattleSetup.reset()


func test_expedition_mouse_wheel_zooms_without_borders_or_oversized_player() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_null(screen.get_node_or_null("MapView/ZoomFocusPulse"),
			"缩放只保留尺度转场，不得再叠加暗化或扩散脉冲")
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	screen._on_map_view_gui_input(wheel_up)
	assert_eq(Vector2i(screen.get_zoom_contract()["current_grid"]), Vector2i(23, 13),
			"选角或浮层阶段不得在背后误缩放地图")

	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame
	screen.map.player = Vector2i(16, 9)
	screen._camera_initialized = false
	screen._update_map_camera()
	screen._on_map_view_gui_input(wheel_up)

	var contract: Dictionary = screen.get_zoom_contract()
	assert_eq(contract["grid_presets"], [
		Vector2i(31, 17), Vector2i(27, 15), Vector2i(23, 13),
		Vector2i(19, 11), Vector2i(15, 9),
	])
	assert_eq(Vector2i(contract["current_grid"]), Vector2i(19, 11))
	assert_eq(Vector2i(contract["default_grid"]), Vector2i(23, 13))
	assert_true(bool(contract["transition_active"]))
	assert_almost_eq(float(contract["transition_duration"]), 0.15, 0.001)
	assert_eq(screen.map_view.position, Vector2.ZERO)
	assert_eq(screen.map_view.size, Vector2(1920, 1080),
			"缩放只改变地图投影，PVE视窗始终必须满屏")
	var middle_scale := Vector2(16.0 / 23.0, 9.0 / 13.0)
	assert_lte(screen.map_world.scale.distance_to(middle_scale), 0.001,
			"滚轮触发帧不得瞬间跳到下一档")
	screen._advance_view_zoom(screen.ZOOM_TRANSITION_DURATION * 0.5)
	assert_gt(screen.map_world.scale.x, middle_scale.x)
	assert_lt(screen.map_world.scale.x, 16.0 / 19.0)
	var transition_token_scale: Vector2 = screen.player_token.scale * screen.map_world.scale
	assert_almost_eq(absf(transition_token_scale.x), absf(transition_token_scale.y), 0.001,
			"PVE缩放动效中也不得压扁角色")
	screen._advance_view_zoom(screen.ZOOM_TRANSITION_DURATION * 0.5)
	screen._on_map_view_gui_input(wheel_up)
	screen._advance_view_zoom(screen.ZOOM_TRANSITION_DURATION)
	assert_eq(Vector2i(screen.get_zoom_contract()["current_grid"]), Vector2i(15, 9))
	assert_false(bool(screen.get_zoom_contract()["transition_active"]))
	assert_lte(screen.map_world.scale.distance_to(Vector2(16.0 / 15.0, 1.0)), 0.001)
	var rendered_cell_size: Vector2 = Vector2.ONE * float(screen.MAP_CELL) \
			* screen.map_world.scale
	assert_lte((screen.MAP_VIEW_SIZE / rendered_cell_size)
			.distance_to(Vector2(15, 9)), 0.001,
			"最近档四边也必须停在完整格边界")
	var backdrop_center: Vector2 = (
			screen.player_backdrop.position + screen.player_backdrop.size * 0.5)
	assert_lte((screen.map_world.position + backdrop_center * screen.map_world.scale)
			.distance_to(screen.MAP_VIEW_SIZE * 0.5), 0.71,
			"PVE缩放中心必须保持在角色格，而不是鼠标位置")
	var token_screen_scale: Vector2 = screen.player_token.scale * screen.map_world.scale
	assert_almost_eq(absf(token_screen_scale.x), absf(token_screen_scale.y), 0.001)
	assert_lte(screen.player_token.size.y * absf(token_screen_scale.y), 208.01,
			"最近档角色不得超过208px")
	assert_eq(screen._raw_cell_from_map_view_position(
			screen._map_view_position_for_cell(Vector2i(16, 9))), Vector2i(16, 9),
			"缩放后屏幕坐标与逻辑格换算必须互逆")
	BattleSetup.reset()


func test_authored_terrain_tiles_keep_complete_grid_nearest_neighbor_scale() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	for path: String in AUTHORED_TERRAIN_PATHS:
		var texture := load(path) as Texture2D
		assert_not_null(texture)
		if texture != null:
			assert_eq(texture.get_size(), Vector2(60, 60),
					"正式格继续保留60px原资产：%s" % path)
	assert_eq(screen.MAP_CELL, 120)
	assert_lte(screen._current_render_scale().distance_to(
			Vector2(16.0 / 23.0, 9.0 / 13.0)), 0.0001)
	var rendered_cell_size: Vector2 = Vector2.ONE * 60.0 * 2.0 \
			* screen._current_render_scale()
	assert_lte(rendered_cell_size.distance_to(Vector2(1920.0 / 23.0, 1080.0 / 13.0)),
			0.001, "60px正式格必须以默认23×13个完整格精确铺满画面")
	BattleSetup.reset()


func test_qingfeng_atmosphere_adds_large_chaff_below_objects_and_screen_space_light() -> void:
	BattleSetup.reset()
	var atlas := load(CHAFF_ATLAS_PATH) as Texture2D
	assert_not_null(atlas, "晴风稻田必须使用正式稻壳粒子资产")
	if atlas != null:
		assert_eq(atlas.get_size(), Vector2(64, 20), "稻壳资产必须是4帧16×20横向图集")

	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var world := screen.get_node("MapView/MapWorld") as Control
	var foliage := world.get_node("RiceFoliageLayer") as CanvasItem
	var chaff := world.get_node_or_null("FieldChaff") as GPUParticles2D
	var objects := world.get_node("ObjectArtLayer") as CanvasItem
	var terrain := world.get_node("TerrainLayer") as CanvasItem
	var atmosphere := world.get_node("AtmosphereLayer") as ColorRect
	var markers := world.get_node("MarkerArtLayer") as CanvasItem
	assert_null(chaff, "未通过的稻壳粒子必须从场景断开")
	assert_not_null(atmosphere)
	assert_lt(foliage.get_index(), objects.get_index())
	assert_lt(objects.get_index(), terrain.get_index())
	assert_lt(terrain.get_index(), atmosphere.get_index())
	assert_lt(atmosphere.get_index(), markers.get_index(), "光影不能压暗交互标识与角色")
	assert_eq(atmosphere.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((atmosphere.material as ShaderMaterial).shader.resource_path, ATMOSPHERE_SHADER_PATH)
	screen._sync_atmosphere_to_camera()
	assert_eq(atmosphere.position * screen._current_render_scale() + world.position, Vector2.ZERO,
			"屏幕空间光影必须抵消地图镜头位移")
	BattleSetup.reset()


func test_pve_uses_continuous_three_band_vision_shadow_without_restoring_fog() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var shadow := screen.get_node_or_null(
			"MapView/MapWorld/VisionShadowLayer") as ColorRect
	assert_not_null(shadow, "PVE必须有独立的当前视野阴影层")
	if shadow == null:
		BattleSetup.reset()
		return
	assert_false(shadow.visible, "选角阶段不得在背景地图上提前显示视野阴影")
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame
	assert_true(shadow.visible)
	assert_eq(shadow.size, screen.MAP_WORLD_SIZE)
	var atmosphere := screen.get_node("MapView/MapWorld/AtmosphereLayer") as ColorRect
	var markers := screen.get_node("MapView/MapWorld/MarkerArtLayer") as Control
	assert_gt(shadow.get_index(), atmosphere.get_index(),
			"视野阴影必须压住地表与环境光影")
	assert_lt(shadow.get_index(), markers.get_index(),
			"路线、目标与角色不得被外围阴影压暗")
	var material := shadow.material as ShaderMaterial
	assert_not_null(material)
	assert_eq(material.shader.resource_path, VISION_SHADOW_SHADER_PATH)
	assert_almost_eq(float(material.get_shader_parameter("inner_radius_cells")), 2.5, 0.001)
	assert_almost_eq(float(material.get_shader_parameter("outer_radius_cells")), 4.5, 0.001)
	assert_almost_eq(float(material.get_shader_parameter("horizontal_ratio")), 1.4, 0.001)
	assert_almost_eq(float(material.get_shader_parameter("outer_alpha")), 0.60, 0.001)
	screen._sync_vision_shadow_to_player()
	var expected_center: Vector2 = screen._camera_visual_token_origin \
			- screen.TOKEN_OFFSET + Vector2.ONE * float(screen.MAP_CELL) * 0.5
	assert_lte(Vector2(material.get_shader_parameter("player_world_px"))
			.distance_to(expected_center), 0.001,
			"视野中心必须跟随角色的连续视觉坐标，不能逐格跳变")
	assert_false(screen.FOG_OF_WAR_ENABLED)
	assert_false((screen.get_node("MapView/MapWorld/TerrainLayer") as CanvasItem).visible)
	var shader_source := FileAccess.get_file_as_string(VISION_SHADOW_SHADER_PATH)
	assert_true(shader_source.contains("player_world_px"))
	assert_true(shader_source.contains("inner_radius_cells"))
	assert_false(shader_source.contains("map_data"),
			"当前视野阴影不得读取或保存探索历史")
	BattleSetup.reset()


func test_disabled_world_fog_keeps_unexplored_cells_visible() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	var start: Vector2i = screen.map.player
	screen.map.player = Vector2i(9, 5)
	screen.map._reveal_around(screen.map.player)
	screen._refresh()
	assert_true(screen.map.revealed.has(start), "旧格必须保持在探索记录")
	assert_false(screen.FOG_OF_WAR_ENABLED)
	assert_false((screen.get_node("MapView/MapWorld/TerrainLayer") as CanvasItem).visible)
	assert_true(screen._is_cell_visible(start))
	assert_true(screen._is_cell_explored(start))
	assert_true(screen._is_cell_visible(screen.map.player))
	var unknown := Vector2i(0, 0)
	assert_false(screen._is_cell_explored(unknown))
	assert_true(screen._is_cell_visible(unknown),
			"未探索格也必须直接显示，探索记录不再控制画面")
	BattleSetup.reset()


func test_token_and_complete_grid_camera_share_one_monotonic_visual_coordinate() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.camera_follow_enabled = true
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	screen.map.player = Vector2i(16, 9)
	screen._camera_initialized = false
	screen._update_map_camera()
	screen._queued_move_direction = Vector2i.UP
	screen.map.player = Vector2i(16, 8)
	screen._update_map_camera()
	var target: Vector2 = screen._camera_target_token_origin
	var previous_distance: float = screen._camera_visual_token_origin.distance_to(target)
	for frame: int in 120:
		screen._step_camera_follow(1.0 / 60.0)
		var current_distance: float = screen._camera_visual_token_origin.distance_to(target)
		assert_lte(current_distance, previous_distance + 0.001, "临界阻尼跟随不能反向或过冲：frame=%d" % frame)
		previous_distance = current_distance
		var backdrop_center: Vector2 = (
				screen.player_backdrop.position + screen.player_backdrop.size * 0.5)
		var screen_center: Vector2 = (
				screen.map_world.position + backdrop_center * screen._current_render_scale())
		assert_lte(screen_center.distance_to(screen.MAP_VIEW_SIZE * 0.5), 0.71,
				"地图与角色必须共用同一视觉坐标；横纵各半像素取整误差不得累积成抖动")
	assert_almost_eq(screen._camera_visual_token_origin.x, target.x, 0.05)
	assert_almost_eq(screen._camera_visual_token_origin.y, target.y, 0.05)
	BattleSetup.reset()


func test_complete_grid_camera_clamps_at_real_map_edges() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	assert_true(screen.camera_follow_enabled)
	screen.map.player = Vector2i.ZERO
	screen._camera_initialized = false
	screen._update_map_camera()
	assert_eq(screen.map_world.position, Vector2.ZERO)

	screen.map.player = Vector2i(31, 17)
	screen._camera_initialized = false
	screen._update_map_camera()
	assert_eq(screen.map_world.position, Vector2(-751, -415))
	assert_gt(screen.map_world.size.x * screen._current_render_scale().x, screen.MAP_VIEW_SIZE.x)
	assert_gt(screen.map_world.size.y * screen._current_render_scale().y, screen.MAP_VIEW_SIZE.y)
	BattleSetup.reset()


func test_standing_player_uses_only_authored_idle_frames_without_extra_sway() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame
	assert_false(screen.has_method("_token_idle_rotation_at"),
			"静止时不得在idle sprite sheet之外再叠加正弦扫动")
	screen.player_token.rotation = 0.0
	screen._process(0.25)
	assert_eq(screen.player_token.rotation, 0.0,
			"站立帧只允许播放素材自身idle，代码不得额外旋转人物")
	BattleSetup.reset()


func test_player_idle_sprite_uses_integer_hop_and_wobble_during_grid_movement() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	screen.map.player = Vector2i(9, 6)
	screen._camera_initialized = false
	screen._update_map_camera()
	screen._queued_move_direction = Vector2i.RIGHT
	screen.map.player = Vector2i(10, 6)
	screen._update_map_camera()
	assert_true(screen._token_step_active)
	var midpoint: Vector2 = screen._token_step_start_origin.lerp(
			screen._token_step_target_origin, 0.5)
	screen._camera_visual_token_origin = midpoint
	screen._apply_camera_visual_position()
	var base_origin: Vector2 = screen._quantize_world_pixel(midpoint)
	var motion_offset: Vector2 = screen.player_token.position - base_origin
	assert_eq(motion_offset, Vector2(5, -10),
			"放大后移动中段必须整体前倾一逻辑步并上浮两逻辑步")
	assert_eq(fmod(absf(motion_offset.x), screen.TOKEN_STEP_LOGICAL_PX), 0.0)
	assert_eq(fmod(absf(motion_offset.y), screen.TOKEN_STEP_LOGICAL_PX), 0.0)
	assert_lte(absf(screen._token_step_rotation_at(0.25)), 0.04,
			"移动摆动要明显但不能把idle像素人物扭成旋转贴纸")
	for frame: int in 120:
		screen._step_camera_follow(1.0 / 60.0)
	assert_false(screen._token_step_active)
	assert_eq(screen.player_token.position, screen._token_origin_for_cell(Vector2i(10, 6)))
	BattleSetup.reset()


func test_horizontal_steps_use_a_foot_pivoted_squeeze_turn_and_vertical_steps_keep_facing() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	assert_eq(screen._player_facing_sign, 1.0)
	screen._begin_token_step(Vector2(9, 6) * screen.MAP_CELL + screen.TOKEN_OFFSET,
			Vector2(8, 6) * screen.MAP_CELL + screen.TOKEN_OFFSET, Vector2i.LEFT)
	assert_true(screen._token_turn_active)
	var compressed: Vector2 = screen._token_scale_at_step_progress(0.25)
	assert_gt(compressed.x, 0.0, "转身前半段仍保持旧朝向")
	assert_lt(absf(compressed.x), screen.TOKEN_RENDER_COMPENSATION.x,
			"转身必须先横向压缩，不能瞬间镜像")
	var flipped: Vector2 = screen._token_scale_at_step_progress(0.5)
	assert_lt(flipped.x, 0.0, "最窄帧后才切换到左朝向")
	screen._finish_token_step_visuals()
	assert_eq(screen._player_facing_sign, -1.0)
	screen._begin_token_step(Vector2(8, 6) * screen.MAP_CELL + screen.TOKEN_OFFSET,
			Vector2(8, 5) * screen.MAP_CELL + screen.TOKEN_OFFSET, Vector2i.UP)
	assert_false(screen._token_turn_active)
	assert_lt(screen._token_scale_at_step_progress(0.5).x, 0.0,
			"上下移动必须保留最近一次水平朝向")
	# 模拟连续输入残留的斜向视觉位置：逻辑向下仍不得触发转身。
	screen._camera_visual_token_origin = Vector2(8, 5.4) * screen.MAP_CELL + screen.TOKEN_OFFSET
	screen._begin_token_step(screen._camera_visual_token_origin,
			Vector2(8, 6) * screen.MAP_CELL + screen.TOKEN_OFFSET, Vector2i.DOWN)
	assert_false(screen._token_turn_active)
	assert_lt(screen._token_scale_at_step_progress(0.5).x, 0.0)
	# 未完成的旧转身被新方向取代，不得先完成旧朝向再回头校正。
	screen._player_facing_sign = 1.0
	screen._begin_token_step(Vector2(8, 6) * screen.MAP_CELL + screen.TOKEN_OFFSET,
			Vector2(7, 6) * screen.MAP_CELL + screen.TOKEN_OFFSET, Vector2i.LEFT)
	screen._camera_visual_token_origin = screen._token_step_start_origin
	screen._begin_token_step(screen._camera_visual_token_origin,
			Vector2(9, 6) * screen.MAP_CELL + screen.TOKEN_OFFSET, Vector2i.RIGHT)
	assert_false(screen._token_turn_active,
			"旧左转尚未切面时，立即向右应继续保持右朝向")
	BattleSetup.reset()


func test_complete_grid_camera_uses_real_map_bounds_without_fake_fog_padding() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[2])
	await get_tree().process_frame

	assert_eq(screen.map_world.size, Vector2(3840, 2160), "逻辑地图必须为32×18")
	assert_lte(screen.map_world.scale.distance_to(
			Vector2(16.0 / 23.0, 9.0 / 13.0)), 0.0001)
	assert_true(screen._is_fog_extension_cell(Vector2i(-1, 0)))
	assert_true(screen._is_fog_extension_cell(Vector2i(32, 17)))
	assert_false(screen._is_fog_extension_cell(Vector2i(0, 0)))
	assert_false(screen._is_fog_extension_cell(Vector2i(31, 17)))
	assert_eq(screen._camera_extension_world_rect(), Rect2(Vector2.ZERO, screen.MAP_WORLD_SIZE))
	var expected_offsets := [
		Vector2.ZERO,
		Vector2(-751, 0),
		Vector2(0, -415),
		Vector2(-751, -415),
	]
	var corners := [Vector2i.ZERO, Vector2i(31, 0), Vector2i(0, 17), Vector2i(31, 17)]
	for index: int in corners.size():
		var corner: Vector2i = corners[index]
		var visual_origin: Vector2 = screen._token_origin_for_cell(corner)
		var world_offset: Vector2 = screen._camera_world_offset_for_visual(visual_origin)
		assert_eq(world_offset, expected_offsets[index])
	BattleSetup.reset()


func test_screen_space_test_button_cycles_only_the_character_preview() -> void:
	BattleSetup.reset()
	var screen := (load(EXPEDITION_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var pool: Array[HeroData] = HeroDataScript.create_launch_pool()
	screen._on_hero_selected(pool[2])
	await get_tree().process_frame

	var controls := screen.get_node("TestControls") as Control
	var button := screen.get_node("TestControls/NextHeroButton") as Button
	assert_true(controls.visible)
	assert_eq(controls.get_parent(), screen, "测试按钮必须固定在屏幕空间，不能随地图镜头移动")
	assert_eq(button.text, "测试·下个角色")
	var original_map: Variant = screen.map
	var original_player: Vector2i = screen.map.player
	button.pressed.emit()
	assert_eq(screen.map, original_map, "切角色测试按钮不得重开远征或重置地图")
	assert_eq(screen.map.player, original_player)
	assert_eq(screen.hero_idle_frames_path, pool[3].sprite_frames_path)
	assert_false(screen._hero_idle_token_frames.is_empty())
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

	var exit_cell := Vector2i(5, 1)
	screen.map.grid[exit_cell.y][exit_cell.x] = MapStateScript.Tile.EXT1
	screen.map.ext_pos[MapStateScript.Tile.EXT1] = exit_cell
	screen.map.player = exit_cell
	screen.map._reveal_around(exit_cell)
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


func _rect_has_alpha(image: Image, rect: Rect2i) -> bool:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).a >= 0.38:
				return true
	return false


func _alpha_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < 0.0625:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
