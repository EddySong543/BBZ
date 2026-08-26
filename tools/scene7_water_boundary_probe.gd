extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const SCREEN_WIDTH := 1920
const SAMPLE_STEP := 96
const ALPHA_THRESHOLD := 0.08
const FAR_WATER_SHADER := \
		"res://assets/shaders/canvas_env_scene7_oasis_far_water.gdshader"
const FAR_REFLECTION_SHADER := \
		"res://assets/shaders/canvas_env_scene7_oasis_far_reflection.gdshader"
const FRONT_WATER_SHADER := \
		"res://assets/shaders/canvas_env_scene7_oasis_water.gdshader"
const PLATFORM_SPRING_CONTACT_SHADER := \
		"res://assets/shaders/canvas_env_scene7_platform_spring_contact.gdshader"
const REAR_SPRITESHEET := \
		"res://assets/scenes/scene7/scene7_water_rear_animated.png"
const FRONT_SPRITESHEET := \
		"res://assets/scenes/scene7/scene7_water_front_animated.png"


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var stage := SCENE7.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame
	var bottom_envelope := PackedFloat32Array()
	bottom_envelope.resize(SCREEN_WIDTH / SAMPLE_STEP + 1)
	bottom_envelope.fill(-INF)
	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		_accumulate_bottom_envelope(
			stage.get_node(node_name) as TextureRect,
			bottom_envelope)
	var samples: Array[String] = []
	for index: int in range(bottom_envelope.size()):
		samples.append("%d:%.1f" % [index * SAMPLE_STEP, bottom_envelope[index]])
	var rear_water := stage.get_node("RearWater") as Polygon2D
	var rear_reflection := stage.get_node("RearWaterReflection") as Polygon2D
	var visible_upper_excess := 0.0
	for point_index: int in range(rear_water.polygon.size() - 2):
		var point := rear_water.polygon[point_index]
		var sample_index := clampi(
			roundi(point.x / SAMPLE_STEP),
			0,
			bottom_envelope.size() - 1)
		visible_upper_excess = maxf(
			visible_upper_excess,
			bottom_envelope[sample_index] - point.y)
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var platform_rect := _scene7_platform_visible_rect(platform)
	var bottom_edge_pixel_count := _bottom_edge_pixel_count(
			platform.texture.get_image())
	var front_water := stage.get_node("FrontWater") as ColorRect
	var spring_contact := stage.get_node("PlatformSpringContact") as ColorRect
	var front_underlap := platform_rect.end.y - front_water.position.y
	var rear_material := rear_water.material as ShaderMaterial
	var front_material := front_water.material as ShaderMaterial
	var rear_source := FileAccess.get_file_as_string(FAR_WATER_SHADER)
	var rear_reflection_source := FileAccess.get_file_as_string(
			FAR_REFLECTION_SHADER)
	var front_source := FileAccess.get_file_as_string(FRONT_WATER_SHADER)
	var shared_palette_delta := 0.0
	for palette_pair: Array in [
		["surface_color", "surface_color"],
		["mid_color", "shallow_color"],
		["deep_color", "deep_color"],
		["ripple_color", "ripple_color"],
		["spring_glow_color", "spring_glow_color"],
	]:
		shared_palette_delta = maxf(
				shared_palette_delta,
				_rgb_distance(
					rear_material.get_shader_parameter(palette_pair[0]),
					front_material.get_shader_parameter(palette_pair[1])))
	var code_water_ready := (
		rear_material != null
		and front_material != null
		and rear_material.shader.resource_path == FAR_WATER_SHADER
		and front_material.shader.resource_path == FRONT_WATER_SHADER
		and rear_water.texture == null
		and rear_water.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and front_water.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and rear_source.contains("motion_time() * anim_fps")
		and rear_source.contains("local_position = VERTEX")
		and rear_source.contains("spring_distance")
		and rear_source.contains("ring_mask")
		and rear_source.contains("secondary_distance_a")
		and rear_source.contains("secondary_distance_b")
		and rear_source.contains("glint_pulse")
		and rear_source.contains("glint_segment")
		and rear_source.contains("diagnostic_time_sec")
		and rear_source.contains("shoreline_depth = COLOR.r")
		and rear_source.contains("shore_depth_px")
		and rear_source.contains("distance_atmosphere")
		and not rear_source.contains("polygon_uv")
		and not rear_source.contains("reflected_bank")
		and (rear_reflection.material as ShaderMaterial).shader.resource_path
				== FAR_REFLECTION_SHADER
		and rear_reflection_source.contains("hint_screen_texture")
		and rear_reflection_source.contains("SCREEN_UV")
		and rear_reflection_source.contains("shoreline_depth = COLOR.r")
		and rear_reflection_source.contains("palette_reflection_from_luma")
		and rear_reflection_source.contains("vegetation_signal")
		and rear_reflection_source.contains("motion_time() * anim_fps")
		and rear_reflection_source.contains("animated_offset")
		and rear_reflection_source.contains("reflection_breathe_strength")
		and rear_reflection_source.contains("signed_pixel_snap")
		and not rear_reflection_source.contains("flow_direction")
		and not rear_reflection_source.contains("flow_speed")
		and front_source.contains("motion_time() * anim_fps")
		and front_source.contains("hint_screen_texture")
		and front_source.contains("signed_radial_wave")
		and front_source.contains("spring_distance")
		and front_source.contains("secondary_distance_a")
		and front_source.contains("secondary_distance_b")
		and front_source.contains("glint_pulse")
		and front_source.contains("glint_segment")
		and front_source.contains("reflection_sway")
		and front_source.contains("diagnostic_time_sec")
		and front_source.contains("p1_reflection_tex")
		and front_source.contains("reflection_height_px")
		and front_source.contains("palette_reflection_from_luma")
		and not front_source.contains("shore_cluster")
		and shared_palette_delta <= 0.01
		and not rear_source.contains("flow_speed_px")
		and not front_source.contains("ripple_speed_px")
		and not front_source.contains("flow_direction")
		and not front_source.contains("slice_speed")
		and float(rear_material.get_shader_parameter("main_ring_strength")) >= 0.38
		and float(front_material.get_shader_parameter("main_ring_strength")) >= 0.35
		and float(rear_material.get_shader_parameter("glint_strength")) >= 0.12
		and float(front_material.get_shader_parameter("glint_strength")) >= 0.12
		and float(rear_material.get_shader_parameter("micro_ring_strength")) >= 0.08
		and float(front_material.get_shader_parameter("micro_ring_strength")) >= 0.08
		and float(front_material.get_shader_parameter("reflection_height_px")) >= 500.0
		and float(front_material.get_shader_parameter("reflection_strength")) >= 0.5
		and float(front_material.get_shader_parameter("reflection_colorize")) >= 0.6
		and not FileAccess.file_exists(REAR_SPRITESHEET)
		and not FileAccess.file_exists(FRONT_SPRITESHEET))
	var platform_material := platform.material as ShaderMaterial
	code_water_ready = (
		code_water_ready
		and rear_water.uv.size() == 24
		and rear_water.uv[0] == Vector2(0.0, 0.0)
		and rear_water.uv[21] == Vector2(480.0, 0.0)
		and rear_water.uv[22] == Vector2(480.0, 29.0)
		and rear_water.uv[23] == Vector2(0.0, 29.0)
		and rear_water.vertex_colors.size() == 24
		and is_equal_approx(rear_water.vertex_colors[0].r, 0.0)
		and is_equal_approx(rear_water.vertex_colors[21].r, 0.0)
		and is_equal_approx(rear_water.vertex_colors[22].r, 1.0)
		and is_equal_approx(rear_water.vertex_colors[23].r, 1.0))
	code_water_ready = (
		code_water_ready
		and rear_reflection.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and rear_reflection.polygon == rear_water.polygon
		and rear_reflection.uv == rear_water.uv
		and _vertex_colors_match(
				rear_reflection.vertex_colors, rear_water.vertex_colors)
		and is_equal_approx(float(rear_reflection.get_meta("parallax_factor")), 0.55)
		and float((rear_reflection.material as ShaderMaterial).get_shader_parameter(
				"reflection_strength")) >= 0.24
		and float((rear_reflection.material as ShaderMaterial).get_shader_parameter(
				"reflection_strength")) <= 0.34)
	var code_boundary_ready: bool = (
		rear_water.get_index() < stage.get_node("MidgroundLeft").get_index()
		and stage.get_node("MidgroundLeft").get_index() < front_water.get_index()
		and stage.get_node("MidgroundCenter").get_index() < front_water.get_index()
		and stage.get_node("MidgroundRight").get_index() < front_water.get_index()
		and stage.get_node("MidgroundCenter").get_index()
				< stage.get_node("OasisReflectionGrab").get_index()
		and stage.get_node("OasisReflectionGrab").get_index()
				< rear_reflection.get_index()
		and rear_reflection.get_index() < front_water.get_index()
		and front_water.get_index() < spring_contact.get_index()
		and spring_contact.get_index() < platform.get_index()
		and stage.get_node_or_null("WaterAnimationController") == null
		and stage.get_node_or_null("RearWaterAnimated") == null
		and stage.get_node_or_null("FrontWaterAnimated") == null
		and stage.get_node_or_null("RearWaterShape") == null
		and stage.get_node_or_null("FrontShallowWater") == null)
	var underside_tint: Color = platform_material.get_shader_parameter(
			"underside_tint")
	var platform_elevation_ready: bool = (
		platform_material.shader.resource_path.ends_with(
				"canvas_env_scene7_platform_elevation.gdshader")
		and stage.get_node_or_null("PlatformWaterGrab") == null
		and stage.get_node_or_null("PlatformFoundation") == null
		and bottom_edge_pixel_count == 316
		and underside_tint.s >= 0.28
		and underside_tint.s <= 0.38
		and underside_tint.v >= 0.36
		and underside_tint.v <= 0.44
		and float(platform_material.get_shader_parameter(
				"underside_strength")) >= 0.78
		and float(platform_material.get_shader_parameter(
				"underside_strength")) <= 0.86)
	var platform_source := FileAccess.get_file_as_string(
			platform_material.shader.resource_path)
	var spring_contact_material := spring_contact.material as ShaderMaterial
	var spring_contact_source := FileAccess.get_file_as_string(
			PLATFORM_SPRING_CONTACT_SHADER)
	var platform_source_ready: bool = (
		platform_source.contains("source_surface")
		and platform_source.contains("source_down")
		and platform_source.contains("bottom_edge")
		and platform_source.contains("underside_tint")
		and platform_source.contains("source_surface.a")
		and not platform_source.contains("hint_screen_texture")
		and not platform_source.contains("SCREEN_UV")
		and not platform_source.contains("outside_alpha")
		and not platform_source.contains("submerged_shelf")
		and not platform_source.contains("TIME"))
	var spring_contact_resource_ready: bool = (
		spring_contact_material != null
		and spring_contact_material.shader.resource_path
				== PLATFORM_SPRING_CONTACT_SHADER)
	var spring_contact_geometry_ready: bool = (
		spring_contact.position == Vector2(-32.0, 824.0)
		and spring_contact.size == Vector2(1984.0, 18.0))
	var spring_contact_scalar_parameters_ready: bool = (
		is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"contact_thickness_px")), 5.0)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"line_cell_width_px")), 78.0)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"line_presence")), 0.86)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"line_margin_px")), 8.0)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"contact_alpha")), 0.66)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"minimum_thickness_px")), 3.0)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"anim_fps")), 8.0)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"spring_period_sec")), 7.6)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"active_line_ratio")), 0.64)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"ripple_palette_mix")), 0.58)
		and is_equal_approx(float(spring_contact_material.get_shader_parameter(
				"glow_palette_mix")), 0.42))
	var spring_contact_platform_binding_ready: bool = (
		(spring_contact_material.get_shader_parameter(
				"platform_rect_size_px") as Vector2).is_equal_approx(platform.size)
		and (spring_contact_material.get_shader_parameter(
				"platform_node_scale") as Vector2).is_equal_approx(platform.scale))
	var spring_contact_no_legacy_motion: bool = (
		spring_contact_material.get_shader_parameter("motion_px") == null)
	var spring_contact_parameters_ready: bool = (
		spring_contact_resource_ready
		and spring_contact_geometry_ready
		and spring_contact_scalar_parameters_ready
		and spring_contact_platform_binding_ready
		and spring_contact_no_legacy_motion)
	var spring_contact_source_ready: bool = (
		spring_contact_source.contains("platform_texture")
		and spring_contact_source.contains("platform_rect_size_px")
		and spring_contact_source.contains("platform_node_scale")
		and spring_contact_source.contains("platform_uv_x")
		and spring_contact_source.contains("stable_hash")
		and spring_contact_source.contains("TIME")
		and spring_contact_source.contains("accepted_static_alpha")
		and spring_contact_source.contains("authored_line_width")
		and spring_contact_source.contains("authored_line_start")
		and spring_contact_source.contains("contact_event_state")
		and spring_contact_source.contains("active_line_ratio")
		and spring_contact_source.contains("spring_period_sec")
		and spring_contact_source.contains(
				"floor(TIME * anim_fps) / anim_fps")
		and spring_contact_source.contains("single_line_mask")
		and spring_contact_source.contains("maximum_edge_cut")
		and spring_contact_source.contains("active_thickness_px")
		and spring_contact_source.contains("minimum_thickness_px")
		and spring_contact_source.contains("hold_frames = 6.0")
		and spring_contact_source.contains("contact_ripple_color")
		and spring_contact_source.contains("contact_glow_color"))
	var spring_contact_forbidden_free: bool = (
		not spring_contact_source.contains("segment_length_ratio")
		and not spring_contact_source.contains("segment_width_px")
		and not spring_contact_source.contains("segment_density")
		and not spring_contact_source.contains("cluster_layout")
		and not spring_contact_source.contains("straight_edge_coverage")
		and not spring_contact_source.contains("cos(6.2831853 * group_phase)")
		and not spring_contact_source.contains("smoothstep")
		and not spring_contact_source.contains("spring_surge_event")
		and not spring_contact_source.contains("surge_extension_alpha")
		and not spring_contact_source.contains("base_highlight")
		and not spring_contact_source.contains("local_spring_retraction")
		and not spring_contact_source.contains("bottom_row_visibility")
		and not spring_contact_source.contains("diagnostic_motion_enabled")
		and not spring_contact_source.contains("diagnostic_phase")
		and not spring_contact_source.contains("diagnostic_region")
		and not spring_contact_source.contains("accent_color")
		and not spring_contact_source.contains("accent_contact_thickness_px")
		and not spring_contact_source.contains("flow_direction")
		and not spring_contact_source.contains("flow_speed")
		and not spring_contact_source.contains("touch_shift"))
	var platform_contact_ready: bool = (
		platform_elevation_ready
		and platform_source_ready
		and spring_contact_parameters_ready
		and spring_contact_source_ready
		and spring_contact_forbidden_free)
	var passed: bool = (
		visible_upper_excess >= 16.0
		and visible_upper_excess <= 32.0
		and front_underlap >= 4.0
		and front_underlap <= 10.25
		and is_equal_approx(float(rear_water.get_meta("parallax_factor")), 0.55)
		and is_equal_approx(float(front_water.get_meta("parallax_factor")), 1.0)
		and code_water_ready
		and code_boundary_ready
		and platform_contact_ready
		and stage.get_node_or_null("RearPool") == null
		and stage.get_node_or_null("PlatformWaterContact") == null)
	print(
		"SCENE7_WATER_BOUNDARY_PROBE: ",
		"PASS" if passed else "FAIL",
		" mid_bottom_envelope=",
		",".join(samples),
		" visible_upper_excess=",
		snappedf(visible_upper_excess, 0.01),
		" platform_visible_top=",
		snappedf(platform_rect.position.y, 0.01),
		" platform_visible_bottom=",
		snappedf(platform_rect.end.y, 0.01),
		" front_underlap=",
		snappedf(front_underlap, 0.01),
		" code_water_ready=",
		code_water_ready,
		" code_boundary_ready=",
		code_boundary_ready,
		" platform_contact_ready=",
		platform_contact_ready,
		" platform_contact_debug=",
		{
			"contact_position": spring_contact.position,
			"contact_size": spring_contact.size,
			"platform_rect_material": spring_contact_material.get_shader_parameter(
					"platform_rect_size_px"),
			"platform_rect_runtime": platform.size,
			"platform_scale_material": spring_contact_material.get_shader_parameter(
					"platform_node_scale"),
			"platform_scale_runtime": platform.scale,
			"underside_tint": underside_tint,
			"underside_strength": platform_material.get_shader_parameter(
					"underside_strength"),
			"contact_shader": spring_contact_material.shader.resource_path,
			"contact_thickness_px": spring_contact_material.get_shader_parameter(
					"contact_thickness_px"),
			"line_cell_width_px": spring_contact_material.get_shader_parameter(
					"line_cell_width_px"),
			"line_presence": spring_contact_material.get_shader_parameter(
					"line_presence"),
			"line_margin_px": spring_contact_material.get_shader_parameter(
					"line_margin_px"),
			"contact_alpha": spring_contact_material.get_shader_parameter(
					"contact_alpha"),
			"minimum_thickness_px": spring_contact_material.get_shader_parameter(
					"minimum_thickness_px"),
			"anim_fps": spring_contact_material.get_shader_parameter("anim_fps"),
			"spring_period_sec": spring_contact_material.get_shader_parameter(
					"spring_period_sec"),
			"active_line_ratio": spring_contact_material.get_shader_parameter(
					"active_line_ratio"),
			"ripple_palette_mix": spring_contact_material.get_shader_parameter(
					"ripple_palette_mix"),
			"glow_palette_mix": spring_contact_material.get_shader_parameter(
					"glow_palette_mix"),
			"motion_px": spring_contact_material.get_shader_parameter("motion_px"),
			"platform_elevation_ready": platform_elevation_ready,
			"platform_source_ready": platform_source_ready,
			"spring_contact_resource_ready": spring_contact_resource_ready,
			"spring_contact_geometry_ready": spring_contact_geometry_ready,
			"spring_contact_scalar_parameters_ready":
					spring_contact_scalar_parameters_ready,
			"spring_contact_platform_binding_ready":
					spring_contact_platform_binding_ready,
			"spring_contact_no_legacy_motion": spring_contact_no_legacy_motion,
			"spring_contact_parameters_ready": spring_contact_parameters_ready,
			"spring_contact_source_ready": spring_contact_source_ready,
			"spring_contact_forbidden_free": spring_contact_forbidden_free,
			"source_contract": spring_contact_source.contains(
					"accepted_static_alpha") \
					and spring_contact_source.contains("contact_event_state") \
					and not spring_contact_source.contains("flow_direction"),
		},
		" spring_contact_thickness=",
		float(spring_contact_material.get_shader_parameter(
			"contact_thickness_px")),
		" underside_reach_px=",
		platform.scale.y,
		" bottom_edge_pixel_count=",
		bottom_edge_pixel_count,
		" shared_palette_delta=",
		snappedf(shared_palette_delta, 0.001),
		" rear_parallax=",
		float(rear_water.get_meta("parallax_factor")),
		" front_parallax=",
		float(front_water.get_meta("parallax_factor")))
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _accumulate_bottom_envelope(
		layer: TextureRect,
		bottom_envelope: PackedFloat32Array) -> void:
	var image := layer.texture.get_image()
	var source_size := Vector2(image.get_size())
	var local_pixel_scale := layer.size / source_size
	var screen_pixel_scale := local_pixel_scale * layer.scale
	for source_y: int in range(image.get_height()):
		for source_x: int in range(image.get_width()):
			if image.get_pixel(source_x, source_y).a < ALPHA_THRESHOLD:
				continue
			var screen_x := layer.position.x + source_x * screen_pixel_scale.x
			var screen_y := layer.position.y + (source_y + 1) * screen_pixel_scale.y
			var sample_index := clampi(
				roundi(screen_x / SAMPLE_STEP),
				0,
				bottom_envelope.size() - 1)
			bottom_envelope[sample_index] = maxf(
				bottom_envelope[sample_index],
				screen_y)


func _displayed_used_rect(layer: TextureRect) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.5)
	var source_size: Vector2 = layer.texture.get_size()
	var content_scale := layer.size / source_size
	return Rect2(
		layer.position + Vector2(used_rect.position) * content_scale * layer.scale,
		Vector2(used_rect.size) * content_scale * layer.scale)


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
	var content_scale := layer.size / Vector2(layer.texture.get_size())
	return Rect2(
			layer.position + visible_source_rect.position * content_scale * layer.scale,
			visible_source_rect.size * content_scale * layer.scale)


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


func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _vertex_colors_match(a: PackedColorArray, b: PackedColorArray) -> bool:
	if a.size() != b.size():
		return false
	for index: int in range(a.size()):
		if not a[index].is_equal_approx(b[index]):
			return false
	return true


func _bottom_edge_pixel_count(image: Image) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.5:
				continue
			var alpha_down := image.get_pixel(x, y + 1).a \
					if y + 1 < image.get_height() else 0.0
			if alpha_down < 0.5:
				count += 1
	return count
