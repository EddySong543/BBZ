extends Node

const BATTLE7 := preload("res://src/ui/battle_screen7.tscn")
const GLOW_CONTRACT := {
	"MidgroundCenterGlowFX": Vector2i(1, 0),
	"MidgroundCenterGrassGlowFX": Vector2i(0, 1),
	"MidgroundLeftGlowFX": Vector2i(1, 0),
	"MidgroundRightGlowFX": Vector2i(1, 0),
	"MidgroundRightGrassGlowFX": Vector2i(0, 1),
	"ForegroundLeftGlowFX": Vector2i(1, 0),
}
const SAMPLE_COUNT := 20


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
		"MidgroundCenter",
		"MidgroundLeft",
		"MidgroundRight",
		"ForegroundLeft",
	]:
		var leaf_material := (stage.get_node(source_name) as TextureRect).material \
				as ShaderMaterial
		leaf_material.set_shader_parameter("branch_motion_enabled", 0.0)
	for glow_name: String in GLOW_CONTRACT:
		(stage.get_node(glow_name) as MeshInstance2D).visible = false
	await RenderingServer.frame_post_draw
	var baseline := viewport.get_texture().get_image()

	var passed := true
	var reports: Array[String] = []
	var point_core_by_layer: Dictionary[String, Array] = {}
	var cluster_core_by_layer: Dictionary[String, Array] = {}
	for glow_name: String in GLOW_CONTRACT:
		var expected_channels: Vector2i = GLOW_CONTRACT[glow_name]
		var expects_points: bool = expected_channels.x == 1
		var expects_cluster: bool = expected_channels.y == 1
		var overlay := stage.get_node(glow_name) as MeshInstance2D
		var glow_material := overlay.material as ShaderMaterial
		var cluster_mask_texture := glow_material.get_shader_parameter(
				"cluster_mask") as Texture2D
		var point_mask := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		point_mask.fill(Color(0.0, 0.0, 0.0, 0.0))
		if expects_points:
			var point_mask_texture := glow_material.get_shader_parameter(
					"point_mask") as Texture2D
			point_mask = point_mask_texture.get_image()
		var cluster_mask := cluster_mask_texture.get_image()
		var point_core_positions := _screen_positions_for_mask(
				overlay, point_mask, 0)
		var point_halo_positions := _screen_positions_for_mask(
				overlay, point_mask, 1)
		var cluster_core_positions := _screen_positions_for_mask(
				overlay, cluster_mask, 0)
		var cluster_halo_positions := _screen_positions_for_mask(
				overlay, cluster_mask, 1)
		point_core_by_layer[glow_name] = point_core_positions
		cluster_core_by_layer[glow_name] = cluster_core_positions

		overlay.visible = true
		var metrics: Dictionary = await _measure_complete_cycle(
				viewport, glow_material, baseline,
				point_core_positions, point_halo_positions,
				cluster_core_positions, cluster_halo_positions)
		overlay.visible = false
		glow_material.set_shader_parameter("diagnostic_time_sec", -1.0)

		var layer_passed := true
		if not expects_points:
			layer_passed = point_core_positions.is_empty() \
					and point_halo_positions.is_empty()
		else:
			layer_passed = (
					not point_core_positions.is_empty()
					and not point_halo_positions.is_empty()
					and float(metrics["point_core_max_range"]) >= 0.10
					and int(metrics["point_core_readable_pixels"]) >= 3
					and float(metrics["point_halo_max_range"]) >= 0.06
					and float(metrics["point_peak_over_off"]) >= 0.14)
		if not expects_cluster:
			layer_passed = layer_passed \
					and cluster_core_positions.is_empty() \
					and cluster_halo_positions.is_empty()
		else:
			layer_passed = layer_passed \
					and not cluster_core_positions.is_empty() \
					and not cluster_halo_positions.is_empty() \
					and float(metrics["cluster_core_mean_range"]) >= 0.055 \
					and float(metrics["cluster_halo_mean_range"]) >= 0.035 \
					and float(metrics["cluster_peak_over_off"]) >= 0.10
		passed = passed and layer_passed
		reports.append("%s:%s" % [glow_name, metrics])

	var collective_overlap_counts := {
		"center": _screen_overlap_count(
				point_core_by_layer["MidgroundCenterGlowFX"],
				cluster_core_by_layer["MidgroundCenterGrassGlowFX"]),
		"right": _screen_overlap_count(
				point_core_by_layer["MidgroundRightGlowFX"],
				cluster_core_by_layer["MidgroundRightGrassGlowFX"]),
	}
	for overlap_count: int in collective_overlap_counts.values():
		passed = passed and overlap_count == 0
	var center_collective_point_clearance := _minimum_screen_distance(
				point_core_by_layer["MidgroundCenterGlowFX"],
				cluster_core_by_layer["MidgroundCenterGrassGlowFX"])
	passed = passed and center_collective_point_clearance >= 16.0

	print(
			"SCENE7_BIOLUME_FULL_SCENE_VISIBILITY: ",
			"PASS" if passed else "FAIL",
			" collective_point_overlap=", collective_overlap_counts,
			" center_point_clearance=", center_collective_point_clearance,
			" layers=", reports)
	get_tree().quit(0 if passed else 1)


