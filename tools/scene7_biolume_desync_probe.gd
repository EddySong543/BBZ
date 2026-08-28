extends Node

const BATTLE7 := preload("res://src/ui/battle_screen7.tscn")
const POINT_LAYERS: Array[String] = [
	"MidgroundCenterGlowFX",
	"MidgroundLeftGlowFX",
	"MidgroundRightGlowFX",
	"ForegroundLeftGlowFX",
]
const CLUSTER_LAYERS: Array[String] = [
	"MidgroundCenterGrassGlowFX",
	"MidgroundRightGrassGlowFX",
]
const SAMPLE_COUNT := 49
const SAMPLE_STEP_SEC := 0.75


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var screen := BATTLE7.instantiate() as Control
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	stage.set_process(false)
	for source_name: String in [
		"MidgroundCenter", "MidgroundLeft", "MidgroundRight", "ForegroundLeft",
	]:
		var source_material := (stage.get_node(source_name) as TextureRect).material \
				as ShaderMaterial
		source_material.set_shader_parameter("branch_motion_enabled", 0.0)

	var layer_positions: Dictionary[String, Array] = {}
	var materials: Dictionary[String, ShaderMaterial] = {}
	var passed := true
	var phase_reports: Array[String] = []
	for layer_name: String in POINT_LAYERS + CLUSTER_LAYERS:
		var overlay := stage.get_node(layer_name) as MeshInstance2D
		var material := overlay.material as ShaderMaterial
		materials[layer_name] = material
		var mask_name := "point_mask" if POINT_LAYERS.has(layer_name) \
				else "cluster_mask"
		var mask := (material.get_shader_parameter(mask_name) as Texture2D).get_image()
		layer_positions[layer_name] = _screen_positions_for_core(overlay, mask)
		if POINT_LAYERS.has(layer_name):
			var phase_count := _point_phase_count(mask)
			var component_count := int(overlay.get_meta("point_component_count", 0))
			passed = passed and phase_count == component_count
			phase_reports.append("%s=%d/%d" % [
					layer_name, phase_count, component_count])

	var series: Dictionary[String, PackedFloat32Array] = {}
	for layer_name: String in POINT_LAYERS + CLUSTER_LAYERS:
		series[layer_name] = PackedFloat32Array()
	for sample_index: int in range(SAMPLE_COUNT):
		var sample_time := float(sample_index) * SAMPLE_STEP_SEC
		for material: ShaderMaterial in materials.values():
			material.set_shader_parameter("diagnostic_time_sec", sample_time)
		await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image()
		for layer_name: String in series:
			series[layer_name].append(_mean_luma(
					frame, layer_positions[layer_name]))

	var correlation_reports: Array[String] = []
	var cluster_correlation := absf(_correlation(
			series[CLUSTER_LAYERS[0]], series[CLUSTER_LAYERS[1]]))
	passed = passed and cluster_correlation <= 0.80
	correlation_reports.append("clusters=%.3f" % cluster_correlation)
	for first_index: int in range(POINT_LAYERS.size()):
		for second_index: int in range(first_index + 1, POINT_LAYERS.size()):
			var first_name := POINT_LAYERS[first_index]
			var second_name := POINT_LAYERS[second_index]
			var correlation := absf(_correlation(
					series[first_name], series[second_name]))
			passed = passed and correlation <= 0.88
			correlation_reports.append("%s/%s=%.3f" % [
					first_name, second_name, correlation])

	for material: ShaderMaterial in materials.values():
		material.set_shader_parameter("diagnostic_time_sec", -1.0)
	print(
			"SCENE7_BIOLUME_DESYNC: ", "PASS" if passed else "FAIL",
			" phases=", phase_reports,
			" correlations=", correlation_reports)
	get_tree().quit(0 if passed else 1)


func _screen_positions_for_core(
		overlay: MeshInstance2D, mask: Image) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	var authored_size: Vector2 = overlay.get_meta("authored_size")
	var transform := overlay.get_global_transform_with_canvas()
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			var color := mask.get_pixel(x, y)
			if color.a < 0.5 or color.r < 0.5:
				continue
			var uv := Vector2(
					(float(x) + 0.5) / float(mask.get_width()),
					(float(y) + 0.5) / float(mask.get_height()))
			var position := Vector2i((transform * (uv * authored_size)).round())
			if position.x < 0 or position.y < 0 \
					or position.x >= 1920 or position.y >= 1080 \
					or seen.has(position):
				continue
			seen[position] = true
			result.append(position)
	return result


func _point_phase_count(mask: Image) -> int:
	var phases: Dictionary[int, bool] = {}
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			var color := mask.get_pixel(x, y)
			if color.a >= 0.5 and color.r >= 0.5:
				phases[int(round(color.b * 255.0))] = true
	return phases.size()


func _mean_luma(image: Image, positions: Array) -> float:
	if positions.is_empty():
		return 0.0
	var total := 0.0
	for position: Vector2i in positions:
		var color := image.get_pixelv(position)
		total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return total / float(positions.size())


func _correlation(first: PackedFloat32Array, second: PackedFloat32Array) -> float:
	var count := mini(first.size(), second.size())
	if count <= 1:
		return 1.0
	var first_mean := 0.0
	var second_mean := 0.0
	for index: int in range(count):
		first_mean += first[index]
		second_mean += second[index]
	first_mean /= float(count)
	second_mean /= float(count)
	var covariance := 0.0
	var first_variance := 0.0
	var second_variance := 0.0
	for index: int in range(count):
		var first_delta := first[index] - first_mean
		var second_delta := second[index] - second_mean
		covariance += first_delta * second_delta
		first_variance += first_delta * first_delta
		second_variance += second_delta * second_delta
	return covariance / maxf(sqrt(first_variance * second_variance), 0.000001)
