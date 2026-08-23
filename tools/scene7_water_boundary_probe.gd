extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const SCREEN_WIDTH := 1920
const SAMPLE_STEP := 96
const ALPHA_THRESHOLD := 0.08
const FAR_WATER_SHADER := \
		"res://assets/shaders/canvas_env_scene7_oasis_far_water.gdshader"
const FRONT_WATER_SHADER := \
		"res://assets/shaders/canvas_env_scene7_oasis_water.gdshader"
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
	var platform_rect := _displayed_used_rect(platform)
	var front_water := stage.get_node("FrontWater") as ColorRect
	var front_underlap := platform_rect.end.y - front_water.position.y
	var rear_material := rear_water.material as ShaderMaterial
	var front_material := front_water.material as ShaderMaterial
	var rear_source := FileAccess.get_file_as_string(FAR_WATER_SHADER)
	var front_source := FileAccess.get_file_as_string(FRONT_WATER_SHADER)
	var code_water_ready := (
		rear_material != null
		and front_material != null
		and rear_material.shader.resource_path == FAR_WATER_SHADER
		and front_material.shader.resource_path == FRONT_WATER_SHADER
		and rear_water.texture == null
		and rear_water.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and front_water.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and rear_source.contains("TIME * anim_fps")
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
		and float(rear_material.get_shader_parameter("main_ring_strength")) >= 0.38
		and float(front_material.get_shader_parameter("main_ring_strength")) >= 0.35
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
		and rear_water.uv[23] == Vector2(0.0, 29.0))
	var code_boundary_ready: bool = (
		rear_water.get_index() < stage.get_node("MidgroundLeft").get_index()
		and stage.get_node("MidgroundLeft").get_index() < front_water.get_index()
		and stage.get_node("MidgroundCenter").get_index() < front_water.get_index()
		and stage.get_node("MidgroundRight").get_index() < front_water.get_index()
		and stage.get_node("MidgroundCenter").get_index()
				< stage.get_node("OasisReflectionGrab").get_index()
		and stage.get_node("OasisReflectionGrab").get_index()
				< front_water.get_index()
		and front_water.get_index() < platform.get_index()
		and stage.get_node_or_null("WaterAnimationController") == null
		and stage.get_node_or_null("RearWaterAnimated") == null
		and stage.get_node_or_null("FrontWaterAnimated") == null
		and stage.get_node_or_null("RearWaterShape") == null
		and stage.get_node_or_null("FrontShallowWater") == null)
	var platform_contact_ready := (
		float(platform_material.get_shader_parameter("contact_band_px")) >= 4.0
		and float(platform_material.get_shader_parameter("contact_band_px")) <= 6.0
		and float(platform_material.get_shader_parameter("dry_edge_strength")) >= 0.34
		and float(platform_material.get_shader_parameter("wet_edge_strength")) >= 0.22
		and float(platform_material.get_shader_parameter("wet_edge_strength")) <= 0.24
		and float(platform_material.get_shader_parameter("contact_shadow_strength")) >= 0.28
		and float(platform_material.get_shader_parameter("contact_shadow_strength")) <= 0.3
		and float(platform_material.get_shader_parameter("waterline_strength")) >= 0.12
		and float(platform_material.get_shader_parameter("waterline_strength")) <= 0.14)
	var passed: bool = (
		visible_upper_excess >= 16.0
		and visible_upper_excess <= 32.0
		and front_underlap >= 6.0
		and front_underlap <= 10.0
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
