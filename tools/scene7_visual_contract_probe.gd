extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const PLATFORM_ELEVATION_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_platform_elevation.gdshader"
const FAR_WATER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_far_water.gdshader"
const FRONT_WATER_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_water.gdshader"
const DEPTH_VEIL_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_depth_veil.gdshader"
const MOTES_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_motes.gdshader"
const FAR_CLEANUP_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_far_cleanup.gdshader"
func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var stage := SCENE7.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame
	stage.set_process(false)

	var rear_water := stage.get_node("RearWater") as Polygon2D
	var front_water := stage.get_node("FrontWater") as ColorRect
	var depth_veil := stage.get_node("OasisDepthVeil") as ColorRect
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var platform_visible_rect := _displayed_used_rect(platform)
	var authored_geometry_ready := (
		platform.position.is_equal_approx(Vector2(-133.165, 234.0))
		and platform.size.is_equal_approx(Vector2(364.83334, 188.0))
		and platform.scale.is_equal_approx(Vector2(6.0, 6.0))
		and platform.texture.get_size() == Vector2(332.0, 188.0)
		and platform_visible_rect.position.x < 0.0
		and platform_visible_rect.end.x > 1920.0
		and is_equal_approx(platform_visible_rect.position.y, 738.0)
		and is_equal_approx(platform_visible_rect.size.y, 126.0))
	var authored_layering_ready := (
		stage.get_node("FarBackground").get_index() < depth_veil.get_index()
		and depth_veil.get_index() < rear_water.get_index()
		and rear_water.get_index() < stage.get_node("OasisMotesFar").get_index()
		and stage.get_node("OasisMotesFar").get_index()
				< stage.get_node("MidgroundCenter").get_index()
		and stage.get_node("MidgroundCenter").get_index()
				< stage.get_node("MidgroundLeft").get_index()
		and stage.get_node("MidgroundLeft").get_index()
				< stage.get_node("MidgroundRight").get_index()
		and stage.get_node("MidgroundRight").get_index()
				< stage.get_node("OasisReflectionGrab").get_index()
		and stage.get_node("OasisReflectionGrab").get_index()
				< front_water.get_index()
		and front_water.get_index() < platform.get_index()
		and platform.get_index() < stage.get_node("OasisMotesNear").get_index()
		and stage.get_node("OasisMotesNear").get_index()
				< stage.get_node("ForegroundLeft").get_index())

	var water_layering_ready := true
	var road_overdraw_height := 0.0
	var water_system_ready := true
	var depth_luma_ranges: Array[float] = []
	for water_name: String in ["RearWater", "FrontWater"]:
		var water := stage.get_node(water_name) as CanvasItem
		var overlap := _water_rect(water).intersection(
			platform_visible_rect)
		if water.get_index() > platform.get_index() and overlap.has_area():
			water_layering_ready = false
			road_overdraw_height += overlap.size.y
		var material := water.material as ShaderMaterial
		var expected_shader := (
			FAR_WATER_SHADER_PATH
			if water is Polygon2D
			else FRONT_WATER_SHADER_PATH)
		water_system_ready = (
			water_system_ready
			and material != null
			and material.shader.resource_path == expected_shader
			and water.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		var surface: Color = material.get_shader_parameter("surface_color")
		var deep: Color = material.get_shader_parameter("deep_color")
		depth_luma_ranges.append(absf(_luma(surface) - _luma(deep)))
	water_system_ready = (
		water_system_ready
		and rear_water.polygon.size() == 24
		and rear_water.uv.size() == 24
		and rear_water.polygon[0] == Vector2(-32.0, 680.0)
		and rear_water.polygon[16] == Vector2(1536.0, 684.0)
		and rear_water.uv[0] == Vector2(0.0, 0.0)
		and rear_water.uv[21] == Vector2(480.0, 0.0)
		and rear_water.uv[22] == Vector2(480.0, 29.0)
		and rear_water.uv[23] == Vector2(0.0, 29.0)
		and rear_water.texture == null
		and platform_visible_rect.end.y - front_water.position.y >= 6.0
		and platform_visible_rect.end.y - front_water.position.y <= 10.0
		and stage.get_node_or_null("PlatformWaterContact") == null)
	var rear_source := FileAccess.get_file_as_string(FAR_WATER_SHADER_PATH)
	var front_source := FileAccess.get_file_as_string(FRONT_WATER_SHADER_PATH)
	var water_animation_ready: bool = (
		rear_source.contains("TIME * anim_fps")
		and rear_source.contains("local_position = VERTEX")
		and rear_source.contains("spring_distance")
		and rear_source.contains("ring_mask")
		and front_source.contains("TIME * anim_fps")
		and front_source.contains("hint_screen_texture")
		and front_source.contains("signed_radial_wave")
		and front_source.contains("spring_distance")
		and front_source.contains("p1_reflection_tex")
		and front_source.contains("reflection_height_px")
		and not rear_source.contains("flow_speed_px")
		and not front_source.contains("ripple_speed_px")
		and not front_source.contains("flow_direction")
		and not front_source.contains("slice_speed")
		and float((rear_water.material as ShaderMaterial).get_shader_parameter(
				"main_ring_strength")) >= 0.38
		and float((front_water.material as ShaderMaterial).get_shader_parameter(
				"main_ring_strength")) >= 0.35
		and float((front_water.material as ShaderMaterial).get_shader_parameter(
				"reflection_height_px")) >= 500.0
		and float((front_water.material as ShaderMaterial).get_shader_parameter(
				"reflection_strength")) >= 0.5
		and stage.get_node_or_null("WaterAnimationController") == null
		and stage.get_node_or_null("RearWaterAnimated") == null
		and stage.get_node_or_null("FrontWaterAnimated") == null
		and stage.get_node_or_null("RearWaterShape") == null
		and stage.get_node_or_null("FrontShallowWater") == null
		and stage.get_node_or_null("RearWaterFrameArt") == null
		and stage.get_node_or_null("FrontWaterFrameArt") == null
		and stage.get_node_or_null("RearWaterDiagnosticRoot") == null
		and stage.get_node_or_null("FrontWaterDiagnosticRoot") == null)

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
			and float(platform_material.get_shader_parameter("dry_edge_strength")) >= 0.34
			and float(platform_material.get_shader_parameter("wet_edge_strength")) >= 0.22
			and float(platform_material.get_shader_parameter("wet_edge_strength")) <= 0.24
			and float(platform_material.get_shader_parameter("contact_shadow_strength")) >= 0.28
			and float(platform_material.get_shader_parameter("contact_shadow_strength")) <= 0.3
			and float(platform_material.get_shader_parameter("waterline_strength")) >= 0.12
			and float(platform_material.get_shader_parameter("waterline_strength")) <= 0.14)

	var veil_material := depth_veil.material as ShaderMaterial
	var depth_veil_ready := (
		veil_material != null
		and veil_material.shader.resource_path == DEPTH_VEIL_SHADER_PATH
		and float(veil_material.get_shader_parameter("opacity")) >= 0.06
		and float(veil_material.get_shader_parameter("opacity")) <= 0.12
		and depth_veil.position.x <= -24.0
		and depth_veil.position.x + depth_veil.size.x >= 1944.0)
	var far_background := stage.get_node("FarBackground") as TextureRect
	var far_material := far_background.material as ShaderMaterial
	var sky := stage.get_node("Sky") as TextureRect
	var sky_original_ready := (
		sky.material == null
		and sky.texture.resource_path
				== "res://assets/scenes/scene7/scene7_sky.png"
		and stage.get_node_or_null("DaylightBackdrop") == null)
	var far_cleanup_ready := (
		far_material != null
		and far_material.shader.resource_path == FAR_CLEANUP_SHADER_PATH
		and far_background.size.is_equal_approx(Vector2(289.0, 171.0))
		and far_background.scale.is_equal_approx(Vector2(6.7, 6.7))
		and far_background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and float(far_material.get_shader_parameter("cleanup_strength")) >= 0.65
		and float(far_material.get_shader_parameter("cleanup_strength")) <= 0.82
		and float(far_material.get_shader_parameter("outlier_threshold")) >= 0.14
		and float(far_material.get_shader_parameter("neighbor_coherence")) <= 0.16
		and float(far_material.get_shader_parameter("edge_protection")) >= 0.12
		and float(far_material.get_shader_parameter("macro_block_px")) >= 1.5
		and float(far_material.get_shader_parameter("macro_block_px")) <= 2.5
		and float(far_material.get_shader_parameter("detail_reduction")) >= 0.20
		and float(far_material.get_shader_parameter("detail_reduction")) <= 0.36
		and float(far_material.get_shader_parameter("palette_strength")) <= 0.24
		and float(far_material.get_shader_parameter("atmosphere_strength")) >= 0.08
		and float(far_material.get_shader_parameter("atmosphere_strength")) <= 0.16)
	var root_contacts_ready := true
	var mid_air_total := 0.0
	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var atmosphere_strength := float(
				material.get_shader_parameter("atmosphere_strength"))
		mid_air_total += atmosphere_strength
		root_contacts_ready = (
			root_contacts_ready
			and float(material.get_shader_parameter("palette_strength")) >= 0.20
			and atmosphere_strength >= 0.06
			and atmosphere_strength <= 0.08
			and float(material.get_shader_parameter("edge_integration_strength")) >= 0.08
			and float(material.get_shader_parameter("edge_integration_strength")) <= 0.15
			and float(material.get_shader_parameter("contact_strength")) >= 0.34
			and float(material.get_shader_parameter("sediment_strength")) >= 0.14
			and float(material.get_shader_parameter("reflection_strength")) >= 0.10
			and float(material.get_shader_parameter("reflection_strength")) <= 0.24
			and float(material.get_shader_parameter("root_merge_strength")) >= 0.72)
	var foreground_palette_ready := true
	var foreground_air_total := 0.0
	for node_name: String in ["ForegroundLeft", "ForegroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var shadow_palette: Color = material.get_shader_parameter("shadow_palette")
		var sunlit_palette: Color = material.get_shader_parameter("sunlit_palette")
		var palette_strength := float(material.get_shader_parameter("palette_strength"))
		var atmosphere_strength := float(
				material.get_shader_parameter("atmosphere_strength"))
		foreground_air_total += atmosphere_strength
		foreground_palette_ready = (
			foreground_palette_ready
			and palette_strength >= 0.20
			and palette_strength <= 0.25
			and atmosphere_strength >= 0.02
			and atmosphere_strength <= 0.045
			and float(material.get_shader_parameter("edge_integration_strength")) >= 0.04
			and float(material.get_shader_parameter("edge_integration_strength")) <= 0.075
			and shadow_palette.g > shadow_palette.r * 3.0
			and shadow_palette.b > shadow_palette.r * 2.8
			and sunlit_palette.r > sunlit_palette.b * 1.35
			and sunlit_palette.g > sunlit_palette.b * 1.25)
	var depth_layer_integration_ready := (
		root_contacts_ready
		and foreground_palette_ready
		and mid_air_total / 3.0 > foreground_air_total / 2.0 + 0.025)
	var environment_motion_ready := true
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
	for mote_name: String in ["OasisMotesFar", "OasisMotesNear"]:
		var material := (stage.get_node(mote_name) as ColorRect).material as ShaderMaterial
		environment_motion_ready = (
			environment_motion_ready
			and material.shader.resource_path == MOTES_SHADER_PATH
			and float(material.get_shader_parameter("rise_px_per_sec")) >= 2.6
			and float(material.get_shader_parameter("density")) >= 0.34
			and float(material.get_shader_parameter("alpha")) >= 0.28
			and float(material.get_shader_parameter("alpha")) <= 0.42)

	var passed: bool = (
		authored_geometry_ready
		and authored_layering_ready
		and water_layering_ready
		and water_system_ready
		and water_animation_ready
		and platform_contact_ready
		and depth_veil_ready
		and sky_original_ready
		and far_cleanup_ready
		and depth_layer_integration_ready
		and environment_motion_ready)
	print(
		"SCENE7_VISUAL_CONTRACT_PROBE: ",
		"PASS" if passed else "FAIL",
		" authored_geometry_ready=",
		authored_geometry_ready,
		" authored_layering_ready=",
		authored_layering_ready,
		" water_layering_ready=",
		water_layering_ready,
		" water_system_ready=",
		water_system_ready,
		" water_animation_ready=",
		water_animation_ready,
		" platform_contact_ready=",
		platform_contact_ready,
		" depth_veil_ready=",
		depth_veil_ready,
		" sky_original_ready=",
		sky_original_ready,
		" far_cleanup_ready=",
		far_cleanup_ready,
		" far_position=",
		far_background.position,
		" far_macro_block_px=",
		far_material.get_shader_parameter("macro_block_px") if far_material != null else null,
		" far_detail_reduction=",
		far_material.get_shader_parameter("detail_reduction") if far_material != null else null,
		" far_palette_strength=",
		far_material.get_shader_parameter("palette_strength") if far_material != null else null,
		" far_atmosphere_strength=",
		far_material.get_shader_parameter("atmosphere_strength") if far_material != null else null,
		" root_contacts_ready=",
		root_contacts_ready,
		" depth_layer_integration_ready=",
		depth_layer_integration_ready,
		" foreground_palette_ready=",
		foreground_palette_ready,
		" environment_motion_ready=",
		environment_motion_ready,
		" road_overdraw_height=",
		snappedf(road_overdraw_height, 0.01),
		" rear_code_palette_range=",
		snappedf(depth_luma_ranges[0], 0.001),
		" front_code_palette_range=",
		snappedf(depth_luma_ranges[1], 0.001),
		" contact_band_px=",
		contact_band_px,
		" platform_visible_rect=",
		platform_visible_rect)
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _displayed_used_rect(layer: TextureRect) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.5)
	var source_size: Vector2 = layer.texture.get_size()
	var stretch_ratio := Vector2(
		layer.size.x / source_size.x,
		layer.size.y / source_size.y)
	return Rect2(
		layer.position + Vector2(used_rect.position) * stretch_ratio * layer.scale,
		Vector2(used_rect.size) * stretch_ratio * layer.scale)


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


func _water_rect(water: CanvasItem) -> Rect2:
	if water is Control:
		var rect := water as Control
		return Rect2(rect.position, rect.size)
	var polygon := water as Polygon2D
	var bounds := Rect2(polygon.polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon.polygon:
		bounds = bounds.expand(point)
	return bounds


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _water_art_stats(image: Image) -> Vector4:
	var luma_sum := 0.0
	var luma_square_sum := 0.0
	var min_luma := 1.0
	var max_luma := 0.0
	var luminous_count := 0
	var count := image.get_width() * image.get_height()
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var luma := _luma(image.get_pixel(x, y))
			luma_sum += luma
			luma_square_sum += luma * luma
			min_luma = minf(min_luma, luma)
			max_luma = maxf(max_luma, luma)
			if luma >= 0.48:
				luminous_count += 1
	var mean := luma_sum / float(count)
	var deviation := sqrt(maxf(
		luma_square_sum / float(count) - mean * mean, 0.0))
	return Vector4(
		mean,
		max_luma - min_luma,
		deviation,
		float(luminous_count) / float(count))


func _water_color_count(image: Image) -> int:
	var colors: Dictionary = {}
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			colors[image.get_pixel(x, y).to_html(false)] = true
	return colors.size()
