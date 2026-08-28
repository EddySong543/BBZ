extends GutTest

const SCENE8_PATH := "res://src/ui/scenes/scene8.tscn"
const BATTLE8_PATH := "res://src/ui/battle_screen8.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const SCENE1_PATH := "res://src/ui/scenes/scene1.tscn"
const NIGHT_SKY_SHADER_PATH := "res://assets/shaders/canvas_env_night_sky.gdshader"
const STARS_SHADER_PATH := "res://assets/shaders/canvas_env_stars.gdshader"
const REF48_PATH := "res://ref/ref48.png"
const PIXEL_AURORA_TEXTURE_PATH := (
		"res://assets/scenes/scene8/scene8_ref48_aurora.png")
const PIXEL_AURORA_MOTION_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_ref48_aurora_motion.gdshader")
const RETIRED_PIXEL_AURORA_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_pixel_aurora.gdshader")
const OPEN_LAKE_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_open_lake.gdshader")
const AURORA_REFLECTION_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_aurora_reflection.gdshader")
const SHARED_WATER_WAVE_INCLUDE_PATH := (
		"res://assets/shaders/canvas_env_scene8_shared_water_wave.gdshaderinc")
const PLATFORM_FLOAT_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_platform_float.gdshader")
const PLATFORM_CONTACT_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_platform_water_contact.gdshader")
const LAKE_TOPOLOGY_SCRIPT_PATH := (
		"res://src/ui/components/scene8_lake_topology.gd")
const PLATFORM_PATH := "res://assets/scenes/scene8/scene8_battle_platform.png"
const FAR_MOUNTAIN_PATH := "res://assets/scenes/scene8/scene8_far_mountain.png"
const FOREGROUND_LEFT_PATH := "res://assets/scenes/scene8/scene8_foreground_left.png"
const FOREGROUND_RIGHT_PATH := "res://assets/scenes/scene8/scene8_foreground_right.png"
const FOREGROUND_CENTER_SNOW_PATH := (
		"res://assets/scenes/scene8/scene8_foreground_center_snow.png")
const CHARACTER_LIGHT_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_character_light.gdshader")


func test_scene8_resources_exist() -> void:
	assert_true(ResourceLoader.exists(SCENE8_PATH))
	assert_true(ResourceLoader.exists(BATTLE8_PATH))
	assert_true(ResourceLoader.exists(OPEN_LAKE_SHADER_PATH))
	assert_true(ResourceLoader.exists(AURORA_REFLECTION_SHADER_PATH))
	assert_true(ResourceLoader.exists(SHARED_WATER_WAVE_INCLUDE_PATH))
	assert_true(ResourceLoader.exists(PLATFORM_FLOAT_SHADER_PATH))
	assert_true(ResourceLoader.exists(PLATFORM_CONTACT_SHADER_PATH))
	assert_true(ResourceLoader.exists(LAKE_TOPOLOGY_SCRIPT_PATH))
	assert_true(ResourceLoader.exists(PIXEL_AURORA_TEXTURE_PATH))
	assert_true(ResourceLoader.exists(PIXEL_AURORA_MOTION_SHADER_PATH))
	assert_true(ResourceLoader.exists(FOREGROUND_CENTER_SNOW_PATH))
	assert_true(ResourceLoader.exists(CHARACTER_LIGHT_SHADER_PATH))
	assert_false(ResourceLoader.exists(RETIRED_PIXEL_AURORA_SHADER_PATH))


func test_scene8_framework_has_direct_editable_depth_roles() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_not_null(stage)
	if stage == null:
		return

	var expected_factors := {
		"Sky": 0.0,
		"Stars": 0.0,
		"PixelAurora": 0.0,
		"FarMountainDistant": 0.06,
		"FarMountainMiddle": 0.10,
		"FarSnowfield": 0.15,
		"AuroraReflection": 0.28,
		"MirrorLake": 0.58,
		"PlatformWaterContact": 1.0,
		"BattlePlatform": 1.0,
		"ForegroundLeft": 1.18,
		"ForegroundRight": 1.18,
		"ForegroundCenterSnow": 1.22,
	}
	for node_name: String in expected_factors:
		var layer := stage.get_node_or_null(node_name) as CanvasItem
		assert_not_null(layer, "%s must remain directly editable" % node_name)
		if layer != null:
			assert_eq(
					float(layer.get_meta("parallax_factor")),
					float(expected_factors[node_name]))

	for child: Node in stage.get_children():
		assert_false(child.name.ends_with("Slot"),
				"Scene8 must not add wrapper slots that obstruct Inspector editing")
	assert_false(stage.has_node("FrameworkBackdrop"),
			"The temporary framework color must leave once the real sky is active")


func test_scene8_replicates_scene1_night_sky_and_star_contract() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	var scene1 := (load(SCENE1_PATH) as PackedScene).instantiate()
	var scene8 := (load(SCENE8_PATH) as PackedScene).instantiate()
	add_child_autofree(scene1)
	add_child_autofree(scene8)
	for node_name: String in ["Sky", "Stars"]:
		var scene1_name := "NightSky" if node_name == "Sky" else node_name
		var source_material := (
				scene1.get_node(scene1_name) as ColorRect).material as ShaderMaterial
		var copied_material := (
				scene8.get_node(node_name) as ColorRect).material as ShaderMaterial
		assert_not_null(copied_material)
		if copied_material == null:
			continue
		assert_true(copied_material.resource_local_to_scene)
		assert_eq(copied_material.shader.resource_path,
				NIGHT_SKY_SHADER_PATH if node_name == "Sky" else STARS_SHADER_PATH)
		for parameter: StringName in (
				[
					&"zenith_color", &"horizon_color", &"gradient_curve",
					&"horizon_pos", &"glow_color", &"glow_width",
					&"glow_intensity", &"breath_amount", &"breath_speed",
					&"breath_scale", &"dither_amount", &"posterize_steps",
					&"pixel_grid",
				] if node_name == "Sky" else [
					&"grid", &"coverage", &"band_scale", &"gap_threshold",
					&"band_soft", &"star_color", &"star_color_warm",
					&"warm_ratio", &"brightness", &"faint_floor",
					&"twinkle_speed", &"twinkle_depth", &"bright_ratio",
					&"spike_strength",
					&"edge_margin", &"sky_bottom", &"sky_fade",
					&"top_concentration", &"pixel_grid",
				]):
			assert_eq(copied_material.get_shader_parameter(parameter),
					source_material.get_shader_parameter(parameter),
					"Scene8 must replicate Scene1 parameter: %s" % parameter)
	var stars_material := (
			scene8.get_node("Stars") as ColorRect).material as ShaderMaterial
	assert_eq(float(stars_material.get_shader_parameter("moon_clear")), 0.0,
			"Scene8 has no moon disc, so Scene1's moon-only star hole must be disabled")


func test_scene8_imported_far_mountain_and_platform_preserve_current_composition() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	assert_true(ResourceLoader.exists(FAR_MOUNTAIN_PATH))
	assert_true(ResourceLoader.exists(PLATFORM_PATH))
	assert_false(FileAccess.file_exists("res://assets/import/farmountain.png"))
	assert_false(FileAccess.file_exists("res://assets/import/platform.png"))
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var mountain := stage.get_node("FarSnowfield") as TextureRect
	var platform := stage.get_node("BattlePlatform") as TextureRect
	assert_eq(mountain.texture.resource_path, FAR_MOUNTAIN_PATH)
	assert_eq(platform.texture.resource_path, PLATFORM_PATH)
	assert_eq(mountain.size, Vector2(332.0, 188.0))
	assert_eq(platform.size, Vector2(288.0, 188.0))
	assert_eq(mountain.scale, Vector2(6.0, 6.0))
	assert_eq(mountain.rotation, 0.0,
			"Topology mapping assumes the authored mountain stays axis-aligned")
	assert_eq(platform.scale, Vector2(6.0, 6.0))
	assert_eq(mountain.position, Vector2(-36.0, 0.0))
	assert_eq(platform.position, Vector2(88.0, 166.0))
	var mountain_rect := _displayed_used_rect(mountain)
	var platform_rect := _displayed_used_rect(platform)
	assert_between(mountain_rect.position.y, 317.0, 319.0)
	assert_between(mountain_rect.end.y, 569.0, 571.0)
	assert_between(platform_rect.position.y, 705.0, 707.0)
	assert_between(platform_rect.end.y, 879.0, 881.0)
	var reflection_grab := (
			stage.get_node_or_null("AuroraReflectionGrab") as BackBufferCopy)
	assert_not_null(reflection_grab)
	assert_lt(stage.get_node("PixelAurora").get_index(),
			reflection_grab.get_index())
	assert_eq(reflection_grab.copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT)
	assert_lt(reflection_grab.get_index(), mountain.get_index(),
			"Reflection source must be locked before mountains are drawn")
	assert_lt(mountain.get_index(), platform.get_index())


