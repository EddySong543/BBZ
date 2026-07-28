extends Node

## Windowed battle renderer benchmark.
## The probe disables VSync and the project FPS cap only in its own process,
## warms shader pipelines, then records stable render metrics to JSON.

@export_file("*.tscn") var target_scene_path: String
@export var warmup_seconds := 3.0
@export_range(120, 1200, 1) var sample_frames := 360

var _frame_times_ms: Array[float] = []
var _process_times_ms: Array[float] = []
var _draw_calls: Array[float] = []
var _rendered_objects: Array[float] = []
var _rendered_primitives: Array[float] = []


func _ready() -> void:
	if target_scene_path.is_empty() or not ResourceLoader.exists(target_scene_path):
		push_error("Invalid performance probe target: %s" % target_scene_path)
		get_tree().quit(2)
		return

	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	var packed_scene := load(target_scene_path) as PackedScene
	var target := packed_scene.instantiate()
	add_child(target)

	await get_tree().create_timer(warmup_seconds).timeout
	await _sample_rendering()
	await _write_results()
	get_tree().quit()


func _sample_rendering() -> void:
	var previous_tick := Time.get_ticks_usec()
	for frame_index in sample_frames:
		await RenderingServer.frame_post_draw
		var current_tick := Time.get_ticks_usec()
		if frame_index > 0:
			_frame_times_ms.append(float(current_tick - previous_tick) / 1000.0)
			_process_times_ms.append(
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			_draw_calls.append(
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_rendered_objects.append(
					Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			_rendered_primitives.append(
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		previous_tick = current_tick


func _write_results() -> void:
	var output_root := _get_probe_output_root()
	DirAccess.make_dir_recursive_absolute(output_root)
	var target_stem := target_scene_path.get_file().get_basename()
	var sorted_frame_times := _frame_times_ms.duplicate()
	sorted_frame_times.sort()
	var result := {
		"target": target_scene_path,
		"renderer": RenderingServer.get_current_rendering_method(),
		"sample_count": _frame_times_ms.size(),
		"average_fps": 1000.0 / maxf(_average(_frame_times_ms), 0.001),
		"average_frame_ms": _average(_frame_times_ms),
		"p95_frame_ms": _percentile(sorted_frame_times, 0.95),
		"average_process_ms": _average(_process_times_ms),
		"average_draw_calls": _average(_draw_calls),
		"average_rendered_objects": _average(_rendered_objects),
		"average_rendered_primitives": _average(_rendered_primitives),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"pipeline_compilations_canvas":
				Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
		"pipeline_compilations_draw":
				Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		"pipeline_compilations_specialization":
				Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),
	}
	var json_path := output_root.path_join("%s_performance.json" % target_stem)
	var output_file := FileAccess.open(json_path, FileAccess.WRITE)
	if output_file == null:
		push_error("Could not write performance probe output: %s" % json_path)
		get_tree().quit(3)
		return
	output_file.store_string(JSON.stringify(result, "\t"))
	output_file.close()

	await RenderingServer.frame_post_draw
	var screenshot_path := output_root.path_join("%s_performance.png" % target_stem)
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("performance_probe: ", JSON.stringify(result))
	print("performance_probe_json: ", json_path)
	print("performance_probe_screenshot: ", screenshot_path)


func _get_probe_output_root() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("probe-output="):
			return argument.trim_prefix("probe-output=")
	return "D:/Game/BoBoZan/_probe_output"


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _percentile(sorted_values: Array[float], percentile: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(
			int(ceil(percentile * float(sorted_values.size()))) - 1,
			0,
			sorted_values.size() - 1)
	return sorted_values[index]