func _measure_complete_cycle(
		viewport: SubViewport,
		material: ShaderMaterial,
		baseline: Image,
		point_core_positions: Array[Vector2i],
		point_halo_positions: Array[Vector2i],
		cluster_core_positions: Array[Vector2i],
		cluster_halo_positions: Array[Vector2i]) -> Dictionary:
	var position_groups: Array[Array] = [
		point_core_positions,
		point_halo_positions,
		cluster_core_positions,
		cluster_halo_positions,
	]
	var minimums: Array[PackedFloat32Array] = []
	var maximums: Array[PackedFloat32Array] = []
	for positions: Array in position_groups:
		var group_minimums := PackedFloat32Array()
		var group_maximums := PackedFloat32Array()
		group_minimums.resize(positions.size())
		group_maximums.resize(positions.size())
		group_minimums.fill(10.0)
		group_maximums.fill(-1.0)
		minimums.append(group_minimums)
		maximums.append(group_maximums)

	var longest_cycle := float(material.get_shader_parameter("cluster_cycle_sec"))
	if not point_core_positions.is_empty():
		longest_cycle = maxf(
				longest_cycle,
				float(material.get_shader_parameter("point_cycle_sec")))
	for sample_index: int in range(SAMPLE_COUNT):
		var sample_time := longest_cycle \
				* float(sample_index) / float(SAMPLE_COUNT - 1)
		material.set_shader_parameter("diagnostic_time_sec", sample_time)
		await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image()
		for group_index: int in range(position_groups.size()):
			var positions: Array = position_groups[group_index]
			for position_index: int in range(positions.size()):
				var luma := _luma(frame.get_pixelv(positions[position_index]))
				minimums[group_index][position_index] = minf(
						minimums[group_index][position_index], luma)
				maximums[group_index][position_index] = maxf(
						maximums[group_index][position_index], luma)

	var point_core_stats := _range_stats(
			point_core_positions, baseline, minimums[0], maximums[0], 0.08)
	var point_halo_stats := _range_stats(
			point_halo_positions, baseline, minimums[1], maximums[1], 0.045)
	var cluster_core_stats := _range_stats(
			cluster_core_positions, baseline, minimums[2], maximums[2], 0.045)
	var cluster_halo_stats := _range_stats(
			cluster_halo_positions, baseline, minimums[3], maximums[3], 0.025)
	return {
		"point_core_samples": point_core_positions.size(),
		"point_halo_samples": point_halo_positions.size(),
		"point_screen_bounds": _screen_bounds(point_core_positions),
		"point_core_max_range": point_core_stats["max_range"],
		"point_core_readable_pixels": point_core_stats["readable_pixels"],
		"point_halo_max_range": point_halo_stats["max_range"],
		"point_peak_over_off": point_core_stats["peak_over_off"],
		"cluster_core_samples": cluster_core_positions.size(),
		"cluster_halo_samples": cluster_halo_positions.size(),
		"cluster_screen_bounds": _screen_bounds(cluster_core_positions),
		"cluster_core_max_range": cluster_core_stats["max_range"],
		"cluster_core_mean_range": cluster_core_stats["mean_range"],
		"cluster_halo_max_range": cluster_halo_stats["max_range"],
		"cluster_halo_mean_range": cluster_halo_stats["mean_range"],
		"cluster_peak_over_off": cluster_core_stats["peak_over_off"],
	}


