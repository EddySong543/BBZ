extends GutTest

const SCENE1_PATH := "res://src/ui/scenes/scene1.tscn"
const SCENE5_PATH := "res://src/ui/scenes/scene5.tscn"
const BATTLE_BASE_PATH := "res://src/ui/battle_screen_base.tscn"
const BATTLE1_PATH := "res://src/ui/battle_screen1.tscn"
const BATTLE5_PATH := "res://src/ui/battle_screen5.tscn"
const SKY_PATH := "res://assets/scenes/scene5/scene5_sky.png"
const SKY_OVERLAY_PATH := (
		"res://assets/scenes/scene5/scene5_sky_overlay.png")
const FAR_WHEAT_PATH := "res://assets/scenes/scene5/scene5_far_wheat.png"
const DISTANT_FIELD_PATH := (
		"res://assets/scenes/scene5/scene5_distant_field.png")
const GROUND_PATH := "res://assets/scenes/scene5/scene5_ground.png"
const NEAR_WHEAT_PATH := (
		"res://assets/scenes/scene5/scene5_near_wheat.png")
const WIND_SHADER_PATH := (
		"res://assets/shaders/scene5_wheat_wind.gdshader")
const SUN_RAY_SHADER_PATH := (
		"res://assets/shaders/scene5_sun_rays.gdshader")
const PIXEL_CLOUD_SHADER_PATH := (
		"res://assets/shaders/canvas_env_dark_smoke.gdshader")
const DISTANT_WHEAT_SHADER_PATH := (
		"res://assets/shaders/scene5_distant_wheat_light.gdshader")
const WIND_SCRIPT_PATH := (
		"res://src/ui/components/scene5_wind_field.gd")
const WHEAT_MESH_SCRIPT_PATH := (
		"res://src/ui/components/scene5_wheat_mesh.gd")
const CHAFF_PATH := (
		"res://assets/scenes/scene5/scene5_wind_chaff_atlas.png")


