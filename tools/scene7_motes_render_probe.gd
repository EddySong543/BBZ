extends Node

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const MOTE_LAYERS: Array[String] = [
	"OasisMotesFar",
	"OasisMotesMid",
	"OasisMotesNear",
]
const SAMPLE_TIMES := [0.0, 2.0, 4.0, 6.0, 8.0, 10.0]
const VISIBLE_DELTA := 0.025
const MINIMUM_CHANGED_PIXELS := [90, 150, 110]


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage := SCENE7.instantiate() as BattleStage
	viewport.add_child(stage)
	await get_tree().process_frame
	await get_tree().process_frame
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	for source_name: String in [
		"MidgroundCenter", "MidgroundLeft", "MidgroundRight", "ForegroundLeft",
	]:
		var source_material := (stage.get_node(source_name) as TextureRect).material \
				as ShaderMaterial
		source_material.set_shader_parameter("branch_motion_enabled", 0.0)
	for glow_name: String in [
		"MidgroundCenterGlowFX", "MidgroundCenterGrassGlowFX",
		"MidgroundLeftGlowFX", "MidgroundRightGlowFX",
		"MidgroundRightGrassGlowFX", "ForegroundLeftGlowFX",
	]:
		(stage.get_node(glow_name) as CanvasItem).visible = false
	for animated_name: String in [
		"RearWater", "RearWaterReflection", "FrontWater",
		"PlatformSpringContact",
	]:
		(stage.get_node(animated_name) as CanvasItem).visible = false
	for mote_name: String in MOTE_LAYERS:
		(stage.get_node(mote_name) as ColorRect).visible = false

	var passed := true
	var reports: Array[String] = []
	for layer_index: int in range(MOTE_LAYERS.size()):
		var mote_name := MOTE_LAYERS[layer_index]
		var layer := stage.get_node(mote_name) as ColorRect
		var material := layer.material as ShaderMaterial
		var bounds := _screen_bounds(layer)
		var best_changed := 0
		var best_mean_delta := 0.0
		var best_max_delta := 0.0
		var first_mask: Dictionary[Vector2i, bool] = {}
		var last_mask: Dictionary[Vector2i, bool] = {}
		for sample_index: int in range(SAMPLE_TIMES.size()):
			material.set_shader_parameter(
					"diagnostic_time_sec", SAMPLE_TIMES[sample_index])
			layer.visible = false
			await RenderingServer.frame_post_draw
			var baseline := viewport.get_texture().get_image()
			layer.visible = true
			await RenderingServer.frame_post_draw
			var frame := viewport.get_texture().get_image()
			var metrics := _difference_metrics(baseline, frame, bounds)
			best_changed = maxi(best_changed, int(metrics["changed_pixels"]))
			best_mean_delta = maxf(
					best_mean_delta, float(metrics["mean_changed_delta"]))
			best_max_delta = maxf(best_max_delta, float(metrics["max_delta"]))
			if sample_index == 0:
				first_mask = metrics["changed_positions"]
			if sample_index == SAMPLE_TIMES.size() - 1:
				last_mask = metrics["changed_positions"]
			layer.visible = false
		var moved_pixels := _symmetric_difference_count(first_mask, last_mask)
		var minimum_changed: int = int(MINIMUM_CHANGED_PIXELS[layer_index])
		var layer_passed: bool = best_changed >= minimum_changed \
				and best_mean_delta >= 0.045 \
				and best_max_delta >= 0.10 \
				and moved_pixels >= 55
		passed = passed and layer_passed
		reports.append(
				"%s:changed=%d,mean=%.3f,max=%.3f,moved=%d,bounds=%s" % [
					mote_name, best_changed, best_mean_delta,
					best_max_delta, moved_pixels, bounds])
		material.set_shader_parameter("diagnostic_time_sec", -1.0)

	print("SCENE7_MOTES_FULL_SCENE_VISIBILITY: ",
			"PASS" if passed else "FAIL", " layers=", reports)
	get_tree().quit(0 if passed else 1)


func _screen_bounds(layer: ColorRect) -> Rect2i:
	var transform := layer.get_global_transform_with_canvas()
	var minimum := transform * Vector2.ZERO
	var maximum := transform * layer.size
	var rect := Rect2i(
			Vector2i(minimum.floor()),
			Vector2i((maximum - minimum).ceil()))
	return rect.intersection(Rect2i(0, 0, 1920, 1080))


func _difference_metrics(
		baseline: Image, frame: Image, bounds: Rect2i) -> Dictionary:
	var changed_positions: Dictionary[Vector2i, bool] = {}
	var changed_delta_total := 0.0
	var max_delta := 0.0
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var before := baseline.get_pixel(x, y)
			var after := frame.get_pixel(x, y)
			var delta := maxf(
					absf(after.r - before.r),
					maxf(absf(after.g - before.g), absf(after.b - before.b)))
			max_delta = maxf(max_delta, delta)
			if delta < VISIBLE_DELTA:
				continue
			var position := Vector2i(x, y)
			changed_positions[position] = true
			changed_delta_total += delta
	var mean_delta := changed_delta_total / maxf(
			float(changed_positions.size()), 1.0)
	return {
		"changed_pixels": changed_positions.size(),
		"mean_changed_delta": mean_delta,
		"max_delta": max_delta,
		"changed_positions": changed_positions,
	}


func _symmetric_difference_count(
		first: Dictionary, second: Dictionary) -> int:
	var count := 0
	for position: Vector2i in first:
		count += int(not second.has(position))
	for position: Vector2i in second:
		count += int(not first.has(position))
	return count