func _screen_bounds(positions: Array[Vector2i]) -> Rect2i:
	if positions.is_empty():
		return Rect2i()
	var minimum := positions[0]
	var maximum := positions[0]
	for position: Vector2i in positions:
		minimum.x = mini(minimum.x, position.x)
		minimum.y = mini(minimum.y, position.y)
		maximum.x = maxi(maximum.x, position.x)
		maximum.y = maxi(maximum.y, position.y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _screen_overlap_count(first: Array, second: Array) -> int:
	var first_positions: Dictionary[Vector2i, bool] = {}
	for position: Vector2i in first:
		first_positions[position] = true
	var overlap_count := 0
	for position: Vector2i in second:
		if first_positions.has(position):
			overlap_count += 1
	return overlap_count


func _minimum_screen_distance(first: Array, second: Array) -> float:
	if first.is_empty() or second.is_empty():
		return INF
	var minimum_distance := INF
	for first_position: Vector2i in first:
		for second_position: Vector2i in second:
			minimum_distance = minf(
					minimum_distance,
					Vector2(first_position).distance_to(Vector2(second_position)))
	return minimum_distance


func _range_stats(
		positions: Array[Vector2i],
		baseline: Image,
		minimums: PackedFloat32Array,
		maximums: PackedFloat32Array,
		readable_threshold: float) -> Dictionary:
	if positions.is_empty():
		return {
			"max_range": 0.0,
			"mean_range": 0.0,
			"readable_pixels": 0,
			"peak_over_off": 0.0,
		}
	var max_range := 0.0
	var range_total := 0.0
	var readable_pixels := 0
	var peak_over_off := 0.0
	for index: int in range(positions.size()):
		var value_range := maximums[index] - minimums[index]
		max_range = maxf(max_range, value_range)
		range_total += value_range
		if value_range >= readable_threshold:
			readable_pixels += 1
		peak_over_off = maxf(
				peak_over_off,
				maximums[index] - _luma(baseline.get_pixelv(positions[index])))
	return {
		"max_range": max_range,
		"mean_range": range_total / float(positions.size()),
		"readable_pixels": readable_pixels,
		"peak_over_off": peak_over_off,
	}


func _screen_positions_for_mask(
		overlay: MeshInstance2D, mask: Image, channel: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	var authored_size: Vector2 = overlay.get_meta("authored_size")
	var transform := overlay.get_global_transform_with_canvas()
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			var color := mask.get_pixel(x, y)
			var channel_value := color.r if channel == 0 else color.g
			if color.a < 0.5 or channel_value < 0.5:
				continue
			var uv := Vector2(
					(float(x) + 0.5) / float(mask.get_width()),
					(float(y) + 0.5) / float(mask.get_height()))
			var screen_point := Vector2i((transform * (uv * authored_size)).round())
			if screen_point.x < 0 or screen_point.y < 0 \
					or screen_point.x >= 1920 or screen_point.y >= 1080 \
					or seen.has(screen_point):
				continue
			seen[screen_point] = true
			result.append(screen_point)
	return result


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
