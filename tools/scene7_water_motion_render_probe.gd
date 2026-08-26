extends Node

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const REAR_RECT := Rect2i(0, 674, 1920, 86)
const FRONT_RECT := Rect2i(0, 824, 1920, 256)
const SAMPLE_STEP := 4
const SAMPLE_TIMES := [0.0, 2.4, 4.8, 7.2, 9.6]


func _ready() -> void:
	get_window().size = VIEWPORT_SIZE
	get_window().position = Vector2i.ZERO
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)
	var stage := SCENE7.instantiate() as BattleStage
	viewport.add_child(stage)
	stage.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame

	var rear_water := stage.get_node("RearWater") as Polygon2D
	var rear_reflection := stage.get_node("RearWaterReflection") as Polygon2D
	var front_water := stage.get_node("FrontWater") as ColorRect
	var rear_material := rear_water.material as ShaderMaterial
	var reflection_material := rear_reflection.material as ShaderMaterial
	var front_material := front_water.material as ShaderMaterial
	_disable_environment_motion(stage)

	_hide_stage_canvas(stage)
	rear_water.visible = true
	var rear_metrics := await _measure_motion(
			viewport, rear_material, REAR_RECT)

	_hide_stage_canvas(stage)
	_show_static_reflection_sources(stage)
	rear_water.visible = true
	(rear_water.material as ShaderMaterial).set_shader_parameter(
			"diagnostic_time_sec", 0.0)
	(stage.get_node("OasisReflectionGrab") as BackBufferCopy).visible = true
	rear_reflection.visible = true
	var reflection_metrics := await _measure_motion(
			viewport, reflection_material, REAR_RECT)

	_hide_stage_canvas(stage)
	_show_static_reflection_sources(stage)
	(stage.get_node("OasisReflectionGrab") as BackBufferCopy).visible = true
	front_water.visible = true
	var front_metrics := await _measure_motion(
			viewport, front_material, FRONT_RECT)

	rear_material.set_shader_parameter("diagnostic_time_sec", -1.0)
	reflection_material.set_shader_parameter("diagnostic_time_sec", -1.0)
	front_material.set_shader_parameter("diagnostic_time_sec", -1.0)

	var passed := (
			int(rear_metrics["readable_samples"]) >= 140
			and float(rear_metrics["maximum_range"]) >= 0.045
			and float(rear_metrics["mean_range"]) >= 0.004
			and int(reflection_metrics["readable_samples"]) >= 90
			and float(reflection_metrics["maximum_range"]) >= 0.035
			and float(reflection_metrics["mean_range"]) >= 0.003
			and int(front_metrics["readable_samples"]) >= 260
			and float(front_metrics["maximum_range"]) >= 0.055
			and float(front_metrics["mean_range"]) >= 0.006)
	print(
			"SCENE7_WATER_MOTION_RENDER: ", "PASS" if passed else "FAIL",
			" rear=", rear_metrics,
			" reflection=", reflection_metrics,
			" front=", front_metrics)
	stage.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)


func _disable_environment_motion(stage: BattleStage) -> void:
	for source_name: String in [
		"MidgroundCenter", "MidgroundLeft", "MidgroundRight", "ForegroundLeft",
	]:
		var source := stage.get_node_or_null(source_name) as TextureRect
		if source == null:
			continue
		var material := source.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("branch_motion_enabled", 0.0)
	for glow_name: String in [
		"MidgroundCenterGlowFX", "MidgroundCenterGrassGlowFX",
		"MidgroundLeftGlowFX", "MidgroundRightGlowFX",
		"MidgroundRightGrassGlowFX", "ForegroundLeftGlowFX",
	]:
		var glow := stage.get_node_or_null(glow_name) as CanvasItem
		if glow != null:
			glow.visible = false


func _hide_stage_canvas(stage: BattleStage) -> void:
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false


func _show_static_reflection_sources(stage: BattleStage) -> void:
	for node_name: String in ["MidgroundCenter", "MidgroundLeft", "MidgroundRight"]:
		var item := stage.get_node(node_name) as CanvasItem
		item.visible = true


func _measure_motion(
		viewport: SubViewport,
		material: ShaderMaterial,
		sample_rect: Rect2i) -> Dictionary:
	var positions: Array[Vector2i] = []
	for y: int in range(sample_rect.position.y, sample_rect.end.y, SAMPLE_STEP):
		for x: int in range(sample_rect.position.x, sample_rect.end.x, SAMPLE_STEP):
			positions.append(Vector2i(x, y))
	var minimums := PackedFloat32Array()
	var maximums := PackedFloat32Array()
	minimums.resize(positions.size())
	maximums.resize(positions.size())
	minimums.fill(10.0)
	maximums.fill(-1.0)
	for sample_time: float in SAMPLE_TIMES:
		material.set_shader_parameter("diagnostic_time_sec", sample_time)
		RenderingServer.force_draw(false, 0.0)
		var frame := viewport.get_texture().get_image()
		for index: int in range(positions.size()):
			var luma := _luma(frame.get_pixelv(positions[index]))
			minimums[index] = minf(minimums[index], luma)
			maximums[index] = maxf(maximums[index], luma)
	var maximum_range := 0.0
	var range_total := 0.0
	var readable_samples := 0
	for index: int in range(positions.size()):
		var value_range := maximums[index] - minimums[index]
		maximum_range = maxf(maximum_range, value_range)
		range_total += value_range
		if value_range >= 0.035:
			readable_samples += 1
	return {
		"sample_count": positions.size(),
		"readable_samples": readable_samples,
		"maximum_range": snappedf(maximum_range, 0.0001),
		"mean_range": snappedf(range_total / float(positions.size()), 0.0001),
	}


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
