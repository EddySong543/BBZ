extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
var BRANCH_CONTRACT := {
	"MidgroundCenter": [3, PackedInt32Array([1000, 1000, 1000])],
	"MidgroundLeft": [1, PackedInt32Array([1000])],
	"MidgroundRight": [1, PackedInt32Array([2000])],
	"ForegroundLeft": [3, PackedInt32Array([300, 200, 180])],
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := SCENE7.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame
	var passed := true
	var report: Array[String] = []
	for source_name: String in BRANCH_CONTRACT:
		var contract: Array = BRANCH_CONTRACT[source_name]
		var expected_groups: int = contract[0]
		var minimum_counts: PackedInt32Array = contract[1]
		var source := stage.get_node(source_name) as TextureRect
		var material := source.material as ShaderMaterial
		var layer_passed := source.visible and material != null
		var channel_counts: Array[int] = []
		var angle_steps: Array[int] = []
		var peak_screen_motion: Array[float] = []
		var visible_screen_widths: Array[float] = []
		if material != null:
			layer_passed = layer_passed \
					and float(material.get_shader_parameter(
							"branch_motion_enabled")) == 1.0 \
					and int(material.get_shader_parameter(
							"branch_group_count")) == expected_groups
			var mask_texture := material.get_shader_parameter(
					"branch_mask") as Texture2D
			layer_passed = layer_passed and mask_texture != null
			if mask_texture != null:
				var mask_image := mask_texture.get_image()
				layer_passed = layer_passed \
						and mask_image.get_size() == Vector2i(source.texture.get_size())
				var cycles: Vector3 = material.get_shader_parameter("branch_cycle_sec")
				var angles: Vector3 = material.get_shader_parameter("branch_angle_deg")
				var phases: Vector3 = material.get_shader_parameter("branch_phase")
				var fps := float(material.get_shader_parameter("branch_motion_fps"))
				for group_index: int in range(expected_groups):
					var count := _channel_pixel_count(mask_image, group_index)
					channel_counts.append(count)
					layer_passed = layer_passed \
							and count >= minimum_counts[group_index]
					var sampled_angles: Dictionary = {}
					for sample_index: int in range(61):
						var sample_time := float(sample_index) * 0.25
						var stepped_time := floorf(sample_time * fps) / fps
						var phase := stepped_time * TAU / _vector_component(
								cycles, group_index) + _vector_component(
								phases, group_index)
						var angle := snappedf(
								sin(phase) * _vector_component(angles, group_index),
								0.01)
						sampled_angles[angle] = true
					angle_steps.append(sampled_angles.size())
					layer_passed = layer_passed and sampled_angles.size() >= 5
					var peak_motion := _peak_screen_displacement(
							mask_image,
							group_index,
							_branch_pivot(material, group_index),
							_vector_component(angles, group_index),
							source)
					peak_screen_motion.append(snappedf(peak_motion, 0.01))
					var minimum_peak_motion := 10.0 \
							if source_name == "ForegroundLeft" and group_index == 2 \
							else 5.0
					layer_passed = layer_passed \
							and peak_motion >= minimum_peak_motion \
							and peak_motion <= 14.0
					var screen_bounds := _mask_screen_bounds(
							mask_image, group_index, source)
					var visible_bounds := screen_bounds.intersection(
							Rect2(0.0, 0.0, 1920.0, 1080.0))
					visible_screen_widths.append(
							snappedf(visible_bounds.size.x, 0.01))
					layer_passed = layer_passed \
							and visible_bounds.size.x >= 48.0 \
							and visible_bounds.size.y >= 24.0
			var underpaint_enabled := float(material.get_shader_parameter(
					"branch_underpaint_enabled"))
			var underpaint_texture := material.get_shader_parameter(
					"branch_underpaint_texture") as Texture2D
			layer_passed = layer_passed \
					and underpaint_enabled == 1.0 \
					and underpaint_texture != null
			if underpaint_texture != null:
				var moving_pixel_count := 0
				for group_count: int in channel_counts:
					moving_pixel_count += group_count
				var underpaint_pixel_count := _opaque_pixel_count(
						underpaint_texture.get_image())
				layer_passed = layer_passed \
						and underpaint_pixel_count >= 100 \
						and underpaint_pixel_count >= moving_pixel_count
		passed = passed and layer_passed
		report.append(
				"%s:pixels=%s,angle_steps=%s,peak_screen_px=%s,visible_width=%s" % [
				source_name, channel_counts, angle_steps, peak_screen_motion,
				visible_screen_widths])
	for old_motion_name: String in [
		"MidgroundCenterLeafMotion",
		"MidgroundLeftLeafMotion",
		"MidgroundRightLeafMotion",
	]:
		passed = passed and stage.get_node_or_null(old_motion_name) == null

	var glow_varieties := true
	var glow_reports: Array[String] = []
	var glow_contract := {
		"MidgroundLeftGlowFX": ["MidgroundLeft", true, false, false],
		"MidgroundCenterGlowFX": ["MidgroundCenter", true, false, false],
		"MidgroundCenterGrassGlowFX": ["MidgroundCenter", false, true, true],
		"MidgroundRightGlowFX": ["MidgroundRight", true, false, false],
		"MidgroundRightGrassGlowFX": ["MidgroundRight", false, true, true],
		"ForegroundLeftGlowFX": ["ForegroundLeft", true, false, false],
	}
	for glow_name: String in glow_contract:
		var contract: Array = glow_contract[glow_name]
		var source_name: String = contract[0]
		var expects_points: bool = contract[1]
		var expects_cluster: bool = contract[2]
		var expects_relight: bool = contract[3]
		var material := (stage.get_node(source_name) as TextureRect).material \
				as ShaderMaterial
		if source_name.begins_with("Midground"):
			glow_varieties = glow_varieties \
					and is_zero_approx(float(material.get_shader_parameter(
							"point_twinkle_strength"))) \
					and is_zero_approx(float(material.get_shader_parameter(
							"cluster_breathe_strength"))) \
					and is_zero_approx(float(material.get_shader_parameter(
							"glow_pulse_strength")))
		var overlay := stage.get_node_or_null(glow_name) as MeshInstance2D
		glow_varieties = glow_varieties and overlay != null
		if overlay == null:
			continue
		var point_components := int(overlay.get_meta("point_component_count", 0))
		var point_core_pixels := int(overlay.get_meta("point_core_pixel_count", 0))
		var point_halo_pixels := int(overlay.get_meta("point_halo_pixel_count", 0))
		var cluster_core_pixels := int(overlay.get_meta("cluster_core_pixel_count", 0))
		var cluster_halo_pixels := int(overlay.get_meta("cluster_halo_pixel_count", 0))
		var overlay_material := overlay.material as ShaderMaterial
		glow_varieties = glow_varieties and overlay_material != null
		if expects_points:
			glow_varieties = glow_varieties \
					and point_components >= 3 \
					and point_core_pixels >= point_components \
					and point_halo_pixels > point_core_pixels
		else:
			glow_varieties = glow_varieties \
					and point_components == 0 \
					and point_core_pixels == 0 \
					and point_halo_pixels == 0
		if expects_cluster:
			glow_varieties = glow_varieties \
					and cluster_core_pixels >= 40 \
					and cluster_halo_pixels >= 20
			if glow_name == "MidgroundCenterGrassGlowFX":
				var source_bounds: Rect2i = overlay.get_meta(
						"cluster_core_source_bounds", Rect2i())
				glow_varieties = glow_varieties \
						and cluster_core_pixels >= 2100 \
						and source_bounds.position.x <= 281 \
						and source_bounds.position.y <= 74 \
						and source_bounds.end.x >= 360 \
						and source_bounds.end.y >= 139
		else:
			glow_varieties = glow_varieties \
					and cluster_core_pixels == 0 \
					and cluster_halo_pixels == 0
		if overlay_material != null:
			var expected_shader := \
					"res://assets/shaders/canvas_env_scene7_biolume_cluster_relight.gdshader" \
					if expects_relight else \
					"res://assets/shaders/canvas_env_scene7_biolume_glow_fx.gdshader"
			glow_varieties = glow_varieties \
					and overlay_material.shader.resource_path == expected_shader
			if expects_points:
				glow_varieties = glow_varieties \
						and float(overlay_material.get_shader_parameter(
								"point_core_peak")) >= 0.30 \
						and float(overlay_material.get_shader_parameter(
								"point_halo_peak")) >= 0.14 \
						and float(overlay_material.get_shader_parameter(
								"point_cycle_sec")) >= 7.0
			if expects_cluster:
				glow_varieties = glow_varieties \
						and float(overlay_material.get_shader_parameter(
								"cluster_cycle_sec")) >= 7.5 \
						and (not expects_relight \
								or (float(overlay_material.get_shader_parameter(
										"trough_brightness")) <= 0.75 \
									and float(overlay_material.get_shader_parameter(
										"peak_brightness")) >= 1.20))
		glow_reports.append("%s:p=%s/%s/%s,c=%s/%s" % [
				glow_name, point_components, point_core_pixels,
				point_halo_pixels, cluster_core_pixels, cluster_halo_pixels])
	var center_point_material := (stage.get_node(
			"MidgroundCenterGlowFX") as MeshInstance2D).material as ShaderMaterial
	var center_cluster_material := (stage.get_node(
			"MidgroundCenterGrassGlowFX") as MeshInstance2D).material as ShaderMaterial
	var center_point_mask := (center_point_material.get_shader_parameter(
			"point_mask") as Texture2D).get_image()
	var center_cluster_mask := (center_cluster_material.get_shader_parameter(
			"cluster_mask") as Texture2D).get_image()
	var center_core_overlap := _core_overlap_count(
			center_point_mask, center_cluster_mask)
	glow_varieties = glow_varieties and center_core_overlap == 0
	glow_reports.append("center_collective_point_overlap=%s" % center_core_overlap)
	passed = passed and glow_varieties
	print(
			"SCENE7_MIDGROUND_MOTION: ", "PASS" if passed else "FAIL",
			" branch_motion=", report,
			" glow_overlays=", glow_reports)
	stage.queue_free()
	quit(0 if passed else 1)


func _channel_pixel_count(image: Image, channel: int) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var value := color.r if channel == 0 else (
					color.g if channel == 1 else color.b)
			if color.a >= 0.5 and value >= 0.5:
				count += 1
	return count


func _vector_component(value: Vector3, index: int) -> float:
	if index == 0:
		return value.x
	if index == 1:
		return value.y
	return value.z


func _branch_pivot(material: ShaderMaterial, index: int) -> Vector2:
	if index == 0:
		return material.get_shader_parameter("branch_pivot_a")
	if index == 1:
		return material.get_shader_parameter("branch_pivot_b")
	return material.get_shader_parameter("branch_pivot_c")


func _peak_screen_displacement(
		mask: Image,
		channel: int,
		pivot_uv: Vector2,
		angle_deg: float,
		source: TextureRect) -> float:
	var texture_size := Vector2(mask.get_size())
	var pivot_px := pivot_uv * texture_size
	var pixel_to_screen := source.size / texture_size * source.scale
	var angle := deg_to_rad(angle_deg)
	var maximum := 0.0
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			var color := mask.get_pixel(x, y)
			var value := color.r if channel == 0 else (
					color.g if channel == 1 else color.b)
			if color.a < 0.5 or value < 0.5:
				continue
			var delta := Vector2(x + 0.5, y + 0.5) - pivot_px
			var screen_offset := (delta.rotated(angle) - delta) * pixel_to_screen
			maximum = maxf(maximum, screen_offset.length())
	return maximum


func _mask_screen_bounds(
		mask: Image, channel: int, source: TextureRect) -> Rect2:
	var source_bounds := Rect2i()
	var has_pixel := false
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			var color := mask.get_pixel(x, y)
			var value := color.r if channel == 0 else (
					color.g if channel == 1 else color.b)
			if color.a < 0.5 or value < 0.5:
				continue
			var pixel_rect := Rect2i(x, y, 1, 1)
			source_bounds = pixel_rect if not has_pixel \
					else source_bounds.merge(pixel_rect)
			has_pixel = true
	if not has_pixel:
		return Rect2()
	var texture_size := Vector2(mask.get_size())
	var pixel_scale := source.size / texture_size * source.scale
	return Rect2(
			source.position + Vector2(source_bounds.position) * pixel_scale,
			Vector2(source_bounds.size) * pixel_scale)


func _opaque_pixel_count(image: Image) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			count += int(image.get_pixel(x, y).a > 0.08)
	return count


func _core_overlap_count(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return -1
	var overlap := 0
	for y: int in range(first.get_height()):
		for x: int in range(first.get_width()):
			if first.get_pixel(x, y).r >= 0.5 \
					and second.get_pixel(x, y).r >= 0.5:
				overlap += 1
	return overlap
