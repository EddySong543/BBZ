extends Node

const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"
const BATTLE7_PATH := "res://src/ui/battle_screen7.tscn"
const SCENE7_ASSET_ROOT := "res://assets/scenes/scene7/"
const FAR_WATER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_far_water.gdshader"
const FRONT_WATER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_water.gdshader"
const PLATFORM_ELEVATION_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_platform_elevation.gdshader"
const DEPTH_VEIL_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_depth_veil.gdshader"
const MOTES_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_motes.gdshader"
const SCENE7_CHARACTER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_character_light.gdshader"
const SCENE7_CONTACT_SHADOW_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_character_contact_shadow.gdshader"
const UI_READABILITY_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_ui_readability.gdshader"
const FAR_CLEANUP_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_far_cleanup.gdshader"
func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var packed := load(BATTLE7_PATH) as PackedScene
	var screen := packed.instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return
	if screen.get_node_or_null("WorldGroup") == null:
		print(
			"SCENE7_DAYLIGHT_OASIS_PROBE: BLOCKED",
			" missing_battle_dependency=WorldGroup")
		BattleSetup.reset()
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var sky := stage.get_node("Sky") as TextureRect
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var world := screen.get_node("WorldGroup") as Control
	var p1 := screen.get_node("WorldGroup/P1CharDisplay") as CharacterDisplay
	var p2 := screen.get_node("WorldGroup/P2CharDisplay") as CharacterDisplay
	var p1_sprite := p1.get_node("SubViewport/AnimatedSprite2D") as AnimatedSprite2D
	var p2_sprite := p2.get_node("SubViewport/AnimatedSprite2D") as AnimatedSprite2D
	stage.set_process(false)
	screen.set_process(false)
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var rear_water := stage.get_node("RearWater") as Polygon2D
	var front_water := stage.get_node("FrontWater") as ColorRect
	var runtime_front_water_material := front_water.material as ShaderMaterial
	var p1_reflection_rect: Vector4 = runtime_front_water_material.get_shader_parameter(
			"p1_reflection_rect")
	var p2_reflection_rect: Vector4 = runtime_front_water_material.get_shader_parameter(
			"p2_reflection_rect")
	var complete_reflection_ready: bool = (
		bool(screen.get("character_reflections_enabled"))
		and NodePath(screen.get("character_reflection_receiver_path"))
				== NodePath("FrontWater")
		and float(runtime_front_water_material.get_shader_parameter(
				"reflection_height_px")) >= 500.0
		and float(runtime_front_water_material.get_shader_parameter(
				"reflection_strength")) >= 0.5
		and p1_reflection_rect.z > 1.0
		and p1_reflection_rect.w > 1.0
		and p2_reflection_rect.z > 1.0
		and p2_reflection_rect.w > 1.0)
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	await get_tree().create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	var motion_frame := get_viewport().get_texture().get_image()
	await get_tree().create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	var motion_frame_2 := get_viewport().get_texture().get_image()
	var far_background := stage.get_node("FarBackground") as TextureRect
	var far_material := far_background.material as ShaderMaterial
	var cleanup_viewport := SubViewport.new()
	cleanup_viewport.size = Vector2i(far_background.texture.get_size())
	cleanup_viewport.transparent_bg = true
	cleanup_viewport.disable_3d = true
	cleanup_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cleanup_rect := TextureRect.new()
	cleanup_rect.size = Vector2(far_background.texture.get_size())
	cleanup_rect.texture = far_background.texture
	cleanup_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cleanup_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var cleanup_material := far_material.duplicate(true) as ShaderMaterial
	cleanup_rect.material = cleanup_material
	cleanup_material.set_shader_parameter("cleanup_strength", 0.0)
	cleanup_viewport.add_child(cleanup_rect)
	add_child(cleanup_viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var far_baseline_image := cleanup_viewport.get_texture().get_image()
	cleanup_material.set_shader_parameter(
		"cleanup_strength",
		far_material.get_shader_parameter("cleanup_strength"))
	await RenderingServer.frame_post_draw
	var far_cleaned_image := cleanup_viewport.get_texture().get_image()
	var far_cleanup_stats := _far_cleanup_stats(
		far_baseline_image,
		far_cleaned_image,
		float(far_material.get_shader_parameter("outlier_threshold")),
		float(far_material.get_shader_parameter("neighbor_coherence")),
		float(far_material.get_shader_parameter("edge_protection")))
	cleanup_viewport.queue_free()
	var rebuilt_sky_image := sky.texture.get_image()
	var sky_art_top := _mean_region(
		rebuilt_sky_image,
		Rect2i(0, 0, rebuilt_sky_image.get_width(), rebuilt_sky_image.get_height() / 4),
		8)
	var sky_art_horizon := _mean_region(
		rebuilt_sky_image,
		Rect2i(
			0, rebuilt_sky_image.get_height() / 2,
			rebuilt_sky_image.get_width(), rebuilt_sky_image.get_height() / 4),
		8)
	var far_art_stats := _palette_region_stats(
		far_cleaned_image, Rect2i(Vector2i.ZERO, far_cleaned_image.get_size()), 2)
	var far_art_edge_fraction := _edge_fraction(far_cleaned_image, 0.10, 2)
	var left_motion_stats := _max_motion_stats(
		_max_motion_stats(
			_motion_stats(frame, motion_frame, Rect2i(0, 260, 340, 390), 3),
			_motion_stats(motion_frame, motion_frame_2,
					Rect2i(0, 260, 340, 390), 3)),
		_motion_stats(frame, motion_frame_2, Rect2i(0, 260, 340, 390), 3))
	var right_motion_stats := _max_motion_stats(
		_max_motion_stats(
			_motion_stats(frame, motion_frame, Rect2i(1580, 260, 340, 390), 3),
			_motion_stats(motion_frame, motion_frame_2,
					Rect2i(1580, 260, 340, 390), 3)),
		_motion_stats(frame, motion_frame_2, Rect2i(1580, 260, 340, 390), 3))
	var center_motion_stats := _max_motion_stats(
		_max_motion_stats(
			_motion_stats(frame, motion_frame, Rect2i(700, 280, 520, 300), 3),
			_motion_stats(motion_frame, motion_frame_2,
					Rect2i(700, 280, 520, 300), 3)),
		_motion_stats(frame, motion_frame_2, Rect2i(700, 280, 520, 300), 3))
	var rear_water_motion := _max_motion_stats(
		_motion_stats(frame, motion_frame, Rect2i(0, 700, 1920, 56), 2),
		_motion_stats(motion_frame, motion_frame_2,
				Rect2i(0, 700, 1920, 56), 2))
	var front_water_motion := _max_motion_stats(
		_motion_stats(frame, motion_frame, Rect2i(0, 900, 1920, 176), 2),
		_motion_stats(motion_frame, motion_frame_2,
				Rect2i(0, 900, 1920, 176), 2))
	var water_surface_frame := frame.get_region(Rect2i(560, 900, 800, 176))
	var water_surface_stats := _water_surface_stats(water_surface_frame, 2)
	var water_motion_ready: bool = (
		rear_water_motion.x >= 0.08
		# Rear shallows are deliberately subtle: coverage proves animation while
		# this floor rejects the former near-static failure without demanding churn.
		and rear_water_motion.y >= 0.004
		and front_water_motion.x >= 0.05
		and front_water_motion.y >= 0.003)
	var water_surface_ready := (
		water_surface_stats.x >= 0.20
		and water_surface_stats.x <= 0.48
		# Full-screen capture contains battle UI colors in this band, so its
		# absolute min/max is not a water-only signal. Mean/deviation and the
		# dedicated center-water sample below remain stable runtime evidence.
		and water_surface_stats.z >= 0.07
		and water_surface_stats.z <= 0.24
		and water_surface_stats.w <= 0.08)
	var motion_render_ready := (
		left_motion_stats.x >= 0.01
		# The new cyan-source compression lowers color delta without reducing
		# the authored vertex displacement, so keep motion judged by coverage
		# and a darker-output-aware minimum delta.
		and left_motion_stats.y >= 0.0018
		and right_motion_stats.x >= 0.004
		and right_motion_stats.y >= 0.0013
		and center_motion_stats.x >= 0.02
		and center_motion_stats.y >= 0.0025)
	var p1_character_stats := _visible_image_stats(p1.get_render_texture().get_image(), 4)
	var p2_character_stats := _visible_image_stats(p2.get_render_texture().get_image(), 4)
	var p1_contact_depth := _character_contact_depth(platform, p1)
	var p2_contact_depth := _character_contact_depth(platform, p2)
	var p1_idle_contact_range := _idle_contact_range(platform, p1, p1_sprite)
	var p2_idle_contact_range := _idle_contact_range(platform, p2, p2_sprite)
	var p1_shadow_contact_depth := _shadow_contact_depth(
		platform, screen.get_node("WorldGroup/P1Shadow") as TextureRect)
	var p2_shadow_contact_depth := _shadow_contact_depth(
		platform, screen.get_node("WorldGroup/P2Shadow") as TextureRect)
	var p1_source_stats := _visible_image_stats(
		p1_sprite.sprite_frames.get_frame_texture(
			p1_sprite.animation, p1_sprite.frame).get_image(), 2)
	var p2_source_stats := _visible_image_stats(
		p2_sprite.sprite_frames.get_frame_texture(
			p2_sprite.animation, p2_sprite.frame).get_image(), 2)
	var character_pixels_ready := (
		absf(p1_character_stats.x - p1_source_stats.x) <= 0.025
		and absf(p2_character_stats.x - p2_source_stats.x) <= 0.025
		and absf(p1_character_stats.y - p1_source_stats.y) <= 0.02
		and absf(p2_character_stats.y - p2_source_stats.y) <= 0.02
		and p1_character_stats.y >= p1_source_stats.y * 0.94
		and p2_character_stats.y >= p2_source_stats.y * 0.94
		and p1_character_stats.z >= p1_source_stats.z * 0.62
		and p2_character_stats.z >= p2_source_stats.z * 0.62
		and p1_character_stats.w <= p1_source_stats.w + 0.10
		and p2_character_stats.w <= p2_source_stats.w + 0.10)
	var character_grounding_ready := (
		p1_idle_contact_range.x >= 6.0
		and p1_idle_contact_range.y <= 12.0
		and p2_idle_contact_range.x >= 6.0
		and p2_idle_contact_range.y <= 12.0
		and p1_shadow_contact_depth >= 6.0
		and p1_shadow_contact_depth <= 12.0
		and p2_shadow_contact_depth >= 6.0
		and p2_shadow_contact_depth <= 12.0
		and absf(p1_contact_depth - p1_shadow_contact_depth) <= 2.0
		and absf(p2_contact_depth - p2_shadow_contact_depth) <= 2.0)
	var top_color := _mean_region(frame, Rect2i(640, 40, 640, 260), 8)
	var center_color := _mean_region(frame, Rect2i(640, 300, 640, 400), 8)
	var left_color := _mean_region(frame, Rect2i(0, 180, 320, 600), 8)
	var right_color := _mean_region(frame, Rect2i(1600, 180, 320, 600), 8)
	var top_luma := _luma(top_color)
	var center_luma := _luma(center_color)
	var edge_color := (left_color + right_color) * 0.5
	var edge_luma := (_luma(left_color) + _luma(right_color)) * 0.5
	var high_saturation_fraction := _fraction_above_saturation(frame, 0.65, 4)
	var lower_water_color := _mean_region(frame, Rect2i(760, 875, 270, 45), 4)
	var lower_water_luma := _luma(lower_water_color)
	var rear_water_color := _mean_region(frame, Rect2i(760, 680, 400, 38), 4)
	var rear_water_luma := _luma(rear_water_color)
	var road_color := _mean_region(frame, Rect2i(760, 745, 270, 100), 4)
	var road_luma := _luma(road_color)
	var sky_image := sky.texture.get_image()
	var sky_top_color := _mean_region(
		sky_image, Rect2i(0, 0, sky_image.get_width(), sky_image.get_height() / 4), 8)
	var sky_bottom_color := _mean_region(
		sky_image,
		Rect2i(0, sky_image.get_height() * 3 / 4,
				sky_image.get_width(), sky_image.get_height() / 4),
		8)
	var sky_source_luma := _mean_visible_luma(sky_image, 8)
	var mid_source_luma := 0.0
	var mid_bright_fraction := 0.0
	for mid_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var mid_image := (stage.get_node(mid_name) as TextureRect).texture.get_image()
		mid_source_luma += _mean_visible_luma(mid_image, 4) / 3.0
		mid_bright_fraction += _visible_fraction_above_luma(mid_image, 0.32, 4) / 3.0
	var daylight_palette_ready := (
		top_luma > 0.22
		# Daylight is established by the bright authored sky; dense oasis
		# vegetation is intentionally darker so its sparse tips can glow.
		and center_luma > 0.40
		and center_luma > edge_luma * 1.15
		and sky_source_luma > 0.68
		and sky_top_color.b > sky_top_color.r * 1.18
		and sky_bottom_color.r > sky_bottom_color.b * 1.15
		and mid_source_luma < 0.28
		and mid_bright_fraction > 0.04)
	var final_render_palette_ready := (
		top_color.b > top_color.r * 1.35
		and road_color.r > road_color.b * 1.6
		and lower_water_color.g > lower_water_color.r * 1.12
		and edge_color.s <= 0.20
		and edge_luma < center_luma * 0.90
		and center_luma > edge_luma * 1.15)
	var mid_left_rect := _displayed_used_rect(stage.get_node("MidgroundLeft") as TextureRect)
	var mid_center_rect := _displayed_used_rect(stage.get_node("MidgroundCenter") as TextureRect)
	var mid_right_rect := _displayed_used_rect(stage.get_node("MidgroundRight") as TextureRect)
	var platform_visible_rect := _scene7_platform_visible_rect(platform)
	var platform_authored_position := platform.position
	var platform_authored_size := platform.size
	var midground_coverage_ready := (
		mid_left_rect.position.x <= 0.0
		and mid_left_rect.end.x - mid_center_rect.position.x >= 250.0
		and mid_center_rect.end.x - mid_right_rect.position.x >= 150.0
		and mid_right_rect.end.x >= 1920.0
		and mid_left_rect.end.y >= 690.0
		and mid_left_rect.end.y <= 712.0
		and mid_center_rect.end.y >= 700.0
		and mid_center_rect.end.y <= 715.0
		and mid_right_rect.end.y >= 690.0
		and mid_right_rect.end.y <= 712.0)
	var lower_edge_delta_sum := 0.0
	var lower_edge_signed_delta_sum := 0.0
	var lower_edge_sample_count := 0.0
	for mid_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var edge_stats := _lower_edge_luma_stats(
			frame, stage.get_node(mid_name) as TextureRect)
		lower_edge_delta_sum += edge_stats.x * edge_stats.y
		lower_edge_signed_delta_sum += edge_stats.z * edge_stats.y
		lower_edge_sample_count += edge_stats.y
	var lower_edge_luma_delta := (
		lower_edge_delta_sum / lower_edge_sample_count
		if lower_edge_sample_count > 0.0 else 1.0)
	var lower_edge_signed_luma_delta := (
		lower_edge_signed_delta_sum / lower_edge_sample_count
		if lower_edge_sample_count > 0.0 else 1.0)

	var platform_center_x: float = platform.position.x
	var world_center_x: float = world.position.x
	screen.state = 1  # BattleScreen.State.PLAYER_SELECT
	screen._on_switch_main_pressed()
	var switch_tray_open: bool = screen._switch_tray.visible
	screen._on_switch_candidate_pressed(1)
	var switch_armed: bool = (
		screen._armed_switch_frame == 1
		and screen._switch_selected)

	stage.set("_pnx", 1.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_delta: float = platform.position.x - platform_center_x
	var world_delta: float = world.position.x - world_center_x
	var sync_error: float = absf(platform_delta - world_delta)

	var required_nodes: Array[String] = [
		"P1Hud",
		"P2Hud",
		"Buttons",
		"DeathSwitchOverlay",
		"WorldGroup/P1CharDisplay",
		"WorldGroup/P2CharDisplay",
	]
	var missing_nodes: Array[String] = []
	for node_path: String in required_nodes:
		if screen.get_node_or_null(node_path) == null:
			missing_nodes.append(node_path)

	var expected_factors: Dictionary[String, float] = {
		"Sky": 0.0,
		"FarBackground": 0.18,
		"OasisDepthVeil": 0.32,
		"OasisMotesFar": 0.64,
		"MidgroundLeft": 0.55,
		"MidgroundCenter": 0.55,
		"MidgroundRight": 0.55,
		"OasisMotesMid": 0.82,
		"FrontWater": 1.0,
		"BattlePlatform": 1.0,
		"OasisMotesNear": 1.12,
		"ForegroundLeft": 1.25,
		"ForegroundRight": 1.25,
	}
	var layers_ready := true
	for node_name: String in expected_factors:
		var layer := stage.get_node_or_null(node_name) as Control
		layers_ready = layers_ready and layer != null
		if layer == null:
			continue
		layers_ready = (
			layers_ready
			and layer.get_parent() == stage
			and layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and is_equal_approx(
				float(layer.get_meta("parallax_factor")),
				expected_factors[node_name]))
	var rear_water_shape := stage.get_node_or_null("RearWater") as Polygon2D
	layers_ready = (
		layers_ready
		and rear_water_shape != null
		and rear_water_shape.get_parent() == stage
		and rear_water_shape.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and is_equal_approx(
			float(rear_water_shape.get_meta("parallax_factor")), 0.55))
	var authored_layering_ready: bool = (
		stage.get_node("FarBackground").get_index()
				< stage.get_node("OasisDepthVeil").get_index()
		and stage.get_node("OasisDepthVeil").get_index()
				< stage.get_node("RearWater").get_index()
		and stage.get_node("RearWater").get_index()
				< stage.get_node("OasisMotesFar").get_index()
		and stage.get_node("OasisMotesFar").get_index()
				< stage.get_node("MidgroundCenter").get_index()
		and stage.get_node("MidgroundCenter").get_index()
				< stage.get_node("MidgroundLeft").get_index()
		and stage.get_node("MidgroundLeft").get_index()
				< stage.get_node("MidgroundRight").get_index()
		and stage.get_node("RearWaterReflection").get_index()
				< stage.get_node("OasisMotesMid").get_index()
		and stage.get_node("OasisMotesMid").get_index()
				< stage.get_node("FrontWater").get_index()
		and stage.get_node("FrontWater").get_index() < platform.get_index()
		and platform.get_index() < stage.get_node("OasisMotesNear").get_index()
		and stage.get_node("OasisMotesNear").get_index()
				< stage.get_node("ForegroundLeft").get_index())
	layers_ready = layers_ready and authored_layering_ready

	var texture_contract: Dictionary[String, String] = {
		"Sky": SCENE7_ASSET_ROOT + "scene7_sky.png",
		"FarBackground": SCENE7_ASSET_ROOT + "scene7_far_background.png",
		"MidgroundLeft": SCENE7_ASSET_ROOT + "scene7_midground_left.png",
		"MidgroundCenter": SCENE7_ASSET_ROOT + "scene7_midground_center.png",
		"MidgroundRight": SCENE7_ASSET_ROOT + "scene7_midground_right.png",
		"BattlePlatform": SCENE7_ASSET_ROOT + "scene7_battle_platform.png",
		"ForegroundLeft": SCENE7_ASSET_ROOT + "scene7_foreground_left.png",
		"ForegroundRight": SCENE7_ASSET_ROOT + "scene7_foreground_right.png",
	}
	for node_name: String in texture_contract:
		var layer := stage.get_node(node_name) as TextureRect
		layers_ready = (
			layers_ready
			and layer.texture != null
			and layer.texture.resource_path == texture_contract[node_name])
	var biolume_ready := true
	for node_name: String in [
		"MidgroundLeft", "MidgroundCenter", "MidgroundRight",
		"ForegroundLeft", "ForegroundRight",
	]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		biolume_ready = (
			biolume_ready
			and material != null
			and material.shader.resource_path
					== "res://assets/shaders/canvas_env_scene7_biolume_plant.gdshader"
			and float(material.get_shader_parameter("emission_strength")) >= (
				0.64 if node_name.begins_with("Foreground") else 0.12)
			and float(material.get_shader_parameter("halo_strength")) >= (
				0.48 if node_name.begins_with("Foreground") else 0.16))
	var depth_veil := stage.get_node("OasisDepthVeil") as ColorRect
	var depth_veil_material := depth_veil.material as ShaderMaterial
	var depth_transition_ready := (
		depth_veil_material != null
		and depth_veil_material.shader.resource_path == DEPTH_VEIL_SHADER_PATH
		and float(depth_veil_material.get_shader_parameter("opacity")) >= 0.06
		and float(depth_veil_material.get_shader_parameter("opacity")) <= 0.12
		and depth_veil.position.x <= -24.0
		and depth_veil.position.x + depth_veil.size.x >= 1944.0
		and lower_edge_sample_count >= 20.0
		# Water stage 1 deliberately removes the old rear-water overdraw above the
		# midground edge. Keep this pixel-data metric as a gross seam guard, but do
		# not retain the tighter threshold that depended on the rejected overdraw.
		and lower_edge_luma_delta <= 0.20)
	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		depth_transition_ready = (
			depth_transition_ready
			and float(material.get_shader_parameter("palette_strength")) >= 0.20
			and float(material.get_shader_parameter("contact_strength")) >= 0.34
			and float(material.get_shader_parameter("sediment_strength")) >= 0.14
			and float(material.get_shader_parameter("reflection_strength")) >= 0.10
			and float(material.get_shader_parameter("reflection_strength")) <= 0.24)
	var environment_motion_ready := motion_render_ready
	for node_name: String in [
		"MidgroundLeft", "MidgroundCenter", "MidgroundRight",
		"ForegroundLeft", "ForegroundRight",
	]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		environment_motion_ready = (
			environment_motion_ready
			and float(material.get_shader_parameter("sway_strength_px")) >= (
				0.68 if node_name.begins_with("Foreground") else 0.46)
			and float(material.get_shader_parameter("glow_pulse_strength")) >= (
				0.16 if node_name.begins_with("Foreground") else 0.13))
	for mote_name: String in ["OasisMotesFar", "OasisMotesMid", "OasisMotesNear"]:
		var material := (stage.get_node(mote_name) as ColorRect).material as ShaderMaterial
		environment_motion_ready = (
			environment_motion_ready
			and material.shader.resource_path == MOTES_SHADER_PATH
			and float(material.get_shader_parameter("rise_px_per_sec")) >= 1.4
			and float(material.get_shader_parameter("secondary_density")) >= 0.12
			and float(material.get_shader_parameter("horizontal_sway_px")) >= 1.0
			and float(material.get_shader_parameter("alpha")) <= 0.42)
	var rear_water_material := rear_water.material as ShaderMaterial
	var front_water_material := front_water.material as ShaderMaterial
	var rear_water_source := FileAccess.get_file_as_string(FAR_WATER_SHADER_PATH)
	var front_water_source := FileAccess.get_file_as_string(FRONT_WATER_SHADER_PATH)
	var water_geometry_ready: bool = (
		rear_water.polygon.size() == 24
		and rear_water.uv.size() == 24
		and rear_water.polygon[0] == Vector2(-32.0, 680.0)
		and rear_water.polygon[15] == Vector2(1440.0, 683.0)
		and rear_water.polygon[16] == Vector2(1536.0, 684.0)
		and rear_water.polygon[21] == Vector2(1952.0, 680.0)
		and rear_water.polygon[22] == Vector2(1952.0, 760.0)
		and rear_water.polygon[23] == Vector2(-32.0, 760.0)
		and rear_water.uv[0] == Vector2(0.0, 0.0)
		and rear_water.uv[21] == Vector2(480.0, 0.0)
		and rear_water.uv[22] == Vector2(480.0, 29.0)
		and rear_water.uv[23] == Vector2(0.0, 29.0)
		and front_water.position.x <= -24.0
		and front_water.position.x + front_water.size.x >= 1944.0
		and platform_visible_rect.end.y - front_water.position.y >= 4.0
		and platform_visible_rect.end.y - front_water.position.y <= 10.0
		and front_water.position.y + front_water.size.y >= 1080.0
		and is_equal_approx(float(rear_water.get_meta("parallax_factor")), 0.55)
		and is_equal_approx(float(front_water.get_meta("parallax_factor")), 1.0)
		and rear_water.texture == null
		and rear_water_material != null
		and front_water_material != null
		and rear_water_material.shader.resource_path == FAR_WATER_SHADER_PATH
		and front_water_material.shader.resource_path == FRONT_WATER_SHADER_PATH
		and rear_water_source.contains("TIME * anim_fps")
		and rear_water_source.contains("local_position = VERTEX")
		and rear_water_source.contains("spring_distance")
		and rear_water_source.contains("ring_mask")
		and front_water_source.contains("TIME * anim_fps")
		and front_water_source.contains("hint_screen_texture")
		and front_water_source.contains("signed_radial_wave")
		and front_water_source.contains("spring_distance")
		and not rear_water_source.contains("flow_speed_px")
		and not front_water_source.contains("ripple_speed_px")
		and not front_water_source.contains("flow_direction")
		and not front_water_source.contains("slice_speed")
		and float(rear_water_material.get_shader_parameter("main_ring_strength")) >= 0.38
		and float(front_water_material.get_shader_parameter("main_ring_strength")) >= 0.35
		and stage.get_node_or_null("WaterAnimationController") == null
		and stage.get_node_or_null("RearWaterAnimated") == null
		and stage.get_node_or_null("FrontWaterAnimated") == null
		and stage.get_node_or_null("RearWaterShape") == null
		and stage.get_node_or_null("FrontShallowWater") == null
		and stage.get_node_or_null("RearWaterFrameArt") == null
		and stage.get_node_or_null("FrontWaterFrameArt") == null
		and stage.get_node_or_null("RearWaterAnimation") == null
		and stage.get_node_or_null("FrontWaterAnimation") == null
		and stage.get_node_or_null("RearWaterDiagnosticRoot") == null
		and stage.get_node_or_null("FrontWaterDiagnosticRoot") == null
		and stage.get_node_or_null("PlatformWaterContact") == null)
	var water_layering_ready := true
	var road_overdraw_height := 0.0
	for water_name: String in ["RearWater", "FrontWater"]:
		var water := stage.get_node(water_name) as CanvasItem
		var water_rect := _water_rect(water)
		var overlap := water_rect.intersection(platform_visible_rect)
		if water.get_index() > platform.get_index() and overlap.has_area():
			water_layering_ready = false
			road_overdraw_height += overlap.size.y
	water_layering_ready = (
		water_layering_ready
		and rear_water.get_index() < platform.get_index()
		and front_water.get_index() < platform.get_index())
	var rear_surface: Color = rear_water_material.get_shader_parameter("surface_color")
	var rear_deep: Color = rear_water_material.get_shader_parameter("deep_color")
	var front_surface: Color = front_water_material.get_shader_parameter("surface_color")
	var front_deep: Color = front_water_material.get_shader_parameter("deep_color")
	var water_colors_ready := (
		_luma(rear_surface) >= _luma(rear_deep) + 0.24
		and _luma(front_surface) >= _luma(front_deep) + 0.24
		and rear_surface.g > rear_surface.r * 1.5
		and front_surface.b > front_surface.r * 1.5
		and lower_water_color.g > lower_water_color.r * 1.15
		and lower_water_color.b > lower_water_color.r * 1.15
		and lower_water_luma >= 0.26
		and lower_water_luma <= 0.58)
	var platform_material := platform.material as ShaderMaterial
	var platform_contact_ready := (
		platform_material != null
		and platform_material.shader.resource_path
				== PLATFORM_ELEVATION_SHADER_PATH)
	var contact_band_px := 0.0
	if platform_contact_ready:
		contact_band_px = float(
			platform_material.get_shader_parameter("contact_band_px"))
		platform_contact_ready = (
			contact_band_px >= 4.0
			and contact_band_px <= 6.0
			and float(platform_material.get_shader_parameter("wet_edge_strength")) <= 0.24
			and float(platform_material.get_shader_parameter("contact_shadow_strength")) <= 0.3
			and float(platform_material.get_shader_parameter("waterline_strength")) <= 0.14)
	var water_ready: bool = (
		water_geometry_ready
		and water_layering_ready
		and water_colors_ready
		and water_motion_ready
		and water_surface_ready
		and platform_contact_ready
		and road_luma >= lower_water_luma + 0.08)

	var platform_image := platform.texture.get_image()
	var platform_integrity: bool = (
		platform.texture.get_size() == Vector2(332.0, 188.0)
		and platform_image.get_used_rect() == Rect2i(7, 83, 318, 23)
		and is_equal_approx(platform_authored_position.y, 234.0)
		and platform_authored_size.is_equal_approx(Vector2(364.83334, 188.0))
		and platform.scale == Vector2(6.0, 6.0)
		and platform.stretch_mode == TextureRect.STRETCH_SCALE
		and is_equal_approx(platform.scale.x, platform.scale.y)
		and platform_visible_rect.position.x < 0.0
		and platform_visible_rect.end.x > 1920.0
		and is_equal_approx(platform_visible_rect.position.y, 738.0)
		and is_equal_approx(platform_visible_rect.size.y, 96.0)
		and platform_visible_rect.position.y <= 748.0
		and platform_visible_rect.end.y > 748.0)
	var source_geometry_ready: bool = (
		sky.texture.get_size() == Vector2(1672.0, 941.0)
		and sky.material == null
		and stage.get_node_or_null("DaylightBackdrop") == null
		and is_equal_approx(sky.scale.x, sky.scale.y)
		and absf(sky.size.x * sky.scale.x - 1920.0) < 1.0
		and (stage.get_node("FarBackground") as TextureRect).texture.get_size()
				== Vector2(289.0, 171.0)
		and (stage.get_node("MidgroundLeft") as TextureRect).texture.get_size()
				== Vector2(304.0, 204.0)
		and (stage.get_node("MidgroundCenter") as TextureRect).texture.get_size()
				== Vector2(396.0, 156.0)
		and (stage.get_node("MidgroundRight") as TextureRect).texture.get_size()
				== Vector2(288.0, 216.0)
		and (stage.get_node("ForegroundLeft") as TextureRect).texture.get_size()
				== Vector2(224.0, 280.0)
		and (stage.get_node("ForegroundRight") as TextureRect).texture.get_size()
				== Vector2(304.0, 204.0)
		and (stage.get_node("MidgroundLeft") as TextureRect).size.is_equal_approx(
				Vector2(359.83334, 271.08334))
		and (stage.get_node("MidgroundCenter") as TextureRect).size.is_equal_approx(
				Vector2(522.2, 240.8))
		and (stage.get_node("MidgroundRight") as TextureRect).size.is_equal_approx(
				Vector2(352.4167, 251.0))
		and (stage.get_node("ForegroundLeft") as TextureRect).size.is_equal_approx(
				Vector2(224.0, 280.0))
		and (stage.get_node("ForegroundRight") as TextureRect).size.is_equal_approx(
				Vector2(304.0, 204.0)))
	var far_cleanup_ready := (
		far_material != null
		and far_material.shader.resource_path == FAR_CLEANUP_SHADER_PATH
		and far_background.size.is_equal_approx(Vector2(332.0, 188.0))
		and far_background.scale.is_equal_approx(Vector2(6.0, 6.0))
		and far_background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and far_cleanup_stats.x > 0.0
		and far_cleanup_stats.y <= far_cleanup_stats.x
		and far_cleanup_stats.y <= 0.0003
		and far_cleanup_stats.z >= 0.95)
	var sky_far_art_ready := (
		_luma(sky_art_top) >= 0.60
		and _luma(sky_art_top) <= 0.78
		and sky_art_top.g >= sky_art_top.r * 1.18
		and sky_art_top.b >= sky_art_top.r * 1.28
		and _luma(sky_art_horizon) >= _luma(sky_art_top) + 0.05
		and far_art_stats.x >= 0.30
		and far_art_stats.x <= 0.62
		and far_art_stats.y >= 0.22
		and far_art_stats.y <= 0.62
		and far_art_stats.z <= 0.04
		and far_art_stats.w >= 0.78
		and far_art_stats.w <= 0.96
		and far_art_edge_fraction >= 0.36
		and far_art_edge_fraction <= 0.50)

	var characters_ready: bool = (
		p1.get_render_texture() != null
		and p2.get_render_texture() != null
		and p1.visible
		and p2.visible
		and is_zero_approx(p1.rim_strength)
		and is_zero_approx(p2.rim_strength)
		and is_zero_approx(p1.backlight)
		and is_zero_approx(p2.backlight)
		and is_zero_approx(p1.warmth_amount)
		and is_zero_approx(p2.warmth_amount)
		and is_zero_approx(p1.fill_amount)
		and is_zero_approx(p2.fill_amount)
		and (p1_sprite.material as ShaderMaterial).shader.resource_path
				== SCENE7_CHARACTER_SHADER_PATH
		and (p2_sprite.material as ShaderMaterial).shader.resource_path
				== SCENE7_CHARACTER_SHADER_PATH
		and character_pixels_ready)
	for shadow_name: String in ["P1Shadow", "P2Shadow"]:
		var shadow := screen.get_node("WorldGroup/%s" % shadow_name) as TextureRect
		var shadow_material := shadow.material as ShaderMaterial
		characters_ready = (
			characters_ready
			and shadow_material != null
			and shadow_material.shader.resource_path
					== SCENE7_CONTACT_SHADOW_SHADER_PATH
			and shadow.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and shadow.rotation == 0.0
			and shadow.size.is_equal_approx(Vector2(132.0, 32.0)))
	var post_material := (screen.get_node("PostFX") as ColorRect).material as ShaderMaterial
	post_material.set_shader_parameter("brightness", 1.03)
	post_material.set_shader_parameter("contrast", 1.04)
	post_material.set_shader_parameter("saturation", 1.05)
	post_material.set_shader_parameter("tint_strength", 0.02)
	post_material.set_shader_parameter("shadow_tint", Color(0.1, 0.34, 0.32, 1.0))
	post_material.set_shader_parameter("highlight_tint", Color(1.0, 0.82, 0.52, 1.0))
	post_material.set_shader_parameter("split_strength", 0.06)
	post_material.set_shader_parameter("vignette_strength", 0.08)
	await RenderingServer.frame_post_draw
	var aggressive_grade_frame := get_viewport().get_texture().get_image()
	var aggressive_high_saturation_fraction := _fraction_above_saturation(
		aggressive_grade_frame, 0.65, 4)
	post_material.set_shader_parameter("brightness", 1.0)
	post_material.set_shader_parameter("contrast", 1.0)
	post_material.set_shader_parameter("saturation", 1.0)
	post_material.set_shader_parameter("tint_strength", 0.0)
	post_material.set_shader_parameter("shadow_tint", Color(0.92, 1.0, 0.98, 1.0))
	post_material.set_shader_parameter("highlight_tint", Color(1.0, 0.99, 0.95, 1.0))
	post_material.set_shader_parameter("split_strength", 0.0)
	post_material.set_shader_parameter("vignette_strength", 0.0)
	var daylight_postfx: bool = (
		post_material != null
		and is_equal_approx(
			float(post_material.get_shader_parameter("brightness")), 1.0)
		and is_equal_approx(
			float(post_material.get_shader_parameter("contrast")), 1.0)
		and is_equal_approx(
			float(post_material.get_shader_parameter("saturation")), 1.0)
		and is_equal_approx(
			float(post_material.get_shader_parameter("tint_strength")), 0.0)
		and is_equal_approx(
			float(post_material.get_shader_parameter("split_strength")), 0.0)
		and is_equal_approx(
			float(post_material.get_shader_parameter("vignette_strength")), 0.0)
		and is_zero_approx(
			float(post_material.get_shader_parameter("heat_haze_strength"))))
	var readability_veil := screen.get_node_or_null("UiReadabilityVeil") as ColorRect
	var post_readability_grab := screen.get_node_or_null(
			"UiReadabilityPostGrab") as BackBufferCopy
	var ui_readability_ready := readability_veil != null and post_readability_grab != null
	if ui_readability_ready:
		var veil_material := readability_veil.material as ShaderMaterial
		ui_readability_ready = (
			veil_material != null
			and veil_material.shader.resource_path == UI_READABILITY_SHADER_PATH
			and screen.get_node("WorldGrab").get_index() < readability_veil.get_index()
			and readability_veil.get_index() < post_readability_grab.get_index()
			and post_readability_grab.get_index() < screen.get_node("PostFX").get_index()
			and post_readability_grab.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT
			and readability_veil.get_index() < screen.get_node("P1Hud").get_index()
			and readability_veil.get_index() < screen.get_node("P2Hud").get_index()
			and readability_veil.get_index() < screen.get_node("TimerLabel").get_index()
			and readability_veil.get_index() < screen.get_node("Buttons").get_index()
			and float(veil_material.get_shader_parameter("hud_support_strength")) >= 0.14
			and float(veil_material.get_shader_parameter("hud_support_strength")) <= 0.22
			and float(veil_material.get_shader_parameter("timer_support_strength")) >= 0.18
			and float(veil_material.get_shader_parameter("timer_support_strength")) <= 0.26
			and float(veil_material.get_shader_parameter("top_fade_start")) >= 0.04
			and float(veil_material.get_shader_parameter("top_fade_start")) <= 0.07
			and float(veil_material.get_shader_parameter("top_fade_end")) >= 0.20
			and float(veil_material.get_shader_parameter("top_fade_end")) <= 0.25)
	var comfort_palette_ready := (
		daylight_postfx
		and ui_readability_ready
		and high_saturation_fraction <= 0.38)
	var foreground_palette_ready := true
	for node_name: String in ["ForegroundLeft", "ForegroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var shadow_palette: Color = material.get_shader_parameter("shadow_palette")
		var sunlit_palette: Color = material.get_shader_parameter("sunlit_palette")
		var palette_strength := float(material.get_shader_parameter("palette_strength"))
		foreground_palette_ready = (
			foreground_palette_ready
			and palette_strength >= 0.20
			and palette_strength <= 0.25
			and shadow_palette.g > shadow_palette.r * 3.0
			and shadow_palette.b > shadow_palette.r * 2.8
			and sunlit_palette.r > sunlit_palette.b * 1.35)
	var final_palette_ready := (
		final_render_palette_ready
		and foreground_palette_ready
		and daylight_postfx)
	var particles_disabled := true
	for dust_name: String in ["ForeDust", "LowerDust"]:
		var dust := screen.get_node(dust_name) as GPUParticles2D
		particles_disabled = particles_disabled and not dust.visible and not dust.emitting

	var passed: bool = (
		stage.scene_file_path == SCENE7_PATH
		and not bool(stage.get_meta("framework_only", true))
		and String(stage.get_meta("theme_name", "")) == "白昼碧月泉"
		and layers_ready
		and biolume_ready
		and depth_transition_ready
		and environment_motion_ready
		and water_ready
		and complete_reflection_ready
		and platform_integrity
		and source_geometry_ready
		and far_cleanup_ready
		and sky_far_art_ready
		and daylight_palette_ready
		and final_palette_ready
		and comfort_palette_ready
		and midground_coverage_ready
		and characters_ready
		and character_grounding_ready
		and daylight_postfx
		and particles_disabled
		and absf(platform_delta) > 2.0
		and sync_error < 0.05
		and switch_tray_open
		and switch_armed
		and missing_nodes.is_empty())
	print(
		"SCENE7_DAYLIGHT_OASIS_PROBE: ",
		"PASS" if passed else "FAIL",
		" platform_delta=",
		platform_delta,
		" world_delta=",
		world_delta,
		" error=",
		sync_error,
		" switch_tray_open=",
		switch_tray_open,
		" switch_armed=",
		switch_armed,
		" characters_ready=",
		characters_ready,
		" character_pixels_ready=",
		character_pixels_ready,
		" character_grounding_ready=",
		character_grounding_ready,
		" p1_character_luma=",
		snappedf(p1_character_stats.x, 0.001),
		" p1_character_saturation=",
		snappedf(p1_character_stats.y, 0.001),
		" p1_character_dark_fraction=",
		snappedf(p1_character_stats.z, 0.001),
		" p1_character_bright_fraction=",
		snappedf(p1_character_stats.w, 0.001),
		" p2_character_luma=",
		snappedf(p2_character_stats.x, 0.001),
		" p2_character_saturation=",
		snappedf(p2_character_stats.y, 0.001),
		" p2_character_dark_fraction=",
		snappedf(p2_character_stats.z, 0.001),
		" p2_character_bright_fraction=",
		snappedf(p2_character_stats.w, 0.001),
		" p1_contact_depth=",
		snappedf(p1_contact_depth, 0.01),
		" p2_contact_depth=",
		snappedf(p2_contact_depth, 0.01),
		" p1_idle_contact_range=",
		p1_idle_contact_range,
		" p2_idle_contact_range=",
		p2_idle_contact_range,
		" p1_shadow_contact_depth=",
		snappedf(p1_shadow_contact_depth, 0.01),
		" p2_shadow_contact_depth=",
		snappedf(p2_shadow_contact_depth, 0.01),
		" p1_source_luma=",
		snappedf(p1_source_stats.x, 0.001),
		" p1_source_saturation=",
		snappedf(p1_source_stats.y, 0.001),
		" p1_source_dark_fraction=",
		snappedf(p1_source_stats.z, 0.001),
		" p1_source_bright_fraction=",
		snappedf(p1_source_stats.w, 0.001),
		" p2_source_luma=",
		snappedf(p2_source_stats.x, 0.001),
		" p2_source_saturation=",
		snappedf(p2_source_stats.y, 0.001),
		" p2_source_dark_fraction=",
		snappedf(p2_source_stats.z, 0.001),
		" p2_source_bright_fraction=",
		snappedf(p2_source_stats.w, 0.001),
		" layers_ready=",
		layers_ready,
		" biolume_ready=",
		biolume_ready,
		" depth_transition_ready=",
		depth_transition_ready,
		" environment_motion_ready=",
		environment_motion_ready,
		" left_motion_fraction=",
		snappedf(left_motion_stats.x, 0.0001),
		" left_motion_mean_delta=",
		snappedf(left_motion_stats.y, 0.0001),
		" right_motion_fraction=",
		snappedf(right_motion_stats.x, 0.0001),
		" right_motion_mean_delta=",
		snappedf(right_motion_stats.y, 0.0001),
		" center_motion_fraction=",
		snappedf(center_motion_stats.x, 0.0001),
		" center_motion_mean_delta=",
		snappedf(center_motion_stats.y, 0.0001),
		" water_motion_ready=",
		water_motion_ready,
		" rear_water_motion_fraction=",
		snappedf(rear_water_motion.x, 0.0001),
		" rear_water_motion_mean_delta=",
		snappedf(rear_water_motion.y, 0.0001),
		" front_water_motion_fraction=",
		snappedf(front_water_motion.x, 0.0001),
		" front_water_motion_mean_delta=",
		snappedf(front_water_motion.y, 0.0001),
		" water_surface_ready=",
		water_surface_ready,
		" water_surface_mean_luma=",
		snappedf(water_surface_stats.x, 0.001),
		" water_surface_luma_range=",
		snappedf(water_surface_stats.y, 0.001),
		" water_surface_luma_deviation=",
		snappedf(water_surface_stats.z, 0.001),
		" water_luminous_fraction=",
		snappedf(water_surface_stats.w, 0.0001),
		" lower_edge_luma_delta=",
		snappedf(lower_edge_luma_delta, 0.001),
		" lower_edge_signed_luma_delta=",
		snappedf(lower_edge_signed_luma_delta, 0.001),
		" lower_edge_sample_count=",
		int(lower_edge_sample_count),
		" water_ready=",
		water_ready,
		" complete_reflection_ready=",
		complete_reflection_ready,
		" p1_reflection_rect=",
		p1_reflection_rect,
		" p2_reflection_rect=",
		p2_reflection_rect,
		" water_geometry_ready=",
		water_geometry_ready,
		" water_layering_ready=",
		water_layering_ready,
		" water_colors_ready=",
		water_colors_ready,
		" platform_contact_ready=",
		platform_contact_ready,
		" contact_band_px=",
		contact_band_px,
		" road_overdraw_height=",
		road_overdraw_height,
		" platform_visible_rect=",
		platform_visible_rect,
		" lower_water_rgb=",
		lower_water_color,
		" lower_water_luma=",
		lower_water_luma,
		" rear_water_rgb=",
		rear_water_color,
		" rear_water_luma=",
		rear_water_luma,
		" road_rgb=",
		road_color,
		" road_luma=",
		road_luma,
		" road_water_luma_delta=",
		road_luma - lower_water_luma,
		" platform_integrity=",
		platform_integrity,
		" source_geometry_ready=",
		source_geometry_ready,
		" sky_material=",
		sky.material,
		" sky_render_width=",
		sky.size.x * sky.scale.x,
		" daylight_backdrop=",
		stage.get_node_or_null("DaylightBackdrop"),
		" plant_sizes=",
		[
			(stage.get_node("MidgroundLeft") as TextureRect).size,
			(stage.get_node("MidgroundCenter") as TextureRect).size,
			(stage.get_node("MidgroundRight") as TextureRect).size,
			(stage.get_node("ForegroundLeft") as TextureRect).size,
			(stage.get_node("ForegroundRight") as TextureRect).size,
		],
		" far_cleanup_ready=",
		far_cleanup_ready,
		" far_shader_path=",
		far_material.shader.resource_path if far_material != null else "<none>",
		" far_position=",
		far_background.position,
		" far_size=",
		far_background.size,
		" far_scale=",
		far_background.scale,
		" far_filter=",
		far_background.texture_filter,
		" far_isolated_before=",
		far_cleanup_stats.x,
		" far_isolated_after=",
		far_cleanup_stats.y,
		" far_edge_preservation=",
		far_cleanup_stats.z,
		" sky_far_art_ready=",
		sky_far_art_ready,
		" sky_art_top_rgb=",
		sky_art_top,
		" sky_art_top_luma=",
		_luma(sky_art_top),
		" sky_art_horizon_rgb=",
		sky_art_horizon,
		" sky_art_horizon_luma=",
		_luma(sky_art_horizon),
		" far_art_luma=",
		far_art_stats.x,
		" far_art_saturation=",
		far_art_stats.y,
		" far_art_cyan_fraction=",
		far_art_stats.z,
		" far_art_warm_fraction=",
		far_art_stats.w,
		" far_art_edge_fraction=",
		far_art_edge_fraction,
		" daylight_palette_ready=",
		daylight_palette_ready,
		" final_palette_ready=",
		final_palette_ready,
		" comfort_palette_ready=",
		comfort_palette_ready,
		" ui_readability_ready=",
		ui_readability_ready,
		" high_saturation_fraction=",
		high_saturation_fraction,
		" aggressive_high_saturation_fraction=",
		aggressive_high_saturation_fraction,
		" foreground_palette_ready=",
		foreground_palette_ready,
		" top_rgb=",
		top_color,
		" top_luma=",
		top_luma,
		" center_rgb=",
		center_color,
		" edge_rgb=",
		edge_color,
		" edge_luma=",
		edge_luma,
		" center_luma=",
		center_luma,
		" sky_source_luma=",
		sky_source_luma,
		" mid_source_luma=",
		mid_source_luma,
		" mid_bright_fraction=",
		mid_bright_fraction,
		" midground_coverage_ready=",
		midground_coverage_ready,
		" mid_left_rect=",
		mid_left_rect,
		" mid_center_rect=",
		mid_center_rect,
		" mid_right_rect=",
		mid_right_rect,
		" daylight_postfx=",
		daylight_postfx,
		" particles_disabled=",
		particles_disabled,
		" missing=",
		missing_nodes)
	BattleSetup.reset()
	get_tree().quit(0 if passed else 1)


func _mean_region(image: Image, region: Rect2i, step: int) -> Color:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var sum := Vector3.ZERO
	var count := 0
	for y: int in range(clipped.position.y, clipped.end.y, step):
		for x: int in range(clipped.position.x, clipped.end.x, step):
			var sample := image.get_pixel(x, y)
			sum += Vector3(sample.r, sample.g, sample.b)
			count += 1
	if count == 0:
		return Color.BLACK
	var mean := sum / float(count)
	return Color(mean.x, mean.y, mean.z, 1.0)


func _water_surface_stats(image: Image, step: int) -> Vector4:
	var luma_sum := 0.0
	var luma_sq_sum := 0.0
	var min_luma := 1.0
	var max_luma := 0.0
	var luminous_count := 0
	var count := 0
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			var sample := image.get_pixel(x, y)
			if sample.a < 0.9:
				continue
			var sample_luma := _luma(sample)
			luma_sum += sample_luma
			luma_sq_sum += sample_luma * sample_luma
			min_luma = minf(min_luma, sample_luma)
			max_luma = maxf(max_luma, sample_luma)
			if (
				sample_luma >= 0.48
				and sample.g >= sample.r * 1.32
				and sample.b >= sample.r * 1.48
			):
				luminous_count += 1
			count += 1
	if count == 0:
		return Vector4.ZERO
	var mean_luma := luma_sum / float(count)
	var variance := maxf(
		0.0, luma_sq_sum / float(count) - mean_luma * mean_luma)
	return Vector4(
		mean_luma,
		max_luma - min_luma,
		sqrt(variance),
		float(luminous_count) / float(count))


func _lower_edge_luma_stats(frame: Image, layer: TextureRect) -> Vector3:
	var source := layer.texture.get_image()
	var transform := layer.get_global_transform()
	var delta_sum := 0.0
	var signed_delta_sum := 0.0
	var count := 0
	for y: int in range(2, source.get_height() - 6, 2):
		if float(y) / float(source.get_height()) < 0.54:
			continue
		for x: int in range(0, source.get_width(), 2):
			var inside_source := source.get_pixel(x, y)
			if inside_source.a < 0.62 or _luma(inside_source) > 0.48:
				continue
			if source.get_pixel(x, y + 2).a > 0.08:
				continue
			var inside_local := Vector2(
				(float(x) + 0.5) / float(source.get_width()) * layer.size.x,
				(float(y) + 0.5) / float(source.get_height()) * layer.size.y)
			var outside_local := Vector2(
				(float(x) + 0.5) / float(source.get_width()) * layer.size.x,
				(float(y) + 2.5) / float(source.get_height()) * layer.size.y)
			var inside_point := Vector2i(transform * inside_local)
			var outside_point := Vector2i(transform * outside_local)
			if not Rect2i(Vector2i.ZERO, frame.get_size()).has_point(inside_point):
				continue
			if not Rect2i(Vector2i.ZERO, frame.get_size()).has_point(outside_point):
				continue
			var inside_rendered := frame.get_pixelv(inside_point)
			var outside_rendered := frame.get_pixelv(outside_point)
			if _luma(inside_rendered) > 0.72:
				continue
			var signed_delta := _luma(inside_rendered) - _luma(outside_rendered)
			delta_sum += absf(signed_delta)
			signed_delta_sum += signed_delta
			count += 1
	return Vector3(
		delta_sum / float(count) if count > 0 else 1.0,
		float(count),
		signed_delta_sum / float(count) if count > 0 else 1.0)


func _motion_stats(
		before: Image,
		after: Image,
		region: Rect2i,
		step: int) -> Vector2:
	var bounds := Rect2i(Vector2i.ZERO, before.get_size())
	var clipped := region.intersection(bounds)
	var changed := 0
	var sampled := 0
	var delta_sum := 0.0
	for y: int in range(clipped.position.y, clipped.end.y, step):
		for x: int in range(clipped.position.x, clipped.end.x, step):
			var color_before := before.get_pixel(x, y)
			var color_after := after.get_pixel(x, y)
			var delta := maxf(
				absf(color_before.r - color_after.r),
				maxf(absf(color_before.g - color_after.g),
						absf(color_before.b - color_after.b)))
			delta_sum += delta
			changed += 1 if delta >= 0.012 else 0
			sampled += 1
	if sampled == 0:
		return Vector2.ZERO
	return Vector2(float(changed) / float(sampled), delta_sum / float(sampled))


func _max_motion_stats(first: Vector2, second: Vector2) -> Vector2:
	return Vector2(maxf(first.x, second.x), maxf(first.y, second.y))


func _horizontal_motion_coherence(
		before: Image,
		after: Image,
		region: Rect2i,
		step: int) -> float:
	var bounds := Rect2i(Vector2i.ZERO, before.get_size())
	var clipped := region.intersection(bounds)
	var coherent_pairs := 0
	var moving_pairs := 0
	for y: int in range(clipped.position.y, clipped.end.y, step):
		var previous_delta := 0.0
		var has_previous := false
		for x: int in range(clipped.position.x, clipped.end.x, step):
			var signed_delta := _luma(after.get_pixel(x, y)) \
					- _luma(before.get_pixel(x, y))
			if has_previous \
					and absf(signed_delta) >= 0.002 \
					and absf(previous_delta) >= 0.002:
				moving_pairs += 1
				if signf(signed_delta) == signf(previous_delta) \
						and absf(signed_delta - previous_delta) <= 0.025:
					coherent_pairs += 1
			previous_delta = signed_delta
			has_previous = true
	return (
		float(coherent_pairs) / float(moving_pairs)
		if moving_pairs > 0 else 0.0)


func _visible_image_stats(image: Image, step: int) -> Vector4:
	var luma_sum := 0.0
	var saturation_sum := 0.0
	var dark_count := 0
	var bright_count := 0
	var visible_count := 0
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			var sample := image.get_pixel(x, y)
			if sample.a <= 0.05:
				continue
			var luma := _luma(sample)
			luma_sum += luma
			saturation_sum += maxf(sample.r, maxf(sample.g, sample.b)) \
					- minf(sample.r, minf(sample.g, sample.b))
			dark_count += 1 if luma < 0.20 else 0
			bright_count += 1 if luma > 0.78 else 0
			visible_count += 1
	if visible_count == 0:
		return Vector4.ZERO
	return Vector4(
		luma_sum / float(visible_count),
		saturation_sum / float(visible_count),
		float(dark_count) / float(visible_count),
		float(bright_count) / float(visible_count))


func _character_contact_depth(
		platform: TextureRect,
		display: CharacterDisplay) -> float:
	var rendered := display.get_render_texture().get_image()
	var used_rect := _alpha_used_rect(rendered, 0.35)
	if not used_rect.has_area():
		return -1000.0
	var foot_local := Vector2(
		float(used_rect.position.x) + float(used_rect.size.x) * 0.5,
		float(used_rect.end.y) - 0.5)
	var foot_canvas := display.get_global_transform() * foot_local
	return foot_canvas.y - _platform_surface_y(platform, foot_canvas.x)


func _shadow_contact_depth(
		platform: TextureRect,
		shadow: TextureRect) -> float:
	var contact_local := Vector2(shadow.size.x * 0.5, shadow.size.y * 0.54)
	var contact_canvas := shadow.get_global_transform() * contact_local
	return contact_canvas.y - _platform_surface_y(platform, contact_canvas.x)


func _idle_contact_range(
		platform: TextureRect,
		display: CharacterDisplay,
		sprite: AnimatedSprite2D) -> Vector2:
	var minimum := 1000.0
	var maximum := -1000.0
	var frames := sprite.sprite_frames
	for frame_index: int in frames.get_frame_count(&"idle"):
		var image := frames.get_frame_texture(&"idle", frame_index).get_image()
		var source_row := -1
		for y: int in range(image.get_height() - 1, -1, -1):
			for x: int in image.get_width():
				if image.get_pixel(x, y).a >= 0.35:
					source_row = y
					break
			if source_row >= 0:
				break
		if source_row < 0:
			continue
		var foot_local := sprite.position + Vector2(
			0.0,
			(float(source_row) + 0.5 - float(image.get_height()) * 0.5)
				* sprite.scale.y)
		var foot_canvas := display.get_global_transform() * foot_local
		var depth := foot_canvas.y - _platform_surface_y(platform, foot_canvas.x)
		minimum = minf(minimum, depth)
		maximum = maxf(maximum, depth)
	return Vector2(minimum, maximum)


func _platform_surface_y(platform: TextureRect, canvas_x: float) -> float:
	var platform_image := platform.texture.get_image()
	var inverse := platform.get_global_transform().affine_inverse()
	var local_point := inverse * Vector2(canvas_x, 0.0)
	var source_x := clampi(int(floor(
		local_point.x / platform.size.x * float(platform_image.get_width()))),
		0,
		platform_image.get_width() - 1)
	var source_y := platform_image.get_height()
	for y: int in platform_image.get_height():
		if platform_image.get_pixel(source_x, y).a >= 0.5:
			source_y = y
			break
	var surface_local := Vector2(
		local_point.x,
		(float(source_y) + 0.5) / float(platform_image.get_height())
			* platform.size.y)
	return (platform.get_global_transform() * surface_local).y


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


func _mean_visible_luma(image: Image, step: int) -> float:
	var luma_sum := 0.0
	var count := 0
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			var sample := image.get_pixel(x, y)
			if sample.a <= 0.03:
				continue
			luma_sum += _luma(sample)
			count += 1
	return luma_sum / float(count) if count > 0 else 0.0


func _displayed_used_rect(layer: TextureRect) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.5)
	var source_size := layer.texture.get_size()
	var stretch_ratio := Vector2(
		layer.size.x / source_size.x,
		layer.size.y / source_size.y)
	return Rect2(
		layer.position + Vector2(used_rect.position) * stretch_ratio * layer.scale,
		Vector2(used_rect.size) * stretch_ratio * layer.scale)


func _scene7_platform_visible_rect(layer: TextureRect) -> Rect2:
	var source_rect := _alpha_used_rect(layer.texture.get_image(), 0.5)
	var material := layer.material as ShaderMaterial
	var surface_bottom_row: float = material.get_shader_parameter("surface_bottom_row")
	var shallow_wall_rows: float = material.get_shader_parameter("shallow_wall_rows")
	var edge_variation_rows: float = material.get_shader_parameter("edge_variation_rows")
	var visible_source_bottom := minf(
			float(source_rect.end.y),
			surface_bottom_row + shallow_wall_rows + edge_variation_rows)
	var visible_source_rect := Rect2(
			Vector2(source_rect.position),
			Vector2(source_rect.size.x,
					visible_source_bottom - float(source_rect.position.y)))
	var stretch_ratio := layer.size / Vector2(layer.texture.get_size())
	return Rect2(
			layer.position + visible_source_rect.position * stretch_ratio * layer.scale,
			visible_source_rect.size * stretch_ratio * layer.scale)


func _water_rect(water: CanvasItem) -> Rect2:
	if water is Control:
		var rect := water as Control
		return Rect2(rect.position, rect.size)
	var polygon := water as Polygon2D
	var bounds := Rect2(polygon.polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon.polygon:
		bounds = bounds.expand(point)
	return bounds


func _visible_fraction_above_luma(image: Image, threshold: float, step: int) -> float:
	var bright_count := 0
	var visible_count := 0
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			var sample := image.get_pixel(x, y)
			if sample.a <= 0.03:
				continue
			visible_count += 1
			if _luma(sample) >= threshold:
				bright_count += 1
	return float(bright_count) / float(visible_count) if visible_count > 0 else 0.0


func _fraction_above_saturation(image: Image, threshold: float, step: int) -> float:
	var saturated_count := 0
	var sampled_count := 0
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			var sample := image.get_pixel(x, y)
			var maximum := maxf(sample.r, maxf(sample.g, sample.b))
			var minimum := minf(sample.r, minf(sample.g, sample.b))
			var saturation := (maximum - minimum) / maxf(maximum, 0.001)
			saturated_count += 1 if saturation >= threshold else 0
			sampled_count += 1
	return float(saturated_count) / float(sampled_count) if sampled_count > 0 else 0.0


func _palette_region_stats(image: Image, region: Rect2i, step: int) -> Vector4:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var luma_sum := 0.0
	var saturation_sum := 0.0
	var cyan_count := 0
	var warm_count := 0
	var count := 0
	for y: int in range(clipped.position.y, clipped.end.y, step):
		for x: int in range(clipped.position.x, clipped.end.x, step):
			var sample := image.get_pixel(x, y)
			if sample.a < 0.5:
				continue
			var maximum := maxf(sample.r, maxf(sample.g, sample.b))
			var minimum := minf(sample.r, minf(sample.g, sample.b))
			luma_sum += _luma(sample)
			saturation_sum += (maximum - minimum) / maxf(maximum, 0.001)
			cyan_count += 1 if (
				sample.g >= sample.r * 1.12
				and sample.b >= sample.r * 1.08) else 0
			warm_count += 1 if (
				sample.r >= sample.b * 1.16
				and sample.g >= sample.b * 0.82) else 0
			count += 1
	if count == 0:
		return Vector4.ZERO
	return Vector4(
		luma_sum / float(count),
		saturation_sum / float(count),
		float(cyan_count) / float(count),
		float(warm_count) / float(count))


func _edge_fraction(image: Image, threshold: float, step: int) -> float:
	var edge_count := 0
	var count := 0
	for y: int in range(0, image.get_height() - step, step):
		for x: int in range(0, image.get_width() - step, step):
			var sample := image.get_pixel(x, y)
			if sample.a < 0.5:
				continue
			var right := image.get_pixel(x + step, y)
			var down := image.get_pixel(x, y + step)
			if right.a < 0.5 or down.a < 0.5:
				continue
			edge_count += 1 if maxf(
				_color_delta(sample, right),
				_color_delta(sample, down)) >= threshold else 0
			count += 1
	return float(edge_count) / float(count) if count > 0 else 0.0


func _far_cleanup_stats(
		baseline: Image,
		cleaned: Image,
		outlier_threshold: float,
		neighbor_coherence: float,
		edge_protection: float) -> Vector3:
	var before_isolated := 0
	var after_isolated := 0
	var eligible := 0
	var preserved_edges := 0
	var edge_count := 0
	var width := mini(baseline.get_width(), cleaned.get_width())
	var height := mini(baseline.get_height(), cleaned.get_height())
	for y: int in range(1, height - 1):
		for x: int in range(1, width - 1):
			var before_center := baseline.get_pixel(x, y)
			if before_center.a < 0.95:
				continue
			var before_left := baseline.get_pixel(x - 1, y)
			var before_right := baseline.get_pixel(x + 1, y)
			var before_up := baseline.get_pixel(x, y - 1)
			var before_down := baseline.get_pixel(x, y + 1)
			if minf(minf(before_left.a, before_right.a),
					minf(before_up.a, before_down.a)) < 0.95:
				continue
			var before_mean := (
				before_left + before_right + before_up + before_down) * 0.25
			var before_spread := maxf(
				maxf(_color_delta(before_left, before_mean),
					_color_delta(before_right, before_mean)),
				maxf(_color_delta(before_up, before_mean),
					_color_delta(before_down, before_mean)))
			var before_edge := maxf(
				_color_delta(before_left, before_right),
				_color_delta(before_up, before_down))
			var before_is_outlier := (
				_color_delta(before_center, before_mean) >= outlier_threshold
				and before_spread <= neighbor_coherence
				and before_edge <= edge_protection)

			var after_center := cleaned.get_pixel(x, y)
			var after_left := cleaned.get_pixel(x - 1, y)
			var after_right := cleaned.get_pixel(x + 1, y)
			var after_up := cleaned.get_pixel(x, y - 1)
			var after_down := cleaned.get_pixel(x, y + 1)
			var after_mean := (
				after_left + after_right + after_up + after_down) * 0.25
			var after_spread := maxf(
				maxf(_color_delta(after_left, after_mean),
					_color_delta(after_right, after_mean)),
				maxf(_color_delta(after_up, after_mean),
					_color_delta(after_down, after_mean)))
			var after_edge := maxf(
				_color_delta(after_left, after_right),
				_color_delta(after_up, after_down))
			var after_is_outlier := (
				_color_delta(after_center, after_mean) >= outlier_threshold
				and after_spread <= neighbor_coherence
				and after_edge <= edge_protection)

			before_isolated += 1 if before_is_outlier else 0
			after_isolated += 1 if after_is_outlier else 0
			eligible += 1
			if before_edge >= edge_protection and not before_is_outlier:
				edge_count += 1
				preserved_edges += 1 if (
					_color_delta(before_center, after_center) <= 0.035) else 0
	return Vector3(
		float(before_isolated) / float(eligible) if eligible > 0 else 0.0,
		float(after_isolated) / float(eligible) if eligible > 0 else 0.0,
		float(preserved_edges) / float(edge_count) if edge_count > 0 else 1.0)


func _color_delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
