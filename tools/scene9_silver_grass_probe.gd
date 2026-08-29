extends Node

const SCENE9: PackedScene = preload("res://src/ui/scenes/scene9.tscn")
const CAPTURE_SIZE := Vector2i(1920, 1080)
const GRASS_REGION := Rect2i(0, 310, 1920, 450)


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage := SCENE9.instantiate() as BattleStage
	viewport.add_child(stage)
	for frame_index: int in 3:
		await get_tree().process_frame
	for node_name: String in [
		"SilverGrassland/PerspectiveGround",
		"BattlePlatform",
		"ForegroundLeft",
		"ForegroundRight",
		"CompositionGuides",
	]:
		var layer := stage.get_node_or_null(node_name) as CanvasItem
		if layer != null:
			layer.visible = false

	for frame_index: int in 3:
		await get_tree().process_frame
	var first := viewport.get_texture().get_image()
	await get_tree().create_timer(0.72).timeout
	for frame_index: int in 3:
		await get_tree().process_frame
	var second := viewport.get_texture().get_image()

	var render_metrics := _measure_rendered_grass(first, second,
			(stage.get_node("FrameworkBackdrop") as ColorRect).color)
	var field := stage.get_node("SilverGrassland") as Node2D
	var distribution_metrics := _measure_distribution(field)
	var palette_metrics := _measure_palette_remap(field)
	var passed := (
		bool(render_metrics.get("passed", false))
		and bool(distribution_metrics.get("passed", false))
		and bool(palette_metrics.get("passed", false)))
	print("SCENE9_SILVER_GRASS_PROBE: ", "PASS" if passed else "FAIL",
			" render=", render_metrics,
			" distribution=", distribution_metrics,
			" palette=", palette_metrics)
	stage.queue_free()
	viewport.queue_free()
	get_tree().quit(0 if passed else 1)


func _measure_rendered_grass(
		first: Image, second: Image, backdrop: Color) -> Dictionary:
	if first == null or second == null or first.is_empty() or second.is_empty():
		return {"passed": false, "reason": "render image unavailable"}
	var visible_samples := 0
	var changed_samples := 0
	var luminance_total := 0.0
	var chroma_total := 0.0
	var change_total := 0.0
	var maximum_change := 0.0
	for y: int in range(GRASS_REGION.position.y, GRASS_REGION.end.y, 2):
		for x: int in range(GRASS_REGION.position.x, GRASS_REGION.end.x, 2):
			var before := first.get_pixel(x, y)
			var after := second.get_pixel(x, y)
			var backdrop_distance := _rgb_distance(after, backdrop)
			if backdrop_distance >= 0.055:
				visible_samples += 1
				luminance_total += _luminance(after)
				chroma_total += _chroma(after)
			var change := _rgb_distance(before, after)
			maximum_change = maxf(maximum_change, change)
			if change >= 0.025:
				changed_samples += 1
				change_total += change
	var mean_luminance := luminance_total / maxf(float(visible_samples), 1.0)
	var mean_chroma := chroma_total / maxf(float(visible_samples), 1.0)
	var mean_change := change_total / maxf(float(changed_samples), 1.0)
	return {
		"passed": (
				visible_samples >= 9000
				and changed_samples >= 900
				and mean_luminance >= 0.42
				and mean_chroma <= 0.16
				and mean_change >= 0.045
				and maximum_change >= 0.20),
		"visible_samples_step2": visible_samples,
		"changed_samples_step2": changed_samples,
		"mean_luminance": snappedf(mean_luminance, 0.001),
		"mean_chroma": snappedf(mean_chroma, 0.001),
		"mean_change": snappedf(mean_change, 0.001),
		"maximum_change": snappedf(maximum_change, 0.001),
	}