func test_scene8_platform_has_a_shallow_wall_and_real_water_contact() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var mountain := stage.get_node("FarSnowfield") as TextureRect
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var contact := stage.get_node_or_null("PlatformWaterContact") as ColorRect
	assert_not_null(contact,
			"The platform needs a masked water contact, not a free-floating glow")
	if contact == null:
		return

	assert_eq(platform.position, Vector2(88.0, 166.0))
	assert_eq(platform.size, Vector2(288.0, 188.0))
	assert_eq(platform.scale, Vector2(6.0, 6.0))
	assert_eq(contact.position, Vector2(-32.0, 802.0))
	assert_eq(contact.size, Vector2(1984.0, 24.0))
	assert_eq(float(contact.get_meta("parallax_factor")), 1.0)
	assert_eq(contact.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(contact.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_lt(mountain.get_index(), contact.get_index())
	assert_lt(contact.get_index(), platform.get_index())
	assert_lt(platform.get_index(), stage.get_node("ForegroundLeft").get_index())

	var platform_material := platform.material as ShaderMaterial
	var contact_material := contact.material as ShaderMaterial
	assert_not_null(platform_material)
	assert_not_null(contact_material)
	if platform_material == null or contact_material == null:
		return
	assert_true(platform_material.resource_local_to_scene)
	assert_true(contact_material.resource_local_to_scene)
	assert_eq(platform_material.shader.resource_path, PLATFORM_FLOAT_SHADER_PATH)
	assert_eq(contact_material.shader.resource_path, PLATFORM_CONTACT_SHADER_PATH)
	assert_eq(contact_material.get_shader_parameter("platform_texture"),
			platform.texture)

	var surface_bottom_row := float(platform_material.get_shader_parameter(
			"surface_bottom_row"))
	var shallow_wall_rows := float(platform_material.get_shader_parameter(
			"shallow_wall_rows"))
	var edge_variation_rows := float(platform_material.get_shader_parameter(
			"edge_variation_rows"))
	var block_width := float(platform_material.get_shader_parameter(
			"ice_block_width"))
	assert_eq(surface_bottom_row, 103.0)
	assert_eq(shallow_wall_rows, 4.0)
	assert_eq(edge_variation_rows, 1.0)
	assert_eq(block_width, 7.0)

	var platform_image := platform.texture.get_image()
	var total_opaque := 0
	var submerged_opaque := 0
	var contact_columns := 0
	var occupied_columns := 0
	var maximum_visible_row := -1
	for x: int in platform_image.get_width():
		var column_has_alpha := false
		var source_block := floorf(float(x) / block_width)
		var edge_step := (
				edge_variation_rows
				if _scene8_stable_hash(source_block) >= 0.72 else 0.0)
		var visible_bottom := surface_bottom_row + shallow_wall_rows + edge_step
		var support_row := clampi(
				int(floor(visible_bottom)) - 1, 0,
				platform_image.get_height() - 1)
		for y: int in platform_image.get_height():
			if platform_image.get_pixel(x, y).a < 0.03:
				continue
			column_has_alpha = true
			total_opaque += 1
			if float(y) >= visible_bottom:
				submerged_opaque += 1
			else:
				maximum_visible_row = maxi(maximum_visible_row, y)
		if column_has_alpha:
			occupied_columns += 1
			contact_columns += int(
					platform_image.get_pixel(x, support_row).a >= 0.03)
	var submerged_ratio := float(submerged_opaque) / maxf(float(total_opaque), 1.0)
	var contact_column_ratio := (
			float(contact_columns) / maxf(float(occupied_columns), 1.0))
	assert_between(submerged_ratio, 0.28, 0.42,
			"At least one third of the old dark wall must be water-occluded")
	assert_lte(maximum_visible_row, 107,
			"The 96px dark wall must collapse to a shallow floating-ice rim")
	assert_gte(contact_column_ratio, 0.70,
			"The pressure line must follow most occupied platform columns")

	assert_eq(float(contact_material.get_shader_parameter("contact_cell_px")), 6.0)
	assert_eq(float(contact_material.get_shader_parameter("shadow_rows")), 1.0)
	assert_eq(float(contact_material.get_shader_parameter("crest_rows")), 1.0)
	assert_between(float(contact_material.get_shader_parameter(
			"shadow_line_coverage")), 0.70, 0.90)
	assert_between(float(contact_material.get_shader_parameter(
			"crest_line_coverage")), 0.25, 0.55)
	for parameter_name: String in [
		"wave_cycle_sec",
		"wave_travel_cells_per_sec",
		"wave_max_offset_cells",
		"diagnostic_time_sec",
	]:
		assert_almost_eq(
				float(contact_material.get_shader_parameter(parameter_name)),
				float((stage.get_node("MirrorLake") as ColorRect).material
						.get_shader_parameter(parameter_name)),
				0.0001)

	var platform_source := FileAccess.get_file_as_string(
			PLATFORM_FLOAT_SHADER_PATH)
	var contact_source := FileAccess.get_file_as_string(
			PLATFORM_CONTACT_SHADER_PATH)
	assert_true(platform_source.contains("source_visible"))
	assert_true(platform_source.contains("visible_bottom_row"))
	assert_true(platform_source.contains("source_surface *= source_visible"))
	assert_false(platform_source.contains("hint_screen_texture"))
	assert_false(platform_source.contains("TIME"))
	assert_true(contact_source.contains("platform_texture"))
	assert_true(contact_source.contains("source_contact_alpha"))
	assert_true(contact_source.contains("shared_wave_field"))
	assert_true(contact_source.contains(SHARED_WATER_WAVE_INCLUDE_PATH))
	assert_false(contact_source.contains("hint_screen_texture"))


func test_scene8_builds_one_shared_lake_topology_from_the_far_mountain() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var topology := stage.get_node_or_null("LakeTopology")
	var mountain := stage.get_node_or_null("FarSnowfield") as TextureRect
	var lake := stage.get_node_or_null("MirrorLake") as ColorRect
	var reflection := stage.get_node_or_null("AuroraReflection") as ColorRect
	var contact := stage.get_node_or_null("PlatformWaterContact") as ColorRect
	assert_not_null(topology)
	assert_not_null(mountain)
	assert_not_null(lake)
	assert_not_null(reflection)
	assert_not_null(contact)
	if (topology == null or mountain == null or lake == null
			or reflection == null or contact == null):
		return

	assert_eq(topology.get_script().resource_path, LAKE_TOPOLOGY_SCRIPT_PATH)
	assert_eq(topology.get("grid_size"), Vector2i(320, 180))
	assert_eq(topology.get("design_size"), Vector2(1920.0, 1080.0))
	assert_true(bool(topology.call("rebuild")))
	var topology_image := topology.call("get_topology_image") as Image
	assert_not_null(topology_image)
	if topology_image == null:
		return
	assert_eq(topology_image.get_size(), Vector2i(320, 180))

	var lake_material := lake.material as ShaderMaterial
	var reflection_material := reflection.material as ShaderMaterial
	var contact_material := contact.material as ShaderMaterial
	var lake_topology: Variant = lake_material.get_shader_parameter("lake_topology")
	var reflection_topology: Variant = reflection_material.get_shader_parameter(
			"lake_topology")
	var contact_topology: Variant = contact_material.get_shader_parameter(
			"lake_topology")
	assert_true(bool(lake_material.get_shader_parameter("use_lake_topology")))
	assert_true(bool(reflection_material.get_shader_parameter(
			"use_lake_topology")))
	assert_true(bool(contact_material.get_shader_parameter("use_lake_topology")))
	assert_not_null(lake_topology)
	assert_true(lake_topology == reflection_topology,
			"Water and reflection must consume the exact same topology texture")
	assert_true(lake_topology == contact_topology,
			"The platform pressure line must consume the lake's topology texture")
	assert_almost_eq(float(lake_material.get_shader_parameter(
			"shore_distance_cells")), float(topology.get("shore_distance_cells")),
			0.0001)
	assert_almost_eq(float(reflection_material.get_shader_parameter(
			"shore_distance_cells")), float(topology.get("shore_distance_cells")),
			0.0001)
	var initial_origin: Vector2 = lake_material.get_shader_parameter(
			"topology_current_origin_uv")
	var initial_size: Vector2 = lake_material.get_shader_parameter(
			"topology_current_size_uv")
	assert_eq(initial_origin, reflection_material.get_shader_parameter(
			"topology_current_origin_uv"))
	assert_eq(initial_size, reflection_material.get_shader_parameter(
			"topology_current_size_uv"))
	assert_eq(initial_origin, contact_material.get_shader_parameter(
			"topology_current_origin_uv"))
	assert_eq(initial_size, contact_material.get_shader_parameter(
			"topology_current_size_uv"))

	var grid_size := Vector2i(320, 180)
	var design_size: Vector2 = topology.get("design_size")
	var cell_size := design_size / Vector2(grid_size)
	var overlap_cells := int(topology.get("shore_overlap_cells"))
	var alpha_threshold := float(topology.get("mountain_alpha_threshold"))
	var mountain_image := mountain.texture.get_image()
	var mountain_draw_size := mountain.size * mountain.scale
	var minimum_first_water := grid_size.y
	var maximum_first_water := -1
	for x: int in grid_size.x:
		var first_water := -1
		for y: int in grid_size.y:
			if topology_image.get_pixel(x, y).r >= 0.5:
				first_water = y
				break
		assert_ne(first_water, -1, "Every visible column must reach the lake")
		if first_water < 0:
			continue
		minimum_first_water = mini(minimum_first_water, first_water)
		maximum_first_water = maxi(maximum_first_water, first_water)
		assert_lt(first_water, grid_size.y - 1)
		assert_gte(topology_image.get_pixel(x, grid_size.y - 1).r, 0.99)
		var occupancy_holes := 0
		for y: int in range(first_water, grid_size.y):
			if topology_image.get_pixel(x, y).r < 0.5:
				occupancy_holes += 1
		assert_eq(occupancy_holes, 0,
				"A lake column must stay occupied after entering the water")

		if x % 16 != 0 and x != grid_size.x - 1:
			continue
		var screen_x := (float(x) + 0.5) * cell_size.x
		var source_u := clampf(
				(screen_x - mountain.position.x) / mountain_draw_size.x,
				0.0, 0.999999)
		var source_x := clampi(
				int(floor(source_u * float(mountain_image.get_width()))),
				0, mountain_image.get_width() - 1)
		var source_bottom := _bottom_alpha_row(
				mountain_image, source_x, alpha_threshold)
		assert_gte(source_bottom, 0)
		if source_bottom < 0:
			continue
		var shore_screen_y := mountain.position.y + (
				(float(source_bottom) + 1.0)
				/ float(mountain_image.get_height())) * mountain_draw_size.y
		var expected_first_water := clampi(int(ceil(
				(shore_screen_y - float(overlap_cells) * cell_size.y)
				/ cell_size.y - 0.5)), 0, grid_size.y - 1)
		assert_lte(absi(first_water - expected_first_water), 1,
				"Topology must track the authored mountain alpha within one cell")
		var first_true_shore_row := clampi(int(ceil(
				shore_screen_y / cell_size.y - 0.5)), 0, grid_size.y - 1)
		for y: int in range(first_water, first_true_shore_row):
			var hidden_overlap_pixel := topology_image.get_pixel(x, y)
			assert_lte(hidden_overlap_pixel.g, 0.004,
					"Hidden overlap must not advance shore distance")
			assert_lte(hidden_overlap_pixel.b, 0.004,
					"Hidden overlap must not advance perspective depth")

		var previous_shore_distance := -0.001
		var previous_depth := -0.001
		for y: int in range(first_water, grid_size.y):
			var topology_pixel := topology_image.get_pixel(x, y)
			assert_gte(topology_pixel.g + 0.0001, previous_shore_distance)
			assert_gte(topology_pixel.b + 0.0001, previous_depth)
			previous_shore_distance = topology_pixel.g
			previous_depth = topology_pixel.b
		assert_gte(topology_image.get_pixel(x, grid_size.y - 1).g, 0.99)
		assert_gte(topology_image.get_pixel(x, grid_size.y - 1).b, 0.98)

	assert_between(maximum_first_water - minimum_first_water, 2, 4,
			"The shoreline must preserve the far mountain's per-column variation")
	mountain.position += Vector2(24.0, 12.0)
	mountain.scale *= Vector2(1.01, 1.01)
	topology.call("sync_shader_mapping")
	var shifted_origin: Vector2 = lake_material.get_shader_parameter(
			"topology_current_origin_uv")
	var shifted_size: Vector2 = lake_material.get_shader_parameter(
			"topology_current_size_uv")
	assert_ne(shifted_origin, initial_origin,
			"The shoreline mapping must follow mountain parallax and shake")
	assert_ne(shifted_size, initial_size,
			"The shoreline mapping must follow mountain focus scaling")
	assert_eq(shifted_origin, reflection_material.get_shader_parameter(
			"topology_current_origin_uv"))
	assert_eq(shifted_size, reflection_material.get_shader_parameter(
			"topology_current_size_uv"))
	assert_eq(shifted_origin, contact_material.get_shader_parameter(
			"topology_current_origin_uv"))
	assert_eq(shifted_size, contact_material.get_shader_parameter(
			"topology_current_size_uv"))
	var viewport_size: Vector2 = stage.get_viewport().get_visible_rect().size
	var mountain_transform: Transform2D = (
			mountain.get_global_transform_with_canvas())
	var expected_origin_px: Vector2 = mountain_transform * Vector2.ZERO
	var expected_right_px: Vector2 = mountain_transform * Vector2(
			mountain.size.x, 0.0)
	var expected_bottom_px: Vector2 = mountain_transform * Vector2(
			0.0, mountain.size.y)
	var expected_origin_uv: Vector2 = expected_origin_px / viewport_size
	var expected_size_uv := Vector2(
			expected_right_px.x - expected_origin_px.x,
			expected_bottom_px.y - expected_origin_px.y) / viewport_size
	assert_almost_eq(shifted_origin.x, expected_origin_uv.x, 0.000001)
	assert_almost_eq(shifted_origin.y, expected_origin_uv.y, 0.000001)
	assert_almost_eq(shifted_size.x, expected_size_uv.x, 0.000001)
	assert_almost_eq(shifted_size.y, expected_size_uv.y, 0.000001)
	assert_true(lake_topology == lake_material.get_shader_parameter(
			"lake_topology"),
			"Transform sync must update uniforms without rebuilding the image")
	assert_lt(stage.get_node("AuroraReflectionGrab").get_index(), lake.get_index())
	assert_lt(lake.get_index(), reflection.get_index())
	assert_lt(reflection.get_index(), mountain.get_index(),
			"The original mountain alpha must be the final shoreline occluder")


func test_scene8_imported_foregrounds_frame_the_lake_without_crowding_center() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	assert_true(ResourceLoader.exists(FOREGROUND_LEFT_PATH))
	assert_true(ResourceLoader.exists(FOREGROUND_RIGHT_PATH))
	assert_false(FileAccess.file_exists("res://assets/import/left.png"))
	assert_false(FileAccess.file_exists("res://assets/import/right.png"))
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var foreground_left := stage.get_node_or_null("ForegroundLeft") as TextureRect
	var foreground_right := stage.get_node_or_null("ForegroundRight") as TextureRect
	assert_not_null(foreground_left)
	assert_not_null(foreground_right)
	if foreground_left == null or foreground_right == null:
		return
	assert_eq(foreground_left.texture.resource_path, FOREGROUND_LEFT_PATH)
	assert_eq(foreground_right.texture.resource_path, FOREGROUND_RIGHT_PATH)
	assert_almost_eq(foreground_left.size.x, 233.33334, 0.001)
	assert_almost_eq(foreground_left.size.y, 178.6667, 0.001)
	assert_almost_eq(foreground_right.size.x, 240.6666, 0.001)
	assert_almost_eq(foreground_right.size.y, 189.0, 0.001)
	assert_eq(foreground_left.scale, Vector2(3.0, 3.0))
	assert_eq(foreground_right.scale, Vector2(3.0, 3.0))
	assert_eq(foreground_left.position, Vector2(-99.0, 620.0))
	assert_eq(foreground_right.position, Vector2(1336.0, 616.0))
	var left_used_rect := _displayed_used_rect(foreground_left)
	var right_used_rect := _displayed_used_rect(foreground_right)
	assert_between(left_used_rect.position.x, -44.0, -42.0)
	assert_between(left_used_rect.end.x, 427.0, 430.0)
	assert_between(right_used_rect.position.x, 1442.0, 1445.0)
	assert_between(right_used_rect.end.x, 2041.0, 2044.0)
	assert_between(left_used_rect.end.y, 1132.0, 1135.0)
	assert_between(right_used_rect.end.y, 1153.0, 1156.0)
	assert_gt(right_used_rect.position.x - left_used_rect.end.x, 1000.0,
			"The foreground pair must preserve a readable lake and battle opening")
	assert_lt(stage.get_node("BattlePlatform").get_index(), foreground_left.get_index())
	assert_lt(foreground_left.get_index(), foreground_right.get_index())


func test_scene8_far_mountain_depth_and_center_snow_complete_the_frame() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	assert_true(ResourceLoader.exists(FOREGROUND_CENTER_SNOW_PATH))
	assert_false(FileAccess.file_exists("res://assets/import/snow.png"))
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var distant := stage.get_node_or_null("FarMountainDistant") as Sprite2D
	var middle := stage.get_node_or_null("FarMountainMiddle") as Sprite2D
	var shoreline := stage.get_node_or_null("FarSnowfield") as TextureRect
	var center_snow := stage.get_node_or_null("ForegroundCenterSnow") as TextureRect
	assert_not_null(distant)
	assert_not_null(middle)
	assert_not_null(shoreline)
	assert_not_null(center_snow)
	if distant == null or middle == null or shoreline == null or center_snow == null:
		return

	assert_eq(distant.texture.resource_path, FAR_MOUNTAIN_PATH)
	assert_eq(middle.texture.resource_path, FAR_MOUNTAIN_PATH)
	assert_true(distant.flip_h,
			"The farthest ridge must break the single-texture repetition")
	assert_false(middle.flip_h)
	assert_eq(distant.position, Vector2(-70.0, -78.0))
	assert_eq(distant.scale, Vector2(6.35, 6.35))
	assert_eq(middle.position, Vector2(-108.0, -36.0))
	assert_eq(middle.scale, Vector2(6.12, 6.12))
	assert_lt(float(distant.get_meta("parallax_factor")),
			float(middle.get_meta("parallax_factor")))
	assert_lt(float(middle.get_meta("parallax_factor")),
			float(shoreline.get_meta("parallax_factor")))
	var distant_rect := _displayed_sprite_used_rect(distant)
	var middle_rect := _displayed_sprite_used_rect(middle)
	var shoreline_rect := _displayed_used_rect(shoreline)
	assert_lt(distant_rect.position.y, middle_rect.position.y)
	assert_lt(middle_rect.position.y, shoreline_rect.position.y)
	assert_lt(distant_rect.end.y, middle_rect.end.y)
	assert_lt(middle_rect.end.y, shoreline_rect.end.y)
	assert_lte(distant_rect.position.x, 0.0)
	assert_gte(distant_rect.end.x, 1920.0)
	assert_lte(middle_rect.position.x, 0.0)
	assert_gte(middle_rect.end.x, 1920.0)
	assert_lt(stage.get_node("AuroraReflection").get_index(), distant.get_index())
	assert_lt(distant.get_index(), middle.get_index())
	assert_lt(middle.get_index(), shoreline.get_index())

	assert_eq(center_snow.texture.resource_path, FOREGROUND_CENTER_SNOW_PATH)
	assert_eq(center_snow.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_almost_eq(center_snow.position.x, 1890.0, 0.001)
	assert_almost_eq(center_snow.position.y, 2198.0, 0.001)
	assert_almost_eq(center_snow.size.x, 649.0686, 0.001)
	assert_almost_eq(center_snow.size.y, 462.0484, 0.001)
	assert_almost_eq(center_snow.rotation, PI, 0.0001)
	assert_eq(center_snow.scale, Vector2(3.0, 3.0))
	var snow_rect := _displayed_used_rect(center_snow)
	assert_between(snow_rect.position.x, -40.0, 0.0)
	assert_between(snow_rect.end.x, 1870.0, 1890.0)
	assert_between(snow_rect.position.y, 1000.0, 1020.0)
	assert_between(snow_rect.end.y, 1405.0, 1425.0)
	assert_gt(snow_rect.position.y, 900.0,
			"Current manual center snow framing must not cover combat feet")
	assert_lt(stage.get_node("BattlePlatform").get_index(), center_snow.get_index())
	assert_lt(center_snow.get_index(), stage.get_node("ForegroundLeft").get_index())


func test_scene8_sky_aurora_follows_scene8_4_bottom_curve_without_breaks() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var aurora := stage.get_node("PixelAurora") as TextureRect
	assert_not_null(aurora)
	if aurora == null:
		return
	var motion_material := aurora.material as ShaderMaterial
	assert_not_null(motion_material,
			"The accepted ref48 texture must animate as one complete curtain")
	if motion_material != null:
		assert_true(motion_material.resource_local_to_scene)
		assert_eq(motion_material.shader.resource_path, PIXEL_AURORA_MOTION_SHADER_PATH)
		assert_eq(motion_material.get_shader_parameter("logical_size"), Vector2(256.0, 144.0))
		var motion_source_texture := motion_material.get_shader_parameter(
				"source_texture") as Texture2D
		assert_not_null(motion_source_texture)
		if motion_source_texture != null:
			assert_eq(motion_source_texture.resource_path, PIXEL_AURORA_TEXTURE_PATH)
		assert_gte(float(motion_material.get_shader_parameter("motion_floor")), 0.60,
				"Every aurora region must participate instead of leaving a static cap")
		assert_between(float(motion_material.get_shader_parameter(
				"primary_cycle_sec")), 24.0, 30.0)
		assert_between(float(motion_material.get_shader_parameter(
				"secondary_cycle_sec")), 34.0, 44.0)
		assert_between(float(motion_material.get_shader_parameter(
				"sway_x_pixels")), 1.4, 2.0)
		assert_between(float(motion_material.get_shader_parameter(
				"sway_y_pixels")), 0.8, 1.3)
		assert_between(float(motion_material.get_shader_parameter(
				"energy_strength")), 0.10, 0.18)
		assert_between(float(motion_material.get_shader_parameter(
				"body_opacity_top")), 0.68, 0.78,
				"The night sky must remain visible through the upper curtain")
		assert_between(float(motion_material.get_shader_parameter(
				"body_opacity_bottom")), 0.84, 0.92,
				"The fluorescent lower rim may remain brighter than the upper curtain")
		assert_between(float(motion_material.get_shader_parameter(
				"halo_strength")), 0.08, 0.20,
				"A restrained pixel halo must blend the texture into the night sky")
		assert_eq(float(motion_material.get_shader_parameter("diagnostic_time_sec")), -1.0)
		var motion_source := FileAccess.get_file_as_string(PIXEL_AURORA_MOTION_SHADER_PATH)
		assert_true(motion_source.contains("TIME"))
		assert_true(motion_source.contains("diagnostic_time_sec"))
		assert_true(motion_source.contains("source_pixel"))
		assert_true(motion_source.contains("floor(source_px + vec2(0.5))"),
				"Motion sampling must stay locked to the accepted 256x144 pixel grid")
		assert_true(motion_source.contains("neighbor_light"))
		assert_true(motion_source.contains("halo_only"))
		assert_false(motion_source.contains("floor(energy * 5.0)"),
				"Slow aurora light must not jump between five coarse brightness levels")
		assert_false(motion_source.contains("discard"),
				"The animation must move the whole source instead of cutting out pieces")
	assert_eq(aurora.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(aurora.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
	assert_eq(aurora.stretch_mode, TextureRect.STRETCH_SCALE)
	assert_eq(aurora.offset_left, -23.0)
	assert_eq(aurora.offset_top, -124.0)
	assert_eq(aurora.offset_right, 258.0)
	assert_eq(aurora.offset_bottom, -150.0,
			"The scene8-4 repair must preserve Eddy's current aurora framing")
	assert_eq(aurora.texture.resource_path, PIXEL_AURORA_TEXTURE_PATH)
	assert_ne(FileAccess.get_sha256(PIXEL_AURORA_TEXTURE_PATH),
			"8adc76919419b2d3516c1a531c0a83e41d267878ba0e386607eb5043e417c90e",
			"The original tree and mountain occlusion gaps must not return")
	assert_ne(FileAccess.get_sha256(PIXEL_AURORA_TEXTURE_PATH),
			"a3b3bc54114cb7eedda063f9d6319262c9ec8ee1c7d1947ea38dd577e480c14b",
			"The rejected mosaic-like full reconstruction must not return")
	assert_ne(FileAccess.get_sha256(PIXEL_AURORA_TEXTURE_PATH),
			"a0170aab022cb2909737841d36264b04877437ea6899046f59de40a0e1e59feb",
			"The red-marked rectangular repair blocks must not return")
	assert_ne(FileAccess.get_sha256(PIXEL_AURORA_TEXTURE_PATH),
			"4782bacab72423b260b146dba9e81eb843038fd9de4bd05008d38ae3309a262a",
			"The scene8-2 black cutouts and generated right tail must not return")
	assert_ne(FileAccess.get_sha256(PIXEL_AURORA_TEXTURE_PATH),
			"c13f98daa5d9c6c066c45b05258f637b9f7235f04f2866d08ce0179905decede",
			"The scene8-3 repair must not erase the entire right curtain body")
	assert_ne(FileAccess.get_sha256(PIXEL_AURORA_TEXTURE_PATH),
			"484eca7f285bd5e75697a2508760ee4f8e727e7f157cea33326575fd34e85bd2",
			"The three scene8-4 bottom breaks and wrong right curve must not return")
	assert_ne(FileAccess.get_sha256(PIXEL_AURORA_TEXTURE_PATH),
			"7f7d7879ae4881227c85e380687abc77524e95f691a73f1a9abab1c5cc4bfd2c",
			"The scene8-4 left rim must not return to dark broken pixels")
	assert_ne(FileAccess.get_sha256(PIXEL_AURORA_TEXTURE_PATH),
			"17bfe6d9a6bc4d4a978b56bc07ed76d61a7434a708b8d2caff562602d8edfc9c",
			"The latest red-circled left silhouette notch must not return")
	assert_eq(FileAccess.get_sha256(PIXEL_AURORA_TEXTURE_PATH),
			"42648aea4431a8d2acd5ee1f8f75fc6633e9ae6c618fdc9ee2d54f75ed488e21",
			"The pixel-verified closed left rim must not drift")
	var image := aurora.texture.get_image()
	var reference := Image.load_from_file(REF48_PATH)
	assert_eq(image.get_size(), Vector2i(256, 144),
			"The aurora must retain the accepted logical pixel scale")
	assert_eq(reference.get_size(), Vector2i(1024, 576))
	var opaque_count := 0
	var exact_source_pixels := 0
	var non_binary_alpha := 0
	var unique_colors: Dictionary[int, bool] = {}
	var top_by_column := PackedInt32Array()
	var bottom_by_column := PackedInt32Array()
	top_by_column.resize(image.get_width())
	top_by_column.fill(-1)
	bottom_by_column.resize(image.get_width())
	bottom_by_column.fill(-1)
	var max_opaque_y := -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			opaque_count += 1
			if top_by_column[x] < 0:
				top_by_column[x] = y
			bottom_by_column[x] = y
			max_opaque_y = maxi(max_opaque_y, y)
			unique_colors[color.to_rgba32()] = true
			non_binary_alpha += int(color.a8 != 255)
			var ref_color := reference.get_pixel(x * 4, y * 4)
			exact_source_pixels += int(
					color.r8 == ref_color.r8
					and color.g8 == ref_color.g8
					and color.b8 == ref_color.b8)
	var internal_transparent_pixels := 0
	var occupied_columns := 0
	var right_bottom_max_delta := 0
	for x: int in image.get_width():
		if top_by_column[x] < 0:
			continue
		occupied_columns += 1
		for y: int in range(top_by_column[x], bottom_by_column[x] + 1):
			internal_transparent_pixels += int(image.get_pixel(x, y).a <= 0.0)
		if x >= 193:
			right_bottom_max_delta = maxi(
					right_bottom_max_delta,
					absi(bottom_by_column[x] - bottom_by_column[x - 1]))
	assert_eq(opaque_count, 7416)
	assert_eq(exact_source_pixels, 6355,
			"Unmarked ref48 pixels must remain stable")
	assert_eq(opaque_count - exact_source_pixels, 1061,
			"The cleanup must remain local to the marked areas")
	assert_eq(occupied_columns, 256,
			"The right curtain body must reach the full logical canvas")
	assert_eq(max_opaque_y, 70)
	assert_eq(unique_colors.size(), 19)
	assert_eq(non_binary_alpha, 0)
	assert_eq(internal_transparent_pixels, 0,
			"No black hole may remain between any column's top and bottom")
	assert_lte(right_bottom_max_delta, 2,
			"The yellow-guided right curve must use continuous pixel steps")
	assert_gt(float(exact_source_pixels) / float(opaque_count), 0.85,
			"The repair must preserve the original pixel allocation, not redesign it")
	var fluorescent_colors := {
		Color("4ac88e").to_rgba32(): true, Color("5ade8b").to_rgba32(): true,
		Color("40f1b9").to_rgba32(): true, Color("6df29e").to_rgba32(): true,
		Color("3cf4dc").to_rgba32(): true, Color("29d8be").to_rgba32(): true,
		Color("39d5ea").to_rgba32(): true, Color("35baef").to_rgba32(): true,
	}
	var dirty_dark_green_colors := {
		Color("226a71").to_rgba32(): true, Color("338c88").to_rgba32(): true,
		Color("37a28f").to_rgba32(): true, Color("44b3bb").to_rgba32(): true,
		Color("53bca7").to_rgba32(): true,
	}
	var marked_dirty_green_pixels := 0
	for rect: Rect2i in [
		Rect2i(146, 45, 9, 14), Rect2i(168, 44, 15, 8), Rect2i(191, 36, 8, 7),
	]:
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var color := image.get_pixel(x, y)
				var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
				marked_dirty_green_pixels += int(
						color.a > 0.0 and dirty_dark_green_colors.has(rgb_key))
	assert_eq(marked_dirty_green_pixels, 0,
			"The three red-marked tree rectangles must use surrounding bright colors")
	var fluorescent_hull_holes := 0
	for x: int in image.get_width():
		var fluorescent_bottom := -1
		for y: int in range(71):
			var color := image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
			if fluorescent_colors.has(rgb_key):
				fluorescent_bottom = y
		if top_by_column[x] < 0 or fluorescent_bottom <= top_by_column[x]:
			continue
		for y: int in range(top_by_column[x], fluorescent_bottom + 1):
			fluorescent_hull_holes += int(image.get_pixel(x, y).a <= 0.0)
	assert_eq(fluorescent_hull_holes, 0,
			"Every scene8-3 black cutout inside the fluorescent curtain must be filled")
	var left_rim_non_fluorescent_pixels := 0
	for x: int in range(74, 101):
		var bottom := bottom_by_column[x]
		var color := image.get_pixel(x, bottom)
		var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
		left_rim_non_fluorescent_pixels += int(not fluorescent_colors.has(rgb_key))
	assert_eq(left_rim_non_fluorescent_pixels, 0,
			"The left scene8-4 red circle must have one continuous fluorescent rim")
	var scene8_3_cutout_rects: Array[Rect2i] = [
		Rect2i(72, 39, 7, 18), Rect2i(82, 49, 12, 21),
		Rect2i(78, 61, 8, 9), Rect2i(157, 58, 6, 6),
		Rect2i(178, 39, 10, 18), Rect2i(186, 43, 9, 15),
	]
	var marked_slot_holes := 0
	for rect: Rect2i in scene8_3_cutout_rects:
		for x: int in range(rect.position.x, rect.end.x):
			var top := -1
			var bottom := -1
			for y: int in range(maxi(rect.position.y - 4, 0), mini(rect.end.y + 4, 70)):
				if image.get_pixel(x, y).a <= 0.0:
					continue
				if top < 0:
					top = y
				bottom = y
			if top < 0 or bottom <= top:
				continue
			for y: int in range(maxi(rect.position.y, top), mini(rect.end.y, bottom + 1)):
				marked_slot_holes += int(image.get_pixel(x, y).a <= 0.0)
	assert_eq(marked_slot_holes, 0,
			"Every scene8-3 red-circled vertical black slot must be opaque")
	var green_tail_colors := {
		Color("4ac88e").to_rgba32(): true, Color("5ade8b").to_rgba32(): true,
		Color("40f1b9").to_rgba32(): true, Color("6df29e").to_rgba32(): true,
		Color("3cf4dc").to_rgba32(): true, Color("29d8be").to_rgba32(): true,
	}
	var right_green_tail_pixels := 0
	for x: int in range(214, image.get_width()):
		for y: int in range(26, 33):
			var color := image.get_pixel(x, y)
			var rgb_key := Color(color.r, color.g, color.b).to_rgba32()
			right_green_tail_pixels += int(
					color.a > 0.0 and green_tail_colors.has(rgb_key))
	assert_eq(right_green_tail_pixels, 0,
			"The detached fluorescent-green source curve must be recolored, not deleted")
	var curve_holes := 0
	var below_curve_pixels := 0
	var left_closure_arc_points: Array[Vector2i] = [
		Vector2i(82, 65), Vector2i(83, 67), Vector2i(85, 67),
		Vector2i(89, 69), Vector2i(93, 70), Vector2i(96, 68),
		Vector2i(100, 63),
	]
	for x: int in range(82, 101):
		var bottom := left_closure_arc_points[-1].y
		for index: int in range(left_closure_arc_points.size() - 1):
			var start := left_closure_arc_points[index]
			var finish := left_closure_arc_points[index + 1]
			if x > finish.x:
				continue
			var t := float(x - start.x) / maxf(float(finish.x - start.x), 1.0)
			bottom = int(roundf(lerpf(start.y, finish.y, t)))
			break
		for y: int in range(top_by_column[x], bottom + 1):
			curve_holes += int(image.get_pixel(x, y).a <= 0.0)
		for y: int in range(bottom + 1, 71):
			below_curve_pixels += int(image.get_pixel(x, y).a > 0.0)
	var yellow_curve_points: Array[Vector2i] = [
		Vector2i(169, 63), Vector2i(180, 52), Vector2i(190, 45),
		Vector2i(197, 43), Vector2i(205, 40), Vector2i(213, 38),
		Vector2i(218, 31), Vector2i(223, 29), Vector2i(238, 29),
		Vector2i(243, 32), Vector2i(255, 30),
	]
	var previous_curve_bottom := -1
	var maximum_curve_step := 0
	for x: int in range(169, image.get_width()):
		var curve_bottom := yellow_curve_points[-1].y
		for index: int in range(yellow_curve_points.size() - 1):
			var start := yellow_curve_points[index]
			var finish := yellow_curve_points[index + 1]
			if x > finish.x:
				continue
			var t := float(x - start.x) / maxf(float(finish.x - start.x), 1.0)
			curve_bottom = int(roundf(lerpf(start.y, finish.y, t)))
			break
		if previous_curve_bottom >= 0:
			maximum_curve_step = maxi(
					maximum_curve_step, absi(curve_bottom - previous_curve_bottom))
		previous_curve_bottom = curve_bottom
		for y: int in range(top_by_column[x], curve_bottom + 1):
			curve_holes += int(image.get_pixel(x, y).a <= 0.0)
		for y: int in range(curve_bottom + 1, 71):
			below_curve_pixels += int(image.get_pixel(x, y).a > 0.0)
	assert_eq(curve_holes, 0,
			"The latest left red-circle arc and the accepted right breaks must stay closed")
	assert_eq(below_curve_pixels, 0,
			"The right lower edge must follow the yellow guide without overhang")
	assert_lte(maximum_curve_step, 2,
			"The yellow-guided curve may change by at most two logical pixels per column")


func test_scene8_aurora_reflection_is_ref48_continuous_water_broken_light() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var reflection := stage.get_node("AuroraReflection") as ColorRect
	var material := reflection.material as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return
	assert_between(float(material.get_shader_parameter(
			"reflection_start_depth")), 0.06, 0.10)
	assert_between(float(material.get_shader_parameter(
			"reflection_end_depth")), 0.84, 0.90)
	assert_between(float(material.get_shader_parameter(
			"reflection_horizontal_stretch")), 1.02, 1.18)
	assert_between(float(material.get_shader_parameter(
			"reflection_source_top_y")), 0.02, 0.06)
	assert_between(float(material.get_shader_parameter(
			"reflection_source_bottom_y")), 0.33, 0.37)
	assert_between(float(material.get_shader_parameter(
			"reflection_floor")), 0.18, 0.30)
	var source := FileAccess.get_file_as_string(AURORA_REFLECTION_SHADER_PATH)
	assert_true(source.contains("float continuous_reflection_zone("))
	assert_true(source.contains("float source_y_from_depth("))
	assert_true(source.contains("reflection_horizontal_stretch"))
	assert_true(source.contains("mix(reflection_floor, 1.0"),
			"The lake must retain a quiet reflected body between brighter wave crests")
	assert_true(source.contains("* reflection_zone"))
	assert_true(source.contains("* reflection_wave"),
			"Water motion must break the continuous sampled light")
	assert_false(source.contains("interval_mask"))
	assert_false(source.contains("broken_band_segments"))
	assert_false(source.contains("reflection_band_depths"))
	assert_false(source.contains("reflection_band_widths"))
	assert_false(source.contains("four_band_mask"))
	assert_false(source.contains("six_lane_mask"))
	assert_false(source.contains("nearest_lane_index"))
	assert_false(source.contains("reflection_lane_depths"))


func test_scene8_open_lake_is_water_first_and_preserves_layer_contract() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var lake := stage.get_node_or_null("MirrorLake") as ColorRect
	var reflection := stage.get_node_or_null("AuroraReflection") as ColorRect
	var reflection_grab := (
			stage.get_node_or_null("AuroraReflectionGrab") as BackBufferCopy)
	assert_not_null(lake)
	assert_not_null(reflection)
	assert_not_null(reflection_grab)
	if lake == null or reflection == null or reflection_grab == null:
		return
	var lake_material := lake.material as ShaderMaterial
	var reflection_material := reflection.material as ShaderMaterial
	assert_not_null(lake_material)
	assert_not_null(reflection_material)
	if lake_material == null or reflection_material == null:
		return
	assert_true(lake_material.resource_local_to_scene)
	assert_true(reflection_material.resource_local_to_scene)
	assert_eq(lake_material.shader.resource_path, OPEN_LAKE_SHADER_PATH)
	assert_eq(reflection_material.shader.resource_path,
			AURORA_REFLECTION_SHADER_PATH)
	assert_eq(lake_material.get_shader_parameter("pixel_grid"),
			Vector2(320.0, 180.0))
	assert_eq(reflection_material.get_shader_parameter("pixel_grid"),
			Vector2(320.0, 180.0))
	assert_almost_eq(float(lake_material.get_shader_parameter("horizon_y")),
			float(reflection_material.get_shader_parameter("horizon_y")), 0.0001)
	assert_between(float(lake_material.get_shader_parameter("horizon_y")),
			0.50, 0.55)
	assert_lte(float(lake_material.get_shader_parameter("thin_ice_depth")), 0.040)
	assert_lte(float(lake_material.get_shader_parameter("thin_ice_presence")), 0.45)
	assert_lte(float(lake_material.get_shader_parameter("shore_ice_reach")), 0.18)
	assert_between(float(lake_material.get_shader_parameter(
			"shore_ice_opacity")), 0.48, 0.62)
	assert_between(float(lake_material.get_shader_parameter(
			"near_floe_min_depth")), 0.62, 0.72)
	assert_between(float(lake_material.get_shader_parameter(
			"near_floe_max_depth")), 0.88, 0.94)
	assert_lte(float(lake_material.get_shader_parameter(
			"near_floe_opacity")), 0.56)
	assert_lte(float(lake_material.get_shader_parameter("bank_shadow_distance")),
			0.22)
	var far_color: Color = lake_material.get_shader_parameter("far_color")
	var middle_color: Color = lake_material.get_shader_parameter("middle_color")
	var near_color: Color = lake_material.get_shader_parameter("near_color")
	for water_color: Color in [far_color, middle_color, near_color]:
		assert_gt(water_color.b, water_color.g)
		assert_gt(water_color.g, water_color.r)
	assert_between(float(reflection_material.get_shader_parameter(
			"reflection_strength")), 0.60, 0.72)
	assert_between(float(reflection_material.get_shader_parameter(
			"reflection_saturation")), 1.16, 1.28)
	assert_between(float(reflection_material.get_shader_parameter(
			"reflection_value_ceiling")), 0.86, 0.95)
	assert_lte(float(reflection_material.get_shader_parameter(
			"wave_max_offset_cells")), 2.0)
	assert_eq(reflection_grab.copy_mode, BackBufferCopy.COPY_MODE_VIEWPORT)
	assert_lt(stage.get_node("PixelAurora").get_index(),
			reflection_grab.get_index())
	assert_lt(reflection_grab.get_index(),
			stage.get_node("FarSnowfield").get_index(),
			"Only the sky and aurora may enter the reflection source")
	assert_lt(lake.get_index(), reflection.get_index(),
			"The opaque water base must draw before its transparent reflection")
	assert_lt(reflection.get_index(), stage.get_node("FarSnowfield").get_index(),
			"The mountain alpha must occlude both water layers at the shoreline")
	assert_lt(reflection.get_index(), stage.get_node("BattlePlatform").get_index())
	var reflection_source := FileAccess.get_file_as_string(
			AURORA_REFLECTION_SHADER_PATH)
	assert_true(reflection_source.contains("cool_chroma"))
	assert_true(reflection_source.contains("aurora_presence"),
			"White stars and ordinary blue night sky must not activate the bands")
	assert_true(reflection_source.contains("star_rejection"))
	assert_true(reflection_source.contains("relative_saturation"),
			"Low-saturation cool-white stars must be rejected explicitly")
	assert_true(reflection_source.contains("reflection_saturation"))
	assert_true(reflection_source.contains("textureLod(screen_tex"),
			"Reflection must use the live sky and aurora capture")
	assert_eq(reflection_source.count("textureLod(screen_tex"), 1,
			"All reflection lanes must share one nearest screen sample per fragment")


func test_scene8_lake_palette_and_ice_follow_topology_without_hard_bands() -> void:
	var lake_source := FileAccess.get_file_as_string(OPEN_LAKE_SHADER_PATH)
	assert_true(lake_source.contains("floor(UV * pixel_grid)"))
	assert_true(lake_source.contains("uniform sampler2D lake_topology"))
	assert_true(lake_source.contains("use_lake_topology"))
	assert_true(lake_source.contains("topology.r"))
	assert_true(lake_source.contains("topology.g"),
			"Shore shadow and attached ice must follow measured shoreline distance")
	assert_true(lake_source.contains("topology.b"),
			"Water palette and perspective waves must follow per-column depth")
	assert_true(lake_source.contains("ordered_dither_4x4"))
	assert_true(lake_source.contains("topology_palette"))
	assert_true(lake_source.contains("bank_shadow_mask"))
	assert_true(lake_source.contains("shore_ice_mask"))
	assert_true(lake_source.contains("near_floe_mask"))
	assert_true(lake_source.contains("irregular_floe_shape"))
	assert_true(lake_source.contains("near_floe_contact"))
	assert_true(lake_source.contains("shore_distance"))
	assert_false(lake_source.contains("motion_time()") and
			lake_source.contains("near_floe_mask(cell, depth, motion_time"),
			"Near floe bodies stay still while the surrounding shared wave moves")
	assert_false(lake_source.contains("step(0.24, depth)"),
			"A full-width far/middle color boundary is forbidden")
	assert_false(lake_source.contains("step(0.68, depth)"),
			"A full-width middle/near color boundary is forbidden")
	for obsolete_symbol: String in [
		"ice_chunk_cells",
		"ice_start",
		"ice_end",
		"ice_span",
		"ice_jag_depth",
	]:
		assert_false(lake_source.contains(obsolete_symbol),
				"Rectangular x-axis ice construction must stay removed: %s"
				% obsolete_symbol)


func test_scene8_lake_and_reflection_share_one_bounded_wave_field() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate()
	add_child_autofree(stage)
	var lake_material := (
			stage.get_node("MirrorLake") as ColorRect).material as ShaderMaterial
	var reflection_material := (
			stage.get_node("AuroraReflection") as ColorRect).material as ShaderMaterial
	assert_not_null(lake_material)
	assert_not_null(reflection_material)
	if lake_material == null or reflection_material == null:
		return
	for parameter_name: String in [
		"wave_cycle_sec",
		"wave_travel_cells_per_sec",
		"wave_max_offset_cells",
		"far_wave_stride_cells",
		"near_wave_stride_cells",
		"far_wave_segment_cells",
		"near_wave_segment_cells",
		"wave_presence",
		"shore_distance_cells",
		"diagnostic_time_sec",
	]:
		assert_almost_eq(
				float(lake_material.get_shader_parameter(parameter_name)),
				float(reflection_material.get_shader_parameter(parameter_name)),
				0.0001,
				"Shared wave parameter drifted: %s" % parameter_name)
	assert_lte(float(reflection_material.get_shader_parameter(
			"wave_max_offset_cells")), 2.0)

	var lake_source := FileAccess.get_file_as_string(OPEN_LAKE_SHADER_PATH)
	var reflection_source := FileAccess.get_file_as_string(
			AURORA_REFLECTION_SHADER_PATH)
	assert_true(reflection_source.contains("hint_screen_texture"))
	assert_true(reflection_source.contains("uniform sampler2D lake_topology"))
	assert_true(reflection_source.contains("use_lake_topology"))
	assert_true(reflection_source.contains("topology.r"))
	assert_true(reflection_source.contains("filter_nearest"))
	assert_true(reflection_source.contains("floor(UV * pixel_grid)"))
	assert_true(reflection_source.contains("continuous_reflection_zone"))
	assert_true(reflection_source.contains("source_y_from_depth"),
			"Water depth must continuously sample the broad ref48 curtains")
	assert_false(reflection_source.contains("slice_cells"),
			"Generic repeated reflection slicing must stay removed")
	assert_true(reflection_source.contains("shared_wave_field"))
	assert_true(lake_source.contains(
			"vec2 cell = floor(topology_uv * pixel_grid)"))
	assert_true(reflection_source.contains(
			"vec2 cell = floor(topology_uv * pixel_grid)"),
			"Both layers must derive wave cells from the shared topology mapping")
	assert_true(reflection_source.contains("reflection_wave"),
			"Reflection breakup must be driven by the shared lake wave")
	assert_true(reflection_source.contains("x_offset_cells = round(clamp("),
			"Reflection lateral offsets must be integer logical cells")
	assert_true(reflection_source.contains("shore_reflection_fade"),
			"Reflection must clear the shore-attached ice zone")
	assert_true(reflection_source.contains("reflection_horizontal_stretch"))
	assert_false(reflection_source.contains("signed_pixel_snap"))
	assert_false(reflection_source.contains("period_sec"))
	assert_false(reflection_source.contains("breakup_segment_cells"))
	assert_false(reflection_source.contains("step(0.12, luma)"))
	assert_false(reflection_source.contains("step(0.38, luma)"))
	assert_false(reflection_source.contains("water_reflection_palette"),
			"The lake must keep the sampled sky color instead of repainting it")
	assert_true(lake_source.contains(SHARED_WATER_WAVE_INCLUDE_PATH))
	assert_true(reflection_source.contains(SHARED_WATER_WAVE_INCLUDE_PATH))
	var shared_wave_source := FileAccess.get_file_as_string(
			SHARED_WATER_WAVE_INCLUDE_PATH)
	assert_true(shared_wave_source.contains("vec3 shared_wave_field("))
	assert_true(shared_wave_source.contains("diagnostic_time_sec"))
	assert_true(shared_wave_source.contains("wave_max_offset_cells"))
	assert_true(shared_wave_source.contains(
			"horizon_y - 2.0 / max(pixel_grid.y, 1.0)"),
			"The shared fallback topology must retain two hidden overlap rows")
	assert_true(shared_wave_source.contains("moving_cell_x"),
			"Shared wave motion must stay lateral")
	assert_false(shared_wave_source.contains("cell.y + time"),
			"Shared wave rows must not crawl vertically")
	assert_false(lake_source.contains("float scene8_hash21("),
			"Lake must not fork a private wave hash")
	assert_false(reflection_source.contains("float scene8_hash21("),
			"Reflection must not fork a private wave hash")
	var reflection_coverage_depth := float(
			reflection_material.get_shader_parameter("reflection_coverage_depth"))
	var reflection_end_depth := float(
			reflection_material.get_shader_parameter("reflection_end_depth"))
	assert_gt(reflection_coverage_depth, reflection_end_depth,
			"The continuous reflected area must fade before lake coverage ends")


func test_scene8_guides_keep_the_mature_character_baseline() -> void:
	if not ResourceLoader.exists(SCENE8_PATH):
		return

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_eq(
			(stage.get_node("CompositionGuides/P1Baseline") as Marker2D).position,
			Vector2(480.0, 748.0))
	assert_eq(
			(stage.get_node("CompositionGuides/P2Baseline") as Marker2D).position,
			Vector2(1440.0, 748.0))
	assert_eq(
			(stage.get_node("CompositionGuides/PlatformBaseline") as Marker2D).position,
			Vector2(960.0, 748.0))


func test_scene8_entry_reuses_shared_ui_characters_input_and_parallax() -> void:
	if not ResourceLoader.exists(BATTLE8_PATH):
		return

	BattleSetup.reset()
	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE8_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.stage, screen.get_node("StageSlot/Stage"))
	assert_eq(screen.stage.scene_file_path, SCENE8_PATH)
	assert_true(screen.stage.pointer_parallax)
	assert_false(screen.stage.demo_click_shake)
	assert_eq(screen.p1_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p2_char_display.get_parent().name, "WorldGroup")
	assert_eq(screen.p1_char_display.size,
			(base.get_node("P1CharDisplay") as CharacterDisplay).size)
	assert_eq(screen.p2_char_display.size,
			(base.get_node("P2CharDisplay") as CharacterDisplay).size)
	assert_not_null(screen.p1_char_display.get_render_texture())
	assert_not_null(screen.p2_char_display.get_render_texture())
	for node_path: String in [
		"P1Hud",
		"P2Hud",
		"TimerLabel",
		"Buttons",
		"DeathSwitchOverlay",
	]:
		assert_true(screen.has_node(node_path))
	for dust_name: String in ["ForeDust", "LowerDust"]:
		var dust := screen.get_node(dust_name) as GPUParticles2D
		assert_false(dust.visible)
		assert_false(dust.emitting)
	base.free()
	BattleSetup.reset()


func test_scene8_characters_receive_local_slow_aurora_light() -> void:
	if not ResourceLoader.exists(BATTLE8_PATH):
		return

	BattleSetup.reset()
	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate()
	var screen := (load(BATTLE8_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var materials: Array[ShaderMaterial] = []
	for display: CharacterDisplay in [
			screen.p1_char_display,
			screen.p2_char_display,
	]:
		var sprite := display.get_node("SubViewport/AnimatedSprite2D") \
				as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		assert_not_null(material)
		if material == null:
			continue
		materials.append(material)
		assert_true(material.resource_local_to_scene)
		assert_eq(material.shader.resource_path, CHARACTER_LIGHT_SHADER_PATH)
		if material.shader.resource_path != CHARACTER_LIGHT_SHADER_PATH:
			continue
		assert_between(float(material.get_shader_parameter(
				"scene_exposure")), 0.86, 0.94)
		assert_between(float(material.get_shader_parameter(
				"night_grade_amount")), 0.34, 0.52)
		assert_between(float(material.get_shader_parameter(
				"scene_identity_floor")), 0.72, 0.86)
		assert_between(float(material.get_shader_parameter(
				"warm_identity_protection")), 0.7, 0.86)
		assert_between(float(material.get_shader_parameter(
				"aurora_key_amount")), 0.20, 0.30)
		assert_between(float(material.get_shader_parameter(
				"violet_bounce_amount")), 0.08, 0.18)
		assert_between(float(material.get_shader_parameter(
				"aurora_cycle_sec")), 24.0, 36.0)
		assert_lte(float(material.get_shader_parameter(
				"aurora_flow_amount")), 0.16,
				"Aurora color may drift slowly but must not flash over the character")
		assert_between(float(material.get_shader_parameter(
				"rim_strength")), 0.16, 0.30)
		assert_eq(float(material.get_shader_parameter("rim_width")), 1.0)
	assert_eq(materials.size(), 2)
	if materials.size() == 2:
		assert_ne(materials[0], materials[1],
				"P1/P2 need isolated runtime materials for independent feedback")
		var p1_direction: Vector2 = materials[0].get_shader_parameter("light_dir")
		var p2_direction: Vector2 = materials[1].get_shader_parameter("light_dir")
		assert_almost_eq(p1_direction.x, -p2_direction.x, 0.0001)
		assert_almost_eq(p1_direction.y, p2_direction.y, 0.0001)
		assert_lt(p1_direction.y, -0.8)
	var shader_source := FileAccess.get_file_as_string(CHARACTER_LIGHT_SHADER_PATH)
	assert_true(shader_source.contains("texture(TEXTURE, UV)"))
	assert_true(shader_source.contains("TEXTURE_PIXEL_SIZE"))
	assert_true(shader_source.contains("TIME / max(aurora_cycle_sec"))
	assert_true(shader_source.contains("preserve_luma_tint"))
	assert_false(shader_source.contains("floor("),
			"Character aurora must be continuous, not stepped color flashing")
	assert_eq(screen.p1_char_display.position,
			(base.get_node("P1CharDisplay") as CharacterDisplay).position)
	assert_eq(screen.p2_char_display.position,
			(base.get_node("P2CharDisplay") as CharacterDisplay).position)
	base.free()
	BattleSetup.reset()


func test_scene8_keeps_neutral_post_processing() -> void:
	if not ResourceLoader.exists(BATTLE8_PATH):
		return

	var screen := (load(BATTLE8_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var material := (screen.get_node("PostFX") as ColorRect).material as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return
	assert_true(material.resource_local_to_scene)
	assert_eq(float(material.get_shader_parameter("barrel_amount")), 0.0)
	assert_eq(float(material.get_shader_parameter("edge_blur_amount")), 0.0)
	assert_eq(float(material.get_shader_parameter("brightness")), 1.0)
	assert_eq(float(material.get_shader_parameter("contrast")), 1.0)
	assert_eq(float(material.get_shader_parameter("saturation")), 1.0)
	assert_eq(float(material.get_shader_parameter("tint_strength")), 0.0)
	assert_eq(float(material.get_shader_parameter("split_strength")), 0.0)
	assert_eq(float(material.get_shader_parameter("vignette_strength")), 0.0)
	assert_eq(float(material.get_shader_parameter("grain_amount")), 0.0)
	assert_eq(float(material.get_shader_parameter("heat_haze_strength")), 0.0)


func _displayed_used_rect(layer: TextureRect) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.03)
	var texture_size := Vector2(layer.texture.get_size())
	var source_to_node := layer.size / texture_size
	var local_rect := Rect2(
			Vector2(used_rect.position) * source_to_node,
			Vector2(used_rect.size) * source_to_node)
	var layer_transform := Transform2D(
			layer.rotation, layer.scale, 0.0, layer.position)
	var corners: Array[Vector2] = [
		layer_transform * local_rect.position,
		layer_transform * Vector2(local_rect.end.x, local_rect.position.y),
		layer_transform * local_rect.end,
		layer_transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var minimum := corners[0]
	var maximum := corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _displayed_sprite_used_rect(layer: Sprite2D) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.03)
	var left := float(used_rect.position.x)
	if layer.flip_h:
		left = float(layer.texture.get_width() - used_rect.end.x)
	return Rect2(
			layer.position + Vector2(left, used_rect.position.y) * layer.scale,
			Vector2(used_rect.size) * layer.scale)


func _alpha_used_rect(image: Image, threshold: float) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < threshold:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _bottom_alpha_row(image: Image, x: int, threshold: float) -> int:
	for y: int in range(image.get_height() - 1, -1, -1):
		if image.get_pixel(x, y).a >= threshold:
			return y
	return -1


func _scene8_stable_hash(value: float) -> float:
	return fposmod(sin(value * 12.9898) * 43758.5453, 1.0)
