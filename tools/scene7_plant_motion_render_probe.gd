extends Node

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const PLANT_LAYERS: Array[String] = [
	"MidgroundCenter",
	"MidgroundLeft",
	"MidgroundRight",
	"ForegroundLeft",
]
const GLOW_LAYERS: Array[String] = [
	"MidgroundCenterGlowFX",
	"MidgroundCenterGrassGlowFX",
	"MidgroundLeftGlowFX",
	"MidgroundRightGlowFX",
	"MidgroundRightGrassGlowFX",
	"ForegroundLeftGlowFX",
]
const OTHER_ANIMATED_LAYERS: Array[String] = [
	"RearWater",
	"OasisMotesFar",
	"RearWaterReflection",
	"OasisMotesMid",
	"FrontWater",
	"PlatformSpringContact",
	"OasisMotesNear",
]
const SAMPLE_COUNT := 24
const READABLE_DELTA := 0.04


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage := SCENE7.instantiate() as Control
	viewport.add_child(stage)
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	for node_name: String in GLOW_LAYERS + OTHER_ANIMATED_LAYERS:
		stage.get_node(node_name).visible = false
	for layer_name: String in PLANT_LAYERS:
		var material := (stage.get_node(layer_name) as TextureRect).material \
				as ShaderMaterial
		material.set_shader_parameter("branch_motion_enabled", 0.0)
		material.set_shader_parameter("branch_diagnostic_time_sec", 0.0)
	await RenderingServer.frame_post_draw

	var passed := true
	var reports: Array[String] = []
	for layer_name: String in PLANT_LAYERS:
		var layer := stage.get_node(layer_name) as TextureRect
		var material := layer.material as ShaderMaterial
		material.set_shader_parameter("branch_motion_enabled", 1.0)
		material.set_shader_parameter("branch_diagnostic_time_sec", 0.0)
		await RenderingServer.frame_post_draw
		var baseline := viewport.get_texture().get_image()
		var bounds := _screen_bounds(layer)
		var longest_cycle := _longest_cycle(material)
		var best_changed_pixels := 0
		var best_max_delta := 0.0
		for sample_index: int in range(1, SAMPLE_COUNT):
			var sample_time := longest_cycle * 1.5 \
					* float(sample_index) / float(SAMPLE_COUNT - 1)
			material.set_shader_parameter(
					"branch_diagnostic_time_sec", sample_time)
			await RenderingServer.frame_post_draw
			var frame := viewport.get_texture().get_image()
			var metrics := _difference_metrics(baseline, frame, bounds)
			best_changed_pixels = maxi(
					best_changed_pixels, int(metrics["changed_pixels"]))
			best_max_delta = maxf(
					best_max_delta, float(metrics["max_delta"]))
		var layer_passed := best_changed_pixels >= 40 and best_max_delta >= 0.10
		passed = passed and layer_passed
		reports.append("%s:bounds=%s,changed=%d,max_delta=%.3f" % [
				layer_name,
				bounds,
				best_changed_pixels,
				best_max_delta,
		])
		material.set_shader_parameter("branch_motion_enabled", 0.0)
		material.set_shader_parameter("branch_diagnostic_time_sec", -1.0)

	print(
			"SCENE7_PLANT_FULL_SCENE_MOTION: ",
			"PASS" if passed else "FAIL",
			" layers=", reports)
	get_tree().quit(0 if passed else 1)


func _longest_cycle(material: ShaderMaterial) -> float:
	var cycles: Vector3 = material.get_shader_parameter("branch_cycle_sec")
	return maxf(cycles.x, maxf(cycles.y, cycles.z))


func _screen_bounds(layer: TextureRect) -> Rect2i:
	var transform := layer.get_global_transform_with_canvas()
	var corners: Array[Vector2] = [
		transform * Vector2.ZERO,
		transform * Vector2(layer.size.x, 0.0),
		transform * Vector2(0.0, layer.size.y),
		transform * layer.size,
	]
	var minimum := corners[0]
	var maximum := corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	var rect := Rect2i(
			Vector2i(minimum.floor()),
			Vector2i((maximum - minimum).ceil()))
	return rect.intersection(Rect2i(0, 0, 1920, 1080))


func _difference_metrics(
		baseline: Image, frame: Image, bounds: Rect2i) -> Dictionary:
	var changed_pixels := 0
	var max_delta := 0.0
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var before := baseline.get_pixel(x, y)
			var after := frame.get_pixel(x, y)
			var delta := maxf(
					absf(after.r - before.r),
					maxf(absf(after.g - before.g), absf(after.b - before.b)))
			max_delta = maxf(max_delta, delta)
			if delta >= READABLE_DELTA:
				changed_pixels += 1
	return {
		"changed_pixels": changed_pixels,
		"max_delta": max_delta,
	}