func _measure_distribution(field: Node2D) -> Dictionary:
	var bands := ["FarGrass", "MidGrass", "NearGrass"]
	var expected_counts := [12, 9, 6]
	var expected_y := [Vector2(607.0, 643.0), Vector2(660.0, 700.0), Vector2(735.0, 775.0)]
	var maximum_allowed_gaps := [260.0, 330.0, 480.0]
	var metrics: Array[Dictionary] = []
	var passed := true
	for band_index: int in bands.size():
		var band := field.get_node(bands[band_index]) as Node2D
		var count := 0
		var minimum_y := INF
		var maximum_y := -INF
		var minimum_scale := INF
		var maximum_scale := -INF
		var phases: Dictionary[float, bool] = {}
		var roots_x: Array[float] = []
		for child: Node in band.get_children():
			var instances := child as MultiMeshInstance2D
			if instances == null or instances.multimesh == null:
				continue
			for instance_index: int in instances.multimesh.instance_count:
				var transform := instances.multimesh.get_instance_transform_2d(instance_index)
				var scale_value := transform.x.length()
				minimum_y = minf(minimum_y, transform.origin.y)
				maximum_y = maxf(maximum_y, transform.origin.y)
				minimum_scale = minf(minimum_scale, scale_value)
				maximum_scale = maxf(maximum_scale, scale_value)
				roots_x.append(transform.origin.x)
				var custom := instances.multimesh.get_instance_custom_data(instance_index)
				phases[snappedf(custom.r, 0.001)] = true
				count += 1
		roots_x.sort()
		var maximum_gap := 0.0
		for root_index: int in range(1, roots_x.size()):
			maximum_gap = maxf(maximum_gap,
					roots_x[root_index] - roots_x[root_index - 1])
		var band_passed: bool = (
				count == expected_counts[band_index]
				and minimum_y >= expected_y[band_index].x
				and maximum_y <= expected_y[band_index].y
				and roots_x.front() <= 10.0
				and roots_x.back() >= 1920.0
				and maximum_gap <= maximum_allowed_gaps[band_index]
				and phases.size() >= count * 0.9)
		passed = passed and band_passed
		metrics.append({
			"band": bands[band_index],
			"count": count,
			"root_y": Vector2(snappedf(minimum_y, 0.1), snappedf(maximum_y, 0.1)),
			"scale": Vector2(snappedf(minimum_scale, 0.001), snappedf(maximum_scale, 0.001)),
			"root_x": Vector2(snappedf(roots_x.front(), 0.1),
					snappedf(roots_x.back(), 0.1)),
			"maximum_root_gap": snappedf(maximum_gap, 0.1),
			"unique_phases": phases.size(),
			"passed": band_passed,
		})
	return {"passed": passed, "bands": metrics}


func _measure_palette_remap(field: Node2D) -> Dictionary:
	var material := (field.get_node("FarGrass/Variant01") as MultiMeshInstance2D).material \
			as ShaderMaterial
	if material == null:
		return {"passed": false, "reason": "grass material unavailable"}
	var source_chroma_total := 0.0
	var mapped_chroma_total := 0.0
	var mapped_luminance_total := 0.0
	var mapped_minimum := 1.0
	var mapped_maximum := 0.0
	var sample_count := 0
	for variant: Node in (field.get_node("FarGrass") as Node2D).get_children():
		var image := (variant as MultiMeshInstance2D).texture.get_image()
		for y: int in range(0, image.get_height(), 2):
			for x: int in range(0, image.get_width(), 2):
				var source := image.get_pixel(x, y)
				if source.a < 0.03:
					continue
				var mapped := _map_silver(source, float(y) / image.get_height(), material)
				var mapped_luminance := _luminance(mapped)
				source_chroma_total += _chroma(source)
				mapped_chroma_total += _chroma(mapped)
				mapped_luminance_total += mapped_luminance
				mapped_minimum = minf(mapped_minimum, mapped_luminance)
				mapped_maximum = maxf(mapped_maximum, mapped_luminance)
				sample_count += 1
	var source_chroma := source_chroma_total / maxf(float(sample_count), 1.0)
	var mapped_chroma := mapped_chroma_total / maxf(float(sample_count), 1.0)
	var mapped_luminance := mapped_luminance_total / maxf(float(sample_count), 1.0)
	return {
		"passed": (
				sample_count >= 10000
				and mapped_chroma <= source_chroma * 0.45
				and mapped_chroma <= 0.12
				and mapped_luminance >= 0.48
				and mapped_maximum - mapped_minimum >= 0.24),
		"samples_step2": sample_count,
		"source_chroma": snappedf(source_chroma, 0.001),
		"mapped_chroma": snappedf(mapped_chroma, 0.001),
		"mapped_luminance": snappedf(mapped_luminance, 0.001),
		"mapped_luminance_range": snappedf(mapped_maximum - mapped_minimum, 0.001),
	}


func _map_silver(source: Color, uv_y: float, material: ShaderMaterial) -> Color:
	var luminance := _luminance(source)
	var height_mask := pow(clampf(1.0 - uv_y, 0.0, 1.0), 0.72)
	var shadow := material.get_shader_parameter("root_shadow") as Color
	var middle := material.get_shader_parameter("silver_mid") as Color
	var tip := material.get_shader_parameter("silver_tip") as Color
	var highlight := material.get_shader_parameter("cool_highlight") as Color
	var silver := shadow.lerp(middle, smoothstep(0.08, 0.58, luminance))
	silver = silver.lerp(tip,
			smoothstep(0.48, 0.94, luminance) * lerpf(0.52, 1.0, height_mask))
	silver = silver.lerp(highlight,
			clampf(height_mask * 0.13, 0.0, 0.18))
	silver = silver.lerp(source,
			float(material.get_shader_parameter("original_color_influence")))
	return Color(silver.r, silver.g, silver.b, source.a)


func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _chroma(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b)) \
			- minf(color.r, minf(color.g, color.b))


func _rgb_distance(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r),
			maxf(absf(first.g - second.g), absf(first.b - second.b)))
