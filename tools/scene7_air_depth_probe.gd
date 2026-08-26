extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const MOTES_SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_oasis_motes.gdshader"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := SCENE7.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame
	var failures: Array[String] = []
	var metrics: Dictionary = {}
	var names: Array[String] = [
		"OasisMotesFar", "OasisMotesMid", "OasisMotesNear",
	]
	var expected_roles: Array[String] = [
		"far_air_behind_vegetation",
		"mid_air_depth_bridge",
		"near_air_behind_foreground",
	]
	var previous_alpha := -1.0
	var previous_rise := -1.0
	var previous_cell_width := 0.0
	for index: int in names.size():
		var layer := stage.get_node_or_null(names[index]) as ColorRect
		if layer == null:
			failures.append("missing %s" % names[index])
			continue
		var material := layer.material as ShaderMaterial
		if material == null or material.shader == null \
				or material.shader.resource_path != MOTES_SHADER_PATH:
			failures.append("%s is outside the Scene7 mote shader chain" % names[index])
			continue
		var pixel_grid: Vector2 = material.get_shader_parameter("pixel_grid")
		var macro_cell: Vector2 = material.get_shader_parameter("macro_cell")
		var density := float(material.get_shader_parameter("density"))
		var secondary_density := float(material.get_shader_parameter(
				"secondary_density"))
		var layer_alpha := float(material.get_shader_parameter("alpha"))
		var rise_speed := float(material.get_shader_parameter("rise_px_per_sec"))
		var sway_px := float(material.get_shader_parameter("horizontal_sway_px"))
		var macro_count := ceili(pixel_grid.x / macro_cell.x) \
				* ceili(pixel_grid.y / macro_cell.y)
		var expected_visible := float(macro_count) * (density + secondary_density)
		var screen_cell_width := layer.size.x / pixel_grid.x
		var screen_cell_height := layer.size.y / pixel_grid.y
		var rise_over_four_sec := rise_speed * 4.0 * screen_cell_height
		var sway_reach := sway_px * screen_cell_width
		if expected_visible < 13.0:
			failures.append("%s is too sparse to establish its depth plane" % names[index])
		if rise_over_four_sec < 10.0:
			failures.append("%s motion is below the readable displacement gate" % names[index])
		if index > 0 and layer_alpha <= previous_alpha:
			failures.append("mote alpha does not increase toward camera")
		if index > 0 and rise_speed <= previous_rise:
			failures.append("mote speed does not increase toward camera")
		if index > 0 and screen_cell_width + 0.01 < previous_cell_width:
			failures.append("mote pixel scale shrinks toward camera")
		if String(layer.get_meta("composition_role", "")) != expected_roles[index]:
			failures.append("%s lacks its explicit depth role" % names[index])
		material.set_shader_parameter("diagnostic_time_sec", 4.0)
		if not is_equal_approx(float(material.get_shader_parameter(
				"diagnostic_time_sec")), 4.0):
			failures.append("%s diagnostic time is not connected" % names[index])
		material.set_shader_parameter("diagnostic_time_sec", -1.0)
		metrics[names[index]] = {
			"expected_visible": snappedf(expected_visible, 0.1),
			"screen_cell_px": Vector2(
				snappedf(screen_cell_width, 0.01),
				snappedf(screen_cell_height, 0.01)),
			"rise_4s_px": snappedf(rise_over_four_sec, 0.1),
			"sway_reach_px": snappedf(sway_reach, 0.1),
			"alpha": layer_alpha,
			"parallax": float(layer.get_meta("parallax_factor")),
		}
		previous_alpha = layer_alpha
		previous_rise = rise_speed
		previous_cell_width = screen_cell_width

	var source := FileAccess.get_file_as_string(MOTES_SHADER_PATH)
	for required_token: String in [
		"mote_sample", "local_cycle", "seed_speed", "horizontal_sway_px",
		"wrapped_axis_distance", "secondary_density", "motion_time()",
	]:
		if not source.contains(required_token):
			failures.append("mote shader lacks %s" % required_token)
	for rejected_token: String in [
		"moving_cell = cell + drift", "horizontal_px_per_sec",
	]:
		if source.contains(rejected_token):
			failures.append("mote shader retained sheet motion %s" % rejected_token)

	var far := stage.get_node("OasisMotesFar") as ColorRect
	var mid := stage.get_node("OasisMotesMid") as ColorRect
	var near := stage.get_node("OasisMotesNear") as ColorRect
	var reflection := stage.get_node("RearWaterReflection") as Polygon2D
	var front_water := stage.get_node("FrontWater") as ColorRect
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var foreground := stage.get_node("ForegroundLeft") as TextureRect
	if not (far.get_index() < stage.get_node("MidgroundLeft").get_index()
			and reflection.get_index() < mid.get_index()
			and mid.get_index() < front_water.get_index()
			and platform.get_index() < near.get_index()
			and near.get_index() < foreground.get_index()):
		failures.append("air layers do not occupy three independent depth planes")

	var passed := failures.is_empty()
	print("SCENE7_AIR_DEPTH_PROBE: ", "PASS" if passed else "FAIL",
			" metrics=", metrics, " failures=", failures)
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)