func test_scene5_has_an_independent_layered_stage_contract() -> void:
	assert_true(ResourceLoader.exists(SCENE5_PATH))
	if not ResourceLoader.exists(SCENE5_PATH):
		return

	var host := Control.new()
	host.size = Vector2(1920.0, 1080.0)
	add_child_autofree(host)
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	host.add_child(stage)
	await get_tree().process_frame
	assert_eq(stage.size, Vector2(1920.0, 1080.0))
	assert_true(stage.pointer_parallax)
	assert_false(stage.demo_click_shake)

	var depth_layers: Array[String] = [
		"Sky",
		"SunRayField",
		"SkyOverlay",
		"UpperCloud",
		"HorizonHaze",
		"DistantWheat",
		"MidFarWheat",
		"FarWheat",
		"FarWheatCoverBack",
		"MidFieldHaze",
		"Atmosphere",
		"AmbientChaff",
		"BattlePlatform",
		"GustChaff",
		"NearWheatLeft",
	]
	var previous_factor := -1.0
	for layer_name: String in depth_layers:
		assert_true(stage.has_node(layer_name))
		if not stage.has_node(layer_name):
			continue
		var layer := stage.get_node(layer_name) as CanvasItem
		assert_not_null(layer)
		assert_eq(layer.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		var parallax_factor := float(layer.get_meta("parallax_factor"))
		assert_gte(parallax_factor, previous_factor)
		previous_factor = parallax_factor
		assert_true(layer.has_meta("asset_slot"))

	var texture_layers: Dictionary[String, String] = {
		"Sky": SKY_PATH,
		"SkyOverlay": SKY_OVERLAY_PATH,
		"MidFarWheat": FAR_WHEAT_PATH,
		"FarWheat": FAR_WHEAT_PATH,
		"FarWheatCoverBack": FAR_WHEAT_PATH,
		"NearWheatLeft": NEAR_WHEAT_PATH,
	}
	for layer_name: String in texture_layers:
		var layer := stage.get_node(layer_name) as CanvasItem
		var texture := layer.get("texture") as Texture2D
		assert_not_null(texture)
		assert_eq(texture.resource_path, texture_layers[layer_name])
		assert_false(bool(layer.get_meta("placeholder")))

	var far_wheat := stage.get_node("FarWheat") as Control
	assert_eq(far_wheat.get_script().resource_path, WHEAT_MESH_SCRIPT_PATH)
	assert_gte(int(far_wheat.get("mesh_columns")), 24)
	assert_gte(int(far_wheat.get("mesh_rows")), 8)
	# The authored mesh may begin a few pixels inside the viewport; the important
	# contract is that its scaled right edge still covers the full composition.
	assert_lte(far_wheat.position.x, 8.0)
	assert_gte(far_wheat.position.x + far_wheat.size.x * far_wheat.scale.x, 1920.0)
	assert_false(stage.has_node("MidWheat"))
	assert_false(stage.has_node("Cloud"))
	var mid_far_wheat := stage.get_node("MidFarWheat") as Control
	assert_eq(mid_far_wheat.get_script().resource_path, WHEAT_MESH_SCRIPT_PATH)
	assert_gte(int(mid_far_wheat.get("mesh_columns")), 80)
	assert_gte(int(mid_far_wheat.get("mesh_rows")), 18)
	assert_lte(mid_far_wheat.position.x, 0.0)
	assert_gte(
			mid_far_wheat.position.x
					+ mid_far_wheat.size.x * mid_far_wheat.scale.x,
			1920.0)
	assert_lt(stage.get_node("DistantWheat").get_index(), mid_far_wheat.get_index())
	assert_lt(mid_far_wheat.get_index(), far_wheat.get_index())
	assert_lt(
			float(stage.get_node("DistantWheat").get_meta("parallax_factor")),
			float(mid_far_wheat.get_meta("parallax_factor")))
	assert_lt(
			float(mid_far_wheat.get_meta("parallax_factor")),
			float(far_wheat.get_meta("parallax_factor")))
	var cover_back := stage.get_node_or_null("FarWheatCoverBack") as Control
	assert_not_null(cover_back)
	if cover_back != null:
		assert_eq(cover_back.get_script().resource_path, WHEAT_MESH_SCRIPT_PATH)
		assert_gte(int(cover_back.get("mesh_columns")), 88)
		assert_gte(int(cover_back.get("mesh_rows")), 20)
		assert_lte(cover_back.position.x, 0.0)
		assert_gte(cover_back.position.x + cover_back.size.x * cover_back.scale.x, 1920.0)
		assert_lt(far_wheat.get_index(), cover_back.get_index())
		assert_lt(cover_back.get_index(), stage.get_node("MidFieldHaze").get_index())
		assert_lt(
				float(far_wheat.get_meta("parallax_factor")),
				float(cover_back.get_meta("parallax_factor")))
		assert_lt(
				float(cover_back.get_meta("parallax_factor")),
				float(stage.get_node("MidFieldHaze").get_meta("parallax_factor")))
	assert_false(stage.has_node("FarWheatCoverFront"))

	var distant_field := stage.get_node("DistantWheat") as TextureRect
	assert_not_null(distant_field.texture)
	assert_eq(distant_field.texture.resource_path, DISTANT_FIELD_PATH)
	assert_eq(distant_field.anchor_right, 1.0)
	assert_eq(distant_field.anchor_bottom, 1.0)
	assert_false(bool(distant_field.get_meta("placeholder")))
	var rays := stage.get_node("SunRayField") as ColorRect
	var ray_material := rays.material as ShaderMaterial
	assert_not_null(ray_material)
	assert_eq(ray_material.shader.resource_path, SUN_RAY_SHADER_PATH)
	assert_gt(
			float(ray_material.get_shader_parameter("ray_intensity")),
			0.0)
	assert_gte(
			float(ray_material.get_shader_parameter("ray_width_scale")),
			2.4)
	assert_gt(
			float(ray_material.get_shader_parameter("drift_amount")),
			0.0)
	assert_gte(
			float(ray_material.get_shader_parameter("gate_speed")),
			0.5)
	assert_true(ray_material.shader.code.contains("slow_gate"))
	assert_gt(stage.get_node("SkyOverlay").get_index(), rays.get_index())
	assert_gt(stage.get_node("UpperCloud").get_index(), rays.get_index())
	assert_gt(stage.get_node("FarWheat").self_modulate.g, 0.95)
	assert_lt(stage.get_node("NearWheatLeft").self_modulate.r, 0.65)

	var platform := stage.get_node("BattlePlatform") as NinePatchRect
	assert_not_null(platform)
	assert_eq(platform.texture.resource_path, GROUND_PATH)
	assert_eq(platform.patch_margin_left, 8)
	assert_eq(platform.patch_margin_right, 8)
	assert_eq(platform.scale, Vector2(2.0, 2.0))
	assert_eq(platform.position.y, 600.0)
	assert_lt(platform.self_modulate.r, 0.9)
	assert_lt(platform.self_modulate.g, 1.0)
	assert_false(bool(platform.get_meta("placeholder")))
	var near_left := stage.get_node("NearWheatLeft") as Control
	assert_eq(near_left.get_script().resource_path, WHEAT_MESH_SCRIPT_PATH)
	assert_gte(int(near_left.get("mesh_columns")), 24)
	assert_gte(int(near_left.get("mesh_rows")), 8)
	assert_lte(near_left.position.x, 0.0)
	assert_gte(near_left.position.x + near_left.size.x * near_left.scale.x, 1920.0)
	assert_gte(near_left.position.y + near_left.size.y * near_left.scale.y, 1080.0)
	assert_lt(stage.get_node("MidFieldHaze").get_index(), platform.get_index())
	assert_lt(platform.get_index(), near_left.get_index())
	assert_false(stage.has_node("Foreground"))
	assert_false(stage.has_node("ForegroundOverlay"))
	var platform_baseline := stage.get_node(
			"CompositionGuides/PlatformBaseline") as Marker2D
	assert_eq(platform_baseline.position.y, 748.0)


func test_scene5_upper_cloud_preserves_original_shape_at_decorative_speed() -> void:
	var host := Control.new()
	host.size = Vector2(1920.0, 1080.0)
	add_child_autofree(host)
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	host.add_child(stage)
	await get_tree().process_frame
	var upper_cloud := stage.get_node_or_null("UpperCloud") as Control
	assert_not_null(upper_cloud)
	if upper_cloud == null:
		return
	assert_true(upper_cloud.visible)
	assert_eq(upper_cloud.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(upper_cloud.get_child_count(), 1)
	for child: Node in upper_cloud.get_children():
		var band := child as ColorRect
		assert_not_null(band)
		if band == null:
			continue
		var material := band.material as ShaderMaterial
		assert_not_null(material)
		if material == null:
			continue
		assert_eq(material.shader.resource_path, PIXEL_CLOUD_SHADER_PATH)
		var flow_speed := float(material.get_shader_parameter("flow_speed"))
		assert_lt(flow_speed, 0.0)
		assert_between(absf(flow_speed), 0.0025, 0.0045)
		assert_between(
				float(material.get_shader_parameter("alpha_max")),
				0.12,
				0.4)
		assert_eq(float(material.get_shader_parameter("inner_contrast")), 0.0)
		assert_eq(float(material.get_shader_parameter("smooth_flow")), 0.0)
		assert_eq(float(material.get_shader_parameter("motion_blend")), 1.0)
		assert_eq(float(material.get_shader_parameter("lobe_profile")), 1.0)
		assert_almost_eq(
				float(material.get_shader_parameter("cloud_size")),
				1.18,
				0.001)
	var cloud_shader_source := FileAccess.get_file_as_string(
			PIXEL_CLOUD_SHADER_PATH)
	assert_string_contains(cloud_shader_source, "motion_blend")
	assert_string_contains(cloud_shader_source, "next_flow")
	assert_string_contains(cloud_shader_source, "cover_next")
	var main_band := upper_cloud.get_node("CloudMain") as ColorRect
	var main_material := main_band.material as ShaderMaterial
	assert_eq(main_band.size, Vector2(2080.0, 300.0))
	assert_eq(float(main_material.get_shader_parameter("seed")), 35.0)
	assert_gte(float(main_material.get_shader_parameter("alpha_max")), 0.32)
	assert_eq(float(main_material.get_shader_parameter("row_count")), 4.0)
	assert_almost_eq(
			float(main_material.get_shader_parameter("lobe_height_scale")),
			0.68,
			0.001)


func test_scene5_wind_field_is_readable_and_reacts_to_battle() -> void:
	var host := Control.new()
	host.size = Vector2(1920.0, 1080.0)
	add_child_autofree(host)
	var stage := (load(SCENE5_PATH) as PackedScene).instantiate() as BattleStage
	host.add_child(stage)
	await get_tree().process_frame

	var wind_field := stage.get_node_or_null("WindField")
	assert_not_null(wind_field)
	assert_eq(wind_field.get_script().resource_path, WIND_SCRIPT_PATH)
	var wind_shader_source := FileAccess.get_file_as_string(WIND_SHADER_PATH)
	assert_false(wind_shader_source.contains("layer_mode"))
	assert_false(wind_shader_source.contains("depth_layer_alpha"))
	assert_string_contains(wind_shader_source, "void vertex()")
	assert_string_contains(wind_shader_source, "smooth_triangle_wave")
	assert_string_contains(wind_shader_source, "field_wave_strength")
	assert_string_contains(wind_shader_source, "depth_haze_strength")
	assert_false(wind_shader_source.contains("cluster_motion"))
	for layer_name: String in [
		"FarWheat",
		"FarWheatCoverBack",
		"NearWheatLeft",
	]:
		assert_true(stage.has_node(layer_name))
		if not stage.has_node(layer_name):
			continue
		var layer := stage.get_node(layer_name) as Control
		var material := layer.material as ShaderMaterial
		assert_not_null(material)
		assert_eq(material.shader.resource_path, WIND_SHADER_PATH)
		assert_gte(float(material.get_shader_parameter("cluster_count")), 8.0)
		assert_gt(float(material.get_shader_parameter("sway_px")), 1.5)
		assert_gt(float(material.get_shader_parameter("root_y")), 0.5)
	var far_material := (
			stage.get_node("FarWheat") as Control
			).material as ShaderMaterial
	var mid_far_wheat := stage.get_node("MidFarWheat") as Control
	var mid_far_material := mid_far_wheat.material as ShaderMaterial
	assert_not_null(mid_far_material)
	assert_ne(mid_far_material, far_material)
	assert_eq(mid_far_material.shader.resource_path, WIND_SHADER_PATH)
	assert_gte(float(mid_far_material.get_shader_parameter("cluster_count")), 8.0)
	assert_gt(float(mid_far_material.get_shader_parameter("sway_px")), 0.8)
	assert_lt(
			float(mid_far_material.get_shader_parameter("sway_px")),
			float(far_material.get_shader_parameter("sway_px")))
	assert_lt(
			float(mid_far_material.get_shader_parameter("field_wave_speed")),
			float(far_material.get_shader_parameter("field_wave_speed")))
	assert_between(
			float(mid_far_material.get_shader_parameter("shape_wave_vertical_px")),
			2.0,
			3.2)
	assert_between(
			float(mid_far_material.get_shader_parameter("shape_wave_horizontal_px")),
			1.0,
			2.2)
	assert_gt(
			float(mid_far_material.get_shader_parameter("depth_haze_strength")),
			float(far_material.get_shader_parameter("depth_haze_strength")))
	assert_lt(mid_far_wheat.self_modulate.a, stage.get_node("FarWheat").self_modulate.a)
	var wind_layer_paths: Array[NodePath] = wind_field.get("wind_layer_paths")
	assert_has(wind_layer_paths, NodePath("../MidFarWheat"))
	assert_has(wind_layer_paths, NodePath("../FarWheatCoverBack"))
	assert_does_not_have(wind_layer_paths, NodePath(""))
	var cover_back_material := (
			stage.get_node_or_null("FarWheatCoverBack") as Control
			).material as ShaderMaterial if stage.has_node("FarWheatCoverBack") else null
	assert_not_null(cover_back_material)
	if cover_back_material != null:
		assert_ne(cover_back_material, far_material)
		assert_gte(float(cover_back_material.get_shader_parameter("clip_top")), 0.36)
	assert_gte(
			float(far_material.get_shader_parameter("field_wave_strength")),
			0.08)
	assert_between(
			float(far_material.get_shader_parameter("field_highlight_threshold")),
			0.55,
			0.85)
	assert_between(
			float(far_material.get_shader_parameter("field_wave_width")),
			0.08,
			0.28)
	assert_lte(
			float(far_material.get_shader_parameter("field_wave_speed")),
			0.025)
	assert_string_contains(wind_shader_source, "source_highlight_mask")
	assert_string_contains(wind_shader_source, "moving_wave_mask")
	var distant_wheat := stage.get_node("DistantWheat") as TextureRect
	var distant_material := distant_wheat.material as ShaderMaterial
	assert_not_null(distant_material)
	assert_eq(
			distant_material.shader.resource_path,
			DISTANT_WHEAT_SHADER_PATH)
	assert_almost_eq(
			float(distant_material.get_shader_parameter("wave_speed")),
			float(far_material.get_shader_parameter("field_wave_speed")),
			0.0001)
	assert_almost_eq(
			float(distant_material.get_shader_parameter("wave_phase")),
			float(far_material.get_shader_parameter("field_wave_phase")),
			0.0001)
	var distant_shader_source := FileAccess.get_file_as_string(
			DISTANT_WHEAT_SHADER_PATH)
	assert_string_contains(distant_shader_source, "gold_region_mask")
	assert_string_contains(distant_shader_source, "gold_color_mask")
	assert_string_contains(distant_shader_source, "side_exclusion")
	assert_string_contains(distant_shader_source, "gold_rest_dim")
	assert_gte(
			float(distant_material.get_shader_parameter("light_strength")),
			0.55)
	assert_gte(
			float(distant_material.get_shader_parameter("gold_rest_dim")),
			0.05)
	assert_false(wind_shader_source.contains("seam_blend_strength"))
	assert_false(wind_shader_source.contains("top_edge_mask"))
	assert_string_contains(wind_shader_source, "traveling_shape_wave")
	assert_string_contains(wind_shader_source, "shape_wave_mask")
	assert_gte(
			float(far_material.get_shader_parameter("shape_wave_vertical_px")),
			3.5)
	assert_gte(
			float(far_material.get_shader_parameter("shape_wave_horizontal_px")),
			2.0)
	assert_eq(
			float(far_material.get_shader_parameter("field_highlight_rest")),
			1.0)
	assert_eq(
			float(far_material.get_shader_parameter("field_highlight_demote")),
			0.0)
	assert_string_contains(distant_shader_source, "ridge_bottom_edge_mask")
	assert_gte(
			float(distant_material.get_shader_parameter("bottom_edge_trim")),
			0.8)
	assert_gte(int((stage.get_node("FarWheat") as Control).get("mesh_columns")), 128)
	assert_gte(int((stage.get_node("FarWheat") as Control).get("mesh_rows")), 24)
	assert_gte(
			float(far_material.get_shader_parameter("geometry_y_start")),
			0.38)
	assert_gte(
			float(far_material.get_shader_parameter("depth_haze_strength")),
			0.1)
	var near_material := (
			stage.get_node("NearWheatLeft") as Control
			).material as ShaderMaterial
	assert_eq(
			float(near_material.get_shader_parameter("field_wave_strength")),
			0.0)
	assert_gte(
			float(near_material.get_shader_parameter("inertia_mix")),
			0.2)
	assert_gte(float(near_material.get_shader_parameter("sway_px")), 5.0)
	assert_gte(float(near_material.get_shader_parameter("detail_px")), 1.2)
	assert_lte(float(near_material.get_shader_parameter("bend_power")), 1.3)
	assert_gte(float(near_material.get_shader_parameter("gust_px")), 8.0)
	assert_gte(int((stage.get_node("NearWheatLeft") as Control).get("mesh_columns")), 48)
	var ambient := stage.get_node("AmbientChaff") as GPUParticles2D
	assert_true(ambient.emitting)
	assert_gte(ambient.amount, 12)
	assert_eq(ambient.texture.resource_path, CHAFF_PATH)
	var ambient_canvas := ambient.material as CanvasItemMaterial
	assert_not_null(ambient_canvas)
	assert_true(ambient_canvas.particles_animation)
	assert_eq(ambient_canvas.particles_anim_h_frames, 4)
	assert_eq(ambient_canvas.particles_anim_v_frames, 2)
	var ambient_process := ambient.process_material as ParticleProcessMaterial
	assert_lte(ambient_process.initial_velocity_max, 42.0)
	assert_eq(ambient_process.anim_speed_min, 0.0)
	assert_eq(ambient_process.anim_speed_max, 0.0)
	assert_eq(ambient_process.anim_offset_min, 0.0)
	assert_eq(ambient_process.anim_offset_max, 1.0)

	var gust := stage.get_node("GustChaff") as GPUParticles2D
	assert_true(gust.one_shot)
	assert_gte(gust.amount, 12)
	assert_eq(gust.texture.resource_path, CHAFF_PATH)
	var gust_canvas := gust.material as CanvasItemMaterial
	assert_not_null(gust_canvas)
	assert_eq(gust_canvas.particles_anim_h_frames, 4)
	assert_eq(gust_canvas.particles_anim_v_frames, 2)
	var gust_process := gust.process_material as ParticleProcessMaterial
	assert_gte(gust_process.damping_min, 30.0)
	assert_gte(float(wind_field.get("gust_duration")), 1.0)
	assert_gte(float(wind_field.get("recovery_power")), 2.0)
	watch_signals(wind_field)
	stage.shake(16.0, 1.0)
	await get_tree().process_frame
	assert_signal_emitted(wind_field, "gust_triggered")
	assert_true(gust.emitting)
	assert_between(gust_process.initial_velocity_max, 180.0, 220.0)
	var start_strength := float(wind_field.call("response_strength_at", 0.0))
	var early_strength := float(wind_field.call("response_strength_at", 0.2))
	var middle_strength := float(wind_field.call("response_strength_at", 0.4))
	assert_eq(start_strength, 1.0)
	assert_gt(start_strength - early_strength, early_strength - middle_strength)
	for layer_name: String in [
		"MidFarWheat",
		"FarWheat",
		"FarWheatCoverBack",
		"NearWheatLeft",
	]:
		var material := (
				stage.get_node(layer_name) as Control
				).material as ShaderMaterial
		assert_gt(float(material.get_shader_parameter("gust_strength")), 0.5)
		assert_eq(float(material.get_shader_parameter("gust_direction")), 1.0)


func test_battle_screen5_reuses_mature_ui_and_character_runtime() -> void:
	assert_true(ResourceLoader.exists(BATTLE5_PATH))
	if not ResourceLoader.exists(BATTLE5_PATH):
		return

	BattleSetup.reset()
	var screen := (load(BATTLE5_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	await get_tree().process_frame

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	assert_eq(stage.scene_file_path, SCENE5_PATH)
	assert_true(stage.pointer_parallax)
	assert_false(stage.demo_click_shake)
	for node_path: String in [
		"P1Hud",
		"P2Hud",
		"Buttons",
		"WorldGroup",
		"WorldGroup/P1CharDisplay",
		"WorldGroup/P2CharDisplay",
		"WorldGroup/WorldForegroundOccluder",
	]:
		assert_not_null(screen.get_node_or_null(node_path))
	assert_eq(
			screen.get_node("WorldGroup/P1CharDisplay").get_parent().name,
			"WorldGroup")
	assert_eq(
			screen.get_node("WorldGroup/P2CharDisplay").get_parent().name,
			"WorldGroup")
	var world := screen.get_node("WorldGroup") as Control
	var p1_shadow := world.get_node("P1Shadow") as TextureRect
	var p2_shadow := world.get_node("P2Shadow") as TextureRect
	var p1_character := world.get_node("P1CharDisplay") as CharacterDisplay
	var p2_character := world.get_node("P2CharDisplay") as CharacterDisplay
	var occluder := world.get_node("WorldForegroundOccluder") as Control
	assert_lt(p1_shadow.get_index(), p1_character.get_index())
	assert_lt(p2_shadow.get_index(), p2_character.get_index())
	assert_lt(p1_character.get_index(), occluder.get_index())
	assert_lt(p2_character.get_index(), occluder.get_index())
	assert_eq(
			(occluder.get("texture") as Texture2D).resource_path,
			NEAR_WHEAT_PATH)
	var occluder_material := occluder.material as ShaderMaterial
	assert_not_null(occluder_material)
	assert_eq(
			occluder_material.shader.resource_path,
			WIND_SHADER_PATH)
	assert_between(
			float(occluder_material.get_shader_parameter("clip_top")),
			0.5,
			0.75)
	stage.shake(16.0, -1.0)
	await get_tree().process_frame
	assert_gt(
			float(occluder_material.get_shader_parameter("gust_strength")),
			0.5)
	assert_eq(
			float(occluder_material.get_shader_parameter("gust_direction")),
			-1.0)
	var gust := stage.get_node("GustChaff") as GPUParticles2D
	var gust_process := gust.process_material as ParticleProcessMaterial
	assert_gt(gust.position.x, 1500.0)
	assert_eq(gust_process.direction.x, -1.0)
	assert_lt(gust_process.gravity.x, 0.0)
	var ambient := stage.get_node("AmbientChaff") as GPUParticles2D
	assert_lt(ambient.speed_scale, 0.3)
	assert_gte(int(occluder.get("mesh_columns")), 48)
	assert_gte(float(occluder_material.get_shader_parameter("sway_px")), 5.0)
	for character: CharacterDisplay in [p1_character, p2_character]:
		assert_gt(character.rim_strength, 0.0)
		assert_lte(character.rim_strength, 0.2)
		assert_lte(character.rim_width, 2.0)
		assert_gt(character.warmth_amount, 0.1)
		assert_gt(character.fill_amount, 0.05)
		assert_gt(character.rim_color.r, character.rim_color.b)
		assert_gt(character.fill_color.r, character.fill_color.b)
	assert_gt(p1_shadow.self_modulate.r, p1_shadow.self_modulate.b)
	assert_gt(p2_shadow.self_modulate.r, p2_shadow.self_modulate.b)
	BattleSetup.reset()


func test_scene5_basic_wave_pairs_drive_response_from_the_stronger_side() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE5_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.has_method("_base_attack_response_direction"))
	if not screen.has_method("_base_attack_response_direction"):
		BattleSetup.reset()
		return
	assert_eq(
			float(screen.call(
					"_base_attack_response_direction",
					ActionDef.Action.ATTACK,
					ActionDef.Action.ATTACK)),
			0.0)
	assert_eq(
			float(screen.call(
					"_base_attack_response_direction",
					ActionDef.Action.ATTACK,
					ActionDef.Action.BIG_ATTACK)),
			-1.0)
	assert_eq(
			float(screen.call(
					"_base_attack_response_direction",
					ActionDef.Action.BIG_ATTACK,
					ActionDef.Action.ATTACK)),
			1.0)
	assert_eq(
			float(screen.call(
					"_base_attack_response_direction",
					ActionDef.Action.BIG_ATTACK,
					ActionDef.Action.BIG_ATTACK)),
			0.0)
	BattleSetup.reset()


func test_battle_screen5_keeps_base_character_and_ui_geometry() -> void:
	assert_true(ResourceLoader.exists(BATTLE5_PATH))
	if not ResourceLoader.exists(BATTLE5_PATH):
		return

	var base := (load(BATTLE_BASE_PATH) as PackedScene).instantiate() as Control
	var screen := (load(BATTLE5_PATH) as PackedScene).instantiate() as Control
	for node_path: String in [
		"P1CharDisplay",
		"P2CharDisplay",
		"P1Hud",
		"P2Hud",
		"Buttons",
	]:
		var base_node := base.get_node(node_path) as Control
		var scene5_node := screen.get_node(node_path) as Control
		assert_eq(scene5_node.position, base_node.position)
		assert_eq(scene5_node.size, base_node.size)

	var post_fx := screen.get_node("PostFX") as ColorRect
	var post_material := post_fx.material as ShaderMaterial
	assert_not_null(post_material)
	assert_eq(
			post_material.shader.resource_path,
			"res://assets/shaders/post_fx_color_grade.gdshader")
	assert_eq(
			float(post_material.get_shader_parameter("edge_blur_amount")),
			0.0)
	assert_lte(
			float(post_material.get_shader_parameter("tint_strength")),
			0.04)
	assert_between(
			float(post_material.get_shader_parameter("brightness")),
			1.05,
			1.12)
	assert_between(
			float(post_material.get_shader_parameter("split_strength")),
			0.1,
			0.18)
	base.free()
	screen.free()


func test_scene5_does_not_replace_scene1_default_composition() -> void:
	var battle1_source := FileAccess.get_file_as_string(BATTLE1_PATH)
	assert_true(battle1_source.contains(SCENE1_PATH))
	assert_false(battle1_source.contains(SCENE5_PATH))


func test_scene5_keeps_mature_character_idle_cycle_contract() -> void:
	var display_scene := load(
			"res://src/ui/components/character_display.tscn") as PackedScene
	var display := display_scene.instantiate()
	add_child_autofree(display)
	assert_gt(float(display.idle_base_fps), 0.0)
	assert_gt(int(display.idle_ref_frames), 0)

	for frame_count: int in [3, 6, 12]:
		var fps: float = (
				float(display.idle_base_fps)
				* float(frame_count)
				/ float(display.idle_ref_frames))
		assert_almost_eq(
				float(frame_count) / fps,
				float(display.idle_ref_frames) / float(display.idle_base_fps),
				0.0001)
